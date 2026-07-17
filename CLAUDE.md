# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

zGameLib is **tier T1** of a 3-tier bundle: the low-level Zig game framework. It is consumed by the Nexus engine (tier above) as the `zgame` module. Requires **Zig 0.16.0** (`minimum_zig_version` in `build.zig.zon`). `AGENTS.md` is the per-tier source of truth — keep it and this file in sync.

## Commands

```sh
git submodule update --init --recursive   # libs/ are git submodules; needed before first build

zig build                    # default step == `pipeline`: adapter libs → framework, then install
zig build pipeline           # explicit alias of the default
zig build test               # analyze + link the `zgame` module (refAllDecls, no display needed)
zig build test-tdd           # behavioral suite: integration + opengl + gpu (NEEDS display + Vulkan/GL)
zig build test-tdd -Dshaderc # same, building the vulkan stack with runtime GLSL→SPIR-V (shaderc)
zig build examples           # build ALL examples (opt-in; not built by default)
zig build dev                # framework + examples + all tdd tests
zig fmt --check build.zig build.zig.zon examples   # the lint gate (see scripts/ci.sh)
```

Single suites (the finest test granularity — there is no per-test `--test-filter` wired):

```sh
zig build test-integration   # cross-lib: window → surface → device → present
zig build test-opengl        # OpenGL hand-off (system-linked GL)
zig build test-gpu           # framework's own Gpu + FrameRing + transitionImage spec
```

Examples (each compiles only the libs it needs; `zig build <name>` compiles+installs to `zig-out/bin/<name>`, `zig build run-<name>` runs it):

```sh
zig build event-logger       # rung 0 — platform-only (imports zgame_platform, no vulkan)
zig build clear-color        # rung 1 — full framework, raw surface hand-off
zig build clear-color-2      # rung 2 — same app rebuilt on Gpu/FrameRing helpers
zig build hello-triangle     # rung 2+ — pipeline + VMA vertex buffer; compiles shaders via `glslc`
# animation-demo / audio-demo / asset-demo / app-demo are STUBS (panic / await future libs)
```

Docker + CI mirrors (run the exact CI gates locally):

```sh
./scripts/build-in-docker.sh [step]   # runs `zig build <step>` in the container (default: pipeline)
./scripts/shell.sh                    # interactive container shell
./scripts/ci.sh check                 # fmt + compile-check event-logger/clear-color/clear-color-2
./scripts/ci.sh decoupling            # nm gate: platform-only binary has zero vulkan-stack symbols
./scripts/ci.sh integration           # test-integration -Dshaderc (auto-wraps xvfb-run if headless)
./scripts/ci.sh opengl                # test-opengl (auto xvfb-run + Mesa llvmpipe if headless)
```

## Architecture

**libs-first / link-the-artifact DAG.** Three sibling libraries under `libs/` (git submodules) each build their own static-library artifact and expose a Zig module: `platform` (zig-cpp-platform-stack-adapter, SDL3 windowing+input), `vulkan_stack` (zig-cpp-vulkan-stack-adapter — vk + volk + VMA + shaderc + per-OS surface creators), and `zclip` (sprite/skeletal animation data). `build.zig`'s `pipeline` step drives them topologically: `build-platform` + `build-vulkan_stack` + `build-zclip` → `build-framework` → install.

**Two consumer modules** (both `b.addModule`, so consumers import at source level):
- `zgame` (`src/root.zig`) — the full framework. Re-exports the raw building blocks (`zgame.platform`, `.vk`, `.volk`, `.vma`, `.shaderc`, `.surface`, `.swapchain`, `.zclip`) AND links all three lib artifacts, plus framework helpers `zgame.Gpu`, `zgame.FrameRing`, `zgame.transitionImage`, `zgame.animation`, `zgame.App`. **This is what Nexus imports as `zgame`.**
- `zgame_platform` (`src/root_platform.zig`) — platform-only slice. Re-exports `platform` and links **only** the platform artifact — no vulkan. This is a hard decoupling: `zgame_platform` has no `.vk`/`.vma` fields at all, so vulkan absence is enforced by the type system (and separately checked by `scripts/ci.sh decoupling` via `nm`).

**Framework glue** lives in `shared/` and is wired as intermediate modules in `build.zig`, layered *over* the raw libs (never replacing them — every helper exposes its underlying handles as public fields, "raw access always"):
- `surface.zig` — the comptime platform↔vulkan surface bridge; the single place the two adapter libs meet. Branches on target OS at comptime (X11/Wayland tried at runtime on Linux, Android abi checked first), passing raw OS primitives with no shared type crossing the boundary.
- `swapchain.zig` — reusable swapchain (format/present-mode/recreation policy).
- `gpu.zig` — `Gpu.init(window, .{})`: loader → instance → surface → device → present queue, all public fields.
- `frame.zig` — `FrameRing(N)`: comptime `N` frames-in-flight (fixed-size arrays, no allocation); begin → record → end (acquire → submit → present) seam; handles `OutOfDateKHR` swapchain recreation (`begin` returns `null` to skip the iteration).
- `animation.zig` — unified timeline/playback API over `zclip`; **scaffold only, nothing implemented** (`src/app.zig`'s `App` is likewise a stub — bodies `@panic`).

**Comptime usage:** OS-branch selection in the surface bridge; `FrameRing(max_frames)` makes the frame count part of the type; `surface.zig` `@compileError`s on unsupported OS targets.

## Gotchas (verified)

- `examples/` and `shared/*.md`/`docs/` are **not** shipped: `.paths` in `build.zig.zon` lists only `build.zig`, `build.zig.zon`, `src`, `shared`, `tests`, and license files. Examples are consumers, never part of the library package, and are never built by default `zig build`.
- `zig build test` needs no display; `test-tdd` and its sub-steps need a real display + a Vulkan/GL driver and otherwise **skip** (gated by `error.SkipZigTest` and per-suite `done` flags inside the test files) rather than fail.
- `shaderc` (runtime GLSL→SPIR-V) is off by default; enable with `-Dshaderc`. Separately, `hello-triangle` compiles its shaders at build time via the `glslc` system command (needs the Vulkan SDK on PATH).
- The decoupling nm gate deliberately matches only *our* vulkan symbols (`vk.`/`volk`/`vma`/`shaderc_`), not a bare `vk*` grep — SDL3 bundles its own Vulkan loader and is expected in every platform binary.
- This is a mixed Zig/C/C++ codebase; `cheat_sheet.md` documents the FFI, Zig-0.16 stdlib (Io interface, unmanaged ArrayList, `addExecutable` takes a Module), and build-script traps worth consulting before editing `build.zig` or FFI code.
