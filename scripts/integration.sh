#!/usr/bin/env bash
# Run the cross-lib integration tests. Optional arg = --test-filter substring.
#   ./scripts/integration.sh           # all (counts only)
#   ./scripts/integration.sh "surface" # just matching tests (full output, panics shown)
# Needs a display server + a Vulkan loader.
set -uo pipefail
cd "$(dirname "$0")/.."
if [ -n "${1:-}" ]; then
    zig build test-integration --summary all -- --test-filter "$1" 2>&1
else
    zig build test-integration --summary all 2>&1 | grep -iE "run test|build summary|error:|expected.*found|panic|failed:"
fi
