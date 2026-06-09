#!/bin/bash

set -e

IMAGE_NAME="toth-network"
IMAGE_TAG="0.1.0"
CONTEXT_PATH="$(git rev-parse --show-toplevel)"

echo "[INFO]  Construction de l'image ${IMAGE_NAME}:${IMAGE_TAG}"
echo "[INFO]  Contexte de build : ${CONTEXT_PATH}"

docker build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f "$(dirname "$0")/Dockerfile" \
    "${CONTEXT_PATH}"

echo "[SUCCESS] Image ${IMAGE_NAME}:${IMAGE_TAG} construite avec succès"
