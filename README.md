# zGameLib

A light, **transparent** game-dev framework in Zig — built on two sibling
adapter libraries (windowing/input + the Vulkan stack), which it **re-exports**
so you're never boxed in.

> **Status:** active. The build re-exports the libs and the framework's
> behavioral suite is green. Sprite-animation via zClip is integrated
> and consumed by the game. Higher-level rendering and asset pipelines are
> being built out.

## The idea — two tiers, raw-first

Unlike a walled-garden framework (raylib), zGameLib follows the same
**opt-in / raw-first** principle as the libs underneath it:

1. **High-level** — `zgame.App` (the loop) + renderer/asset helpers (coming).
2. **The building blocks, re-exported** — reach them directly and drive the raw
   APIs the moment you outgrow the convenience layer. Nothing is hidden:

   ```zig
   const zgame = @import("zgame");

   const platform = zgame.platform;       // windowing + input (SDL3 backend)
   const vk        = zgame.vk;            // vulkan-zig's typed Vulkan API
   const vma       = zgame.vma;           // GPU allocator
   const shaderc   = zgame.shaderc;       // GLSL → SPIR-V (opt-in -Dshaderc)
   const surface   = zgame.surface;       // the platform↔vulkan surface bridge
   const swapchain = zgame.swapchain;     // a reusable swapchain (renderer policy)
   ```

Re-exports go **through** the libs (not parallel deps), so the Vulkan stack's
version coherence (vk.xml ↔ VMA ↔ shaderc) and the SDL3 backend are inherited
intact.

## Layout

```
.
├── build.zig / build.zig.zon   # re-export module + linked lib artifacts
├── src/
│   ├── root.zig                # the `zgame` module — re-exports + high-level API
│   ├── root_platform.zig       # platform-only module (no vulkan)
│   └── app.zig                 # App harness (stub)
├── shared/
│   ├── surface.zig             # comptime platform↔vulkan surface bridge
│   ├── swapchain.zig           # reusable swapchain (format/present/recreate)
│   ├── gpu.zig                 # Vulkan bring-up helper (Gpu)
│   └── frame.zig               # frames-in-flight ring (FrameRing)
├── examples/                   # framework consumers (NOT part of the library)
│   ├── event-logger/           # rung 0 — platform-only event logger
│   ├── clear-color/            # rung 1 — reactive clear-color
│   ├── clear-color-2/          # rung 1, reprise — on zGameLib abstractions
│   └── color-logger/           # stub
├── tests/                      # the framework's behavioral suite (`test-tdd`)
│   ├── integration_test.zig    # cross-lib: window → surface → device → present
│   ├── opengl_test.zig         # the OpenGL hand-off (system-linked GL)
│   └── gpu_test.zig            # render-abstractions spec (Gpu + FrameRing)
├── docs/
│   ├── theory/                 # beginner theory guides for the stack
│   └── examples/               # per-example design docs + ladder + roadmap
├── scripts/
│   └── ci.sh                   # CI gates (runnable locally)
└── libs/                       # the adapter libs (git submodules)
    ├── zig-cpp-platform-stack-adapter
    └── zig-cpp-vulkan-stack-adapter
```

## Build & test

Requires **Zig 0.16+**. After cloning:

```sh
git submodule update --init --recursive   # the adapter libs live under libs/

zig build                 # build the re-export module + lib artifacts
zig build test            # analyze + link the framework module
zig build test-tdd        # the behavioral suite — needs a display + a Vulkan/GL
                          # driver (run locally, or under Xvfb + Mesa in CI)
zig build test-tdd -Dshaderc   # also build the vulkan stack with runtime shaderc
```

## Examples

The repo ships standalone example apps under `examples/` that consume the
framework but are **not** bundled with the library package. Build and run them
individually:

```sh
zig build event-logger        # rung 0 — platform-only (no vulkan)
zig build clear-color         # rung 1 — windowed clear-color (needs display + Vulkan)
zig build clear-color-2       # rung 1, reprise — on zGameLib abstractions
```

Each example is a complete, runnable app — see [`docs/examples/`](docs/examples/)
for design docs and the full ladder of planned examples.

## Sibling libraries

- [zig-cpp-platform-stack-adapter](https://github.com/SETA1609/zig-cpp-platform-stack-adapter) — windowing + input, renderer-agnostic. **MIT.**
- [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) — the Vulkan stack (vk + volk + VMA + shaderc) + per-OS surface creators. **MIT.**

## License

zGameLib is licensed under the **Apache License 2.0** ([`LICENSE`](LICENSE),
[`NOTICE`](NOTICE)). It's permissive: you can use it in **commercial and
closed-source products** without releasing your own source — you just include the
license, keep the notices, and carry the `NOTICE` attribution forward.

The sibling adapter libraries above (and the native stack they pull in — SDL3,
vulkan-zig, VMA, volk, shaderc) stay under their **own** permissive licenses
(MIT / Zlib / Apache-2.0), and zGameLib links rather than vendors them, so those
attribution obligations travel with your binary too.

**👉 Consuming zGameLib in your own project? Read [`LICENSING.md`](LICENSING.md)** —
it has the full dependency license map and a step-by-step compliance checklist.
