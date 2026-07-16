# The incremental example ladder

Each rung adds **exactly one new capability** to the stack, demonstrating the
**pay-for-what-you-use** principle: you can stop at any rung and continue with
raw access.

The rungs form a progression from minimal (platform only) to full-featured
(optional App middleware). Every rung is a **complete, runnable example** that
only compiles and links the libraries it actually needs.

## The rungs

| # | Example | Libraries compiled | What it proves | Status |
|---|---------|-------------------|----------------|--------|
| **0** | **event-logger** | `platform` only | Windowing + input standalone. No Vulkan, no audio, no animation. `nm` check: zero GPU symbols. | ✅ **shipped** |
| **1** | **clear-color** | `platform` + `vulkan_stack` | Both adapters together through the comptime surface bridge. Explicit raw Vulkan hand-off. | ✅ **shipped** |
| **2** | **clear-color-2** | `platform` + `vulkan_stack` + `zgame.Gpu`/`FrameRing` | Rendering helpers lift ~130 lines of boilerplate. Same behaviour as rung 1, but on the middleware's `Gpu` + `FrameRing`. | ✅ **shipped** |
| **2+** | **hello-triangle** | same + VMA + pipeline | First graphics pipeline, VMA vertex buffer, precompiled shaders. Actual geometry. | **partial** |
| **3** | **animation-demo** | + `zClip` | Animation (sprite-atlas + skeletal via zClip). Only the animation lib is added. | **stub** |
| **4** | **audio-demo** | + `zaudio` (planned) | Audio playback. Only the audio lib is added. | **stub** |
| **5** | **asset-demo** | + `zassets` (planned) | Asset loading / VFS. Only the assets lib is added. | **stub** |
| **6** | **app-demo** | `zgame.App` middleware | Optional convenience loop. Everything is also available raw. | **stub** |

### Key insight: what is NOT compiled

The "pay for what you use" principle is visible in what each rung **excludes**:

| Rung | Not linked |
|------|-----------|
| Rung 0 | Vulkan stack, VMA, shaderc, zClip, audio, assets |
| Rung 1 | zClip, audio, assets |
| Rung 2 | zClip, audio, assets |
| Rung 3 | audio, assets |
| Rung 4 | zClip, assets |
| Rung 5 | zClip, audio |

A developer can stop at rung 0 (headless tools), rung 1 (Vulkan app with manual
wiring), rung 2 (Vulkan app with helper abstractions), or any later rung —
and **continue working with raw access** to everything beneath.

## Decoupling checks (`nm`)

The architecture rests on each sibling library dragging only its own concern.
Two checks prove it — these are required gates, not nice-to-haves:

- **event-logger** (`renderer = .none`, platform only) → `nm <bin> | grep -E 'vk\.[A-Za-z]|volk[A-Z]|[Vv]ma[A-Z]|shaderc_[a-z]'` prints **nothing** (platform drags none of our Vulkan stack).
- A **headless vulkan** sketch (no window, offscreen render) → `nm <bin> | grep -i 'SDL_\|x11\|wayland'` prints **nothing** (vulkan drags no windowing).

> **Why not a bare `vk*` grep?** SDL3 (the platform backend) ships its own Vulkan
> support — `SDL_Vulkan_CreateSurface` and an internal `vk*` function-pointer
> table — so *any* SDL3-linked binary, even `renderer = .none`, contains bare
> `vk*` C symbols. Those belong to the platform backend, not to a Vulkan-stack
> leak. The invariant we actually protect is "importing the platform adapter
> doesn't drag in **our** Vulkan stack," so the check matches what's unique to
> it: vulkan-zig's `vk.`-namespaced Zig wrappers plus the volk / VMA / shaderc
> symbols. Source of truth: `scripts/ci.sh decoupling`.

## Extended validation track (adapter depth)

After the modular rungs above, optional **game-style apps** exercise platform +
Vulkan adapters without pulling in new siblings. Most introduce one new *skill*
(pipeline reuse, texturing, input contexts, shaderc, compute, depth) rather than
one new *library*. Full ordering + adapter version columns:
[`ROADMAP.md`](ROADMAP.md) release table.

| # | App | Develops platform → | Develops vulkan → | Validates |
| --- | --- | --- | --- | --- |
| 2 | **hello-triangle** | (v0.6.0) | v0.3.0 (VMA) | first graphics pipeline + vertex buffer + shaders |
| 3 | **snake** | (v0.6.0) | v0.3.0 | fixed-timestep game loop + action input |
| 4 | **asteroids** | (v0.6.0) | v0.3.0 | float physics + screen-wrap (no new lib surface) |
| 5 | **breakout** | (v0.6.0) | v0.3.0 | instancing / batching throughput |
| 6 | **space-invaders** | (v0.6.0) | v0.3.0 | texturing — VMA image + sampler + atlas UVs |
| 7 | **image-viewer** | v0.6.0 (file_drop) | v0.3.0 | drag-drop PNG upload |
| 8–12 | tetris … typing-game | v0.7.0–v0.8.0 | v0.3.0 | input contexts, replay, gamepads, paths, IME |
| 13–15 | life, particles, shader-playground | (v0.6.0) | v0.4.0 (shaderc) | runtime shaders + compute |
| 16 | **hello-cube** | (v0.6.0) | v0.4.0 + depth | 3D smoke — perspective MVP + depth attachment |

`hello-triangle` appears in both Track A (rung 2+) and here — it is the bridge
between clear-color and game-style apps.

## Animation track (zClip)

The animation examples (rung 3 in the ladder above) exercise **zClip**, the
sibling animation lib, which ships separately and has its own dependency graph.
They are gated on zClip milestones rather than adapter milestones:

| Sub-rung | Example | Animates | zClip milestone | Validates |
|----------|---------|----------|-----------------|-----------|
| A1 | **sprite-showcase** | Sprite-atlas flipbook | v0.6.0 | atlas load → phase-based frame advance — raw `zclip.sprite` path |
| A2 | **gltf-viewer** | Skeletal from glTF | v0.7.0 | cgltf load → bone hierarchy → skinning — raw `zclip.skeletal` path |
| A3 | **animation-browser** | Unified `zgame.animation` | v0.9.0 | `Cursor`/`Animator` over either clip type |
| A4 | **run-cycle** | Blending + game-loop | v0.9.0 | multiple clips, crossfade, keyboard-driven |

## Why this order

- **Rung 0 first** validates the platform half before the surface bridge gets
  involved. If event-logger is broken, clear-color will be too — and you'd be
  debugging two libs at once.
- **Rung 1** proves the two adapters talk to each other (the whole point of
  the architecture) with the absolute minimum code.
- **Rung 2** shows the same app on the framework's helpers — the ~130 lines of
  boilerplate moved into `Gpu` + `FrameRing`.
- **Rung 2+** adds actual rendering (pipeline, vertex buffer). The first
  graphics pipeline is isolated from the game loop.
- **Rungs 3–6** add independent capabilities one at a time, each in its own
  sibling library. No cross-contamination.

## See also

[`vision.md`](vision.md) · [`mission.md`](mission.md) · [`ROADMAP.md`](ROADMAP.md) — release sequence + lib version gates · [`sprint.md`](sprint.md).
