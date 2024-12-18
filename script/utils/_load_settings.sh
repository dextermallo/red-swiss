# Description:
#   Load the settings from the settings.json file.
#   All the key-value pairs under `global_settings` and `functions` are exported as environment variables.
#   Default location: $HOME/oscp-swiss/settings.json
# Usage: _load_settings
function _load_settings() {
    if [ ! -f "$swiss_settings" ]; then
        _logger error "[e] $swiss_settings not found."
        return 1
    fi
    while IFS="=" read -r key value; do
        export "_swiss_$key"="$value"
    done < <(jq -r '.global_settings | to_entries | .[] | "\(.key)=\(.value)"' "$swiss_settings")
    while IFS="=" read -r key value; do
        export "_swiss_$key"="$value"
    done < <(jq -r '.functions | to_entries[] | .key as $k | .value | to_entries[] | "\($k)_\(.key)=\(.value)"' "$swiss_settings")
}