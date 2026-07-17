# Theory: Web Backend Strategy – WebGPU for WASM

## 1. Problem Statement

We have decided to **deprecate OpenGL** as a graphics path in zGameLib. This creates a problem for web deployment:

- **WebGL** is based on OpenGL ES.
- Continuing to support WebGL would go against our decision to move away from OpenGL-style APIs.
- We need a modern, explicit, low-level graphics API for the web that aligns with Vulkan.

## 2. Recommended Solution: WebGPU

**WebGPU** is the clear modern replacement for WebGL.

### Why WebGPU?

| Aspect                    | WebGL 2                              | WebGPU                                      | Winner |
|---------------------------|--------------------------------------|---------------------------------------------|--------|
| API Philosophy            | OpenGL ES style (state machine)      | Explicit, command-buffer based (like Vulkan) | WebGPU |
| Performance               | Good                                 | Significantly better                        | WebGPU |
| Features                  | Limited                              | Compute shaders, modern pipeline model      | WebGPU |
| Future Proofing           | Legacy                               | The new web standard                        | WebGPU |
| Alignment with Vulkan     | Poor                                 | Very good                                   | WebGPU |
| Browser Support (2026)    | Excellent                            | Very good (Chrome, Edge, Firefox, Safari)   | WebGL (slightly ahead) |

**Conclusion**: Since we chose Vulkan for native, **WebGPU** is the natural and modern choice for the web.

## 3. Proposed Architecture

We should treat WebGPU the same way we treat other platform/graphics backends — as an **optional sibling module** in zGameLib.

```ascii
zGameLib
├── Core
│   ├── Platform (SDL3)
│   ├── Math
│   └── Utilities
│
├── Graphics Backends (optional / sibling modules)
│   ├── Vulkan (native - primary)
│   └── WebGPU (WASM / Web)
│
└── High-Level Helpers (optional)
    ├── 2D Batcher
    └── Future: 3D helpers
```

This design keeps zGameLib lean while still allowing full web support.

## 4. What Lives in zGameLib (Tier 1)

**Goal of zGameLib**: Reusable, low-level, raw-first foundation.

### Graphics-related things that belong in zGameLib:

- **WebGPU backend implementation**
  - Device, queue, swapchain/surface creation
  - Command buffer recording
  - Pipeline creation
  - Bind group / resource management
- **Common graphics abstractions** (if useful)
  - A thin `GraphicsContext` or `Backend` interface (optional but recommended)
  - Shader compilation helpers (WGSL)
- **2D rendering helpers** that work on both Vulkan and WebGPU
  - Sprite batcher
  - Basic immediate-mode drawing

**Rule of thumb**: If something is useful for *multiple consumers* (not just Nexus-engine), put it in zGameLib.

## 5. Implementation Strategy (Incremental)

We should add WebGPU support in clear stages:

| Phase | Goal                              | What to Implement                          | Priority |
|-------|-----------------------------------|--------------------------------------------|----------|
| 1     | Basic WebGPU bring-up             | Device, surface, simple triangle           | Medium   |
| 2     | 2D rendering parity               | Port 2D batcher to WebGPU                  | Medium   |
| 3     | Scene rendering on Web            | Surface for Nexus-engine to consume        | Medium   |
| 4     | Examples                          | Web example (WASM + WebGPU)                | Low      |

This follows the same incremental philosophy we use everywhere else.

## 6. References & Resources

### WebGPU Official Resources

- **WebGPU Specification**: https://gpuweb.github.io/gpuweb/
- **WebGPU Samples**: https://webgpu.github.io/webgpu-samples/
- **wgpu (Rust reference implementation)**: https://github.com/gfx-rs/wgpu

### Zig + WebGPU Resources

- `wgpu-native` + Zig bindings (community projects)
- Emscripten WebGPU support
- Zig WASM target + `web-sys` / raw JS interop

### Comparison & Articles

- "WebGPU vs WebGL" articles (multiple sources in 2025–2026)
- "Why WebGPU is the future of web graphics" (various technical blogs)

## 7. Final Recommendations

1. **Use WebGPU** as the web graphics solution (not WebGL).
2. Put the **WebGPU backend** implementation in **zGameLib** as an optional module.
3. Create a thin backend abstraction early so the rest of the code does not care about Vulkan vs WebGPU.
4. Follow an incremental implementation path (start with basic triangle → 2D batcher → full scene rendering).

This approach keeps zGameLib reusable and modern while giving consumers (Nexus-engine, others) the freedom to build game-specific systems on top.

---

*Document created: 2026-07-15. See also Nexus-engine theory [12-web-backend-strategy.md](../../../docs/theory/12-web-backend-strategy.md) for the Tier 2 perspective.*
