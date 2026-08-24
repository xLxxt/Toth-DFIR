#!/bin/bash
set -euo pipefail

# ============================================================================
# Toth-DFIR installer
# ============================================================================
# One-liner:
#   curl -sSL https://raw.githubusercontent.com/xLxxt/Toth-DFIR/dev/install.sh | bash
#
# What it does:
#   1. Detect the OS / package manager
#   2. Install base dependencies (git, curl, python3, pip, make, etc.)
#   3. Install Docker Engine + compose plugin if missing
#   4. Add the current user to the `docker` group
#   5. Clone Toth-DFIR into ~/.toth (or $TOTH_DIR)
#   6. Create the workspace dirs and the `toth` wrapper command
#   7. Add ~/.local/bin to PATH in the user's shell rc
# ============================================================================

REPO_URL="${TOTH_REPO_URL:-https://github.com/xLxxt/Toth-DFIR.git}"
BRANCH="${TOTH_BRANCH:-dev}"
INSTALL_DIR="${TOTH_DIR:-$HOME/.toth}"
BIN_DIR="$HOME/.local/bin"
WORKSPACE="${TOTH_WORKSPACE:-$HOME/toth/workspace}"

# ── helpers ────────────────────────────────────────────────────────────────

info()  { echo -e "\e[32m[+]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
error() { echo -e "\e[31m[x]\e[0m $*" >&2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

run_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif have_cmd sudo; then
        sudo "$@"
    else
        error "This step needs root. Run the installer with sudo or as root, then re-source your shell."
        exit 1
    fi
}

pkg_install() {
    # shellcheck disable=SC2086
    run_sudo apt-get install -y --no-install-recommends "$@"
}

# ── can't run as real root (we'd install into /root) ───────────────────────

if [ "${EUID:-$(id -u)}" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    error "Do not run this installer as root."
    error "It installs Toth for your normal user (~/.toth, ~/.local/bin)."
    error "If you need root for the package-manager steps, re-run as your user;"
    error "the script will invoke sudo itself when needed."
    exit 1
fi

# ── step 1 – detect OS / package manager ──────────────────────────────────

info "Detecting OS..."

if ! have_cmd apt-get; then
    error "This installer currently supports Debian/Ubuntu (apt-get)."
    error "On Fedora/RHEL/Arch/macOS, install Docker and Python 3 manually then clone the repo."
    exit 1
fi

# ── step 2 – install base dependencies ────────────────────────────────────

BASE_PKGS=(
    git curl wget ca-certificates
    python3 python3-pip python3-venv
    make jq
    build-essential pkg-config
    libssl-dev libffi-dev
)

info "Installing base dependencies..."
run_sudo apt-get update -qq
pkg_install "${BASE_PKGS[@]}"

# Upgrade pip quietly
python3 -m pip install --upgrade pip --quiet 2>/dev/null || true

# ── step 3 – install Docker if missing ────────────────────────────────────

install_docker() {
    info "Installing Docker Engine..."

    # Add Docker's official GPG key and repo
    run_sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | run_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    ARCH="$(dpkg --print-architecture)"
    CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
        | run_sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    run_sudo apt-get update -qq
    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    info "Starting Docker daemon..."
    run_sudo systemctl enable --now docker 2>/dev/null || {
        warn "systemctl not available (maybe in a container). Docker may need to be started manually."
    }

    info "Adding $USER to the docker group..."
    run_sudo usermod -aG docker "$USER"

    if ! groups "$USER" | grep -q docker; then
        warn "Group change won't take effect until your next login."
        warn "Run 'newgrp docker' in your current shell to apply it now."
    fi
}

if ! have_cmd docker; then
    install_docker
else
    info "Docker is already installed ($(docker --version 2>/dev/null || true))."
    if ! docker info >/dev/null 2>&1; then
        warn "Docker is installed but the daemon is not reachable."
        warn "Start Docker and retry: toth update <profile>"
    fi
fi

# ── step 4 – clone / update Toth-DFIR ─────────────────────────────────────

info "Installing Toth-DFIR into ${INSTALL_DIR}..."

if [ -d "${INSTALL_DIR}/.git" ]; then
    info "Updating existing install..."
    git -C "$INSTALL_DIR" pull --ff-only "$BRANCH"
elif [ -e "$INSTALL_DIR" ]; then
    error "${INSTALL_DIR} already exists but is not a Git repository."
    error "Remove it or set TOTH_DIR to another location."
    exit 1
else
    info "Cloning ${REPO_URL} (branch: ${BRANCH})..."
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

# ── step 5 – workspace + wrapper command ───────────────────────────────────

info "Setting up workspace at ${WORKSPACE}..."
mkdir -p "${WORKSPACE}/cases" "${WORKSPACE}/output"

# Write .env for local overrides (only if not already present)
ENV_FILE="${INSTALL_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
    printf 'TOTH_WORKSPACE=%s\n' "$WORKSPACE" > "$ENV_FILE"
fi

info "Creating 'toth' command in ${BIN_DIR}..."
mkdir -p "$BIN_DIR"
cat > "${BIN_DIR}/toth" <<'EOF'
#!/bin/bash
exec python3 "${TOTH_INSTALL_DIR:-$HOME/.toth}/wrapper/toth.py" "$@"
EOF
chmod +x "${BIN_DIR}/toth"

# ── step 6 – ensure ~/.local/bin is in PATH ────────────────────────────────

info "Checking PATH..."

case ":${PATH}:" in
    *":${BIN_DIR}:"*)
        ;;
    *)
        info "Adding ${BIN_DIR} to PATH..."

        # Detect shell rc file
        rc=""
        case "$(basename "${SHELL:-}")" in
            zsh)  rc="$HOME/.zshrc"  ;;
            bash) rc="$HOME/.bashrc" ;;
            *)
                rc=""
                warn "Unknown shell \$(basename \"$SHELL\"). Add ${BIN_DIR} to your PATH manually."
                ;;
        esac

        if [ -n "$rc" ]; then
            touch "$rc"
            if ! grep -Fq "export PATH=\"${BIN_DIR}:\$PATH\"" "$rc" 2>/dev/null; then
                {
                    echo ""
                    echo "# Toth CLI"
                    echo "export PATH=\"${BIN_DIR}:\$PATH\""
                } >> "$rc"
                info "Added ${BIN_DIR} to PATH in ${rc}"
                info "Run 'source ${rc}' or start a new shell to use the 'toth' command."
            fi
        fi
        ;;
esac

# ── done ──────────────────────────────────────────────────────────────────

echo ""
info "Toth-DFIR installed!"
info "  Install dir : ${INSTALL_DIR}"
info "  Workspace   : ${WORKSPACE}"
info "  Command     : toth"
echo ""
info "Next steps:"
echo "    toth update dfir          pull the DFIR image from GHCR"
echo "    toth update --build dfir  build locally for development"
echo "    toth shell dfir           open a DFIR shell"
echo ""
info "Note: if you just added yourself to the 'docker' group,"
info "      run 'newgrp docker' or log out / back in before 'toth update'."
