#!/bin/bash

# =============================================================================
# COLORS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# =============================================================================
# HELPERS
# =============================================================================
ok()   { echo -e "  ${GREEN}[✓]${RESET} $1"; return 0; }
fail() { echo -e "  ${RED}[✗]${RESET} $1"; MISSING=$((MISSING+1)); return 1; }
warn() { echo -e "  ${YELLOW}[~]${RESET} $1"; }
section() { echo -e "\n${BOLD}${BLUE}>>> $1${RESET}"; }

check_cmd() {
    local name=$1
    local cmd=${2:-$1}
    command -v "$cmd" &>/dev/null && ok "$name" || fail "$name"
}

check_py() {
    local name=$1
    local module=$2
    python3 -c "import $module" &>/dev/null && ok "$name" || fail "$name"
}

check_path() {
    local name=$1
    local path=$2
    [ -e "$path" ] && ok "$name" || fail "$name"
}

MISSING=0

# =============================================================================
# BASE
# =============================================================================
section "BASE"
check_cmd "curl"
check_cmd "wget"
check_cmd "git"
check_cmd "unzip"
check_cmd "tar"
check_cmd "7zip" "7z"
check_cmd "unar"
check_cmd "file"
check_cmd "xxd"
check_cmd "strings"
check_cmd "vim"
check_cmd "nano"
check_cmd "tmux"
check_cmd "less"
check_cmd "tree"
check_cmd "bat"
check_cmd "ripgrep" "rg"
check_cmd "fd"
check_cmd "fzf"
check_cmd "hexyl"
check_cmd "lnav"
check_cmd "pv"
check_cmd "zsh"
check_cmd "jq"
check_cmd "miller" "mlr"
check_cmd "sqlite3"
check_cmd "python3"
check_cmd "pip3"
check_cmd "foremost"
check_cmd "binwalk"
check_cmd "exiftool"
check_cmd "net-tools" "ifconfig"
check_cmd "dnsutils" "dig"

# =============================================================================
# DFIR
# =============================================================================
if [ -d "/opt/toth/tools/volatility3" ]; then
    section "DFIR"
    check_cmd "Volatility3" "vol3"
    check_cmd "bulk_extractor"
    check_cmd "pffexport"
    check_cmd "libesedb" "esedbexport"
    check_cmd "RegRipper" "regripper"
    check_cmd "Chainsaw" "chainsaw"
    check_cmd "Hayabusa" "hayabusa"
    check_cmd "sigma-cli" "sigma"
    check_path "Sigma rules" "/opt/toth/rules/sigma"
    python3 -c "import Evtx" &>/dev/null && ok "python-evtx" || fail "python-evtx"
    python3 -c "import plaso" &>/dev/null && ok "Plaso" || fail "Plaso"
    check_cmd "ioc-finder"
    check_cmd "lynis"
    check_cmd "chkrootkit"
    check_cmd "rkhunter"
    check_cmd "Sleuth Kit" "fls"
    check_cmd "Sleuth Kit" "icat"
    check_cmd "Sleuth Kit" "mmls"
    check_cmd ".NET runtime" "dotnet"
    check_cmd "MFTECmd" "mftecmd"
    check_cmd "PECmd" "pecmd"
    check_cmd "LECmd" "lecmd"
    check_cmd "JLECmd" "jlecmd"
    check_cmd "SBECmd" "sbecmd"
    check_cmd "AmcacheParser" "amcacheparser"
    check_cmd "RECmd" "recmd"
fi

# =============================================================================
# MALWARE
# =============================================================================
if [ -d "/opt/toth/tools/capa" ]; then
    section "MALWARE"
    check_cmd "Capa" "capa"
    check_cmd "YARA" "yara"
    check_cmd "ClamAV" "clamscan"
    check_cmd "ssdeep"
    check_cmd "TLSH" "tlsh"
    if [ "$(uname -m)" = "x86_64" ]; then
        check_cmd "DIE" "diec"
    fi
    check_cmd "UPX" "upx"
    check_cmd "FLOSS" "floss"
    check_cmd "radare2" "r2"
    check_py  "pefile" "pefile"
    check_py  "pyelftools" "elftools"
    check_py  "capstone" "capstone"
    check_py  "yara-python" "yara"
    check_py  "oletools" "oletools"
    check_py  "pdfminer" "pdfminer"
    check_py  "peepdf" "peepdf"
fi

# =============================================================================
# NETWORK
# =============================================================================
if command -v tshark &>/dev/null || command -v zeek &>/dev/null; then
    section "NETWORK"
    check_cmd "tshark"
    check_cmd "tcpdump"
    check_cmd "nmap"
    check_cmd "netcat" "nc"
    check_cmd "whois"
    check_cmd "ngrep"
    check_cmd "tcpflow"
    check_cmd "dnstwist"
    check_cmd "Zeek" "zeek"
    check_cmd "Zeekctl" "zeekctl"
    check_cmd "Suricata" "suricata"
    check_cmd "Wireshark (GUI)" "wireshark"
    check_cmd "dumpcap"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo -e "\n${BOLD}==============================${RESET}"
if [ "$MISSING" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  Tous les outils sont OK${RESET}"
else
    echo -e "${RED}${BOLD}  $MISSING outil(s) manquant(s)${RESET}"
fi
echo -e "${BOLD}==============================${RESET}\n"

exit $MISSING