ARG BASE_IMAGE=toth-base:0.2.0
FROM ${BASE_IMAGE}

# Build arguments
ARG TOTH_VERSION="0.2.0"

# Metadata
LABEL org.opencontainers.image.title="DFIR-Toth Network"
LABEL org.opencontainers.image.description="DFIR-Toth - Blue Team Docker Distribution - Network Forensics Image"
LABEL org.opencontainers.image.version="${TOTH_VERSION}"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/Toth-DFIR"
LABEL org.opencontainers.image.licenses="MIT"

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

# Runtime environment
ENV TOTH_VERSION=${TOTH_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

WORKDIR /opt/toth/tools

# System packages
#
# `wireshark` (on top of `wireshark-common`) pulls in `wireshark-qt`, the
# actual GUI binary, plus its Qt5/X11 dependency chain -- confirmed via
# `apt-cache depends wireshark` during the X11-forwarding scoping
# (docs/roadmap-x11-forwarding.md). `libcap2-bin` provides `setcap`, used
# right below.
#
# The `setcap` line: with DEBIAN_FRONTEND=noninteractive (set project-wide),
# wireshark-common's postinst silently takes debconf's default answer to
# "let non-superusers capture packets?", which is "no" on Ubuntu 22.04 --
# dumpcap ships with no elevated capabilities and non-root capture fails
# outright, even with the container's own NET_ADMIN/NET_RAW cap_add (a
# binary only gets to use capabilities from the container's bounding set if
# the binary itself carries matching file capabilities or is setuid-root).
# This single setcap line does by hand what the interactive postinst prompt
# would have done, and was confirmed by direct testing during the scoping
# above to fix non-root `dumpcap`/`tshark` capture, not just Wireshark GUI.
#
# dnstwist is included here too: prefer the apt package, fall back to pip if
# the Ubuntu universe package is unavailable -- no second apt-get update
# needed for the same cache.
RUN apt-get update \
    && ( \
        apt-get install -y --no-install-recommends \
            tshark \
            tcpdump \
            nmap \
            netcat-openbsd \
            whois \
            ngrep \
            tcpflow \
            wireshark-common \
            wireshark \
            libcap2-bin \
            software-properties-common \
            gnupg \
            dnstwist \
        || pip3 install --no-cache-dir dnstwist \
    ) \
    && setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Tool installation
RUN echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' \
        > /etc/apt/sources.list.d/zeek.list \
    && curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key \
        | gpg --dearmor > /etc/apt/trusted.gpg.d/zeek.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends zeek \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Compatibility links
RUN ln -s /opt/zeek/bin/zeek /usr/local/bin/zeek \
    && ln -s /opt/zeek/bin/zeekctl /usr/local/bin/zeekctl

# Runtime permissions
RUN mkdir -p /opt/zeek/spool /opt/zeek/logs \
    && chown -R analyst:analyst /opt/zeek/spool /opt/zeek/logs

RUN add-apt-repository ppa:oisf/suricata-stable -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends suricata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install smoke checks
RUN command -v tshark \
    && command -v tcpdump \
    && command -v nmap \
    && command -v nc \
    && command -v whois \
    && command -v ngrep \
    && command -v tcpflow \
    && command -v dnstwist \
    && command -v zeek \
    && command -v zeekctl \
    && command -v suricata \
    && command -v wireshark \
    && command -v dumpcap

# Runtime
#
# Unlike every other Toth image, toth-network starts as root: VPN
# auto-connect (docs/roadmap-vpn.md) needs root to bring up a tun/wg
# interface, which the "analyst" user cannot do even with the container's
# own cap_add grants. vpn-entrypoint.sh does at most a few read-only
# filesystem checks, starts the tunnel only if a config is actually mounted
# at /opt/toth/vpn, then permanently drops to "analyst" via gosu before
# handing off to CMD -- see config/entrypoint/vpn-entrypoint.sh and
# docs/architecture.md's Runtime model.
USER root
WORKDIR /cases

ENTRYPOINT ["/opt/toth/scripts/vpn-entrypoint.sh"]
CMD ["/bin/bash"]
