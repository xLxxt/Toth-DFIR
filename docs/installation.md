# Installation

Toth is currently designed for Linux and macOS users with Docker installed.
On Windows, use WSL2.

The installer is intentionally user-scoped: it installs Toth under your normal
user account, not under `root`. Do not run it with `sudo`.

## Requirements

- Git
- Python 3
- Bash or Zsh

Docker Engine and the Docker Compose plugin are required to run containers, but
the installer itself only requires Git and Python 3.

## Docker sanity check

Before installing Toth, verify that Docker works without `sudo`:

```bash
docker version
docker compose version
docker run --rm hello-world
```

If Docker requires `sudo`, add your user to the Docker group and open a new
shell:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
docker run --rm hello-world
```

Why: the Toth wrapper calls Docker directly. Running the installer with `sudo`
would install files under `/root`, which breaks the expected user workspace.

## Fedora quick setup

On Fedora, install Docker and the Compose plugin first:

```bash
sudo dnf install -y docker docker-compose-plugin git python3 curl
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
docker run --rm hello-world
```

If your shell is Zsh, the installer adds `~/.local/bin` to `~/.zshrc`. For Bash,
it uses `~/.bashrc`.

## Public install

Once the repository is public, the standard install is:

```bash
curl -sSL https://raw.githubusercontent.com/xLxxt/Toth-DFIR/dev/install.sh | bash
```

This clones Toth into `~/.toth`, creates a workspace under
`~/toth/workspace`, and installs a `toth` launcher in `~/.local/bin`.
It does not build Docker images during installation; images are pulled later
with `toth update`.

Restart your shell after installation, or source your shell profile:

```bash
source ~/.bashrc
```

For Zsh:

```bash
source ~/.zshrc
```

## Private or development install

If the repository is private, HTTPS clone can fail because GitHub no longer
supports password authentication for Git operations. Use SSH instead:

```bash
git clone git@github.com:xLxxt/Toth-DFIR.git /tmp/Toth-DFIR
cd /tmp/Toth-DFIR
TOTH_REPO_URL=git@github.com:xLxxt/Toth-DFIR.git ./install.sh
```

The installer keeps HTTPS as the default because it is the right behavior for a
public release. `TOTH_REPO_URL` is only needed for private repositories or
custom forks.

## Installer options

The installer can be customized with environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TOTH_REPO_URL` | `https://github.com/xLxxt/Toth-DFIR.git` | Git repository to clone |
| `TOTH_BRANCH` | `dev` | Branch to install |
| `TOTH_DIR` | `~/.toth` | Local installation directory |
| `TOTH_WORKSPACE` | `~/toth/workspace` | Case workspace mounted into containers |

Examples:

```bash
TOTH_BRANCH=main ./install.sh
TOTH_WORKSPACE="$HOME/labs/toth" ./install.sh
```

## Manual install

Manual installation is useful when developing Toth itself:

```bash
git clone --branch dev https://github.com/xLxxt/Toth-DFIR.git
cd Toth-DFIR
cp .env.example .env
make build-base
make build-dfir
make build-malware
make build-network
```

## Verify the installation

After install, check that the wrapper is available:

```bash
command -v toth
toth --version
```

Install a profile image and open a shell:

```bash
toth update dfir
toth shell dfir
```

If the public image has not been published yet, build it locally:

```bash
toth update --build dfir
```

Inside the container, run the tool inventory check:

```bash
toth-check
```

## Troubleshooting

### The installer asks for a GitHub username

This usually means the repository is private and the installer tried to clone
over HTTPS. Use SSH:

```bash
TOTH_REPO_URL=git@github.com:xLxxt/Toth-DFIR.git ./install.sh
```

### `toth update` says Docker is not running

Start Docker and retry:

```bash
sudo systemctl enable --now docker
docker info
```

### The `toth` command is not found

Ensure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then add the same line to `~/.bashrc` or `~/.zshrc` if needed.
