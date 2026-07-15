# Getting started — modular example ladder

This repo demonstrates the **pay-for-what-you-use** architecture: each example
imports only the sibling libraries it needs. The modular ladder lets you start
minimal and add capabilities one at a time.

**Requires Zig 0.16+** (a display server + a Vulkan loader for the windowed /
integration bits).

## 1. Clone with submodules

The sibling libraries live under `libs/` as git submodules:

```sh
git clone https://github.com/SETA1609/zGameLib.git
cd zGameLib
git submodule update --init --recursive
```

## 2. What you can build today

```sh
zig build --help              # list steps
zig build event-logger        # rung 0 — platform-only example (no vulkan)
zig build clear-color         # rung 1 — platform + vulkan (raw surface hand-off)
zig build clear-color-2       # rung 2 — same app on zGameLib abstractions
zig build test-integration    # cross-lib tests: platform handles → vulkan instance + surface
```

- **event-logger** — rung 0, platform only. The `nm` decoupling baseline.
  Imported module: `zgame_platform` (no `vulkan_stack`). See
  [`event-logger.md`](event-logger.md).

- **clear-color** — rung 1, platform + vulkan together, raw surface hand-off.
  Imported modules: `platform` + `vulkan_stack` + `surface` + `swapchain`.
  See [`clear-color.md`](clear-color.md).

- **clear-color-2** — rung 2, same behaviour on `zgame.Gpu` + `zgame.FrameRing`.
  Imported module: full `zgame`. ~130 lines of boilerplate moved into the
  middleware. See [`clear-color.md`](clear-color.md).

- **Animation examples** (sprite-showcase, gltf-viewer, animation-browser,
  run-cycle) ship alongside the main ladder through the zClip animation lib.
  See [`ladder.md`](ladder.md) § Animation track.

## 2a. What each rung links

| Rung | Example | Linked libraries |
|------|---------|-----------------|
| 0 | event-logger | `platform` artifact only |
| 1 | clear-color | `platform` + `vulkan_stack` artifacts |
| 2 | clear-color-2 | `platform` + `vulkan_stack` artifacts (via `zgame`) |

The difference between rung 0 and rung 1 is visible at the binary level:
`nm event-logger` shows **zero** Vulkan-stack symbols.

## 3. The build model — libs first, link the artifact

`build.zig.zon` references the sibling libs by **local path** (no git fetch);
`build.zig` imports each lib's **module** and links its **static-library
artifact**, so the heavy C/C++ (SDL3, the Vulkan stack) compiles once inside
the lib and is reused across examples. Only the libs actually needed by each
example are linked.

## 4. The cross-lib hand-off (the whole point)

The platform and vulkan libs share **no type** — they meet only at raw OS
primitives:

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

This seam is the only point of contact between the two sibling libs.

## 5. The ladder

Examples are built in a fixed order; each adds exactly one capability.
See [`ladder.md`](ladder.md) for all rungs and [`ROADMAP.md`](ROADMAP.md) for
the release sequence.

## 6. The decoupling checks (`nm`)

Two gates the examples exist to prove (see [`ladder.md`](ladder.md)):

- a platform-only binary (`renderer = .none`) shows **zero** of our Vulkan stack symbols;
- a headless-Vulkan binary shows **zero** windowing symbols.

## Next

- [`../../libs/zig-cpp-platform-stack-adapter/docs/getting-started.md`](../../libs/zig-cpp-platform-stack-adapter/docs/getting-started.md) — the windowing/input half
- [`../../libs/zig-cpp-vulkan-stack-adapter/docs/getting-started.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/getting-started.md) — the Vulkan half
- [`clear-color.md`](clear-color.md) — the first windowed app, designed end-to-end · [`cheat_sheet.md`](cheat_sheet.md) — Zig/C/C++ field guide
