# zGameLib Reference
## Transparent, Raw-First Game Development Framework in Zig

**Version:** 2026-07-15  
**Status:** Living reference document for the foundation layer  
**Philosophy:** Everything is re-exported. Nothing is hidden. Pros drop to raw APIs. Noobs use the convenience layer. The framework grows through independent sibling adapters.

---

## 1. What is zGameLib?

zGameLib is a **light, transparent, explicit game development framework** written in Zig.

It is **not** a full game engine. It is the **low-level foundation** that higher layers (engines, editors, or standalone games) can build upon — or bypass entirely.

It follows the same **raw-first / opt-in** principle as the libraries it wraps:

> "Two tiers, the same opt-in / raw-first principle the libs use:  
> 1. **High-level** — convenience helpers.  
> 2. **The building blocks, re-exported** — reach the raw APIs the moment you outgrow the convenience layer. Nothing is hidden."  
> — zGameLib design philosophy

### The 3-Handshake Usage Model

Consumers interact with zGameLib in three progressive ways:

```ascii
┌──────────────────────────────────────────────────────────────┐
│  TIER 3: EDITOR (Human + Scripting Layer)                    │
│    • Visual inspection of what the code does                 │
│    • Scripting (Mono/C# or native Zig)                       │
│    • Can be used by this engine OR hooked by other engines   │
│    • Optional — many projects ship without it                │
└───────────────────────────────┬──────────────────────────────┘
                                │ uses / extends
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 2: ENGINE (Abstraction Layer)                          │
│    • Higher-level game systems (scene, servers, resources)   │
│    • Built on top of zGameLib APIs                           │
│    • No editor required to ship games                        │
│    • One possible consumer of the framework                  │
└───────────────────────────────┬──────────────────────────────┘
                                │ uses or re-exports
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 1: zGAMELIB FRAMEWORK (Foundation — raylib-like)       │
│    • Direct game development (like raylib)                   │
│    • Raw access to platform, Vulkan, audio, assets, math     │
│    • Transparent — every layer re-exports the one below      │
│    • Can be used standalone to ship complete games           │
└──────────────────────────────────────────────────────────────┘
```

**Key insight:**  
You can ship a complete game using **only Tier 1** (zGameLib directly).  
You can build a full engine on top (Tier 2).  
The Editor (Tier 3) is just one possible consumer that helps humans and adds scripting.

Tier 2 and Tier 3 are **not part of zGameLib** — they live in separate projects that consume the framework. This repo ships Tier 1 only.

---

## 2. Core Design Principles

### Raw-First & Transparent
Every convenience layer re-exports the raw building blocks. You are never locked in.

### Independent Sibling Adapters
The framework grows by adding new independent adapters (not monolithic dependencies):

- `platform` — SDL3 (window, input, events)
- `vulkan` — Explicit Vulkan stack (volk + VMA + shader compilation + reflection)
- `audio` — miniaudio (modern primary) + SDL3 fallback
- Future: assets, animation, etc.
- `zimgui` — optional Dear ImGui bridge (`-DimGui`; see [`imgui.md`](imgui.md))

Each adapter only pulls in what it needs. They meet at narrow, explicit seams.

### Explicit over Implicit
Vulkan is the primary (and only core) graphics path. We follow the modern explicit model that gives control and performance.

**Real-life precedent:**  
Godot 4 performed a complete rewrite of its rendering system around an explicit RenderingDevice abstraction over Vulkan (with optional DX12/Metal). They dropped the old implicit OpenGL path for modern features because the old model could not deliver the required control and multi-threading. We apply the same lesson from day one in Zig.

### Minimal Incremental Steps
Complex systems are broken into small, testable rungs (see the theory docs in `docs/theory/` for the existing Vulkan bring-up path).

---

## 3. What You Can Build with zGameLib

### Tier 1 — Direct Framework Usage (raylib-style)

You can develop complete games directly against zGameLib without any higher engine:

```zig
const zgame = @import("zgame");

pub fn main() !void {
    var app = try zgame.App.init(.{ .title = "My Game", .width = 1280, .height = 720 });
    defer app.deinit();

    // Direct access to raw layers
    const vk = zgame.vk;
    const platform = zgame.platform;

    while (!app.shouldClose()) {
        platform.pollEvents();
        // ... your game loop using raw Vulkan or convenience helpers
    }
}
```

**Use this when:**
- You want maximum control and minimal abstraction
- You are building a custom engine or tool
- You prefer explicit, assembly-like control over the GPU (Vulkan model)

### Tier 2 — Engine Built on zGameLib

An engine consumes zGameLib APIs to provide higher-level systems:
- Scene graph
- Resource management
- Servers (rendering, audio, physics via Jolt, etc.)
- Scripting integration

The engine is **just another consumer**. It can re-export zGameLib or wrap it.

### Tier 3 — Editor Layer

The editor is an **optional human + scripting interface** on top of an engine (or directly on zGameLib).

It helps developers:
- Visually inspect what the code is doing
- Use scripting languages (Mono/C# or native Zig)
- Prototype faster

Other engines can also hook into the editor API if they want the same tooling.

---

## 4. Current Core Components in zGameLib

### Platform (SDL3 Adapter)
- Window creation & management
- Input (keyboard, mouse, gamepad, haptic)
- Event loop
- Basic audio device (fallback)

### Graphics — Vulkan Primary
- Full explicit Vulkan 1.2+ bring-up (`Gpu`, instance, device, queues)
- Swapchain management with resize/recreate handling
- `FrameRing` — frames-in-flight synchronization (fences + semaphores)
- Surface bridge (platform ↔ Vulkan)
- Shader compilation (GLSL/HLSL → SPIR-V) + reflection
- Memory allocation via VMA
- Command buffer recording helpers

**2D Graphics** is provided via lightweight Vulkan batchers/quad renderers built on the above foundation.

**Deprecated:** OpenGL / GLES paths. Vulkan is the explicit, modern choice.

### Audio — Modern Primary
- **miniaudio** as the primary sibling adapter (low latency, custom mixing, DSP)
- SDL3 audio kept as usable fallback (because the platform adapter is already present)

### Math
- Zig-native SIMD-friendly types (`Vec2/3/4`, `Mat3/4`, `Quat`, `Transform`, etc.)
- Built with `@Vector` for performance and simplicity

### Asset Loading (Growing)
- glTF 2.0 + uFBX for meshes and materials (primary modern path)
- Image decoding (PNG, JPEG, WebP, EXR) → GPU texture upload

### Optional / Future Modules
- Post-process (FSR, SMAA)
- Texture compression pipeline (Basis, ASTC, KTX)
- Fonts (FreeType + HarfBuzz + MSDFGen)
- Compression (zstd primary)
- Networking foundation (ENet)

---

## 5. How the Systems Work — Incremental View

The framework teaches through small, composable pieces. Example progression (already partially documented in `docs/theory/`):

1. Platform adapter (SDL3 window + events)
2. Vulkan instance + device bring-up
3. Surface bridge (the narrow seam between platform and Vulkan)
4. Swapchain + present modes
5. `FrameRing` — the frames-in-flight synchronization pattern
6. Basic renderer on top of `FrameRing`
7. 2D batcher (quads, sprites) as next natural rung
8. Audio via miniaudio adapter
9. Asset loaders

Each step adds one minimal concept while keeping raw access to everything below.

**ASCII of a typical frame:**

```ascii
CPU Thread                  GPU
────────────                ─────
beginFrame()  ────────────► acquire image
record commands             │
endFrame()    ────────────► submit + present
wait fence                  │
(next frame)                │
```

This pattern (used in `FrameRing`) hides latency while remaining explicit and correct.

---

## 6. Modernization Decisions (Why We Dropped Things)

We follow a strict decision process when evaluating libraries:

```zig
if (actively_used and good_zig_interop and explicit_model_alignment and no_better_modern_alt) {
    keep_or_port();
} else {
    deprecate_or_move_out();
}
```

**Major modernizations already applied:**

- **OpenGL/GLES** → Fully deprecated (Vulkan primary). Real precedent: Godot 4 rewrote rendering around explicit Vulkan because the old implicit model could not support modern clustered rendering and multi-threading.
- **SCons** → Dropped in favor of full `zig build`.
- **GDScript** → Dropped (clean-room decision).
- **Direct low-level audio backends** → Go through miniaudio or SDL3.
- **Full Assimp** → Slimmed to uFBX + glTF 2.0.
- **Graphite + heavy ICU** → Slimmed (HarfBuzz covers most needs).
- **Theora + MiniUPnP** → Deprecated (low usage + maintenance cost).

**What we added / are adding:**
- miniaudio as modern audio primary
- Zig-native math
- glTF-first asset loading
- Explicit 2D rendering on Vulkan foundation

---

## 7. Getting Started (Minimal Example Path)

1. Clone + `git submodule update --init --recursive`
2. `zig build` — builds the re-export module
3. Run existing examples (`clear-color`, `event-logger`)
4. Study `docs/theory/` in order (01 → 07)
5. Extend with your own game loop using raw `zgame.vk` or convenience helpers
6. Add 2D batching or miniaudio when ready

All examples are designed to be **complete, runnable apps** that demonstrate one rung at a time.

---

## 8. Relationship to Tier 2 & Tier 3 Consumers

zGameLib is Tier 1 — the foundation. It does not ship an engine or an editor.

Higher layers (Tier 2 engines, Tier 3 editors) are **separate projects** that consume the framework. They can re-export zGameLib, wrap it, or bypass it entirely.

The editor is an optional layer that can serve any engine — or be hooked by other tools that want the same human/scripting tooling. **Dear ImGui** is optional in zGameLib (`-DimGui`) for immediate-mode **tool** UI; Nexus **Crucible** requires it for the editor. **In-game UI** uses the planned **2D batcher**, not ImGui — see [`imgui.md`](imgui.md) and [Nexus theory 06](../../Nexus-engine/docs/theory/06-ui-and-localization.md). **Localization** lives in Nexus only: `.po` source → build-time JSON → data-oriented `LocalizationSystem` — no ICU, no i18next, and no i18n in zGameLib.

---

**This is the authoritative reference for zGameLib.**

Use it when:
- Building games directly against the framework (raylib style)
- Creating an engine on top
- Designing the editor or tooling layer
- Deciding what new sibling adapter to add next

Everything is explicit. Everything is re-exported. The metal is always accessible.

Ready for the next incremental step.
