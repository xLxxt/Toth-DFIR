#!/bin/bash
set -e

REPO_URL="https://github.com/xLxxt/Toth-DFIR.git"
BRANCH="${TOTH_BRANCH:-dev}"
INSTALL_DIR="${TOTH_DIR:-$HOME/.toth}"
BIN_DIR="$HOME/.local/bin"
WORKSPACE="${TOTH_WORKSPACE:-$HOME/toth/workspace}"

for cmd in git docker python3; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "[!] $cmd is required"; exit 1; }
done

docker info >/dev/null 2>&1 || { echo "[!] docker daemon is not running"; exit 1; }

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "[+] Updating existing install in $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "[+] Cloning Toth into $INSTALL_DIR"
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

mkdir -p "$BIN_DIR" "$WORKSPACE/cases" "$WORKSPACE/output"

printf '#!/bin/bash\nexec python3 "%s/wrapper/toth.py" "$@"\n' "$INSTALL_DIR" > "$BIN_DIR/toth"
chmod +x "$BIN_DIR/toth"

echo "[+] Building base image (this takes a few minutes)"
bash "$INSTALL_DIR/images/base/build.sh"

echo ""
echo "[+] Toth installed in $INSTALL_DIR"
echo "[+] Workspace: $WORKSPACE"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "[!] Add $BIN_DIR to your PATH to use the toth command" ;;
esac
echo "[+] Next steps:"
echo "      toth update dfir     build the DFIR image"
echo "      toth exec dfir       open a DFIR shell"
