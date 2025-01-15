#!/bin/bash


# Description:
#   Copy a linpeas-like script to the clickboard. You can paste it to the target machine (Linux) directly without any file transfer effort.
#   This is helpful to help you to enumerate the target machine.
#   Once you paste the script to the target machine, you can run the command `check` to enumerate:
# Usage (On the target machine): 
#   Usage: check <option>
# Arguments (option):
#   - 1|user|u: check user information
#   - 2|su: check sudo permission
#   - 3|suid: check suid permission
#   - 4|cred-file: check common credential files (i.e., /etc/passwd, /etc/group)
#   - 5|exec|executable: listing executable files
#   - 6|dir|directory: listing interesting directories (e.g., /tmp, /opt)
#   - 7|os: check OS information
#   - 8|ps|proc|process: check running processes
#   - 9|cron|crontab: check cron jobs
#   - 10|net|network: check network information
#   - 11|dir-filename: find interesting filename recursively under the current directory
#   - 12|dir-file: find the interesting file content recursively under the current directory
#   - 13|search-filename <keyword>: search filename with keyword under the current directory
#   - 14|search-file <keyword>: search file content with keyword under the current directory
#   - 15|env: check environment variables
# Example:
#   $ check user             # list user information
#   $ check 3                # list suid permission
#   $ check 14 funny-content # search file content with 'funny-content' under the current directory
function cp_target_script() {
    [[ $1 == "-h" || $1 == "--help" ]] && _help && return 0
    local shell_path="$swiss_root/script/target/target-enum-script.sh"
    local new_file_path="$mktemp.sh"
    \cat $shell_path > $new_file_path
    echo "" >> $new_file_path
    echo "host='$(_get_default_network_interface_ip)'" >> $new_file_path
    echo "clear; log --bold -f green '[i] target-enum-script loaded.\n[i] See: https://github.com/dextermallo/oscp-swiss/blob/main/script/target/target-enum-script.sh'; log --bold -f red '[i] the script was developed under the OSCP+ rules. No auto-exploits.'" >> $new_file_path
    \cat $new_file_path | xclip -selection clipboard
    rm $new_file_path
    _logger -l info "$shell_path copied!"
}

# Description: tcpdump traffic from/to an IP address
# Usage: listen_target <IP> [-i, --interface INTERFACE]
# Arguments:
#  IP: IP address to listen to
#  -i, --interface: Network interface to listen on (default: tun0)
# Example:
#   listen_target 192.168.1.2 # listen on traffic from/to 192.168.1.2 on the default network interface
function listen_target() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    local arg_interface="${_swiss_default_network_interface:-any}"
    local arg_ip=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interface) arg_interface="$2" && shift 2 ;;
            *) arg_ip="$1" && shift ;;
        esac
    done
    [[ -z "$ip" ]] && _logger error "[e] IP address is required" && return 1
    _logger -l info "start listening traffic from $arg_ip under the interface $arg_interface"
    _wrap sudo tcpdump -i "$arg_interface" dst "$arg_ip" or src "$arg_ip"
}

# Description: lookup an IP address's public information
# Usage: target_ipinfo <ip>
# Example:
#   target_ipinfo 8.8.8.8
function target_ipinfo() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    [[ $(_is_ip $1) -eq 1 ]] && curl https://ipinfo.io/$1/json || _logger error "Input must be a IPv4 address."
}