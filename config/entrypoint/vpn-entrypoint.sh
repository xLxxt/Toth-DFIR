#!/bin/bash
# Root-first entrypoint for VPN-capable Toth images (toth-network in v1).
#
# Starting a VPN tunnel (creating a tun/tap device, adding routes) needs
# capabilities only root has by default -- the "analyst" user does not
# inherit the container's cap_add-granted capabilities just because the
# container has them. This script therefore runs as root, does at most a
# few read-only filesystem checks plus (if a VPN config is actually mounted)
# starts the tunnel, then permanently drops to the unprivileged "analyst"
# user via gosu before handing off to the real command. It never runs
# analyst-supplied code as root, and it exec's away from itself (via gosu)
# rather than staying resident, so there is no long-lived root process once
# startup finishes.
#
# See docs/architecture.md's Runtime model / VPN section and
# docs/roadmap-vpn.md sections 4 and 6.
#
# Security note: a VPN config is analyst-supplied, often from a third party
# (a CTF platform, an engagement contact) -- Toth does not trust its
# *content* just because it trusts the analyst who added it. WireGuard's
# PreUp/PostUp/PreDown/PostDown directives are shell commands wg-quick runs
# as whoever invokes it (root, here); start_wireguard() below refuses any
# config containing them rather than executing arbitrary root code from a
# config file. OpenVPN gets --user/--group so the daemon itself drops to
# "analyst" after opening the tun device, instead of running as root for
# its entire (long) connected lifetime.
set -euo pipefail

VPN_DIR="/opt/toth/vpn"
OVPN_CONFIG="$VPN_DIR/config.ovpn"
WG_CONFIG="$VPN_DIR/config.conf"
CREDS_FILE="$VPN_DIR/creds.txt"
RUN_USER="analyst"

log() {
    echo "[vpn-entrypoint] $*" >&2
}

start_openvpn() {
    log "VPN config found (OpenVPN): $OVPN_CONFIG"
    # --daemon detaches from this process immediately, so a nonzero exit
    # here only means the initial config parse/setup failed -- it does not
    # confirm the tunnel came up. Ongoing connection status/errors from the
    # detached process go to --log, since these images run no syslog daemon
    # for openvpn's default logging to land in.
    local log_file="/var/log/toth-openvpn.log"
    # --user/--group: openvpn opens the tun device and reads config/creds as
    # root, then drops to "analyst" for the connected session itself --
    # --persist-tun/--persist-key keep the already-open tun fd and any
    # embedded keys usable across that drop (openvpn's own documented
    # pattern for running the daemon unprivileged).
    #
    # --script-security 1, placed after --config: a .ovpn file can itself
    # request `script-security 2` (or higher) plus `up`/`down`/`route-up`/
    # etc directives that then run as arbitrary code -- the same
    # config-controls-its-own-code-exec-privilege problem as WireGuard's
    # PreUp/PostUp, just gated behind an extra opt-in line instead of being
    # unconditional. OpenVPN takes the last value of a repeated option, and
    # command-line arguments after --config are processed after the file's
    # own contents, so this explicit, later --script-security 1 overrides
    # whatever the file requests, forcing the documented default (only
    # openvpn's own built-in ip/route calls, no user-defined scripts)
    # regardless of what the config file asks for.
    local args=(
        --config "$OVPN_CONFIG"
        --daemon
        --log "$log_file"
        --user "$RUN_USER"
        --group "$RUN_USER"
        --persist-tun
        --persist-key
        --script-security 1
    )
    if [ -f "$CREDS_FILE" ]; then
        args+=(--auth-user-pass "$CREDS_FILE")
    fi
    local rc=0
    openvpn "${args[@]}" || rc=$?
    if [ "$rc" -eq 0 ]; then
        # openvpn creates $log_file root:root 0600 during its own (still
        # root, pre-drop) startup phase, before this script's own privilege
        # drop -- left as-is, `toth exec network cat` (analyst) couldn't
        # read the log this comment is telling the analyst to go check.
        # Nothing sensitive lands in it at the default verbosity (no
        # plaintext passwords; --auth-user-pass creds are never logged by
        # openvpn), so widening read access here is safe.
        chmod 644 "$log_file" 2>/dev/null || true
        log "openvpn started, see $log_file for connection status"
    else
        log "openvpn failed to start (exit $rc); continuing without VPN"
    fi
}

start_wireguard() {
    log "VPN config found (WireGuard): $WG_CONFIG"
    # wg-quick runs Pre/PostUp and Pre/PostDown lines as shell commands, as
    # whoever invokes it -- root, here. A config is analyst-supplied and
    # often from a third party, so refuse rather than hand root a shell
    # command sourced from a config file Toth has no reason to trust the
    # content of. This is a stricter check than wg-quick's own parser (it
    # flags the directive name regardless of value or formatting), which is
    # the intent: reject anything that looks like a hook rather than trying
    # to sanitize it.
    if grep -Eiq '^[[:space:]]*(pre|post)(up|down)[[:space:]]*=' "$WG_CONFIG"; then
        log "refusing to start: $WG_CONFIG contains a Pre/PostUp or Pre/PostDown directive, which wg-quick would run as a root shell command. Remove that line (Toth only auto-connects plain [Interface]/[Peer] configs) or bring the tunnel up manually with TOTH_VPN_DISABLE=1 and your own judgment."
        return 0
    fi
    install -d -m 700 /etc/wireguard
    install -m 600 "$WG_CONFIG" /etc/wireguard/wg0.conf
    local rc=0
    wg-quick up wg0 || rc=$?
    if [ "$rc" -eq 0 ]; then
        log "wg0 is up"
    else
        log "wg-quick failed to bring up wg0 (exit $rc); continuing without VPN"
    fi
}

maybe_start_vpn() {
    if [ "${TOTH_VPN_DISABLE:-0}" = "1" ]; then
        log "TOTH_VPN_DISABLE=1, skipping VPN auto-connect"
        return 0
    fi
    if [ ! -d "$VPN_DIR" ]; then
        return 0
    fi
    if [ -f "$OVPN_CONFIG" ]; then
        start_openvpn
    elif [ -f "$WG_CONFIG" ]; then
        start_wireguard
    else
        log "no VPN config found at $VPN_DIR, skipping"
    fi
}

maybe_start_vpn
exec gosu "$RUN_USER" "$@"
