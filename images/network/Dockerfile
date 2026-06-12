ARG BASE_IMAGE=toth-base:0.1.0
FROM ${BASE_IMAGE}

# Metadata
LABEL org.opencontainers.image.title="DFIR-Toth Network"
LABEL org.opencontainers.image.description="DFIR-Toth - Blue Team Docker Distribution - Network Forensics Image"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/Toth-DFIR"
LABEL org.opencontainers.image.licenses="MIT"

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG TOTH_VERSION="0.1.0"
ARG TARGETARCH

# Runtime environment
ENV TOTH_VERSION=${TOTH_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

WORKDIR /opt/toth/tools

# System packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tshark \
        tcpdump \
        nmap \
        netcat-openbsd \
        wireshark-common \
        software-properties-common \
        gnupg \
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

RUN add-apt-repository ppa:oisf/suricata-stable -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends suricata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Runtime
USER analyst
WORKDIR /cases

CMD ["/bin/bash"]
