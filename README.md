# zGameLib

A **transparent**, modular game-development middleware in Zig — built on a
growing family of **independent, decoupled sibling libraries** that do one thing
each. You pull in exactly what you use; nothing else compiles or ships.

> **Influenced by Casey Muratori's Handmade Hero philosophy:**
> thin platform layer, explicit control, replaceable pieces, raw access always
> available, and no framework magic.
>
> **Status:** early scaffold. The build re-exports the libs and the framework's
> behavioral suite (the cross-lib integration test) is green; the high-level
> layer (`App`, renderer, assets) is being built out. See
> [`docs/ROADMAP.md`](docs/ROADMAP.md) for the current roadmap.

## Philosophy — pay for what you use

zGameLib is **optional lightweight middleware**, not a required heavy framework.

The core design rule: **only the libraries and modules your application actually
uses are compiled in and shipped.** If your app only needs windowing + input,
that's all that gets linked — no Vulkan, no audio, no animation. Add each
capability explicitly as you need it, with zero cross-contamination.

```
┌──────────────────────────────────────────────────────────────────┐
│  YOUR APP                                                        │
│                                                                  │
│  Pick any subset:   platform · vulkan · audio · zClip · zassets  │
├──────────────────────────────────────────────────────────────────┤
│  zGameLib (optional middleware)                                   │
│    Re-exports everything below so you can always reach raw APIs.  │
│    Provides optional helpers: Gpu · FrameRing · swapchain · App   │
├──────────┬──────────┬──────────┬──────────┬──────────────────────┤
│ platform │ vulkan   │ zaudio   │ zClip    │ zassets  (future)    │
│ adapter  │ stack    │ (future) │ anim     │ VFS                 │
│ (SDL3)   │ adapter  │          │          │                     │
├──────────┴──────────┴──────────┴──────────┴──────────────────────┤
│  SDL3 · libvulkan · miniaudio · cgltf · … (native libraries)    │
└──────────────────────────────────────────────────────────────────┘
```

### Key principles

| Principle | What it means |
|-----------|---------------|
| **Pay for what you use** | Only the libraries you explicitly add to your dependency graph are compiled and linked. Platform-only app? No Vulkan stack compiled. |
| **Thin platform layer** | The platform abstraction is small, stable, and explicit. Most game code stays platform-agnostic. |
| **Raw access always** | Every convenience helper re-exports the raw API beneath it. You can bypass zGameLib at any point and work directly with the underlying library. |
| **Composition, not inheritance** | Build systems by composing small, focused sibling libraries. No deep class hierarchies. |
| **Explicit control flow** | No hidden behavior, no framework magic. You can trace every call. |
| **Replaceable pieces** | The platform backend (SDL3), renderer backend, and audio backend are each swappable independently. |
| **Performance as a first-class concern** | Even examples and docs keep performance implications visible and honest. |

## Two tiers, raw-first

Unlike a walled-garden framework (raylib, Unity), zGameLib gives you **two tiers**
with the same **opt-in / raw-first** principle:

1. **Building blocks** — independent sibling libraries (windowing, Vulkan,
   animation, etc.), each usable standalone or composed. Imported and re-exported
   through zGameLib but never hidden.
2. **Optional middleware** — `zgame.Gpu`, `zgame.FrameRing`, `zgame.App`, and
   other helpers that lift boilerplate out of your app. Always layered *over* the
   raw APIs, never replacing them.

```zig
const zgame = @import("zgame");

const platform = zgame.platform;       // windowing + input (SDL3 backend)
const vk        = zgame.vk;            // vulkan-zig's typed Vulkan API
const vma       = zgame.vma;           // GPU memory allocator
const shaderc   = zgame.shaderc;       // GLSL → SPIR-V (opt-in -Dshaderc)
const surface   = zgame.surface;       // the platform↔vulkan surface bridge
const swapchain = zgame.swapchain;     // a reusable swapchain (renderer policy)
const zclip     = zgame.zclip;         // raw animation lib (sprite + skeletal)
const animation = zgame.animation;     // unified animation API over zclip
```

**Pros stop using the middleware at any rung** and drive the raw libraries
directly. Nothing is hidden; you never get stuck.

The "pay for what you use" rule extends to every tier. A platform-only binary
(`@import("zgame_platform")`) links **only** the platform adapter — no Vulkan
symbols enter the binary, provable via `nm`.

## Layout

Canonical repository layout:
[`docs/file-tree.yml`](docs/file-tree.yml) ·
dependencies:
[`docs/dependencies.yml`](docs/dependencies.yml).

Summary: `src/` (framework modules) · `shared/` (Gpu, FrameRing, …) ·
`examples/` (reference ladder — not shipped with the default artifact) ·
`libs/` (sibling submodules) · `docs/` · `tests/`.

## Build & test

Requires **Zig 0.16+**. After cloning:

```sh
git submodule update --init --recursive

zig build                 # build the re-export module + lib artifacts
zig build test            # analyze + link the framework module
zig build test-tdd        # behavioral suite — needs a display + Vulkan/GL
zig build test-tdd -Dshaderc        # also build with runtime shaderc
zig build -Dgfx-backend=metal       # scaffold for non-Vulkan backends (compileError until implemented)
```

### Example ladder (incremental, pay-as-you-go)

Build and run examples individually. Each only compiles the libraries it needs:

```sh
zig build event-logger        # rung 0 — platform only (no vulkan). ~fastest build.
zig build clear-color         # rung 1 — platform + vulkan (raw surface hand-off)
zig build clear-color-2       # rung 2 — same app on zGameLib Gpu/FrameRing helpers
zig build hello-triangle      # rung 2+ — adds VMA vertex buffer + pipeline
```

Each example is a complete, runnable app — see [`docs/examples/`](docs/examples/)
for design docs and the full modular ladder.

## Sibling libraries (ecosystem)

Every sibling library is **independent, reusable, and MIT-licensed**. Use them
standalone or inside zGameLib:

- [zig-cpp-platform-stack-adapter](https://github.com/SETA1609/zig-cpp-platform-stack-adapter) — windowing + input, renderer-agnostic (SDL3 backend). **MIT.**
- [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) — the Vulkan stack (vk + volk + VMA + shaderc) + per-OS surface creators. **MIT.**
- [`zClip`](libs/zClip) — animation lib: sprite-atlas + skeletal-from-glTF. **MIT.**
- **`zaudio`** (planned) — audio backend abstraction (miniaudio).
- **`zassets`** (planned) — asset loading / VFS.
- **`zmath`** (planned) — math library.

Each follows the Handmade Hero-inspired design: **small interface, thin
abstraction, raw access always available.** The platform adapter, for example,
presents a stable API but exposes the underlying SDL3 backend's native handles.
The Vulkan adapter bundles version-coherent pieces but surfaces them as raw
vulkan-zig bindings.

## License

zGameLib is **Apache License 2.0** ([`LICENSE`](LICENSE), [`NOTICE`](NOTICE)).
Permissive — use in commercial and closed-source products without releasing your
own source. Attribution obligations travel with your binary.

The sibling libraries and their native dependencies (SDL3, vulkan-zig, VMA, volk,
shaderc) stay under their own permissive licenses (MIT / Zlib / Apache-2.0).

**👉 Consuming zGameLib? Read [`LICENSING.md`](LICENSING.md)** — full dependency
license map + compliance checklist.
