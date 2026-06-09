#!/bin/bash

# =============================================================================
# NAVIGATION
# =============================================================================
alias ll='ls -lah --color=auto'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'

# =============================================================================
# TOTH
# =============================================================================
alias toth-check='bash /opt/toth/scripts/check_tools.sh'
alias cases='cd /cases'
alias output='cd /opt/toth/output'
alias toth-home='cd /opt/toth'

# =============================================================================
# PYTHON
# =============================================================================
alias python='python3'
alias pip='pip3'

# =============================================================================
# UTILITAIRES
# =============================================================================
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias tree='tree -C'
alias bat='bat --style=plain'
alias fzf='fzf --ansi'
alias xxd='xxd | head -50'
alias sqlite='sqlite3'

# =============================================================================
# HASHING
# =============================================================================
alias md5='md5sum'
alias sha1='sha1sum'
alias sha256='sha256sum'
alias sha512='sha512sum'

hash-all() {
    echo "[MD5]    $(md5sum "$1" | cut -d' ' -f1)"
    echo "[SHA1]   $(sha1sum "$1" | cut -d' ' -f1)"
    echo "[SHA256] $(sha256sum "$1" | cut -d' ' -f1)"
}

# =============================================================================
# PLASO / LOG2TIMELINE
# =============================================================================
alias log2timeline='log2timeline.py'
alias pinfo='pinfo.py'
alias psort='psort.py'

# =============================================================================
# CHAINSAW
# =============================================================================
alias chainsaw='/opt/toth/tools/chainsaw/chainsaw/chainsaw'

# =============================================================================
# HAYABUSA
# =============================================================================
alias hayabusa='/opt/toth/tools/hayabusa/hayabusa'
alias haya-hunt='hayabusa csv-timeline -d'
alias haya-metrics='hayabusa metrics -d'
alias haya-logon='hayabusa logon-summary -d'

# =============================================================================
# VOLATILITY
# =============================================================================
alias vol='python3 /opt/toth/tools/volatility3/vol.py'
alias vol2='python2 /opt/toth/tools/volatility2/vol.py'

vol-info() { vol -f "$1" windows.info; }
vol-pslist() { vol -f "$1" windows.pslist.PsList; }
vol-pstree() { vol -f "$1" windows.pstree.PsTree; }
vol-netscan() { vol -f "$1" windows.netscan.NetScan; }
vol-malfind() { vol -f "$1" windows.malfind.Malfind; }
vol-cmdline() { vol -f "$1" windows.cmdline.CmdLine; }
vol-filescan() { vol -f "$1" windows.filescan.FileScan; }
vol-dlllist() { vol -f "$1" windows.dlllist.DllList; }

# =============================================================================
# MALWARE ANALYSIS
# =============================================================================
alias pe-info='python3 -c "import pefile, sys; pe = pefile.PE(sys.argv[1]); print(pe.dump_info())"'
alias str='strings -a -n 8'
alias yara-scan='yara -r'
alias olevba='python3 -m oletools.olevba'
alias oleid='python3 -m oletools.oleid'
alias mraptor='python3 -m oletools.mraptor'
alias floss='floss'
alias clamav='clamscan'
alias die='diec'
alias clam-scan='clamscan -r --bell'
alias bw-extract='binwalk -e'
alias carve='foremost -v -o /workspace/reports/carved'
alias capa-scan='capa'
alias vt-check='python3 /opt/toth/scripts/vt_check.py'

mal-check() {
    echo "=== FILE ==="
    file "$1"
    echo "=== EXIFTOOL ==="
    exiftool "$1"
    echo "=== HASHES ==="
    hash-all "$1"
    echo "=== STRINGS (top 50) ==="
    strings -a -n 8 "$1" | head -50
}

# =============================================================================
# LOG ANALYSIS
# =============================================================================
alias jpp='jq "."'
alias jq-keys='jq "keys"'
alias csv2json='python3 -c "import csv,json,sys; print(json.dumps(list(csv.DictReader(sys.stdin)), indent=2))"'
alias evtx2json='python3 -m evtx'
alias sigma='sigma-cli'

# =============================================================================
# NETWORK FORENSICS
# =============================================================================
alias pcap-read='tshark -r'
alias zeek-analyze='zeek -C -r'
alias cap='tcpdump -i any -w /workspace/captures/$(date +%Y%m%d_%H%M%S).pcap'
alias pcap-stats='capinfos'
alias suricata-run='suricata -r'
alias suricata-log='cat /var/log/suricata/fast.log'

pcap-conv()  { tshark -r "$1" -q -z conv,tcp; }
pcap-http()  { tshark -r "$1" -Y "http" -T fields -e http.host -e http.request.uri; }
pcap-dns()   { tshark -r "$1" -Y "dns" -T fields -e dns.qry.name; }
pcap-ips()   { tshark -r "$1" -T fields -e ip.src -e ip.dst | sort -u; }
pcap-tls()   { tshark -r "$1" -Y "tls.handshake.type == 1" -T fields -e ip.dst -e tls.handshake.extensions_server_name; }
pcap-smb()   { tshark -r "$1" -Y "smb || smb2" -T fields -e ip.src -e ip.dst -e smb2.filename; }

# =============================================================================
# REGISTRE WINDOWS
# =============================================================================
alias regripper='perl /opt/toth/tools/regripper/rip.pl'
alias reg-hive='regripper -r'
alias reg-all='regripper -r "$1" -a'
alias reg-plugins='regripper -l'

# =============================================================================
# THREAT INTEL
# =============================================================================
alias ioc-extract='python3 -c "from ioc_finder import find_iocs; import sys; import json; data=sys.stdin.read(); print(json.dumps(find_iocs(data), indent=2))"'
alias misp-cli='python3 /opt/toth/scripts/misp_query.py'

ioc-file() { cat "$1" | ioc-extract; }

# =============================================================================
# HELPERS DFIR
# =============================================================================
setcase() {
    export CASE="$1"
    echo "[+] Case set to: $CASE"
}

newcase() {
    local name="${1:-case_$(date +%Y%m%d)}"
    mkdir -p /cases/$name/{evidence,output/{volatility,chainsaw,hayabusa,plaso,regripper},notes}
    export CASE_DIR="/cases/$name"
    echo "[+] Case created: /cases/$name"
}