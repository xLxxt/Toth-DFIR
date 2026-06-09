FROM toth-base:0.1.0

LABEL org.opencontainers.image.title="Toth DFIR"
LABEL org.opencontainers.image.description="Blue Team Docker Distribution - DFIR Image"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="xLxxt"
LABEL org.opencontainers.image.source="https://github.com/xLxxt/toth"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive

# Dépendances système nécessaires pour compiler les bindings C de plaso
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config \
        build-essential \
        libfuse-dev \
        zlib1g-dev \
        libbz2-dev \
        python3-dev \
        autoconf \
        automake \
        libtool \
        gettext \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip/setuptools/wheel avant tout install
RUN pip3 install --upgrade pip setuptools wheel

RUN git clone https://github.com/volatilityfoundation/volatility3.git \
    /opt/toth/tools/volatility3 \
    && cd /opt/toth/tools/volatility3 \
    && pip3 install . \
    && ln -s /opt/toth/tools/volatility3/vol.py /usr/local/bin/vol3 \
    && chmod +x /opt/toth/tools/volatility3/vol.py

RUN mkdir -p /opt/toth/tools/chainsaw \
    && curl -sL https://github.com/WithSecureLabs/chainsaw/releases/download/v2.9.1/chainsaw_x86_64-unknown-linux-gnu.tar.gz \
    | tar -xz -C /opt/toth/tools/chainsaw \
    && ln -s /opt/toth/tools/chainsaw/chainsaw /usr/local/bin/chainsaw \
    && git clone --depth 1 https://github.com/WithSecureLabs/chainsaw.git \
    /opt/toth/tools/chainsaw-rules \
    && ln -s /opt/toth/tools/chainsaw-rules/rules /opt/toth/tools/chainsaw/rules \
    && ln -s /opt/toth/tools/chainsaw-rules/mappings /opt/toth/tools/chainsaw/mappings

RUN mkdir -p /opt/toth/tools/hayabusa \
    && wget -q --show-progress \
    "https://github.com/Yamato-Security/hayabusa/releases/download/v3.9.0/hayabusa-3.9.0-lin-x64-musl.zip" \
    -O /tmp/hayabusa.zip \
    && unzip /tmp/hayabusa.zip -d /opt/toth/tools/hayabusa \
    && chmod +x /opt/toth/tools/hayabusa/hayabusa-*-lin-x64-musl \
    && ln -s /opt/toth/tools/hayabusa/hayabusa-*-lin-x64-musl /usr/local/bin/hayabusa \
    && rm /tmp/hayabusa.zip

RUN pip3 install plaso

RUN git clone --depth 1 https://github.com/SigmaHQ/sigma.git \
    /opt/toth/rules/sigma

RUN mkdir -p \
    /cases \
    /opt/toth/output/volatility \
    /opt/toth/output/chainsaw \
    /opt/toth/output/hayabusa \
    /opt/toth/output/plaso

WORKDIR /cases