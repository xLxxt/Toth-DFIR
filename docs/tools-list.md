# Tools List

This list tracks the main tools installed by each Toth profile. It is organized
by runtime profile because every specialized image inherits the `base` tools.

## Base

General shell and navigation:

- bash, zsh
- vim, nano
- tmux
- less, tree
- fzf
- bat
- ripgrep (`rg`)
- fd
- pv

Archives and file inspection:

- file
- strings and binutils
- xxd
- unzip, tar
- p7zip / `7z`
- unar
- binwalk
- foremost
- exiftool
- hexyl

Data and log handling:

- jq
- miller (`mlr`)
- lnav
- sqlite3

Network helpers:

- curl, wget
- net-tools
- dnsutils

Python and development basics:

- Python 3
- pip
- python3-venv
- git

## DFIR

The DFIR image inherits all base tools and adds:

- Volatility 3 (`vol3`)
- bulk_extractor
- libesedb-utils
- libpff / `pffexport`
- RegRipper
- python-evtx
- Plaso
- sigma-cli
- Timesketch API client
- Chainsaw
- Hayabusa
- Sigma rules

## Malware

The malware image inherits all base tools and adds:

- YARA and yara-python
- capa
- FLOSS
- radare2 (`r2`)
- Detect It Easy (`diec`) on amd64
- ClamAV
- ssdeep
- TLSH (`tlsh`)
- UPX
- oletools
- pefile
- pyelftools
- capstone
- pdfminer.six
- peepdf-3

## Network

The network image inherits all base tools and adds:

- tshark
- tcpdump
- nmap
- netcat (`nc`)
- whois
- ngrep
- tcpflow
- dnstwist
- Wireshark common files
- Zeek and zeekctl
- Suricata

## Not installed yet

These candidates are tracked for later lots:

- Base/log analysis: zq / zed
- Malware: strace, ltrace, fakenet-ng, inetsim, Ghidra
- Network: RITA
- Threat intel: ioc-finder, unfurl, vt-cli, abuse-cli, CyberChef CLI, PyMISP
- DFIR/Windows: impacket, Volatility 2, Autopsy, Zimmerman tools
- Cloud: aws-cli, azure-cli, pwsh, trailscraper, stormspotter, o365-investigator

Architecture notes and exact versions live in the Dockerfiles.
