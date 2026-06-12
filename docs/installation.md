# Installation

Toth is currently designed for Linux and macOS users with Docker installed.
On Windows, use WSL2.

## Requirements

- Git
- Docker Engine
- Docker Compose plugin
- Python 3
- Bash

## One-line install

```bash
curl -sSL https://raw.githubusercontent.com/xLxxt/Toth-DFIR/dev/install.sh | bash
```

This clones Toth into `~/.toth`, creates a workspace under `~/toth/workspace`,
builds the base image, and installs a `toth` launcher in `~/.local/bin`.

## Manual install

```bash
git clone --branch dev https://github.com/xLxxt/Toth-DFIR.git
cd Toth-DFIR
make build-base
make build-dfir
```

## Docker sanity check

```bash
docker version
docker compose version
docker run --rm hello-world
```

If Docker requires sudo, add your user to the Docker group and open a new shell:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```
