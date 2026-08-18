#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

IMAGE_NAME="toth-base"
VERSION="0.2.0"

log_info()  { echo -e "\e[32m[INFO]\e[0m  $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

log_info "Construction de l'image ${IMAGE_NAME}:${VERSION}"
log_info "Contexte de build : ${PROJECT_ROOT}"

NO_CACHE=""
if [[ "$1" == "--no-cache" ]]; then
    NO_CACHE="--no-cache"
    log_warn "Mode no-cache activé"
fi

docker build \
    ${NO_CACHE} \
    --file "${SCRIPT_DIR}/Dockerfile" \
    --build-arg TOTH_VERSION="${VERSION}" \
    --tag "${IMAGE_NAME}:${VERSION}" \
    --tag "${IMAGE_NAME}:latest" \
    "${PROJECT_ROOT}"

if [[ $? -eq 0 ]]; then
    log_info "✅ Build réussi !"
    docker images | grep "${IMAGE_NAME}"
else
    log_error "❌ Build échoué"
    exit 1
fi