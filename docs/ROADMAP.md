# zGameLib Roadmap (Updated July 2026)

**Goal:** Become the best transparent, raw-first, explicit foundation for game
development in Zig.

> The modular, composable, pay-for-what-you-use game-development stack.

This roadmap describes the **middleware layer** (zGameLib) plus the ecosystem of
**independent sibling libraries** it composes. Each sibling has its own roadmap;
this file tracks integration into a coherent whole and how **Nexus-engine** (Tier 2)
consumes the foundation.

**Repository layout:** [`file-tree.yml`](file-tree.yml)  
**Dependencies:** [`dependencies.yml`](dependencies.yml)  
**Example ladder:** [`docs/examples/ladder.md`](examples/ladder.md) · [`docs/examples/ROADMAP.md`](examples/ROADMAP.md)

---

## Current Strengths (July 2026)

- Excellent theory documentation ([`docs/theory/`](theory/))
- Strong Vulkan + SDL3 foundation via sibling adapters
- Clear sibling-adapter philosophy — pay for what you use
- `Gpu`, `FrameRing`, `Swapchain`, surface bridge abstractions are solid
- Shipped examples: `event-logger` (rung 0), `clear-color` (rung 1), `clear-color-2` (rung 2)
- **zClip sprite-atlas path** live at v0.6 (see `feat/zclip-animation` / submodule pin) — animation example docs landed

---

## Guiding Principles (Never Change)

Every decision flows from these axioms (see [`README.md`](../README.md)):

1. **Pay for what you use.** Only libraries you explicitly add are compiled and linked.
2. **Independent sibling libraries.** Each does one thing; usable standalone or inside zGameLib.
3. **zGameLib is optional middleware.** Re-exports siblings + lightweight helpers (`Gpu`, `FrameRing`, `App`). Skip it and use siblings directly.
4. **Raw access always.** Every convenience layer re-exports the raw API beneath it.
5. **Replaceable backends.** Platform (SDL3 → native), renderer, and audio backends are swappable.
6. **New features → sibling adapters when possible.** Keep the core lean; powerful features stay optional.
7. **Excellent documentation and incremental learning path.** Theory ladder + example ladder.

---

## The Sibling Library Ecosystem

| Library | Status | Purpose | Backend(s) |
|---------|--------|---------|------------|
| `zig-cpp-platform-stack-adapter` | **shipped** v0.6+ | Windowing, input, time, native handles | SDL3 (native planned) |
| `zig-cpp-vulkan-stack-adapter` | **shipped** v0.2+ | Vulkan stack: vk + volk + VMA + shaderc | vulkan-zig |
| `zClip` | **partial** v0.6+ | Animation: sprite-atlas (**shipped**) + skeletal/glTF (in progress) | cgltf |
| `zaudio` | **planned** | Audio playback + streaming | miniaudio |
| `zassets` | **planned** | Asset loading / VFS | — |
| `zmath` | **planned** | SIMD-friendly math | — |
| `zimgui` (wrapper) | **planned** | Optional Dear ImGui bridge | Dear ImGui via `-DimGui` |

---

## Middleware Integration Status

| Area | Where | Status |
|------|-------|--------|
| Re-exports (platform / vulkan / surface / swapchain) | `src/root.zig` | **shipped** |
| Render helpers: `Gpu`, `FrameRing`, `transitionImage` | `shared/gpu.zig`, `shared/frame.zig` | **shipped** |
| Platform-only module (`zgame_platform`) | `src/root_platform.zig` | **shipped** |
| Animation: raw `zclip` + unified `zgame.animation` | `shared/animation.zig` + `libs/zClip` | **partial** — [zClip roadmap](libs/zClip/docs/ROADMAP.md) |
| Audio integration (`zaudio` bridge) | — | **planned** (Phase 1) |
| Asset / VFS integration (`zassets` bridge) | — | **planned** (Phase 1) |
| Dear ImGui optional wrapper | — | **planned** (Phase 1, `-DimGui`) |
| `App` harness (window + frame loop) | `src/app.zig` | **stub** |

---

## Phase 1: Core Completion (Q3 2026)

- [ ] Finish and stabilize Vulkan backend (memory, pipelines, descriptors)
- [ ] Add **miniaudio** as new sibling adapter (`zaudio` — primary audio path)
- [ ] Make Dear ImGui **optional** via `-DimGui` flag + thin wrapper
- [ ] Basic asset loading (glTF 2.0 + image decoding) via `zassets` bridge
- [ ] Improve 2D rendering helpers (batcher, sprites, text)
- [ ] Land `hello-triangle` example (rung 2+) — first pipeline + VMA
- [ ] Animation track A1: **sprite-showcase** on raw `zclip.sprite` (zClip v0.6 ✅)

---

## Phase 2: Polish & Usability (Q4 2026)

- [ ] Better error handling and diagnostics across adapters
- [ ] More examples: textured rendering (`space-invaders`), audio playback (`audio-demo`), basic ImGui demo
- [ ] Documentation updates (especially ImGui integration guide)
- [ ] Stabilize build system and dependency management (pinned submodule SHAs per release)
- [ ] Optional texture compression helpers (Basis Universal / KTX)
- [ ] Extended validation ladder: snake → space-invaders rungs (games + texturing without new libs)
- [ ] Animation track A2: **gltf-viewer** (skeletal/glTF, zClip v0.7+)

---

## Phase 3: Expansion (2027)

- [ ] Font rendering (FreeType + HarfBuzz optional module)
- [ ] Basic networking foundation (ENet) — optional sibling, not core middleware
- [ ] Improved cross-platform support — macOS Metal/MoltenVK path (see [macOS policy](#macos-platform-policy) below)
- [ ] Performance profiling tools integration (optional Tracy)
- [ ] More complete asset pipeline (mesh + material loading)
- [ ] Animation track A3–A4: `animation-browser`, `run-cycle` (`zgame.animation` unified API)
- [ ] `zgame.App` harness + `app-demo` (rung 6) when middleware is stable

---

## Example Ladder (Two Tracks)

Examples are **reference apps** — not shipped with the default `zgame` artifact.
See [`docs/examples/vision.md`](examples/vision.md) and [`docs/examples/mission.md`](examples/mission.md).

### Track A — Modular capability rungs (pay-for-what-you-use)

Each rung adds **one new library capability**. Full table: [`docs/examples/ladder.md`](examples/ladder.md).

| Rung | Example | Adds | Status |
|------|---------|------|--------|
| 0 | `event-logger` | `platform` only | ✅ shipped |
| 1 | `clear-color` | + `vulkan_stack` | ✅ shipped |
| 2 | `clear-color-2` | + `Gpu`/`FrameRing` helpers | ✅ shipped |
| 2+ | `hello-triangle` | + pipeline/VMA | partial |
| 3 | `animation-demo` | + `zClip` | stub |
| 4 | `audio-demo` | + `zaudio` | stub |
| 5 | `asset-demo` | + `zassets` | stub |
| 6 | `app-demo` | + `zgame.App` | stub |

### Track B — Extended validation ladder (adapter depth)

After rung 2+, optional **game-style apps** exercise the same adapters without
adding new siblings — snake, asteroids, breakout, space-invaders, input-depth
toys, shader/compute rungs, `hello-cube` 3D smoke. Release mapping:
[`docs/examples/ROADMAP.md`](examples/ROADMAP.md).

### Track C — Animation (zClip sibling)

Parallel track gated on zClip milestones (needs texturing from rung 6+ / `space-invaders`):

| Sub-rung | Example | zClip milestone | Doc |
|----------|---------|-----------------|-----|
| A1 | `sprite-showcase` | v0.6.0 sprite-atlas | [`sprite-showcase.md`](examples/sprite-showcase.md) |
| A2 | `gltf-viewer` | v0.7.0 skeletal/glTF | [`gltf-viewer.md`](examples/gltf-viewer.md) |
| A3 | `animation-browser` | v0.9.0 unified API | [`animation-browser.md`](examples/animation-browser.md) |
| A4 | `run-cycle` | v0.9.0 blending | [`run-cycle.md`](examples/run-cycle.md) |

Per-rung design docs also include [`rung03-animation.md`](examples/rung03-animation.md) through [`rung06-app.md`](examples/rung06-app.md).

### Example release sequence (summary)

| Release | Rungs |
|---------|-------|
| **v0.1.0** | event-logger ✅, clear-color ✅ |
| **v0.2.0** | clear-color-2 + hello-triangle |
| **v0.3.0** | snake, asteroids, breakout, space-invaders, image-viewer |
| **v0.4.0–v0.7.0** | input depth, devices, shaders/compute, hello-cube |
| **v0.8.0** | sprite-showcase, gltf-viewer |
| **v0.9.0** | animation-browser, run-cycle |
| **v1.0.0+** | audio-demo, asset-demo, app-demo |

---

## Non-Goals

- **ECS / scene graph** — belongs in Nexus-engine (Tier 2), not middleware.
- **Asset pipeline / editor** — runtime hooks only; no GUI editor monolith.
- **Game-engine monolith** — modularity is the point.

## macOS Platform Policy

macOS is **in scope — not deferred.** Windowing and Vulkan-on-Metal behavior
follows the same clean-room study as the rest of the stack: Redot's macOS/Cocoa
hand-off informs the platform adapter's `getCocoaHandle` → vulkan-stack's
`createMetalSurface` (MoltenVK) seam — behavior reference only, no Redot code ships.

| Layer | macOS testing |
|-------|----------------|
| **Maintainer CI** | Compile/`zig build` gates on macOS runners (container/VM pipelines). Display- and GPU-heavy run steps may be limited or informational in CI. |
| **Contributors** | **Own runtime validation** on real macOS hardware — windowed examples, Metal layer, MoltenVK, resize/teardown — required before macOS-specific changes merge. |

The maintainer does not use macOS as a daily dev machine; treat macOS green as
**contributor-verified**, with CI providing build coverage only.

---

## Out of Scope / Deferred

- Full multiplayer stack — Phase 3 may add optional ENet sibling only.
- GUI toolkit in core — Dear ImGui stays **optional** (`-DimGui`), not required.

---

## Downstream: Nexus-engine (Tier 2)

Nexus-engine consumes `zgame` via path dependency. Its roadmap gates on Tier 1
milestones above — especially 2D batcher, image decode, `zaudio`, and zClip
mesh/animation paths. See [Nexus-engine ROADMAP](https://github.com/SETA1609/Nexus-engine/blob/main/docs/ROADMAP.md).