#!/usr/bin/env bash
# Build zGameLib inside the Docker container.
# Usage: ./scripts/build-in-docker.sh [step]
#   step: pipeline (default), build-framework, examples, dev, or any zig build step
set -euo pipefail

STEP="${1:-pipeline}"

cd "$(dirname "$0")/.."

echo "==> zGameLib: zig build ${STEP}"
zig build "${STEP}"
