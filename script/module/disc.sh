#!bin/bash
# About machine.sh
# The machine.sh is for the functions that are used on your machine. (not your VM)

# Description:
#   Run a docker container with a x86-based kali.
#   This is useful for Mac M-series users, which you can use the x86-based kali
#   to compile the exploit or tools that are not supported on the ARM-based kali.
function x64_kali() {
    _banner extension podman
    podman run -it --rm --privileged --userns=host --platform linux/amd64 -v $HOME:$HOME kalilinux/kali-rolling
}

# Description:
#   Upload a file to the ffsend.
#   In some cases, you may have issue regarding transferring files between your host and the VM.
#   You can use the ffsend to upload the file to the ffsend server and download it from the VM.
function upload() {
    _banner extension ffsend
    ffsend upload $1 --copy-cmd
}

# Description:
#   Lookup the public IP address of the host.
#   This does not be used in the OSCP exam but IRL.
# Usage: host_public_ip
function host_public_ip() {
    _wrap curl ipinfo.io/ip
}

# Description: alternative wraps for googler
# Usage: google [-h, --help] <KEYWORD>
function google() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    _banner extension googler
    googler $@ --count 5 --np -x
}

# Description: copy a file to the clickboard
# Usage: copy <FILE>
function copy() {
    [[ -f $1 ]] && \cat $1 | xclip -selection clickboard || _logger -l error "File not found."
}

# Description:
#   Generates a markdown report from all files in a directory.
#   Reads all files in the specified path (or current directory by default)
#   and creates a `report.md` with their contents formatted for a README.
# Usage:
#   generate_report [-p|--path PATH] [-o|--output OUTPUT_PATH]
# Arguments:
#   -p, --path    Specify the directory to scan (default: current directory).
#   -o, --output  Specify the output file path (default: ./report.md).
function generate_report() {
    local dest_path="$PWD"
    local output_file="$PWD/report.md"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--path) dest_path="$2" && shift 2 ;;
            -o|--output) output_file="$2" && shift 2 ;;
            *) _logger error "[e] Unknown argument: $1. See -h, --help." && return 1 ;;
        esac
    done

    echo "" > "$output_file"

    process_files() {
        local current_path="$1"
        for file in "$current_path"/*; do
            if [[ -d "$file" ]]; then
                process_files "$file"
            elif [[ -f "$file" && "$file" != "$output_file" ]]; then
                local filetype="${file##*.}"
                [[ "$file" == *.* ]] || filetype=""

                local relative_path="${file#$dest_path/}"
                echo "- \`$relative_path\`" >> "$output_file"
                echo -e "\t\`\`\`$filetype" >> "$output_file"
                sed 's/^/\t/' "$file" >> "$output_file"
                echo -e "\t\`\`\`" >> "$output_file"
            fi
        done
    }

    process_files "$dest_path"
    _logger info "[i] Report generated at: $output_file"
}