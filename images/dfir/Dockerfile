ARG BASE_IMAGE=toth-base:0.1.0
FROM ${BASE_IMAGE}

# Build arguments
ARG TOTH_VERSION="0.1.0"

# Metadata
LABEL org.opencontainers.image.title="DFIR-Toth DFIR"
LABEL org.opencontainers.image.description="DFIR-Toth - Blue Team Docker Distribution - DFIR Image"
LABEL org.opencontainers.image.version="${TOTH_VERSION}"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/Toth-DFIR"
LABEL org.opencontainers.image.licenses="MIT"

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG CHAINSAW_VERSION="2.16.0"
ARG HAYABUSA_VERSION="3.9.0"

# Runtime environment
ENV TOTH_VERSION=${TOTH_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# System packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config \
        build-essential \
        cmake \
        libfuse-dev \
        zlib1g-dev \
        libbz2-dev \
        python3-dev \
        autoconf \
        automake \
        autopoint \
        libtool \
        gettext \
        libesedb-utils \
        perl \
        libparse-win32registry-perl \
        libssl-dev \
        libewf-dev \
        libexpat1-dev \
        libicu-dev \
        libre2-dev \
        g++ \
        flex \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Tool installation
RUN git clone --depth 1 --recurse-submodules \
        https://github.com/simsong/bulk_extractor.git \
        /tmp/bulk_extractor \
    && cd /tmp/bulk_extractor \
    && ./bootstrap.sh \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/bulk_extractor

RUN git clone --depth 1 --recurse-submodules \
        https://github.com/libyal/libbfio.git \
        /tmp/libbfio \
    && cd /tmp/libbfio \
    && ./synclibs.sh \
    && ./autogen.sh \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && rm -rf /tmp/libbfio

RUN git clone --depth 1 --recurse-submodules \
        https://github.com/libyal/libpff.git \
        /tmp/libpff \
    && cd /tmp/libpff \
    && ./synclibs.sh \
    && ./autogen.sh \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && rm -rf /tmp/libpff

RUN git clone --depth 1 https://github.com/keydet89/RegRipper3.0.git \
        /opt/toth/tools/regripper \
    && chmod +x /opt/toth/tools/regripper/rip.pl \
    && ln -s /opt/toth/tools/regripper/rip.pl /usr/local/bin/regripper

RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install \
        python-evtx \
        sigma-cli \
        timesketch-api-client \
        plaso \
        ioc-finder

RUN git clone https://github.com/volatilityfoundation/volatility3.git \
        /opt/toth/tools/volatility3 \
    && cd /opt/toth/tools/volatility3 \
    && pip3 install . \
    && ln -s /opt/toth/tools/volatility3/vol.py /usr/local/bin/vol3 \
    && chmod +x /opt/toth/tools/volatility3/vol.py

RUN case "${TARGETARCH}" in arm64) CS_ARCH=aarch64 ;; *) CS_ARCH=x86_64 ;; esac \
    && mkdir -p /opt/toth/tools/chainsaw \
    && curl -fsSL \
        "https://github.com/WithSecureLabs/chainsaw/releases/download/v${CHAINSAW_VERSION}/chainsaw_${CS_ARCH}-unknown-linux-gnu.tar.gz" \
        -o /tmp/chainsaw.tar.gz \
    && tar -xzf /tmp/chainsaw.tar.gz -C /opt/toth/tools/chainsaw \
    && rm -f /tmp/chainsaw.tar.gz \
    && git clone --depth 1 https://github.com/WithSecureLabs/chainsaw.git \
        /opt/toth/tools/chainsaw-rules \
    && ln -s /opt/toth/tools/chainsaw-rules/rules /opt/toth/tools/chainsaw/rules \
    && ln -s /opt/toth/tools/chainsaw-rules/mappings /opt/toth/tools/chainsaw/mappings \
    && ln -s /opt/toth/tools/chainsaw/chainsaw/chainsaw /usr/local/bin/chainsaw

RUN case "${TARGETARCH}" in \
        arm64) HAYA_ARCH=aarch64; HAYA_LIBC=gnu ;; \
        *) HAYA_ARCH=x64; HAYA_LIBC=musl ;; \
    esac \
    && mkdir -p /opt/toth/tools/hayabusa \
    && curl -fsSL \
        "https://github.com/Yamato-Security/hayabusa/releases/download/v${HAYABUSA_VERSION}/hayabusa-${HAYABUSA_VERSION}-lin-${HAYA_ARCH}-${HAYA_LIBC}.zip" \
        -o /tmp/hayabusa.zip \
    && unzip -q /tmp/hayabusa.zip -d /opt/toth/tools/hayabusa \
    && chmod +x "/opt/toth/tools/hayabusa/hayabusa-${HAYABUSA_VERSION}-lin-${HAYA_ARCH}-${HAYA_LIBC}" \
    && ln -s "/opt/toth/tools/hayabusa/hayabusa-${HAYABUSA_VERSION}-lin-${HAYA_ARCH}-${HAYA_LIBC}" /opt/toth/tools/hayabusa/hayabusa \
    && ln -s /opt/toth/tools/hayabusa/hayabusa /usr/local/bin/hayabusa \
    && rm -f /tmp/hayabusa.zip

RUN git clone --depth 1 https://github.com/SigmaHQ/sigma.git \
        /opt/toth/rules/sigma

# Threat intel and Linux host forensics packages (lynis/chkrootkit/rkhunter
# audit the host they run on; see docs/known-limitations.md)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        lynis \
        chkrootkit \
        rkhunter \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Bake the rkhunter file-properties database in at build time, while network
# access is available, so it never has to reach out at container runtime
# (dfir runs with network_mode: none).
RUN rkhunter --propupd

# Install smoke checks
RUN command -v bulk_extractor \
    && command -v pffexport \
    && command -v regripper \
    && command -v vol3 \
    && command -v chainsaw \
    && command -v hayabusa \
    && command -v ioc-finder \
    && command -v lynis \
    && command -v chkrootkit \
    && command -v rkhunter \
    && test -d /opt/toth/rules/sigma

# Workspace and permissions
RUN mkdir -p \
        /cases \
        /opt/toth/output/volatility \
        /opt/toth/output/chainsaw \
        /opt/toth/output/hayabusa \
        /opt/toth/output/plaso \
    && chown -R analyst:analyst \
        /opt/toth/tools \
        /opt/toth/rules \
        /opt/toth/output \
        /cases

# Runtime
USER analyst
WORKDIR /cases

CMD ["/bin/bash"]
