#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTH=(python3 "$ROOT/wrapper/toth.py")

"${TOTH[@]}" --version | grep -q "toth 0.2.0-dev"
"${TOTH[@]}" --help | grep -q "Blue Team Docker distribution"
"${TOTH[@]}" --help | grep -q "list,status,start,enter,restart,stop,remove,rm,exec,shell,update,case"
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

"${TOTH[@]}" case --help | grep -q "new,list,use,current"
"${TOTH[@]}" case new --help | grep -q "name"
"${TOTH[@]}" case list --help | grep -q "usage: toth case list"
"${TOTH[@]}" case use --help | grep -q "name"
"${TOTH[@]}" case current --help | grep -q "usage: toth case current"

# Case commands are filesystem-only and must work without Docker installed
# or reachable, and must not touch any files without an explicit workspace.
CASE_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$CASE_WORKSPACE"' EXIT

TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case current | grep -q "No case is currently active"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case list | grep -q "No cases found"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case new alpha | grep -q "case 'alpha' created and set active"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case current | grep -q "^alpha$"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case new beta >/dev/null
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case list | grep -q "\* beta"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case use alpha | grep -q "case 'alpha' is now active"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case current | grep -q "^alpha$"
[ -d "$CASE_WORKSPACE/cases/alpha" ]
[ -d "$CASE_WORKSPACE/output/alpha" ]
[ -d "$CASE_WORKSPACE/cases/beta" ]
[ -d "$CASE_WORKSPACE/output/beta" ]

set +e
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case use nope 2>&1 | grep -q "does not exist"
set -e

# Legacy fallback: a fresh workspace with no .active-case file must behave
# exactly as before this feature -- flat cases/ and output/ directories.
LEGACY_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$CASE_WORKSPACE" "$LEGACY_WORKSPACE"' EXIT
TOTH_WORKSPACE="$LEGACY_WORKSPACE" "${TOTH[@]}" case current | grep -q "legacy workspace mode"
[ ! -e "$LEGACY_WORKSPACE/.active-case" ]

echo "[+] Wrapper command smoke tests passed"
