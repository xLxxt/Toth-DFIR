# images/dfir/build.sh
#!/bin/bash
set -e

IMAGE_NAME="toth-dfir"
VERSION="0.1.0"

echo "[INFO]  Construction de l'image ${IMAGE_NAME}:${VERSION}"
echo "[INFO]  Contexte de build : $(pwd)"

docker build \
    --build-arg TOTH_VERSION="${VERSION}" \
    -t "${IMAGE_NAME}:${VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    -f images/dfir/Dockerfile \
    .

echo "[SUCCESS] Image ${IMAGE_NAME}:${VERSION} construite"