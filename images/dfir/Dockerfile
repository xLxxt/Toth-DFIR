ARG BASE_IMAGE=toth-base:0.2.0
FROM ${BASE_IMAGE}

# Build arguments
ARG TOTH_VERSION="0.2.0"

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
ARG DOTNET_RUNTIME_VERSION="9.0.19"
ARG EZTOOLS_BASE_URL="https://download.ericzimmermanstools.com/net9"

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
        sleuthkit \
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

# Eric Zimmerman's tools (selective subset, per docs/roadmap-phase3.md
# section 4): MFTECmd ($MFT), PECmd (Prefetch), LECmd/JLECmd (LNK files and
# jumplists), SBECmd (shellbags), AmcacheParser, and RECmd (registry) parse
# artifacts nothing else in this image touches. EvtxECmd is intentionally
# skipped -- it overlaps with Chainsaw/Hayabusa's EVTX-hunting coverage.
# RECmd is included alongside RegRipper (not instead of it): RECmd's own
# archive bundles ~90 actively-maintained plugins plus community batch rule
# files (DFIRBatch.reb) and adds transaction-log (.LOG/.LOG1/.LOG2) replay,
# deleted-key recovery, and Volume Shadow Copy enumeration -- none of which
# RegRipper's plugin set does -- so the two are complementary, not redundant.
#
# All tools/repos above are MIT-licensed (confirmed on GitHub); the compiled
# archives are fetched from Eric Zimmerman's own official download endpoint,
# the same one his official Get-ZimmermanTools script uses.
#
# Unlike Chainsaw/Hayabusa, this endpoint has no versioned URL -- it always
# serves the current build (verified here as version 2026.5.0) -- so there
# is no per-tool version ARG to pin.
#
# These ship as .NET 9 framework-dependent builds (a DLL, not a
# self-contained native binary), so a .NET runtime is required to run them.
# Eric Zimmerman does not publish self-contained linux-x64/arm64 builds for
# this tool set. The official runtime IS available for both amd64 and
# arm64, but only as a direct tarball -- packages.microsoft.com's Ubuntu
# 22.04 apt feed carries dotnet-runtime-9.0 for amd64 only, not arm64 -- so
# install from the tarball (TARGETARCH-branched, same as Chainsaw/Hayabusa)
# rather than via apt.
RUN case "${TARGETARCH}" in arm64) DOTNET_ARCH=arm64 ;; *) DOTNET_ARCH=x64 ;; esac \
    && mkdir -p /opt/toth/tools/dotnet \
    && curl -fsSL \
        "https://builds.dotnet.microsoft.com/dotnet/Runtime/${DOTNET_RUNTIME_VERSION}/dotnet-runtime-${DOTNET_RUNTIME_VERSION}-linux-${DOTNET_ARCH}.tar.gz" \
        -o /tmp/dotnet-runtime.tar.gz \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /opt/toth/tools/dotnet \
    && ln -s /opt/toth/tools/dotnet/dotnet /usr/local/bin/dotnet \
    && rm -f /tmp/dotnet-runtime.tar.gz

RUN mkdir -p /opt/toth/tools/zimmerman/MFTECmd \
    && curl -fsSL "${EZTOOLS_BASE_URL}/MFTECmd.zip" -o /tmp/mftecmd.zip \
    && unzip -q /tmp/mftecmd.zip -d /opt/toth/tools/zimmerman/MFTECmd \
    && rm -f /tmp/mftecmd.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/MFTECmd/MFTECmd.dll "$@"\n' \
        > /usr/local/bin/mftecmd \
    && chmod +x /usr/local/bin/mftecmd

RUN mkdir -p /opt/toth/tools/zimmerman/PECmd \
    && curl -fsSL "${EZTOOLS_BASE_URL}/PECmd.zip" -o /tmp/pecmd.zip \
    && unzip -q /tmp/pecmd.zip -d /opt/toth/tools/zimmerman/PECmd \
    && rm -f /tmp/pecmd.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/PECmd/PECmd.dll "$@"\n' \
        > /usr/local/bin/pecmd \
    && chmod +x /usr/local/bin/pecmd

RUN mkdir -p /opt/toth/tools/zimmerman/LECmd \
    && curl -fsSL "${EZTOOLS_BASE_URL}/LECmd.zip" -o /tmp/lecmd.zip \
    && unzip -q /tmp/lecmd.zip -d /opt/toth/tools/zimmerman/LECmd \
    && rm -f /tmp/lecmd.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/LECmd/LECmd.dll "$@"\n' \
        > /usr/local/bin/lecmd \
    && chmod +x /usr/local/bin/lecmd

RUN mkdir -p /opt/toth/tools/zimmerman/JLECmd \
    && curl -fsSL "${EZTOOLS_BASE_URL}/JLECmd.zip" -o /tmp/jlecmd.zip \
    && unzip -q /tmp/jlecmd.zip -d /opt/toth/tools/zimmerman/JLECmd \
    && rm -f /tmp/jlecmd.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/JLECmd/JLECmd.dll "$@"\n' \
        > /usr/local/bin/jlecmd \
    && chmod +x /usr/local/bin/jlecmd

RUN mkdir -p /opt/toth/tools/zimmerman/SBECmd \
    && curl -fsSL "${EZTOOLS_BASE_URL}/SBECmd.zip" -o /tmp/sbecmd.zip \
    && unzip -q /tmp/sbecmd.zip -d /opt/toth/tools/zimmerman/SBECmd \
    && rm -f /tmp/sbecmd.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/SBECmd/SBECmd.dll "$@"\n' \
        > /usr/local/bin/sbecmd \
    && chmod +x /usr/local/bin/sbecmd

RUN mkdir -p /opt/toth/tools/zimmerman/AmcacheParser \
    && curl -fsSL "${EZTOOLS_BASE_URL}/AmcacheParser.zip" -o /tmp/amcacheparser.zip \
    && unzip -q /tmp/amcacheparser.zip -d /opt/toth/tools/zimmerman/AmcacheParser \
    && rm -f /tmp/amcacheparser.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/AmcacheParser/AmcacheParser.dll "$@"\n' \
        > /usr/local/bin/amcacheparser \
    && chmod +x /usr/local/bin/amcacheparser

# RECmd's archive bundles its own Plugins/ (registry-key parsers) and
# BatchExamples/ (.reb rule files) under a top-level RECmd/ directory,
# unlike the flat archives above -- unzip one level up so the layout lands
# at /opt/toth/tools/zimmerman/RECmd/{RECmd.dll,Plugins,BatchExamples}.
RUN mkdir -p /opt/toth/tools/zimmerman \
    && curl -fsSL "${EZTOOLS_BASE_URL}/RECmd.zip" -o /tmp/recmd.zip \
    && unzip -q /tmp/recmd.zip -d /opt/toth/tools/zimmerman \
    && rm -f /tmp/recmd.zip \
    && printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/RECmd/RECmd.dll "$@"\n' \
        > /usr/local/bin/recmd \
    && chmod +x /usr/local/bin/recmd

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
    && command -v fls \
    && command -v icat \
    && command -v mmls \
    && command -v dotnet \
    && command -v mftecmd \
    && command -v pecmd \
    && command -v lecmd \
    && command -v jlecmd \
    && command -v sbecmd \
    && command -v amcacheparser \
    && command -v recmd \
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
#
# No `USER analyst` here -- inherited from images/base/Dockerfile, whose
# root-first ENTRYPOINT (see docs/roadmap-vpn.md section 4) needs the
# image's baked-in default user to stay root. This profile never mounts
# /opt/toth/vpn or gets the VPN capability grant (network-only in v1, see
# section 3), so the entrypoint no-ops immediately here regardless --
# behavior is unchanged -- but re-asserting `USER analyst` in a derived
# Dockerfile would still be wrong in general, since Docker uses the *last*
# USER directive across all layers as the image's default. ENTRYPOINT/CMD
# are also inherited from base; only WORKDIR is redeclared here (a no-op,
# base already sets it) for clarity.
WORKDIR /cases
