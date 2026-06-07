# zGameLib

A light, **transparent** game-dev framework in Zig — built on two sibling
adapter libraries (windowing/input + the Vulkan stack), which it **re-exports**
so you're never boxed in.

> **Status:** early scaffold. The build re-exports the libs and the framework's
> behavioral suite (the cross-lib integration + OpenGL hand-off tests) is green;
> the high-level layer (`App`, renderer, assets) is being built out. See
> [`docs/ROADMAP.md`](docs/ROADMAP.md) once it lands.

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
│   └── app.zig                 # App harness (stub)
├── shared/
│   ├── surface.zig             # comptime platform↔vulkan surface bridge
│   └── swapchain.zig           # reusable swapchain (format/present/recreate)
├── tests/                      # the framework's behavioral suite (`test-tdd`)
│   ├── integration_test.zig    # cross-lib: window → surface → device → present
│   └── opengl_test.zig         # the OpenGL hand-off (system-linked GL)
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

## Sibling libraries

- [zig-cpp-platform-stack-adapter](https://github.com/SETA1609/zig-cpp-platform-stack-adapter) — windowing + input, renderer-agnostic.
- [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) — the Vulkan stack (vk + volk + VMA + shaderc) + per-OS surface creators.
