show-help() {
  cat <<EOF >&2
Usage: $0 <json-array-of-user-application-configs>

Adds or updates applications in Prowlarr based on the specified user configs.
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
  call-prowlarr-api applications/schema |
    jq --sort-keys --compact-output .
)

sync-application() {
  local cfg=$1

  local name
  name=$(<<<"$cfg" jq --raw-output '.name')

  echo "Syncing application '$name'"

  local schema
  schema=$(
    <<<"$schemas" jq \
      --sort-keys \
      --compact-output \
      --argjson cfg "$cfg" \
      '
      map(select(.implementationName == $cfg.implementationName)) |
      first // (
        "Error: Could not find schema for application with implementationName \($cfg.implementationName)" |
        halt_error
      )
      '
  ) || return 1

  cfg=$(
    <<<"$cfg" jq \
      --sort-keys \
      --compact-output \
      --argjson tagIds "$tagIds" \
      '
      .name as $name |

      # Replace tag labels with resolved IDs
      .tags = (
        .tagLabels |
        map(
          $tagIds[.] // (
            "Error while processing application \($name): Could not find tag with label \(.) in Prowlarr" |
            halt_error
          )
        )
      ) |
      del(.tagLabels)
      '
  ) || return 1

  # Find existing application by name, if any. Note that Prowlarr requires
  # applications to have unique names *ignoring case*.
  local existingApplication
  existingApplication=$(
    call-prowlarr-api applications |
      jq \
        --sort-keys \
        --compact-output \
        --argjson cfg "$cfg" \
        '
        .[] |
        select(.name == $cfg.name) |
        if .implementationName != $cfg.implementationName
        then
          "Implementation name conflict when updating application \($cfg.name) with implementationName \($cfg.implementationName):\nAn existing application with name (.name) has a different implementationName \(.implementationName). Please either remove the existing application or choose a different name." |
          halt_error
        end
        '
  ) || return 1

  local url method oldApplication
  if [ -z "$existingApplication" ]; then
    url="applications"
    method="POST"
    oldApplication="$schema"
  else
    url="applications/$(<<<"$existingApplication" jq --raw-output '.id')"
    method="PUT"
    oldApplication="$existingApplication"
  fi

  local newApplication
  newApplication=$(apply-fields "$cfg" "$oldApplication") || return 1

  call-prowlarr-api \
    "$url" \
    --request $method \
    --header 'Content-Type: application/json' \
    --data-binary "$newApplication" \
    --output /dev/null || {
    echo "Error: Failed to process application '$name'. Check Prowlarr logs for details." >&2
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
  sync-application "$cfg" || failed=1
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi
