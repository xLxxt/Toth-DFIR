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
# EZTOOLS_BASE_URL has no versioned per-release path to pin (see the comment
# above the EZTools RUN steps below for why); these pin the SHA256 of each
# tool's archive as downloaded from that endpoint instead, so a silent
# upstream change fails the build rather than being installed unnoticed.
ARG MFTECMD_SHA256="60ae857a554b830243e38e91fafdfdf6066f31c703282c5c6f40daf3b64d3160"
ARG PECMD_SHA256="e361d397c8c64959fd537e1826fcb89ea2d6fe24b3b4b63e6666479d565caa15"
ARG LECMD_SHA256="f3e9c799ec7d3fa4cd5f553ec3f9d544c80c8e48afd04ef43456da3d48ad0760"
ARG JLECMD_SHA256="155ee54e6ac6b70bce1aa636ec52d0b0165263933764d9a45c85af97df546892"
ARG SBECMD_SHA256="88edb98a32baaf68114aa106f25f999e46d387d9d0003d3222a1168cc1b7eb9b"
ARG AMCACHEPARSER_SHA256="d40d1e7863159dbd9aa3ae826d919edc490ca33df84bde57e86da848a583af03"
ARG RECMD_SHA256="4a4e2f4beba54fdb9ba4eeb5e6f9d323e666b309e407ac89e047f82be0c963a2"

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
# Unlike Chainsaw/Hayabusa, there is no versioned-release alternative to pin
# against instead of this endpoint (checked the GitHub API for all seven
# tools' own repos, e.g. github.com/EricZimmerman/MFTECmd): MFTECmd, PECmd,
# LECmd, JLECmd, and RECmd have no GitHub Releases at all (tags exist for
# some, releases don't); AmcacheParser does have release tags but their
# asset lists are empty (source-only zipball/tarball, no compiled DLL
# attached); SBECmd has no dedicated GitHub repo at all in Eric Zimmerman's
# account. download.ericzimmermanstools.com is the only place a compiled
# build of any of these seven tools is published, and it is an unversioned
# "always serves current build" endpoint (verified here as version
# 2026.5.0) -- so there is no per-tool version ARG to pin the way
# CHAINSAW_VERSION/HAYABUSA_VERSION do above.
#
# To still catch a silent upstream change, each ARG *_SHA256 above pins the
# SHA256 of the exact archive downloaded from this endpoint at the time
# this was written; the RUN steps below verify it with `sha256sum -c` and
# fail the build on mismatch. If Eric Zimmerman legitimately updates one of
# these tools, the build breaks until someone re-downloads the new archive,
# recomputes its SHA256, and bumps the corresponding ARG above -- there is
# no version signal from this endpoint to distinguish a legitimate update
# from a compromise automatically. See docs/known-limitations.md for this
# tradeoff.
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

# MFTECmd, PECmd, LECmd, JLECmd, SBECmd, and AmcacheParser share an identical
# download/verify/unpack/wrapper pattern -- loop over them so fixing that
# pattern or adding another flat-archive EZTool is a one-place change. RECmd
# is handled separately below: its archive has a nested Plugins/BatchExamples
# layout the others don't, so it doesn't fit this loop cleanly.
RUN for tool in MFTECmd PECmd LECmd JLECmd SBECmd AmcacheParser; do \
        case "$tool" in \
            MFTECmd) sha256="$MFTECMD_SHA256" ;; \
            PECmd) sha256="$PECMD_SHA256" ;; \
            LECmd) sha256="$LECMD_SHA256" ;; \
            JLECmd) sha256="$JLECMD_SHA256" ;; \
            SBECmd) sha256="$SBECMD_SHA256" ;; \
            AmcacheParser) sha256="$AMCACHEPARSER_SHA256" ;; \
        esac; \
        wrapper="/usr/local/bin/${tool,,}"; \
        mkdir -p "/opt/toth/tools/zimmerman/${tool}"; \
        curl -fsSL "${EZTOOLS_BASE_URL}/${tool}.zip" -o "/tmp/${tool}.zip"; \
        echo "${sha256}  /tmp/${tool}.zip" | sha256sum -c -; \
        unzip -q "/tmp/${tool}.zip" -d "/opt/toth/tools/zimmerman/${tool}"; \
        rm -f "/tmp/${tool}.zip"; \
        printf '#!/bin/bash\nexec dotnet /opt/toth/tools/zimmerman/%s/%s.dll "$@"\n' "$tool" "$tool" \
            > "$wrapper"; \
        chmod +x "$wrapper"; \
    done

# RECmd's archive bundles its own Plugins/ (registry-key parsers) and
# BatchExamples/ (.reb rule files) under a top-level RECmd/ directory,
# unlike the flat archives above -- unzip one level up so the layout lands
# at /opt/toth/tools/zimmerman/RECmd/{RECmd.dll,Plugins,BatchExamples}. It is
# checksum-pinned the same way as the loop above (see the SHA256 note).
RUN mkdir -p /opt/toth/tools/zimmerman \
    && curl -fsSL "${EZTOOLS_BASE_URL}/RECmd.zip" -o /tmp/recmd.zip \
    && echo "${RECMD_SHA256}  /tmp/recmd.zip" | sha256sum -c - \
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

# Install smoke checks: `command -v` only confirms a wrapper script or
# binary exists on PATH and is executable -- it would still pass if dotnet
# or an EZTools wrapper's hardcoded DLL path were wrong, since that failure
# only surfaces when the tool actually runs. So for dotnet, the Sleuth Kit
# trio, and the seven EZTools wrappers, invoke each one for real instead
# (cheap, side-effect-free flags: --list-runtimes / -V / --help).
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
    && test -d /opt/toth/rules/sigma \
    && dotnet --list-runtimes \
    && for tsk in fls icat mmls; do "$tsk" -V; done \
    && for ez in mftecmd pecmd lecmd jlecmd sbecmd amcacheparser recmd; do "$ez" --help >/dev/null; done

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
