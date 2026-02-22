#!/usr/bin/env bash
# scripts/sandbox-dilbert-setup.sh
#
# Builds the Dilbert game-dev sandbox image.
# Extends openclaw-sandbox:bookworm-slim with Go + Ebitengine CGo deps.
#
# Usage:
#   scripts/sandbox-dilbert-setup.sh
#
# Environment overrides:
#   BASE_IMAGE   Base sandbox image (default: openclaw-sandbox:bookworm-slim)
#   TARGET_IMAGE Output image name   (default: openclaw-sandbox-dilbert:latest)
#   GO_VERSION   Go version to pin   (default: 1.22.2)
#
# After building, set in ~/.openclaw/openclaw.json:
#   agents.list[].sandbox.docker.image = "openclaw-sandbox-dilbert:latest"
# Then restart OpenClaw and remove stale sandbox containers:
#   docker rm -f $(docker ps -aq --filter label=openclaw.sandbox=1)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BASE_IMAGE="${BASE_IMAGE:-openclaw-sandbox:bookworm-slim}"
TARGET_IMAGE="${TARGET_IMAGE:-openclaw-sandbox-dilbert:latest}"
GO_VERSION="${GO_VERSION:-1.25.7}"

# Build the base image first if it's missing
if ! docker image inspect "${BASE_IMAGE}" >/dev/null 2>&1; then
  echo "Base image '${BASE_IMAGE}' not found — building it first..."
  bash "${ROOT_DIR}/scripts/sandbox-setup.sh"
fi

echo "Building ${TARGET_IMAGE} (Go ${GO_VERSION} + Ebitengine deps)..."

docker build \
  -t "${TARGET_IMAGE}" \
  -f "${ROOT_DIR}/Dockerfile.sandbox-dilbert" \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  "${ROOT_DIR}"

echo ""
echo "Built ${TARGET_IMAGE} successfully."
echo ""
echo "Next steps:"
echo "  1. Add to ~/.openclaw/openclaw.json:"
echo "       agents.list[id=dilbert].sandbox.docker.image = \"${TARGET_IMAGE}\""
echo "  2. Restart OpenClaw gateway"
echo "  3. Remove stale sandbox containers:"
echo "       docker rm -f \$(docker ps -aq --filter label=openclaw.sandbox=1)"
