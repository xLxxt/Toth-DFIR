#!/bin/bash
set -euo pipefail

IMAGES=(
  "toth-base:0.2.0"
  "toth-dfir:0.2.0"
  "toth-malware:0.2.0"
  "toth-network:0.2.0"
)

missing=0

for image in "${IMAGES[@]}"; do
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "[!] Missing local image: $image"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "[!] Build missing images first with: make build-all"
  exit 1
fi

for image in "${IMAGES[@]}"; do
  echo "[+] Checking $image"
  docker run --rm "$image" toth-check
done

echo "[+] Tool presence checks passed"
