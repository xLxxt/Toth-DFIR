#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTH=(python3 "$ROOT/wrapper/toth.py")

"${TOTH[@]}" --version | grep -q "toth 0.2.0-dev"
"${TOTH[@]}" --help | grep -q "Blue Team Docker distribution"
"${TOTH[@]}" --help | grep -q "list,status,start,enter,restart,stop,remove,rm,exec,shell,update"
"${TOTH[@]}" --help | grep -q "pull images or build them locally"
"${TOTH[@]}" list | grep -q "toth-dfir:0.1.0"
"${TOTH[@]}" list | grep -q "ghcr.io/xlxxt/toth-dfir:0.1.0"
"${TOTH[@]}" list | grep -q "dfir.*default"
"${TOTH[@]}" start --help | grep -q "base,dfir,malware,network"
"${TOTH[@]}" enter --help | grep -q "cmd"
"${TOTH[@]}" restart --help | grep -q "base,dfir,malware,network"
"${TOTH[@]}" stop --help | grep -q "base,dfir,malware,network"
"${TOTH[@]}" remove --help | grep -q "base,dfir,malware,network"
"${TOTH[@]}" rm --help | grep -q "base,dfir,malware,network"
"${TOTH[@]}" exec --help | grep -q "cmd"
"${TOTH[@]}" shell --help | grep -q "cmd"
"${TOTH[@]}" update --help | grep -q "base,dfir,malware,network,all"
"${TOTH[@]}" update --help | grep -q -- "--build"

echo "[+] Wrapper command smoke tests passed"
