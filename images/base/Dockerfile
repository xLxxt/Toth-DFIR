FROM ubuntu:22.04

# Metadata
LABEL org.opencontainers.image.title="DFIR-Toth Base"
LABEL org.opencontainers.image.description="DFIR-Toth - Blue Team Docker Distribution - Base Image"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/Toth-DFIR"
LABEL org.opencontainers.image.licenses="MIT"

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG TOTH_VERSION="0.1.0"
ARG TARGETARCH

# Runtime environment
ENV TOTH_VERSION=${TOTH_VERSION} \
    TOTH_HOME="/opt/toth" \
    TOTH_CASES="/cases" \
    TOTH_OUTPUT="/opt/toth/output" \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    net-tools \
    dnsutils \
    git \
    unzip \
    p7zip-full \
    unar \
    tar \
    file \
    xxd \
    binutils \
    vim \
    nano \
    tmux \
    less \
    tree \
    bat \
    ripgrep \
    fzf \
    fd-find \
    hexyl \
    lnav \
    pv \
    zsh \
    sqlite3 \
    libmagic-dev \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    jq \
    miller \
    foremost \
    binwalk \
    exiftool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Compatibility links
RUN ln -s "$(command -v fdfind)" /usr/local/bin/fd

# Install smoke checks
RUN command -v curl \
    && command -v wget \
    && command -v git \
    && command -v python3 \
    && command -v pip3 \
    && command -v jq \
    && command -v fd \
    && command -v rg \
    && command -v binwalk \
    && command -v exiftool

# Runtime user
RUN groupadd -g 1000 analyst \
    && useradd -m -u 1000 -g analyst -s /bin/bash analyst

# Workspace and permissions
RUN mkdir -p \
        ${TOTH_HOME} \
        ${TOTH_HOME}/output \
        ${TOTH_HOME}/scripts \
        ${TOTH_HOME}/tools \
        ${TOTH_CASES} \
    && chown -R analyst:analyst ${TOTH_HOME} ${TOTH_CASES}

# Shell configuration and helper scripts
COPY --chown=analyst:analyst config/shell/aliases.sh /opt/toth/aliases.sh
COPY --chown=analyst:analyst tools/verify/check_tools.sh /opt/toth/scripts/check_tools.sh

RUN chmod +x /opt/toth/aliases.sh /opt/toth/scripts/check_tools.sh

RUN echo 'source /opt/toth/aliases.sh' >> /home/analyst/.bashrc \
    && echo 'export PATH=$PATH:/opt/toth/tools' >> /home/analyst/.bashrc

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD bash /opt/toth/scripts/check_tools.sh || exit 1

# Runtime
USER analyst
WORKDIR /cases

CMD ["/bin/bash"]
