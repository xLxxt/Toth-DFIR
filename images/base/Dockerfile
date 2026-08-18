FROM ubuntu:22.04

# Build arguments
ARG TOTH_VERSION="0.2.0"

# Metadata
LABEL org.opencontainers.image.title="DFIR-Toth Base"
LABEL org.opencontainers.image.description="DFIR-Toth - Blue Team Docker Distribution - Base Image"
LABEL org.opencontainers.image.version="${TOTH_VERSION}"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/Toth-DFIR"
LABEL org.opencontainers.image.licenses="MIT"

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
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
    openvpn \
    wireguard-tools \
    gosu \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Compatibility links
RUN ln -s "$(command -v fdfind)" /usr/local/bin/fd \
    && if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then \
        ln -s "$(command -v batcat)" /usr/local/bin/bat; \
    fi

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
    && command -v exiftool \
    && command -v openvpn \
    && command -v wg-quick \
    && command -v gosu

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
# Root-owned, unlike the two scripts above: this one runs as root before
# any privilege drop happens (see docs/roadmap-vpn.md section 4), so it
# deliberately stays outside analyst's write access.
COPY config/entrypoint/vpn-entrypoint.sh /opt/toth/scripts/vpn-entrypoint.sh

RUN chmod +x /opt/toth/aliases.sh /opt/toth/scripts/check_tools.sh /opt/toth/scripts/vpn-entrypoint.sh \
    && ln -s /opt/toth/scripts/check_tools.sh /usr/local/bin/toth-check

RUN echo 'source /opt/toth/aliases.sh' >> /home/analyst/.bashrc \
    && echo 'export PATH=$PATH:/opt/toth/tools' >> /home/analyst/.bashrc

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD bash /opt/toth/scripts/check_tools.sh || exit 1

# Runtime
#
# No trailing `USER analyst` here (a change from before this VPN work):
# every image's baked-in default user must stay root so the ENTRYPOINT
# below actually starts as root (needed to bring up a VPN tunnel -- see
# docs/roadmap-vpn.md section 4). The entrypoint itself is what drops
# privileges to `analyst` via gosu before execing CMD, so the CMD process
# analysts actually interact with still ends up running as `analyst`,
# same as before. `docker exec`/`docker compose exec` sessions started
# against an already-running container don't go through the entrypoint,
# so wrapper/utils/docker_manager.py now pins those to `--user analyst`
# explicitly to keep `toth shell`/`toth enter` behavior unchanged.
WORKDIR /cases

ENTRYPOINT ["/opt/toth/scripts/vpn-entrypoint.sh"]
CMD ["/bin/bash"]
