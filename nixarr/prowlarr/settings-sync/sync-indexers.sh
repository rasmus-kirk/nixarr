show-help() {
  cat <<EOF >&2
Usage: $0 <json-array-of-user-indexer-configs>

Adds or updates indexers in Prowlarr based on the specified user configs.
EOF
}

if [ "$#" -ne 1 ] || [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
  show-help
  exit 1
fi

cfgs=$1

tagIds=$(
  call-prowlarr-api tag |
    jq \
      --sort-keys \
      --compact-output \
      'reduce .[] as $tag ({}; .[$tag.label] = $tag.id)'
)
schemas=$(
  call-prowlarr-api indexer/schema |
    jq --sort-keys --compact-output .
)
appProfiles=$(
  call-prowlarr-api appprofile |
    jq --sort-keys --compact-output .
)

sync-indexer() {
  local cfg=$1

  local schema
  schema=$(
    <<<"$schemas" jq \
      --sort-keys \
      --compact-output \
      --argjson cfg "$cfg" \
      '
      map(select(.sortName == $cfg.sortName)) |
      first // (
        "Error: Could not find schema for indexer with sortName \($cfg.sortName)" |
        halt_error
      )
      '
  ) || return 1

  cfg=$(
    <<<"$cfg" jq \
      --sort-keys \
      --compact-output \
      --argjson schema "$schema" \
      '
      # Default to schema name if .name is not provided
      .name //= $schema.name
      '
  )

  local name
  name=$(<<<"$cfg" jq --raw-output '.name')

  echo "Syncing indexer '$name'"

  cfg=$(
    <<<"$cfg" jq \
      --sort-keys \
      --compact-output \
      --argjson tagIds "$tagIds" \
      --argjson appProfiles "$appProfiles" \
      '
      .name as $name |

      # Replace app profile name with resolved ID
      .appProfileId = (
        .appProfileName as $appProfileName |
        $appProfiles |
        map(select(.name == $appProfileName) | .id) |
        first // (
          "Error: Could not find application profile with name \($appProfileName) in Prowlarr" |
          halt_error
        )
      ) |
      del(.appProfileName) |

      # Replace tag labels with resolved IDs
      .tags = (
        .tagLabels |
        map(
          $tagIds[.] // (
            "Error while processing indexer \($name): Could not find tag with label \(.) in Prowlarr" |
            halt_error
          )
        )
      ) |
      del(.tagLabels)
      '
  ) || return 1

  # Find existing indexer by name, if any. Note that Prowlarr requires indexers
  # to have unique names *ignoring case*.
  local existingIndexer
  existingIndexer=$(
    call-prowlarr-api indexer |
      jq \
        --sort-keys \
        --compact-output \
        --argjson cfg "$cfg" \
        '
        .[] |
        select(.name == $cfg.name) |
        if .sortName != $cfg.sortName
        then
          "Sort name conflict when updating indexer \($cfg.name) with sortName \($cfg.sortName):\nAn existing indexer with name (.name) has a different sortName \(.sortName). Please either remove the existing indexer or choose a different name." |
          halt_error
        end
        '
  ) || return 1

  local url method oldIndexer
  if [ -z "$existingIndexer" ]; then
    url="indexer"
    method="POST"
    oldIndexer="$schema"
  else
    url="indexer/$(<<<"$existingIndexer" jq --raw-output '.id')"
    method="PUT"
    oldIndexer="$existingIndexer"
  fi

  local newIndexer
  newIndexer=$(apply-fields "$cfg" "$oldIndexer") || return 1

  call-prowlarr-api \
    "$url" \
    --request $method \
    --header 'Content-Type: application/json' \
    --data-binary "$newIndexer" \
    --output /dev/null || {
    echo "Error: Failed to process indexer '$name'. Check Prowlarr logs for details." >&2
    return 1
  }
}

failed=0

for cfg_b64 in $(
  <<<"$cfgs" jq \
    --raw-output \
    --compact-output \
    '
    # To handle whitespace in keys/values
    .[] | @base64
    '
); do
  cfg=$(<<<"$cfg_b64" base64 --decode)
  sync-indexer "$cfg" || failed=1
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi
