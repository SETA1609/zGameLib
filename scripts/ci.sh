#!/usr/bin/env bash
# CI gates for zGameLib (framework + examples), runnable locally — the same
# checks .github/workflows/build.yml runs (it checks out submodules + installs
# the toolchain / Vulkan ICD, then calls this with the matching command).
#   ./scripts/ci.sh              # fmt + build all (examples + tests skeleton)
#   ./scripts/ci.sh decoupling   # nm: platform-only binary pulls none of our vulkan stack
#   ./scripts/ci.sh integration  # cross-lib test-integration (auto-xvfb if headless)
#   ./scripts/ci.sh opengl       # OpenGL hand-off test (auto-xvfb if headless)
# Examples and tests live directly in this repo (not a submodule).
set -uo pipefail
cd "$(dirname "$0")/.."

case "${1:-check}" in
  check)
    echo "== zig fmt --check =="; zig fmt --check build.zig build.zig.zon examples || exit 1
    echo "== zig build (framework + compile-check all examples) =="; zig build event-logger clear-color clear-color-2 || exit 1
    ;;
  decoupling)
    echo "== zig build (framework + event-logger) =="; zig build || exit 1
    # The decoupling invariant: a platform-only binary pulls in none of OUR
    # vulkan stack. We match vulkan-zig's `vk.`-namespaced wrappers + volk/VMA/
    # shaderc symbols — NOT a bare `vk*` grep, which would also flag SDL3's own
    # bundled Vulkan loader (SDL_Vulkan_CreateSurface & its vk* table), part of
    # the platform backend and present in every SDL3-linked binary.
    echo "== nm: event-logger (platform-only) pulls none of our vulkan stack =="
    if nm zig-out/bin/event-logger | grep -E 'vk\.[A-Za-z]|volk[A-Z]|[Vv]ma[A-Z]|shaderc_[a-z]'; then
      echo "::error::our vulkan stack (vulkan-zig/volk/VMA) leaked into the platform-only binary"
      exit 1
    fi
    echo "clean — no vulkan-stack symbols in event-logger (SDL3's own vk loader is expected & ignored)"
    ;;
  integration)
    # Cross-lib integration test. Needs a display + a Vulkan loader.
    # Headless (no DISPLAY): wrap in xvfb-run.
    if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
      echo "== xvfb-run zig build test-integration -Dshaderc =="
      xvfb-run -a zig build test-integration -Dshaderc || exit 1
    else
      echo "== zig build test-integration -Dshaderc =="
      zig build test-integration -Dshaderc || exit 1
    fi
    ;;
  opengl)
    # OpenGL hand-off test. Needs a display + a GL driver.
    # Headless: xvfb-run + Mesa llvmpipe (software GL).
    if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
      echo "== xvfb-run zig build test-opengl =="
      LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a zig build test-opengl || exit 1
    else
      echo "== zig build test-opengl =="
      zig build test-opengl || exit 1
    fi
    ;;
  *)
    echo "unknown command: $1 (try: check | decoupling | integration | opengl)" >&2
    exit 2
    ;;
esac
echo "ok: ${1:-check}"
