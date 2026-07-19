# zGameLib Roadmap (Updated July 2026)

**Goal:** Become the best transparent, raw-first, explicit foundation for **2D game**
development in Zig — with a clear post-ship path to 3D.

> The modular, composable, pay-for-what-you-use game-development stack.

This roadmap describes the **middleware layer** (zGameLib) plus the ecosystem of
**independent sibling libraries** it composes. **Nexus** (Tier 2, `Nexus-engine` repo)
consumes the foundation to ship a **2D game at v1.0.0** before we invest in 3D depth.

**Repository layout:** [`file-tree.yml`](file-tree.yml)  
**Dependencies:** [`dependencies.yml`](dependencies.yml)  
**Example ladder:** [`docs/examples/ladder.md`](examples/ladder.md) · [`docs/examples/ROADMAP.md`](examples/ROADMAP.md)  
**Cross-tier view:** [Bundle ROADMAP](https://github.com/SETA1609/Link_and_nexus_bundle/blob/main/ROADMAP.md) (meta repo)

**Priority legend:** **🎯** gates Nexus v1.0.0 (first 2D game) · **🔧** gates Crucible · **⏳** post–first 2D ship

---

## July 2026 Update: Framework-Only Development Phase

**Decision:** Focus exclusively on zGameLib (Tier 1 / Framework) for the foreseeable future. Nexus engine work is limited to minimal integration stubs and tests until the framework foundation is solid.

### Rationale

- The 2D pipeline (batcher, assets, audio) is the critical path to validating Nexus with a real 2D game.
- Completing the framework first avoids the overhead of parallel engine development and ensures a rock-solid foundation.
- The framework is estimated at ~60-70% toward enabling a basic 2D game. The critical gaps are the 2D batcher, asset loading, and audio integration.

### Recent Completions

- **macOS MoltenVK surface path** — `shared/surface.zig` now handles `.macos` via `getCocoaHandle` + `createMetalSurface`. Platform adapter caches the Metal view; vulkan-stack adapter adds `vkCreateMetalSurfaceEXT`. `-Dgfx-backend` build option scaffolded (only `.vulkan` implemented).

### Immediate Sprint Priorities

1. Complete `hello-triangle` (robust pipeline, error handling).
2. **Implement 2D batcher v0** — sprites, quads, atlas integration with zClip.
3. Start/integrate `zassets` image decode + basic VFS.
4. Expand example ladder (finish stubs for animation/audio).

### Impact on Nexus

- No heavy engine work until the framework 2D pipeline is proven.
- Nexus integration limited to consuming framework APIs as they stabilise.
- When the framework is solid, shift primary focus to Nexus.

---

## 2D-first strategy

| Principle | zGameLib response |
|-----------|-------------------|
| **Nexus needs 2D draw first** | **2D batcher** is Phase 1 priority — before ImGui, before 3D depth |
| **Sprites + atlases** | zClip sprite-atlas path (shipped v0.6) + batcher integration |
| **Image loading** | `zassets` image decode gates Nexus `textured-quad` |
| **Audio for ship** | `zaudio` before Nexus v1.0.0 |
| **Editor later** | `zimgui` stays **late** — gates Crucible, not the 2D game |
| **3D deferred** | `hello-cube`, glTF skeletal, depth — **v2.x ⏳** after Nexus ships |

**Optional module order:** core adapters → **2D batcher** 🎯 → **`zassets`** 🎯 → **`zaudio`** 🎯 → **`zimgui`** 🔧 → **`zfont`** 🔧 → **3D depth** ⏳ → **GNS net** ⏳

---

## Architectural Boundaries: Framework vs Engine

This separation is a core design principle, informed by Redot/Godot's layered architecture.

| Layer | Responsibility | Owned by |
| --- | --- | --- |
| **Drivers / Adapters** | Low-level platform and graphics stack (SDL3, Vulkan, VMA, etc.). Replaceable backends. | zGameLib |
| **Middleware Helpers** | Thin, opt-in convenience layers (Gpu, FrameRing, surface bridge, future 2D batcher, …). Re-export the raw layer. | zGameLib |
| **Servers (opaque high-level managers)** | Opaque subsystems like RenderingServer, AudioServer, PhysicsServer — the "API backend" for scene-level code. | Nexus (Engine) |
| **Scene / Node System** | Node tree, scene graph, entity composition. | Nexus (Engine) |
| **Editor / Tools** | Dear ImGui tooling, asset pipeline UI, etc. | Crucible (Tool) |

**Key principle:** zGameLib stays lean, raw-first, and engine-agnostic. High-level "Server"-style abstractions belong in Nexus. This preserves the framework's transparent nature and prevents scope creep.

---

## Current Strengths (July 2026)

- Excellent theory documentation ([`docs/theory/`](theory/))
- Strong Vulkan + SDL3 foundation via sibling adapters
- Clear sibling-adapter philosophy — pay for what you use
- `Gpu`, `FrameRing`, `Swapchain`, surface bridge abstractions are solid
- Shipped examples: `event-logger` (rung 0), `clear-color` (rung 1), `clear-color-2` (rung 2)
- **zClip sprite-atlas path** live at v0.6 — 2D animation foundation

---

## Guiding Principles (Never Change)

1. **Pay for what you use.** Only libraries you explicitly add are compiled and linked.
2. **Independent sibling libraries.** Each does one thing; usable standalone or inside zGameLib.
3. **zGameLib is optional middleware.** Re-exports siblings + lightweight helpers (`Gpu`, `FrameRing`, `App`). Skip it and use siblings directly.
4. **Raw access always.** Every convenience layer re-exports the raw API beneath it.
5. **Replaceable backends.** Platform (SDL3 → native), renderer, and audio backends are swappable.
6. **New features → sibling adapters when possible.** Keep the core lean; powerful features stay optional.
7. **Excellent documentation and incremental learning path.** Theory ladder + example ladder.

---

## Version milestones (aligned with Nexus)

Each release ships **implementation + documentation + ≥1 example** where applicable.

| Version | Priority | Focus | Example | Nexus gate |
|---------|----------|-------|---------|------------|
| **0.1.0** | 🎯 | Foundation ✅ | `clear-color`, `clear-color-2` | Nexus 0.1.0 |
| **0.2.0** | 🎯 | First pipeline | `hello-triangle` | — |
| **0.3.0** | 🎯 | 2D game validation | `space-invaders`, `snake` | — |
| **0.4.0** | 🎯 | **2D batcher v0** | `breakout` (batched sprites) | Nexus 0.2.0–0.6.0 |
| **0.5.0** | 🎯 | Input depth | `tetris` | Nexus 0.5.0 |
| **0.6.0** | 🎯 | Shaders + sprites | `sprite-showcase` (zClip atlas) | Nexus 0.7.0 |
| **0.7.0** | 🎯 | **`zassets` image decode** | `image-viewer` | Nexus 0.2.0 textures |
| **0.8.0** | 🎯 | Batcher maturity + text quads | `particles` (2D GPU particles) | Nexus 0.7.0–0.8.0 |
| **0.9.0** | 🎯 | **`zaudio`** | `audio-demo` | Nexus 1.0.0 audio |
| **1.0.0** | 🎯 | Asset pipeline stable | `asset-demo` | Nexus 1.0.0 resources |
| **1.1.0** | 🔧 | **`zimgui`** (late optional) | `imgui-demo` | Crucible v1.1.0 |
| **1.2.0** | 🔧 | **`zfont`** (after ImGui) | font smoke | Nexus `TextServer` later |
| **2.0.0** | ⏳ | **3D depth smoke** | `hello-cube` | Nexus 2.0.0 |
| **2.1.0** | ⏳ | glTF / skeletal (zClip) | `gltf-viewer` | Nexus 2.1.0 |
| **2.2.0** | ⏳ | GNS networking sibling | `net-echo` | Nexus 2.2.0 |

---

## The Sibling Library Ecosystem

| Library | Status | Purpose | Backend(s) | 2D game? |
|---------|--------|---------|------------|----------|
| `zig-cpp-platform-stack-adapter` | **shipped** v0.6+ | Windowing, input, time, native handles | SDL3 (native planned) | 🎯 |
| `zig-cpp-vulkan-stack-adapter` | **shipped** v0.2+ | Vulkan stack: vk + volk + VMA + shaderc | vulkan-zig | 🎯 |
| `zClip` | **partial** v0.6+ | **Sprite-atlas** 🎯 + skeletal/glTF ⏳ | cgltf | 🎯 atlas only |
| `zaudio` | **planned** v0.9.0 | Audio playback + streaming | miniaudio | 🎯 |
| `zassets` | **planned** v0.7.0 | Asset loading / VFS / image decode | — | 🎯 |
| `zmath` | **planned** | SIMD-friendly math | — | 🎯 (light) |
| `zimgui` (wrapper) | **planned (late)** v1.1.0 | Optional Dear ImGui bridge | Dear ImGui via `-DimGui` | 🔧 |
| `zfont` | **planned (after zimgui)** | Font rendering / shaping | FreeType + HarfBuzz optional | 🔧 |
| `zgns` (working name) | **planned** v2.2.0 ⏳ | GNS networking wrapper | GameNetworkingSockets | ⏳ |

---

## Middleware Integration Status

| Area | Where | Status | Priority |
|------|-------|--------|----------|
| Re-exports (platform / vulkan / surface / swapchain) | `src/root.zig` | **shipped** | 🎯 |
| Render helpers: `Gpu`, `FrameRing`, `transitionImage` | `shared/gpu.zig`, `shared/frame.zig` | **shipped** | 🎯 |
| Platform-only module (`zgame_platform`) | `src/root_platform.zig` | **shipped** | 🎯 |
| **2D batcher** (sprites, quads, atlases) | — | **planned** v0.4.0 | 🎯 **critical** |
| Animation: raw `zclip` + unified `zgame.animation` | `shared/animation.zig` + `libs/zClip` | **partial** | 🎯 |
| Asset / VFS integration (`zassets` bridge) | — | **planned** v0.7.0 | 🎯 |
| Audio integration (`zaudio` bridge) | — | **planned** v0.9.0 | 🎯 |
| Dear ImGui optional wrapper (`zimgui`) | — | **planned** v1.1.0 | 🔧 |
| Font module (`zfont`) | — | **planned** v1.2.0 | 🔧 |
| 3D depth / mesh helpers | — | **planned** v2.0.0 | ⏳ |
| GNS networking sibling | — | **planned** v2.2.0 | ⏳ |
| `App` harness (window + frame loop) | `src/app.zig` | **stub** | stretch |

---

## Phase 1: 2D core (Q3 2026) 🎯

**Goal:** Unblock Nexus 0.2.0 through 1.0.0.

- [ ] Finish and stabilize Vulkan backend (memory, pipelines, descriptors) — **2D pipelines first**
- [ ] **`hello-triangle`** example (rung 2+) — first pipeline + VMA
- [ ] **2D batcher** — textured quads, sprite atlases, orthographic projection
- [ ] **`zassets` bridge** — PNG/JPEG decode, VFS hooks, GPU upload helper
- [ ] Animation track A1: **sprite-showcase** on raw `zclip.sprite` (zClip v0.6 ✅)
- [ ] Extended validation: `space-invaders`, `breakout` — prove batcher in game-like apps

**Not in Phase 1:** Dear ImGui, fonts, 3D depth, glTF skeletal, GNS.

---

## Phase 2: Ship-ready polish (Q4 2026) 🎯

**Goal:** Nexus `minimal-2d-game` has audio, stable assets, mature batcher.

- [ ] **`zaudio`** — miniaudio sibling adapter + `audio-demo`
- [ ] **`zassets` maturity** — caching, async load hooks for `ReloadEventBus` consumers
- [ ] 2D batcher maturity — batching stats, atlas packing helpers
- [ ] Better error handling and diagnostics across adapters
- [ ] Stabilize build system and dependency management (pinned submodule SHAs per release)
- [ ] Extended validation ladder: snake → space-invaders rungs

**Not primary in Phase 2:** ImGui — deferred to Phase 3 (Crucible gate).

---

## Phase 3: Editor modules (2027) 🔧

Ship only when core + batcher are stable and Nexus v1.0.0 has shipped or is imminent.

1. **`zimgui`** — optional Dear ImGui via `-DimGui` ([`docs/imgui.md`](imgui.md))
   - Required by **Link-editor / Crucible** (Tier 3) at v1.1.0+
   - Optional for Nexus `debug-ui` rich panels
2. **`zfont`** — font rendering (**after** `zimgui`)
   - FreeType + HarfBuzz as optional sibling
   - Nexus `TextServer` consumes; not a localization system

Also in Phase 3:

- [ ] `zgame.App` harness + `app-demo` (rung 6)
- [ ] Optional Tracy profiling integration
- [ ] macOS Metal/MoltenVK path maturity (see [macOS policy](#macos-platform-policy))

---

## Phase 4: 3D + networking (post–2D ship) ⏳

**Gate:** Nexus v1.0.0 shipped.

- [ ] **3D depth buffer** + `hello-cube` example
- [ ] zClip track A2–A4: **gltf-viewer**, `animation-browser`, `run-cycle` (skeletal)
- [ ] **GNS sibling** (`zgns`) — optional; Nexus owns `MultiplayerAPI`
- [ ] WebGPU backend exploration (pairs with Nexus theory/12)

**Explicitly not blocking the 2D game.**

---

## Framework Version Milestones

These milestones describe zGameLib's own evolution (library releases), distinct from the Nexus-aligned version table above.

| Release | Focus | Key Deliverables |
| --- | --- | --- |
| **v0.1.0** | Foundation | Module re-exports, surface bridge, Swapchain helper, CI decoupling checks. *Current.* |
| **v0.2.0** | First pipeline | Complete hello-triangle (pipeline + vertex buffer + VMA). Early 2D batcher exploration. |
| **v0.3.0** | 2D batcher v0 | Efficient sprite/quad batching, atlas integration with zClip, text quad support. |
| **v0.4.0** | Assets | `zassets`: image decode (PNG), basic VFS, texture creation. |
| **v0.5.0** | Audio | `zaudio`: miniaudio backend, playback/streaming. Hot-reload middleware. |
| **v0.6.0** | Animation | Unified `zgame.animation` on top of zClip. Skeletal/glTF prep. Profiling hooks. |
| **v0.7.0** | Input & polish | Deeper input handling, math utilities (`zmath`), docs polish. |
| **v1.0.0** | Stable | Every component ships with docs + tests + example. CI matrix green. Ready for Nexus heavy integration. |

---

## Example Ladder (Two Tracks)

Examples are **reference apps** — not shipped with the default `zgame` artifact.
See [`docs/examples/vision.md`](examples/vision.md) and [`docs/examples/mission.md`](examples/mission.md).

### Track A — Modular capability rungs (pay-for-what-you-use)

| Rung | Example | Adds | Status | 2D game? |
|------|---------|------|--------|----------|
| 0 | `event-logger` | `platform` only | ✅ shipped | 🎯 |
| 1 | `clear-color` | + `vulkan_stack` | ✅ shipped | 🎯 |
| 2 | `clear-color-2` | + `Gpu`/`FrameRing` helpers | ✅ shipped | 🎯 |
| 2+ | `hello-triangle` | + pipeline/VMA | partial | 🎯 |
| 3 | `space-invaders` / `breakout` | + 2D batcher | planned | 🎯 |
| 4 | `sprite-showcase` | + `zClip` atlas | partial | 🎯 |
| 5 | `audio-demo` | + `zaudio` | stub | 🎯 |
| 6 | `asset-demo` | + `zassets` | stub | 🎯 |
| 7 | `app-demo` | + `zgame.App` | stub | stretch |
| late | `imgui-demo` | + `zimgui` (`-DimGui`) | planned | 🔧 |
| post | `hello-cube` | + 3D depth | planned | ⏳ |
| post | `gltf-viewer` | + skeletal | planned | ⏳ |

### Track B — Extended validation ladder

Game-style apps exercising adapter depth without new siblings — snake, space-invaders, etc.
See [`docs/examples/ROADMAP.md`](examples/ROADMAP.md). **Re-prioritized for 2D** — 3D smoke (`hello-cube`) moved to v2.0.0 ⏳.

### Track C — Animation (zClip sibling)

| Sub-rung | Example | zClip milestone | Priority |
|----------|---------|-----------------|----------|
| A1 | `sprite-showcase` | v0.6.0 sprite-atlas | 🎯 |
| A2 | `gltf-viewer` | v0.7.0 skeletal/glTF | ⏳ |
| A3 | `animation-browser` | v0.9.0 unified API | ⏳ |
| A4 | `run-cycle` | v0.9.0 blending | ⏳ |

---

## Non-Goals

- **ECS / scene graph** — belongs in **Nexus** (Tier 2), not middleware.
- **Localization / `tr()`** — Nexus-only; zGameLib keeps UTF-8 I/O at most.
- **Asset pipeline / editor** — runtime hooks only; **Crucible** owns editor UX.
- **WASM mod runtime** — Nexus `WasmHost`; zGameLib stays lean.
- **Game-engine monolith** — modularity is the point.

## macOS Platform Policy

macOS is **in scope — not deferred.** CI runs `zig build` on macOS runners; contributors
validate windowed examples on real hardware before macOS-specific PRs merge.

**macOS MoltenVK surface path (v0.9.0+):** `getCocoaHandle` + `createMetalSurface` implemented.
Platform adapter uses `SDL_Metal_CreateView`/`SDL_Metal_GetLayer` to obtain the `CAMetalLayer*`;
vulkan-stack adapter calls `vkCreateMetalSurfaceEXT`. Builds compile-clean on Linux (comptime-gated);
runtime validation requires a macOS runner with MoltenVK.

---

## Out of Scope / Deferred

- Full multiplayer stack — GNS sibling only in Phase 4 ⏳.
- **GUI in core** — Dear ImGui stays **optional** (`-DimGui`), implemented **late** 🔧.
- **Fonts before ImGui** — `zfont` ships **after** `zimgui`.
- **3D before 2D ship** — `hello-cube`, glTF skeletal deferred to v2.x ⏳.

---

## Downstream: Nexus (Tier 2)

Nexus consumes `zgame` via path dependency. Critical path to **first 2D game**:

```ascii
zGameLib 0.4.0 (2D batcher) ──► Nexus 0.2.0–0.7.0 (sprites, particles, HUD)
zGameLib 0.7.0 (zassets)      ──► Nexus 0.2.0 (textured-quad)
zGameLib 0.9.0 (zaudio)       ──► Nexus 1.0.0 (minimal-2d-game)
zGameLib 1.1.0 (zimgui)       ──► Link-editor 1.1.0 (Crucible)
```

See [Nexus ROADMAP](https://github.com/SETA1609/Nexus-engine/blob/main/docs/ROADMAP.md) ·
[Nexus architecture](https://github.com/SETA1609/Nexus-engine/blob/main/docs/architecture.md) ·
[Bundle ROADMAP](https://github.com/SETA1609/Link_and_nexus_bundle/blob/main/ROADMAP.md).

---

## Success Metrics

For each milestone:
- [ ] Implementation complete
- [ ] Documentation written (theory guide + inline docs)
- [ ] ≥1 working example
- [ ] Tests pass (`zig build test-tdd`)
- [ ] Decoupling checks pass (platform-drags-no-Vulkan, vulkan-drags-no-windowing)

---

## Risks

- **Scope creep**: Temptation to add engine-level features (Servers, scene graph) into the framework. Mitigated by clear architectural boundaries.
- **Over-engineering**: Building abstractions before they're needed. Mitigated by raw-first philosophy and iterative development.
- **Parallel development**: Splitting focus between framework and engine. Mitigated by the Framework-Only decision.

---

## See Also

- [`docs/examples/ROADMAP.md`](examples/ROADMAP.md) — examples validation ladder and release sequence.
- [`docs/theory/README.md`](theory/README.md) — beginner theory guides for the full stack.
- [`README.md`](../README.md) — project overview and build instructions.
