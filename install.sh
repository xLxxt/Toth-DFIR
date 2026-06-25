#!/bin/bash
set -e

REPO_URL="${TOTH_REPO_URL:-https://github.com/xLxxt/Toth-DFIR.git}"
BRANCH="${TOTH_BRANCH:-dev}"
INSTALL_DIR="${TOTH_DIR:-$HOME/.toth}"
BIN_DIR="$HOME/.local/bin"
WORKSPACE="${TOTH_WORKSPACE:-$HOME/toth/workspace}"

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    target_user="${SUDO_USER:-your-user}"
    echo "[!] Do not run this installer with sudo or as root."
    echo "[!] It must install Toth for your normal user, not under /root."
    echo "[!] If Docker needs sudo, add your user to the docker group first:"
    printf '    sudo usermod -aG docker "%s"\n' "$target_user"
    echo "    newgrp docker"
    exit 1
fi

for cmd in git docker python3; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "[!] $cmd is required"; exit 1; }
done

ensure_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) return 0 ;;
    esac

    local shell_name profile_file
    shell_name="$(basename "${SHELL:-}")"

    case "$shell_name" in
        zsh)
            profile_file="$HOME/.zshrc"
            ;;
        bash)
            profile_file="$HOME/.bashrc"
            ;;
        *)
            profile_file=""
            ;;
    esac

    if [ -n "$profile_file" ]; then
        touch "$profile_file"
        if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$profile_file"; then
            {
                echo ""
                echo "# Toth CLI"
                echo 'export PATH="$HOME/.local/bin:$PATH"'
            } >> "$profile_file"
            echo "[+] Added $BIN_DIR to PATH in $profile_file"
            echo "[!] Restart your shell or run: source $profile_file"
        fi
    else
        echo "[!] Add $BIN_DIR to your PATH manually:"
        echo '    export PATH="$HOME/.local/bin:$PATH"'
    fi
}

docker info >/dev/null 2>&1 || { echo "[!] docker daemon is not running"; exit 1; }

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "[+] Updating existing install in $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
elif [ -e "$INSTALL_DIR" ]; then
    echo "[!] $INSTALL_DIR already exists but is not a Git repository"
    echo "[!] Remove it or set TOTH_DIR to another install directory"
    exit 1
else
    echo "[+] Cloning Toth into $INSTALL_DIR"
    echo "[+] Repository: $REPO_URL"
    if ! git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
        echo ""
        echo "[!] Failed to clone Toth from $REPO_URL"
        echo "[!] If the repository is private or your HTTPS credentials are not configured, use SSH:"
        echo "    TOTH_REPO_URL=git@github.com:xLxxt/Toth-DFIR.git ./install.sh"
        exit 1
    fi
fi

mkdir -p "$BIN_DIR" "$WORKSPACE/cases" "$WORKSPACE/output"
printf 'TOTH_WORKSPACE=%s\n' "$WORKSPACE" > "$INSTALL_DIR/.env"

printf '#!/bin/bash\nexec python3 "%s/wrapper/toth.py" "$@"\n' "$INSTALL_DIR" > "$BIN_DIR/toth"
chmod +x "$BIN_DIR/toth"

echo "[+] Building base image (this takes a few minutes)"
bash "$INSTALL_DIR/images/base/build.sh"

echo ""
echo "[+] Toth installed in $INSTALL_DIR"
echo "[+] Workspace: $WORKSPACE"
ensure_path
echo "[+] Next steps:"
echo "      toth update dfir          pull the DFIR image"
echo "      toth update --build dfir  build the DFIR image locally"
echo "      toth shell dfir           open a DFIR shell"
