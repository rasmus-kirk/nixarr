show-help() {
  cat <<EOF >&2
Usage: $0 <json-user-config> <json-*arr-base>

Applies user-supplied config to a base *arr config.

Expects two positional arguments:

1) JSON config with user-supplied fields and top-level items in the format
produced by this module, e.g:
{
  "someTopLevelItem": "someValue",
  "fields": {
    "someField": "someValue",
    "secretField": {
      "secret": "/path/to/secret/file"
    }
  }
}

2) *arr JSON config (either from a schema or an existing config), e.g:
{
  "someTopLevelItem": "oldValue",
  ...,
  "fields": [
    {
      "name": "someField",
      "value": "oldValue",
      ... # Other per-field properties
    },
    {
      "name": "secretField",
      "value": "oldSecretValue",
      ...
    },
    {
      "name": "unchangedField",
      "value": true,
      ...
    }
  ]
}

Prints (on stdout) the *arr JSON config with field values and top-level items
updated from the user-supplied config, e.g:
{
  "someTopLevelItem": "someValue",
  ..., # Other top-level properties unchanged
  "fields": [
    {
      "name": "someField",
      "value": "someValue",
      ... # Other per-field properties unchanged
    },
    {
      "name": "secretField",
      "value": "actual secret value from file", # Always a string
      ...
    },
    {
      "name": "unchangedField",
      "value": true,
      ...
    }
  ]
}

Exits with status 1 and an error message (on stderr):
  * if any user-supplied fields are not expected by the *arr config.
  * if any of the secret files cannot be read.
EOF
}

if [ "$#" -ne 2 ] || [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
  show-help
  exit 1
fi

cfg=$1
base=$2

# Check `fields` keys against base config. When updating the base config, we
# iterate over the fields in the base config to find user values in `cfg`, so
# any unsupported fields would be silently ignored.
>/dev/null jq \
  --null-input \
  --argjson cfg "$cfg" \
  --argjson base "$base" \
  '
  ($base.fields | map(.name)) as $supported |
  ($cfg.fields | keys) as $provided |
  ($provided - $supported) as $unsupported |
  if $unsupported != []
  then
    "Unsupported fields found: \($unsupported | join(", ")). Supported fields: \($supported | join(", "))." |
    halt_error
  end
  '

# Check non-`fields` keys against base config. *arr apps will *accept* extra
# fields, but we want to catch typos etc.
>/dev/null jq \
  --null-input \
  --argjson cfg "$cfg" \
  --argjson base "$base" \
  '
  ($base | keys - ["fields"]) as $supported |
  ($cfg | keys - ["fields", "name"]) as $provided |
  ($provided - $supported) as $unsupported |
  if $unsupported != []
  then
    "Unsupported top-level items found: \($unsupported | join(", ")). Supported top-level items: \($supported | join(", "))." |
    halt_error
  end
  '

# Expand secrets in `fields`.
for secret_field_b64 in $(
  <<<"$cfg" jq --raw-output \
    '
    .fields |
    to_entries |
    .[] |
    select(.value.secret? != null) |

    # To handle whitespace in keys/paths
    @base64 "\(.key),\(.value.secret)"
    '
); do
  key=$(<<<"${secret_field_b64%,*}" base64 --decode)
  path=$(<<<"${secret_field_b64##*,}" base64 --decode)
  secret=$(<"$path")
  cfg=$(<<<"$cfg" jq \
    --arg key "$key" \
    --arg secret "$secret" \
    '.fields[$key] = $secret')
done

# Expand secrets in non-`fields` top-level items.
for secret_item_b64 in $(
  <<<"$cfg" jq --raw-output \
    '
    del(.fields) |
    to_entries |
    .[] |
    select(.value.secret? != null) |

    # To handle whitespace in keys/paths
    @base64 "\(.key),\(.value.secret)"
    '
); do
  key=$(<<<"${secret_item_b64%,*}" base64 --decode)
  path=$(<<<"${secret_item_b64##*,}" base64 --decode)
  secret=$(<"$path")
  cfg=$(<<<"$cfg" jq \
    --sort-keys \
    --compact-output \
    --arg key "$key" \
    --arg secret "$secret" \
    '.[$key] = $secret')
done

<<<"$base" jq \
  --sort-keys \
  --compact-output \
  --argjson cfg "$cfg" \
  '
  # Update field values.
  .fields[] |= (.value = ($cfg.fields[.name] // .value)) |

  # Update other top-level items.
  reduce (
    $cfg |
    del(.fields) |
    to_entries |
    .[]
  ) as $item (.;
    .[$item.key] |= $item.value // .
  )
  '
