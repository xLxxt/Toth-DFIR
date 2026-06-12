ARG BASE_IMAGE=toth-base:0.1.0
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Toth Network"
LABEL org.opencontainers.image.description="Blue Team Docker Distribution - Network Forensics"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/Toth-DFIR"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive
ARG TOTH_VERSION="0.1.0"
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

WORKDIR /opt/toth/tools

# Outils réseau de base
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    tshark \
    tcpdump \
    nmap \
    netcat-openbsd \
    wireshark-common \
    software-properties-common \
    gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Zeek
RUN echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' \
    > /etc/apt/sources.list.d/zeek.list \
    && curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key \
    | gpg --dearmor > /etc/apt/trusted.gpg.d/zeek.gpg \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y zeek \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Suricata
RUN add-apt-repository ppa:oisf/suricata-stable -y \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y suricata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER analyst
WORKDIR /cases

CMD ["/bin/bash"]
