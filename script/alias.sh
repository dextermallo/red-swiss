#!/bin/bash
# About alias.sh
# alias.sh is a collection of alias commands that are used across the oscp-swiss scripts.
# The functions under alias.sh are the default commands that are replaced with the custom commands.

# Description:
#   Replace the default argument of the command xfreerdp. The default argument is to:
#   1. ignore the certificate
#   2. set the resolution to your preferred screen resolution
#   3. mount to the current directory (optional)
# Usage: xfreerdp [-h, --help]
# Configuration:
#   - function.xfreerdp.use_custom_xfreerdp <boolean>: Use the custom xfreerdp function
#   - function.xfreerdp.prompt_create_mount <boolean>: Prompt to create a mount
#   - function.xfreerdp.create_mount_by_default <boolean>: Create a mount by default
#   - function.xfreerdp.default_mode <string>: Default mode (dynamic/full/half)
#   - function.xfreerdp.full_width <integer>: Full width resolution
#   - function.xfreerdp.half_width <integer>: Half width resolution
#   - function.xfreerdp.full_height <integer>: Full height resolution
#   Example:
#       xfreerdp -m dynamic /u:username /p:password /v:$target
#       xfreerdp -m full /u:username /p:password /v:$target
function custom_xfreerdp() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    local arg_mount
    gum confirm "Create a mount (./xfreerdp-data)?" && arg_mount=1 || arg_mount=0
    if [[ $arg_mount == true ]]; then
        mkdir -p xfreerdp-data
        _wrap "\xfreerdp /drive:xfreerdp-data,$PWD/xfreerdp-data /cert-ignore /dynamic-resolution $@"
    else
        _wrap "\xfreerdp /cert-ignore /dynamic-resolution $@"
    fi
}

if [[ $_swiss_alias_use_custom_xfreerdp == true ]]; then
    alias xfreerdp=custom_xfreerdp
fi

# Description:
#   Replace the default argument of the command wpscan. The default argument is to:
#   1. enumerate users, plugins, and themes
#   2. use aggressive plugin detection
#   3. use the WPSCAN_API_TOKEN environment variable (optional)
#   You can request a free API token from https://wpscan.com/api
# Configuration:
#   - function.wpscan.wpscan_token <string>: WPScan API token
function custom_wpscan() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    _wrap "\wpscan --enumerate ap,at,u --plugins-detection aggressive --api-token $_swiss_alias_wpscan_token $@"
}

if [[ $_swiss_alias_use_custom_wpscan == true ]]; then
    alias wpscan=custom_wpscan
fi

# Description: Use pygmentize to display the content of the file with color under dark-mode Kali.
# Configuration:
#   - function.cat.use_pygmentize <boolean>: feature flag to use pygmentize
# Reference: https://stackoverflow.com/questions/62546404/how-to-use-dracula-theme-as-a-style-in-pygments
function custom_cat() {
    [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]] && _help && return 0
    pygmentize -P style=dracula -g $@
}

if [[ $_swiss_alias_use_custom_wpscan == true ]]; then
    alias cat=custom_cat
fi

############
# wordlist #
############
### directory & files
wordlist_dirsearch="$_swiss_wordlist_base/seclists/Discovery/Web-Content/dirsearch.txt"
wordlist_dirb_commn="$_swiss_wordlist_base/dirb/common.txt"
wordlist_raft_directory_big="$_swiss_wordlist_base/seclists/Discovery/Web-Content/raft-large-directories.txt"
wordlist_raft_file_big="$_swiss_wordlist_base/seclists/Discovery/Web-Content/raft-large-files.txt"

### subdomain
wordlist_subdomain_amass_small="$_swiss_wordlist_base/amass/subdomains-top1mil-20000.txt"
wordlist_subdomain_amass_big="$_swiss_wordlist_base/amass/subdomains-top1mil-110000.txt"
wordlist_subdomain_dirb="$_swiss_wordlist_base/dirbuster/directory-list-2.3-medium.txt"
wordlist_subdomain_top="$_swiss_wordlist_base/Discovery/DNS/subdomains-top1million-110000.txt"

### username & password
wordlist_username_big="$_swiss_wordlist_base/seclists/Usernames/xato-net-10-million-usernames.txt"
wordlist_username_medium="$_swiss_wordlist_base/dirb/others/names.txt"
wordlist_username_medium_seclist="$_swiss_wordlist_base/seclists/Usernames/Names/names.txt"
wordlist_username_small="$_swiss_wordlist_base/seclists/Usernames/top-usernames-shortlist.txt"
wordlist_rockyou="$_swiss_wordlist_base/rockyou.txt"

# api
wordlist_api_obj="$_swiss_wordlist_base/seclists/Discovery/Web-Content/api/objects.txt"
wordlist_api_res="$_swiss_wordlist_base/seclists/Discovery/Web-Content/api/api-endpoints-res.txt"

### specific
wordlist_snmp_community_string="$_swiss_wordlist_base/seclists/Discovery/SNMP/common-snmp-community-strings-onesixtyone.txt"
wordlist_lfi="$_swiss_wordlist_base/IntruderPayloads/FuzzLists/lfi.txt"

## hashcat
wordlist_hashcat_rules="/usr/share/hashcat/rules"
wordlist_hashcat_rule_best64="/usr/share/hashcat/rules/best64.rule"

# traversal
wordlist_traversal="$_swiss_wordlist_base/IntruderPayloads/FuzzLists/traversal.txt"

###########
# windows #
###########
windows_resource="/usr/share/windows-resources"
windows_powercat='/usr/share/powershell-empire/empire/server/data/module_source/management/powercat.ps1'
windows_powerup='/usr/share/windows-resources/powersploit/Privesc/PowerUp.ps1'
windows_powerview='/usr/share/windows-resources/powersploit/Recon/PowerView.ps1'

#########
# linux #
#########
linux_privesc="/usr/bin/unix-privesc-check"

########
# disc #
########
hasncat_potfile_path="$HOME/.local/share/hashcat/hashcat.potfile"
nmap_scripts_path="/usr/share/nmap/scripts"
payload_backdoor="/usr/share/davtest/backdoors"