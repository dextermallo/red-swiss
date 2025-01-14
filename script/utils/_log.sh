# Description: low level function for logging which wrap the echo command with ANSI color codes.
# Usage: _log [options] <text>
function _log() {
    local bold=""
    local fg_color=""
    local bg_color=""
    local no_color=0
    local text=""
    local underline=""
    local newline=1
    local ansi_reset="\033[0m"

    while [ "$1" ]; do
        case "$1" in
            --bold) bold="\033[1m" && shift ;;
            -u|--underline) underline="\033[4m" && shift ;;
            -f|--foreground)
                shift
                case "$1" in
                    black) fg_color="\033[30m" ;;
                    red) fg_color="\033[31m" ;;
                    green) fg_color="\033[32m" ;;
                    yellow) fg_color="\033[33m" ;;
                    blue) fg_color="\033[34m" ;;
                    magenta) fg_color="\033[35m" ;;
                    cyan) fg_color="\033[36m" ;;
                    white) fg_color="\033[37m" ;;
                    gray) fg_color="\033[90m" ;;
                    *) fg_color="" ;;
                esac
                shift
                ;;
            -b|--background)
                shift
                case "$1" in
                    black) bg_color="\033[40m" ;;
                    red) bg_color="\033[41m" ;;
                    green) bg_color="\033[42m" ;;
                    yellow) bg_color="\033[43m" ;;
                    blue) bg_color="\033[44m" ;;
                    magenta) bg_color="\033[45m" ;;
                    cyan) bg_color="\033[46m" ;;
                    white) bg_color="\033[47m" ;;
                    gray) bg_color="\033[100m" ;;
                    *) bg_color="" ;;
                esac
                shift
                ;;
            --no-color) no_color=1 && shift ;;
            -n|--no-newline) newline=0 && shift ;;
            *) text="$1" && shift ;;
        esac
    done

    if [[ "$_swiss_disable_color" = true ]]; then
        [[ "$newline" -eq 1 ]] && echo -e "$text" || echo -e -n "$text"
    else
        [[ "$newline" -eq 1 ]] && newline_flag="" || newline_flag="-n"
        echo -e $newline_flag "${bold}${underline}${fg_color}${bg_color}${text}${ansi_reset}"
    fi
}

# Description:
#   _check_logger_level is a helper function to check the logger level,
#   the function will return 0 if the given level is equal or higher than the global logger level.
# Configuration:
#   - global_settings.logger_level <debug|info|warn|error>: default is info.
# Usage: _check_logger_level <level>
function _check_logger_level() {
    case "$_swiss_logger_level" in
        debug) return 0 ;;
        info) [[ "$1" != "debug" ]] ;;
        warn) [[ "$1" == "warn" || "$1" == "error" ]] ;;
        error) [[ "$1" == "error" || "$1" == "important" ]] ;;
        *) return 1 ;;
    esac
}

# Description: wrap the _log function with the given level.
# Usage: _logger <level> <text>
function _logger() {
    local arg_level=""
    local arg_mark=true
    local mark_msg=""
    local arg_no_newline=""
    local arg_bold=""
    local arg_instruction
    local arg_message
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--level) arg_level="$2" && shift 2 ;;
            --no-mark) arg_mark=false && shift ;;
            -n|--no-newline) arg_no_newline="-n" && shift ;;
            -b|--bold) arg_bold="--bold" && shift ;;
            -i|--instruction) arg_instruction='error' && shift ;;
            *) arg_message=$1 && shift ;;
        esac
    done

    [[ $arg_mark = true ]] && mark_msg="[$arg_level] "

    local level_color=""
    case $arg_level in
        debug) level_color="gray" ;;
        info) level_color="green" ;;
        hint) level_color="cyan" ;;
        warn) level_color="yellow" ;;
        error|important) level_color="red" ;;
        *) echo -n "$@" ;;
    esac

    _check_logger_level ${arg_instruction:-$arg_level} && _log -f $level_color $arg_no_newline $arg_bold "$mark_msg$arg_message" 
}

function _test.logger() {
    _swiss_logger_level="warn"
    echo "=== current level: $_swiss_logger_level ==="
    _logger -l error -n "new line test: " && _logger -l warn --no-mark "merging color"
    _logger -l debug -i "this should bypass logger_level restriction"
    
    _swiss_logger_level="debug"
    echo "=== current level: $_swiss_logger_level ==="

    _logger -l debug "test debug"
    _logger -l info "test info"
    _logger -l hint "test hint"
    _logger -l warn "test warn"
    _logger -l error "test error"
    _logger -l important "test important"

    _swiss_logger_level="error"
    echo "=== current level: $_swiss_logger_level ==="
    _logger -l debug "test debug"
    _logger -l info "test info"
    _logger -l hint "test hint"
    _logger -l warn "test warn"
    _logger -l error "test error"
    _logger -l important "test important"

    _swiss_logger_level="warn"
    echo "=== current level: $_swiss_logger_level ==="
    _logger -l debug "test debug"
    _logger -l info "test info"
    _logger -l hint "test hint"
    _logger -l warn "test warn"
    _logger -l error "test error"
    _logger -l important "test important"
}