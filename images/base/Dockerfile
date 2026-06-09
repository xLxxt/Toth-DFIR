FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Toth Base"
LABEL org.opencontainers.image.description="Blue Team Docker Distribution - Base Image"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/toth"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive
ARG TOTH_VERSION="0.1.0"

ENV TOTH_VERSION=${TOTH_VERSION} \
    TOTH_HOME="/opt/toth" \
    TOTH_CASES="/cases" \
    TOTH_OUTPUT="/opt/toth/output" \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    net-tools \
    dnsutils \
    git \
    unzip \
    tar \
    file \
    xxd \
    binutils \
    vim \
    nano \
    tmux \
    less \
    tree \
    python3 \
    python3-pip \
    python3-dev \
    jq \
    foremost \
    binwalk \
    exiftool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    ${TOTH_HOME} \
    ${TOTH_HOME}/output \
    ${TOTH_HOME}/scripts \
    ${TOTH_CASES}

COPY config/shell/aliases.sh /opt/toth/aliases.sh
COPY tools/verify/check_tools.sh /opt/toth/scripts/check_tools.sh

RUN chmod +x /opt/toth/aliases.sh /opt/toth/scripts/check_tools.sh