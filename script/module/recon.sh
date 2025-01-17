#!/bin/bash


# Description: Wrapped nmap command with default options
# Usage: recon [-s, --service SERVICE] [-m, --mode MODE] <-i, --ip IP>
# Arguements
# Modes: fast (default), tcp, udp, udp-all, stealth
# Example: recon 192.168.1.1
function recon() {
    [[ $1 == "-h" || $1 == "--help" ]] && _help && return 0

    local arg_ip=$(gum input --header="IP address?" --value=$(_get_default_argument "ip"))
    local arg_tool=$(gum choose --header "Used utilities" "rustscan" "nmap")
    local report_path="$(pwd)/reports"

    check_service_and_vuln() {
        local data_path=$1
        local ports=$(grep -oP '^\d+\/\w+' $data_path | awk -F/ '{print $1}' | tr '\n' ',' | sed 's/,$//')
        _logger -l warn "Ports found: $ports."
        _logger -l info "Checking service on ports. Saved to $data_path-svc"
        _wrap nmap -p$ports -sVC $arg_ip -oN $data_path-svc
        _logger -l info "Checking with nmap vuln script. Saved to $data_path-vuln"
        _wrap nmap -p$ports --script vuln $arg_ip -oN $data_path-vuln
    }

    if [[ ! $(_is_ip $arg_ip) ]]; then
        _logger -l error "invalid ip format" && return 1
    fi

    case "$arg_tool" in
        nmap) 
            local saved_file_path="$(pwd)/reports/nmap/$arg_ip"
            _logger info "[i] Creating directory $saved_file_path ..."
            mkdir -p $saved_file_path
            local modes=$(gum choose --header "Mode" --no-limit --selected="tcp-5000","udp-200" "tcp-5000" "udp-200" "tcp" "udp" "stealth" )
            echo "$modes" | while IFS= read -r mode; do
                echo "Selected option: $mode"
                case "$mode" in
                    tcp) 
                    local output="$report_path/$arg_ip-nmap-tcp"
                    _wrap nmap -p0-65535 -v $arg_ip -oN $output && check_service_and_vuln $output ;;
                    tcp-5000)
                    local output="$report_path/$arg_ip-nmap-tcp-top-5000"
                    _wrap nmap -v --top-ports 5000 $arg_ip -oN $output && check_service_and_vuln $output ;;
                    udp-200)
                    local output="$report_path/$arg_ip-nmap-udp-top-200"
                    _wrap sudo nmap --top-ports 200 -sU -F -v $arg_ip -oN $output ;;
                    udp) 
                    local output="$report_path/$arg_ip-nmap-udp"
                    _wrap sudo nmap -sU -F -v $arg_ip -oN $output ;;
                    stealth)
                    local output="$report_path/$arg_ip-nmap-stealth"
                    _wrap sudo nmap -sS -p0-65535 $arg_up -Pn -oN $output ;;
                    *) _logger -l error "Invalid mode '$mode'. Valid modes: fast, tcp, udp-200, udp-all, stealth." && return 1 ;;
                esac
            done            
        ;;
        rustscan)
            _wrap "rustscan -a $arg_ip | tee $report_path/$arg_ip-rustscan"
        ;;
    esac
}

# Description: directory fuzzing by default. compatible with original arguments
# Usage: recon_directory [-h, --help] [-m, --mode MODE] <URL> [OPTIONS]
# Arguments:
#   - MODE: dirsearch | ffuf.
#   - URL: URL endpoints. e.g., http://example.com/FUZZ
#   - OPTIONS: options from ffuf or dirsearch.
# Configuration:
#   - functions.recon_directory.recursive_depth: recursive depth
#   - functions.recon_directory.wordlist: default wordlist
# Example:
#   recon_directory http://example.com/FUZZ -fc 400
#   recon_directory -m dirsearch http://example.com
function recon_directory() {
    _logger -l debug "Recursive depth: $_swiss_recon_directory_recursive_depth"
    _logger -l debug "Wordlist: $_swiss_recon_directory_busting_wordlist"

    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0

    local mode="ffuf"
    [[ $1 == '-m' ]] && mode=$2 && shift 2
    
    local domain_dir=$(_create_web_fuzz_report_directory "$1")
    _display_wordlist_statistic $_swiss_recon_directory_busting_wordlist

    case $mode in
        dirsearch)
            [[ ! $(_cmd_is_exist "dirsearch") ]] && _logger error "[e] dirsearch is not installed" && return 1
            _wrap dirsearch -r -R $((_swiss_recon_directory_recursive_depth+1)) -u ${@} -o "$domain_dir/dirsearch-recon"
        ;;
        ffuf)
            _logger hint "[h] You can use -fc 400,403 to make the output clean."
            _wrap ffuf -w $_swiss_recon_directory_busting_wordlist -recursion \
                 -recursion-depth $_swiss_recon_directory_recursive_depth \
                 -c -t 200 \
                 -u ${@} | tee "$domain_dir/ffuf-recon"
        ;;
        *) _logger "[e] Unsupport mode. check -h or --help for instructions." && return 1 ;;
    esac
}

# Description: file traversal fuzzing using ffuf, compatible with original arguments
# Usage: recon_file_traversal [-h, --help] <URL> [options]
#   [!] You may need to try <URL>/FUZZ and <URL>FUZZ
# Arguments:
#   - URL: URL endpoints. e.g., http://example.com/FUZZ
#   - OPTIONS: options from ffuf.
# Configuration:
#   - functions.recon_file_traversal.wordlist: default wordlist
# Example: recon_file_traversal http://example.comFUZZ -fc 403
function recon_file_traversal() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    local domain_dir=$(_create_web_fuzz_report_directory "$1")
    _display_wordlist_statistic $_swiss_recon_file_traversal_wordlist
    _wrap ffuf -w $_swiss_recon_file_traversal_wordlist -c -t 200 -u ${@} | tee "$domain_dir/traversal-recon"
}

# Description: subdomain fuzzing using gobuster, compatible with original arguments
# Usage: fuzz_subdomain [-h, --help] <DOMAIN_NAME> [OPTIONS]
# Arguments:
#   - DOMAIN_NAME: Domain name. e.g., example.com
#   - OPTIONS: options from gobuster.
# Configuration:
#   - functions.fuzz_subdomain.wordlist: default wordlist
# Example: fuzz_subdomain example.com
function fuzz_subdomain() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    local domain_dir=$(_create_web_fuzz_report_directory "$1")
    _display_wordlist_statistic $_swiss_fuzz_subdomain_wordlist
    _wrap gobuster dns -w $_swiss_fuzz_subdomain_wordlist -t 50 -o $domain_dir/fuzz-subdomain -d ${@}
}

# Description: vhost fuzzing using gobuster, compatible with original arguments
# Usage: fuzz_vhost <IP> <DOMAIN_NAME> [OPTIONS]
# Arguments:
#   - IP: IP address
#   - DOMAIN_NAME: Domain name. e.g., example.com
#   - OPTIONS: options from gobuster.
# Configuration:
#   - functions.fuzz_vhost.wordlist: default wordlist
# Example: fuzz_vhost 192.168.1.1 example.com
function fuzz_vhost() {
    [ $# -eq 0 ] && _help && return 0
    local arg_ip="$1"
    local arg_domain="$2"
    local domain_dir=$(_create_web_fuzz_report_directory "$arg_domain")
    _display_wordlist_statistic $_swiss_fuzz_vhost_wordlist
    _wrap gobuster vhost -k -u $arg_ip --domain $arg_domain --append-domain -r -w $_swiss_fuzz_vhost_wordlist -o $domain_dir/fuzz-vhost -t 100
}

# Description: get all urls from a web page
# Usage: get_web_pagelink <url>
function get_web_pagelink() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    _logger info "[i] Start extracting all urls from $1. original files will be stored at $PWD/links.txt"
    _logger info "[i] unique links (remove duplicated) will be stored at $PWD/links-uniq.txt"
    
    lynx -dump $1 | awk '/http/{print $2}' > links.txt
    sort -u links.txt > links-uniq.txt
    cat ./links-uniq.txt
}

# Description: get keywords from a web page
# Usage: get_web_keywords <url>
function get_web_keywords() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    _wrap cewl -d $_swiss_get_web_keywords_depth -m $_swiss_get_web_keywords_min_word_length --with-numbers -w cewl-wordlist.txt $1
    cat ./cewl-wordlist.txt
}

function _create_web_fuzz_report_directory() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        local domain=$(echo "$url" | awk -F/ '{print $3}')
    else
        local domain=$(echo "$url" | awk -F/ '{print $1}')
    fi
    local domain_dir="$(pwd)/reports/ffuf/$domain"
    mkdir -p "$domain_dir"
    echo $domain_dir
}

function _display_wordlist_statistic() {
    if [[ -f "$1.statistic" ]]; then
        _logger -l warn --no-mark "====== Wordlist Statistic ======"
        \cat $1.statistic
        _logger -l warn  --no-mark "================================"
    fi
}

