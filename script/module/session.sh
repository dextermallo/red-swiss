#!/bin/bash

export swiss_session="$swiss_root/sessions"

# Description: session management.
function session() {
    [[ $1 == "-h" || $1 == "--help" ]] && _help && return 0

    local arg_option=$(gum choose --header "What do you want to do?" "switch" "init" "edit" "reload" "delete" "clean" "help")

    case $arg_option in
        switch)
            [[ -z $(ls $swiss_session) ]] && _logger -l info "No Session found." && exit 0
            local arg_selected_session=$(ls $swiss_session | sed 's/\.[^.]*$//' | gum choose)
            _load_session "$swiss_session/$arg_selected_session.json"
        ;;
        init)
            local arg_session_name=$(gum input --header="Session name?" --placeholder="Box Name (e.g., HTB-Access)")
            local session_conf_path="$swiss_session/$arg_session_name.json"

            [[ -f $session_conf_path ]] && _logger -l error "Duplicated session name." && return 1
            gum confirm "Create a workspace under the current directory?" && arg_create_workspace=1 || arg_create_workspace=0
            local workspace_snippet
            if [[ "$arg_create_workspace" -eq 1 ]]; then
                [[ -d $arg_session_name ]] && _logger -l error "Duplicated directory under $pwd." && return 1
                mkdir $arg_session_name && cd $arg_session_name
                gum confirm "Setting up common files in workspace? (username.txt, password.txt, reports/)" && arg_setup_workspace=1 || arg_setup_workspace=0

                if [[ "$arg_setup_workspace" -eq 1 ]]; then
                    [[ -f "$_swiss_session_default_username_wordlist" ]] && cp $_swiss_session_default_username_wordlist username.txt || touch username.txt
                    [[ -f "$_swiss_session_default_password_wordlist" ]] && cp $_swiss_session_default_password_wordlist password.txt || touch password.txt
                    mkdir reports
                fi
                workspace_snippet=", \"workspace\": \"$(pwd)"\"
            fi

            gum write --header="Setting up the session arguments. Noted that don't override existing arguements (e.g., path)" \
                --value="{ \"ip\": \"\", \"domain\": \"\"$workspace_snippet }" > $session_conf_path
            _logger -l info "Now you can use \$<arg-name> to get the value! (e.g., ping \$ip)"

            local tmp_conf="$(mktemp).json"
            jq --arg path "$session_conf_path" '.variable.used_session = $path' "$swiss_settings" > $tmp_conf && mv $tmp_conf "$swiss_settings"

            _load_session
        ;;
        edit)
            local used_session=$(jq -r '.variable.used_session // empty' "$swiss_settings")
            $EDITOR $used_session
            _set_session $used_session
        ;;
        reload)
            local used_session=$(jq -r '.variable.used_session // empty' "$swiss_settings")
            _set_session $used_session
        ;;
        delete)
            [[ -z $(ls $swiss_session) ]] && _logger -l info "No Session found." && exit 0
            local arg_selected_session=$(ls $swiss_session | sed 's/\.[^.]*$//' | gum choose)
            _delete_session "$swiss_session/$arg_selected_session.json"
        ;;
        clean)
            local tmp_conf="$(mktemp).json"
            jq '.variable.used_session = ""' $swiss_settings > $tmp_conf && mv $tmp_conf $swiss_settings
            rm -rf $swiss_session
            mkdir $swiss_session
        ;;
        help)
        _help
        ;;
    esac
}

function _unset_session() {
    [[ ! -z $1 ]] && jq -r 'to_entries[] | "\(.key)=\(.value)"' "$1" | while IFS="=" read -r key value; do unset $key; done
}

function _set_session() {
    [[ -z $1 ]] && _logger -l error "Missing session file" && return 1
    jq -r 'to_entries[] | "\(.key)=\(.value)"' "$1" | while IFS="=" read -r key value; do export "$key=$value"; done
    [[ ! -z $workspace && -d $workspace ]] && cd $workspace
}

function _load_session() {
    local used_session=$(jq -r '.variable.used_session // empty' "$swiss_settings")
    [[ -z $1 ]] && _set_session $used_session && return 0
    local arg_load_session=$1
    _unset_session $used_session
    _set_session $arg_load_session
}

function _delete_session() {
    [[ -z $1 ]] && _logger -l error "Missing session file" && return 1
    
    local used_session=$(jq -r '.variable.used_session // empty' "$swiss_settings")

    if [[ $1 = "$used_session" ]]; then
        _logger -l warn "Removing from the used_session"
        local tmp_conf="$(mktemp).json"
        jq '.variable.used_session = ""' $swiss_settings > $tmp_conf && mv $tmp_conf $swiss_settings
    fi

    workspace=$(jq -r '.workspace // empty' $1)

    if [[ -d $workspace ]]; then
        gum confirm "Create a workspace under the current directory?" && arg_delete_workspace=1 || arg_delete_workspace=0
        [[ $arg_delete_workspace -eq 1 ]] && rm -rf $workspace
    fi

    rm -rf $1
}

function _sticky_session() {
    if [[ "$_swiss_session_sticky_session" == true ]]; then
        local used_session=$(jq -r '.variable.used_session // empty' "$swiss_settings")
        [[ ! -z "$used_session" ]] && _load_session
    fi
}

_sticky_session