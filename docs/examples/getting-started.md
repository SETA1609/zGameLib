# Getting started — examples repo

This repo consumes the two adapters **together** the way a real engine would:
each lib builds once into a static artifact, the apps link the artifacts. It
doubles as the integration-test bed for the platform↔vulkan hand-off.

**Requires Zig 0.16+** (a display server + a Vulkan loader for the windowed/
integration bits).

## 1. Clone with submodules

The adapters live under `libs/` as git submodules:

```sh
git clone https://github.com/SETA1609/zGameLib.git
cd zGameLib
git submodule update --init --recursive
```

## 2. What you can build today

```sh
zig build --help              # list steps
zig build event-logger        # rung 0 — platform-only example
zig build clear-color         # rung 1 — windowed clear-color (needs a display + Vulkan loader)
zig build test-integration    # cross-lib tests: platform handles → vulkan instance + surface
```

- `event-logger` is **rung 0** (platform-only; the `nm` decoupling baseline) —
  implemented. See [`event-logger.md`](event-logger.md) and the platform lib's
  `docs/getting-started.md`.
- `clear-color` is **rung 1** (platform + vulkan together) — implemented: a window
  whose swapchain image is cleared each frame to a cycling palette, recreated on
  resize. See [`clear-color.md`](clear-color.md).
- **Animation examples** (sprite-showcase, gltf-viewer, animation-browser,
  run-cycle) ship alongside the main ladder through the zClip animation lib.
  See [`ladder.md`](ladder.md) § Animation track.
- `test-integration` today: instance from the platform's extensions, the surface
  hand-off, and the full stack (window → instance → surface → device → VMA
  allocator). Add `-Dshaderc` to also run the shaderc GLSL→SPIR-V cross-stack
  test (off by default — it builds shaderc from source).

## 2a. Reproducible runs (scripts + Docker)

The CI gates live in **`scripts/ci.sh`** so you can run exactly what CI runs,
locally:

```sh
./scripts/ci.sh              # fmt + build both rungs
./scripts/ci.sh decoupling   # nm: the platform-only binary has zero Vulkan symbols
./scripts/ci.sh integration  # cross-lib test-integration -Dshaderc (auto-xvfb when headless)
```

For a clean-room environment, the repo ships a **Dockerfile** (build from a
checkout *with submodules*):

```sh
git submodule update --init --recursive
docker build -t stack-examples .
docker run --rm stack-examples                                 # fmt + build
docker run --rm stack-examples bash scripts/ci.sh integration  # headless via lavapipe + xvfb
```

The image carries both halves' runtime deps (X11/Wayland + xvfb for the window,
lavapipe + libvulkan for a GPU-less Vulkan device). CI also runs a
`lint-workflows` job that validates every workflow YAML (this repo's + both
libs') with the bundled [`check-workflows` skill](../../.claude/skills/check-workflows).

## 3. The build model — libs first, link the artifact

`build.zig.zon` references the libs by **local path** (no git fetch); `build.zig`
imports each lib's **module** and links its **static-library artifact**, so the
heavy C/C++ (SDL3, the Vulkan stack) compiles once inside the lib and is reused
across apps. Full rationale: [`../../libs/README.md`](../../libs/README.md).

## 4. The cross-lib hand-off (the whole point)

The two libs share **no type** — they meet only at raw OS primitives:

```
platform.Window.create(.{ .renderer = .vulkan })
  ├─ requiredVulkanInstanceExtensions()  ─┐
  └─ getX11Handle(win) → { display, window } ─┐
                                              ▼
   vulkan: volk.loadBase() → vk.BaseWrapper.load(volk.getInstanceProcAddr())
           → createInstance(exts) → createX11Surface(instance, display, window)
                                              │
                                              ▼
                                   a non-null VkSurfaceKHR
```

`tests/integration_test.zig` is this handshake, end to end — read it as the
canonical "two libs together" example. `shared/surface.zig` is the comptime,
per-OS bridge that picks the right `get*Handle` → `create*Surface` pair, and
`clear-color` drives the whole hand-off in a real windowed app.

## 5. The ladder

Apps are built in a fixed order; each pulls a specific lib milestone into
existence. See [`ladder.md`](ladder.md) for all rungs and
[`ROADMAP.md`](ROADMAP.md) for the release sequence. Rung 0 (event-logger) and
rung 1 (clear-color) are the Foundation phase — both implemented and building;
the remaining work for the v0.1.0 tag is the `nm` decoupling checks + CI.

## 6. The decoupling checks (`nm`)

Two gates the apps exist to prove (see [`ladder.md`](ladder.md)):

- a platform-only binary (`renderer = .none`) shows **zero `vk*` / `VK_`** symbols;
- a headless-Vulkan binary shows **zero `SDL_` / `x11` / `wayland`** symbols.

## Next

- [`../../libs/zig-cpp-platform-stack-adapter/docs/getting-started.md`](../../libs/zig-cpp-platform-stack-adapter/docs/getting-started.md) — the windowing/input half
- [`../../libs/zig-cpp-vulkan-stack-adapter/docs/getting-started.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/getting-started.md) — the Vulkan half
- [`clear-color.md`](clear-color.md) — the first windowed app, designed end-to-end · [`cheat_sheet.md`](cheat_sheet.md) — Zig/C/C++ field guide
