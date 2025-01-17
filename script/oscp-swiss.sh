#!/bin/bash
# About oscp-swiss.sh
# The oscp-swiss.sh is the main script that contains the main functions to support the OSCP exam.
# It loads all the modules under the script/module directory and other necessary scripts.

export SWISS_VERSION=2.0.0

export swiss_root="$HOME/oscp-swiss"
export swiss_script="$swiss_root/script"
export swiss_alias="$swiss_root/script/alias.sh"
export swiss_extension="$swiss_root/script/extension.sh"
export swiss_utils="$swiss_root/script/utils"
export swiss_module="$swiss_root/script/module"
export swiss_private="$swiss_root/private"
export swiss_wordlist="$swiss_root/wordlist"
export swiss_settings="$swiss_root/settings.json"

for script in "$swiss_utils"/*.sh; do source $script; done
_load_settings
_load_private_scripts

source $swiss_alias
source $swiss_extension

for script in "$swiss_module"/*.sh; do
    is_enabled=0
    module_name="${script##*/}"

    for enable_module in $(echo "$_swiss_used_module" | jq -r '.[]'); do
        [[ "$enable_module" == "$module_name" ]] && is_enabled=1
    done

    [[ "$is_enabled" -eq 1 ]] && source $script
done

# Description: Find the commands, aliases, or variable you need.
# Usage: swiss [-h|--help] <module>
# Arguments:
#   - module: see /script/module. Current support:
#     + bruteforce    functions relate to bruteforce
#     + crypto        functions relate to cryptography
#     + exploit       functions to support you search and craft payloads for exploitation.
#     + host          functions to use on your host (virtual machine).
#     + machine       functions to use on your real physical machine.
#     + payload       functions relate to payload.
#     + prep          functions before you start the work.
#     + recon         functions relate to recon.
#     + target        functions relate to the target machine.
#     + workspace     functions to manage cross-terminal session, faster to navigate.
#     + private       all scripts (.sh) under the directory /private
# Example:
#   swiss bruteforce
function swiss() {
    _parse() {
        if grep -qE '^\s*function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)\s*\{' "$1"; then
            _logger -l info "Function under $1:"
            _logger -l info "Check function instructions with <command> -h or which <command>"
            grep -E '^\s*function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)\s*\{' "$1" | sed -E 's/^\s*function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)\s*\{/\1/' | sort | column
        fi
        if grep -qE '^\s*alias\s+' "$1"; then
            _logger -l info "Alias under $1:"
            grep -E '^\s*alias\s+' "$1" | sed -E 's/^\s*alias\s+([a-zA-Z_][a-zA-Z0-9_]*)=.*/\1/' | sort | column
        fi
        if grep -qE '^\s*[a-zA-Z_][a-zA-Z0-9_]*=' "$1"; then
            _logger -l info "Variable under $1:"
            grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*=' "$1" | sed -E 's/^\s*([a-zA-Z_][a-zA-Z0-9_]*)=.*/\1/' | sort | column
        fi
    }

    local module

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) _help && return 0 ;;
            -v|--version) _banner swiss && return 0 ;;
            *) module=$1 && shift ;;
        esac
    done

    case $module in
        private)
        if [[ -d "$swiss_private" ]]; then
            for script in "$swiss_private"/*.sh; do [[ -f "$script" ]] && _parse $script; done
        else
            _logger -l error "Directory $swiss_private not found."
        fi
        ;;
        utils) for script in "$swiss_utils"/*.sh; do [[ -f "$script" ]] && _parse $script; done ;;
        alias|extension) _parse "$swiss_script/$module.sh" ;;
        bruteforce|crypto|help-exploit|host|machine|payload|prep|recon|target|workspace) _parse "$swiss_script/module/$module.sh" ;;
        *) _logger -l error "Invalid modules. see -h | --help." ;;
    esac
}

function wordlist() {
    arg_option=$(gum choose --header "Looking for wordlists?" "frequent used" "current directory" "wordlist base directory")

    case $arg_option in
        "frequent used")
            _wrap ls -l /usr/share/wordlists
        ;;
        "current directory")
            gum file .
        ;;
        "wordlist base directory")
            _wrap ls -l /usr/share/wordlists
        ;;
    esac
}