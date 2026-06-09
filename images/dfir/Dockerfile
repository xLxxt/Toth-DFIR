FROM toth-base:0.1.0

LABEL org.opencontainers.image.title="DFIR-Toth DFIR"
LABEL org.opencontainers.image.description="DFIR-Toth - Blue Team Docker Distribution - DFIR Image"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/dfir-toth"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive

USER root

# Dépendances système
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

# bulk_extractor — compilation depuis les sources
RUN git clone --depth 1 --recurse-submodules \
        https://github.com/simsong/bulk_extractor.git \
        /tmp/bulk_extractor \
    && cd /tmp/bulk_extractor \
    && ./bootstrap.sh \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/bulk_extractor

# libbfio — dépendance de libpff
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

# libpff — compilation depuis les sources (pffexport)
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

# regripper
RUN git clone --depth 1 https://github.com/keydet89/RegRipper3.0.git \
        /opt/toth/tools/regripper \
    && chmod +x /opt/toth/tools/regripper/rip.pl \
    && ln -s /opt/toth/tools/regripper/rip.pl /usr/local/bin/regripper

# Python — upgrade + packages
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install \
        python-evtx \
        sigma-cli \
        timesketch-api-client \
        plaso

# volatility3
RUN git clone https://github.com/volatilityfoundation/volatility3.git \
        /opt/toth/tools/volatility3 \
    && cd /opt/toth/tools/volatility3 \
    && pip3 install . \
    && ln -s /opt/toth/tools/volatility3/vol.py /usr/local/bin/vol3 \
    && chmod +x /opt/toth/tools/volatility3/vol.py

# chainsaw
RUN mkdir -p /opt/toth/tools/chainsaw \
    && curl -sL https://github.com/WithSecureLabs/chainsaw/releases/download/v2.9.1/chainsaw_x86_64-unknown-linux-gnu.tar.gz \
        | tar -xz -C /opt/toth/tools/chainsaw \
    && git clone --depth 1 https://github.com/WithSecureLabs/chainsaw.git \
        /opt/toth/tools/chainsaw-rules \
    && ln -s /opt/toth/tools/chainsaw-rules/rules /opt/toth/tools/chainsaw/rules \
    && ln -s /opt/toth/tools/chainsaw-rules/mappings /opt/toth/tools/chainsaw/mappings \
    && ln -s /opt/toth/tools/chainsaw/chainsaw /usr/local/bin/chainsaw

# hayabusa
RUN mkdir -p /opt/toth/tools/hayabusa \
    && wget -q \
        "https://github.com/Yamato-Security/hayabusa/releases/download/v3.9.0/hayabusa-3.9.0-lin-x64-musl.zip" \
        -O /tmp/hayabusa.zip \
    && unzip /tmp/hayabusa.zip -d /opt/toth/tools/hayabusa \
    && chmod +x /opt/toth/tools/hayabusa/hayabusa-*-lin-x64-musl \
    && ln -s /opt/toth/tools/hayabusa/hayabusa-*-lin-x64-musl /usr/local/bin/hayabusa \
    && rm /tmp/hayabusa.zip

# Sigma rules
RUN git clone --depth 1 https://github.com/SigmaHQ/sigma.git \
        /opt/toth/rules/sigma

# Arborescence + permissions
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

USER analyst
WORKDIR /cases
