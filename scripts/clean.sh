#!/usr/bin/env bash
# Clean up Docker resources created by zGameLib builds.
set -euo pipefail

source_dir="$(dirname "$0")/.."

echo "==> Removing zGameLib Docker volumes and dangling images..."
docker volume rm -f zgame-cargo-cache 2>/dev/null || true
docker image prune -f --filter "label=component=zgamelib" 2>/dev/null || true

rm -rf "${source_dir}/.zig-cache" "${source_dir}/zig-out" "${source_dir}/zig-pkg" 2>/dev/null || true
echo "==> Done."
