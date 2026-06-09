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

# =============================================================================
# PLASO / LOG2TIMELINE
# =============================================================================
alias log2timeline='log2timeline'
alias pinfo='pinfo'
alias psort='psort'

# =============================================================================
# CHAINSAW
# =============================================================================
alias chainsaw='/opt/toth/tools/chainsaw/chainsaw/chainsaw'

# =============================================================================
# MALWARE ANALYSIS
# =============================================================================
alias pe-info='python3 -c "import pefile, sys; pe = pefile.PE(sys.argv[1]); print(pe.dump_info())"'
alias str='strings -a -n 8'
alias yara-scan='yara -r'
alias olevba='python3 -m oletools.olevba'
alias oleid='python3 -m oletools.oleid'
alias mraptor='python3 -m oletools.mraptor'
alias floss='python3 -m floss'
alias clamav='clamscan'
alias die='diec'
alias mal-check='f() { echo "=== FILE ==="; file "$1"; echo "=== EXIFTOOL ==="; exiftool "$1"; echo "=== STRINGS ==="; strings -a -n 8 "$1" | head -50; }; f'
alias clam-scan='clamscan -r --bell'
alias bw-extract='binwalk -e'
alias carve='foremost -v -o /workspace/reports/carved'

# =============================================================================
# NETWORK FORENSICS
# =============================================================================
alias pcap-read='tshark -r'
alias pcap-conv='tshark -r "$1" -q -z conv,tcp'
alias pcap-http='tshark -r "$1" -Y "http" -T fields -e http.host -e http.request.uri'
alias pcap-dns='tshark -r "$1" -Y "dns" -T fields -e dns.qry.name'
alias pcap-ips='tshark -r "$1" -T fields -e ip.src -e ip.dst | sort -u'
alias zeek-analyze='zeek -C -r'
alias cap='tcpdump -i any -w /workspace/captures/$(date +%Y%m%d_%H%M%S).pcap'
alias pcap-stats='capinfos'