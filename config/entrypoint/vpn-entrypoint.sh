#!/bin/bash
#
# Root-first ENTRYPOINT for VPN auto-connect (docs/roadmap-vpn.md, section 4).
#
# Every Toth image previously ran CMD directly as the non-root `analyst`
# user with no ENTRYPOINT at all. This script is the new PID 1: it runs as
# root (the image's baked-in default user after this change -- root
# privileges are required to create a tun interface and touch routing
# tables), optionally brings up a VPN tunnel if a config is mounted at
# /opt/toth/vpn, then permanently drops privileges to `analyst` and execs
# the original CMD in its place via gosu.
#
# For every container where /opt/toth/vpn has neither config.ovpn nor
# config.conf -- which today means every non-network-profile container
# (base/dfir/malware never mount /opt/toth/vpn at all), and any
# toth-network container for a case with no VPN configured -- this script
# no-ops immediately below and behaves exactly like the old
# `CMD ["/bin/bash"]`-as-analyst setup: same shell, same startup time, no
# observable difference. That is the most important property of this
# script; do not add anything above the config-presence check that could
# change behavior for those containers.
set -euo pipefail

VPN_DIR="/opt/toth/vpn"
OVPN_CONFIG="${VPN_DIR}/config.ovpn"
WG_CONFIG="${VPN_DIR}/config.conf"
CREDS_FILE="${VPN_DIR}/creds.txt"

log() {
    echo "[toth-vpn] $*" >&2
}

if [ "${TOTH_VPN_DISABLE:-0}" = "1" ]; then
    # Escape hatch (docs/roadmap-vpn.md open question 6): lets an analyst
    # start the container without attempting a connection even when a
    # config is mounted, e.g. to debug a broken tunnel without a
    # chicken-and-egg lockout where the only way in is through the
    # entrypoint that's failing.
    log "TOTH_VPN_DISABLE=1 set; skipping VPN auto-connect."
elif [ -f "$OVPN_CONFIG" ]; then
    log "config.ovpn found, starting OpenVPN (backgrounded via --daemon)..."
    if [ -f "$CREDS_FILE" ]; then
        openvpn --config "$OVPN_CONFIG" --auth-user-pass "$CREDS_FILE" --daemon \
            || log "openvpn failed to start; continuing without a tunnel."
    else
        openvpn --config "$OVPN_CONFIG" --daemon \
            || log "openvpn failed to start; continuing without a tunnel."
    fi
    # --daemon backgrounds openvpn immediately (it forks and the foreground
    # process this script launched returns) -- whether the tunnel actually
    # comes up is decided asynchronously after that point and is
    # deliberately NOT waited on here, so a slow/unreachable VPN server
    # never delays or blocks the container from becoming usable.
elif [ -f "$WG_CONFIG" ]; then
    log "config.conf found, bringing up WireGuard (wg0)..."
    if install -D -m 600 "$WG_CONFIG" /etc/wireguard/wg0.conf; then
        wg-quick up wg0 || log "wg-quick up wg0 failed; continuing without a tunnel."
    else
        log "failed to stage WireGuard config; continuing without a tunnel."
    fi
fi

# Permanently drop from root to analyst and replace this script's process
# with the original CMD (or `docker compose run`/`exec` override), via
# gosu. exec here matters: it means gosu itself never lingers as a
# resident process either -- it immediately execs the target command in
# its own place, so the final CMD (e.g. /bin/bash) ends up as PID 1
# directly, not this script or gosu. See the implementation report for the
# read of gosu's own signal-handling docs this relies on.
exec gosu analyst "$@"
