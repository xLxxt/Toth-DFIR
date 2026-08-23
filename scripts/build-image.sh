#!/bin/bash
set -e

# Usage: bash scripts/build-image.sh <IMAGE_NAME> <PROFILE> [--no-cache]
#   IMAGE_NAME : the docker image name (e.g. toth-base)
#   PROFILE    : the image profile, used to locate the Dockerfile
#                (images/<PROFILE>/Dockerfile)
#   --no-cache : rebuild without using the docker layer cache

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <IMAGE_NAME> <PROFILE> [--no-cache]" >&2
    exit 1
fi

IMAGE_NAME="$1"
PROFILE="$2"
shift 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${PROJECT_ROOT}/VERSION"
VERSION="$(cat "${VERSION_FILE}" 2>/dev/null || echo "0.2.0")"

log_info()  { echo -e "\e[32m[INFO]\e[0m  $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

NO_CACHE=""
for arg in "$@"; do
    if [[ "$arg" == "--no-cache" ]]; then
        NO_CACHE="--no-cache"
        log_warn "No-cache mode enabled"
    fi
done

PROFILE_DIR="${PROJECT_ROOT}/images/${PROFILE}"

if [[ ! -f "${PROFILE_DIR}/Dockerfile" ]]; then
    log_error "No Dockerfile found for profile '${PROFILE}' (${PROFILE_DIR}/Dockerfile)"
    exit 1
fi

log_info "Building image ${IMAGE_NAME}:${VERSION}"
log_info "Build context: ${PROJECT_ROOT}"

if docker build \
    ${NO_CACHE} \
    --file "${PROFILE_DIR}/Dockerfile" \
    --build-arg TOTH_VERSION="${VERSION}" \
    --tag "${IMAGE_NAME}:${VERSION}" \
    --tag "${IMAGE_NAME}:latest" \
    "${PROJECT_ROOT}"; then
    log_info "Build successful!"
    docker images | grep "${IMAGE_NAME}"
else
    log_error "Build failed"
    exit 1
fi