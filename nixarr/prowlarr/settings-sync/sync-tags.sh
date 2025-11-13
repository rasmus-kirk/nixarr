shopt -s inherit_errexit

show-help() {
  cat <<EOF >&2
Usage: $0 <json-array-of-tag-labels>

Adds the specified tags to Prowlarr if they do not already exist.
EOF
}

if [ "$#" -ne 1 ] || [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
  show-help
  exit 1
fi

to_insert=$1

sync-tag() {
  local label=$1

  echo "Syncing tag '$label'"

  data=$(
    jq \
      --compact-output \
      --null-input \
      --arg label "$label" \
      '{ label: $label }'
  )

  call-prowlarr-api \
    tag \
    --request POST \
    --header 'Content-Type: application/json' \
    --data-binary "$data" \
    --output /dev/null ||
    {
      echo "Error: Failed to create tag '$label'. Check Prowlarr logs for details." >&2
      return 1
    }
}

failed=0

for label_b64 in $(
  <<<"$to_insert" jq \
    --raw-output \
    --compact-output \
    --argjson existing "$(call-prowlarr-api tag)" \
    '
    . - ($existing | map(.label)) |
    .[] |

    # To handle whitespace in labels
    @base64
    ' || exit 1
); do
  label=$(<<<"$label_b64" base64 --decode)
  sync-tag "$label" || failed=1
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi
