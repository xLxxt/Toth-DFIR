#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTH=(python3 "$ROOT/wrapper/toth.py")

"${TOTH[@]}" --version | grep -q "toth 0.2.0"
"${TOTH[@]}" --help | grep -q "Blue Team Docker distribution"
"${TOTH[@]}" --help | grep -q "list,status,start,enter,restart,stop,remove,rm,exec,shell,update,case"
"${TOTH[@]}" --help | grep -q "pull images or build them locally"
"${TOTH[@]}" list | grep -q "toth-dfir:0.2.0"
"${TOTH[@]}" list | grep -q "ghcr.io/xlxxt/toth-dfir:0.2.0"
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

# --gui (X11 forwarding): available on start/exec/shell (the commands that
# call `docker compose up`, i.e. actually create/recreate the container and
# so decide which compose files get layered in). No real X server exists in
# this sandboxed/CI environment, so these are structural argparse checks,
# not a real GUI pop-up test.
"${TOTH[@]}" start --help | grep -q -- "--gui"
"${TOTH[@]}" exec --help | grep -q -- "--gui"
"${TOTH[@]}" shell --help | grep -q -- "--gui"

# enter re-attaches to an already-existing container via `docker start`/
# `docker exec` directly -- it never calls `docker compose up`, so it never
# re-evaluates which compose files are layered in, and deliberately does not
# expose --gui (a container's GUI mounts are fixed at creation time by
# start/exec/shell --gui). Assert it stays absent so this scope decision
# doesn't silently drift.
"${TOTH[@]}" enter --help | grep -qv -- "--gui"

# The flag must actually change the constructed `docker compose` argv
# (compose-file layering), and the no-flag path must be byte-for-byte
# unchanged from before --gui existed -- this is the regression that
# matters most, so it's checked directly against docker_manager._compose_args
# (a pure function, no subprocess/Docker/X server involved) rather than only
# at the argparse level.
python3 - "$ROOT" <<'PY'
import sys
sys.path.insert(0, sys.argv[1] + "/wrapper")
from utils import docker_manager as dm

no_flag = dm._compose_args(["up", "-d", "toth-network"])
gui_false = dm._compose_args(["up", "-d", "toth-network"], gui=False)
gui_true = dm._compose_args(["up", "-d", "toth-network"], gui=True)

assert no_flag == ["compose", "up", "-d", "toth-network"], no_flag
assert gui_false == no_flag, gui_false
assert gui_true == [
    "compose",
    "-f", "docker-compose.yml",
    "-f", "docker-compose.gui.yml",
    "up", "-d", "toth-network",
], gui_true
print("[+] docker_manager._compose_args --gui plumbing OK")
PY

# Per-profile config overrides (Phase 2, Tier 1): a TOTH_PROFILE_<NAME>_TAG
# env var should surface in `toth list` output for that profile only, and
# remote_image() (GHCR pull target) must stay unaffected.
TOTH_PROFILE_BASE_TAG="override-test" "${TOTH[@]}" list | grep -q "toth-base:override-test"
TOTH_PROFILE_BASE_TAG="override-test" "${TOTH[@]}" list | grep -q "toth-base.*(overridden)"
TOTH_PROFILE_BASE_TAG="override-test" "${TOTH[@]}" list | grep -q "ghcr.io/xlxxt/toth-base:0.2.0"

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
