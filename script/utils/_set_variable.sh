function _set_variable() {
    local key=$1
    local value=$2
    local override=$3

    # if value is an array, convert it to json array
    if [[ $value =~ ^\[.*\]$ ]]; then
        value=$(echo "$value" | jq -c .)
    else
        value=$(jq -c -n --arg val "$value" '$val')
    fi

    [[ -z $key || -z $value ]] && _logger -l error "Missing key or value." && return 1
    
    local cur_value=$(jq -r ".variable.$key // empty" "$swiss_settings")

    if [[ -z $cur_value ]]; then
        # update $swiss_setting
        local tmp_conf="$(mktemp).json"
        jq ".variable.$key = $value" "$swiss_settings" > "$tmp_conf" && mv "$tmp_conf" "$swiss_settings"

        return 0
    fi

    if [[ $override == true ]]; then
        # update $swiss_setting
        local tmp_conf="$(mktemp).json"
        jq ".variable.$key = $value" "$swiss_settings" > "$tmp_conf" && mv "$tmp_conf" "$swiss_settings"
    else
        _logger -l error "Variable $key is already set."
        return 1
    fi
}

function _get_variable() {
    local key=$1
    local value=$(jq -r ".variable.$key // empty" "$swiss_settings")

    if [[ -z $value ]]; then
        _logger -l error "Variable $key is not set."
        return 1
    fi

    echo $value
}