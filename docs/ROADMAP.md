# zGameLib Roadmap (Updated July 2026)

**Goal:** Become the best transparent, raw-first, explicit foundation for game
development in Zig.

> The modular, composable, pay-for-what-you-use game-development stack.

This roadmap describes the **middleware layer** (zGameLib) plus the ecosystem of
**independent sibling libraries** it composes. **Nexus** (Tier 2, `Nexus-engine` repo)
consumes the foundation.

**Repository layout:** [`file-tree.yml`](file-tree.yml)  
**Dependencies:** [`dependencies.yml`](dependencies.yml)  
**Example ladder:** [`docs/examples/ladder.md`](examples/ladder.md) · [`docs/examples/ROADMAP.md`](examples/ROADMAP.md)

---

## Scope — what zGameLib is (and is not)

| In scope | Out of scope (Tier 2+ Nexus) |
|----------|------------------------------|
| Platform, Vulkan, `Gpu`, `FrameRing` | Scene graph, SceneNode, ECS |
| Optional siblings: audio, assets, math, **late** ImGui, **later** fonts | Localization, `tr()`, servers |
| 2D batcher, decode, raw re-exports | Crucible editor, `EditorHost` |

**Optional module order (late roadmap):** core adapters → **2D batcher** → **`zimgui`** → **`zfont`** (fonts **after** ImGui).

---

## Current Strengths (July 2026)

- Excellent theory documentation ([`docs/theory/`](theory/))
- Strong Vulkan + SDL3 foundation via sibling adapters
- Clear sibling-adapter philosophy — pay for what you use
- `Gpu`, `FrameRing`, `Swapchain`, surface bridge abstractions are solid
- Shipped examples: `event-logger` (rung 0), `clear-color` (rung 1), `clear-color-2` (rung 2)
- **zClip sprite-atlas path** live at v0.6 — animation example docs landed

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

## The Sibling Library Ecosystem

| Library | Status | Purpose | Backend(s) |
|---------|--------|---------|------------|
| `zig-cpp-platform-stack-adapter` | **shipped** v0.6+ | Windowing, input, time, native handles | SDL3 (native planned) |
| `zig-cpp-vulkan-stack-adapter` | **shipped** v0.2+ | Vulkan stack: vk + volk + VMA + shaderc | vulkan-zig |
| `zClip` | **partial** v0.6+ | Animation: sprite-atlas (**shipped**) + skeletal/glTF (in progress) | cgltf |
| `zaudio` | **planned** | Audio playback + streaming | miniaudio |
| `zassets` | **planned** | Asset loading / VFS | — |
| `zmath` | **planned** | SIMD-friendly math | — |
| `zimgui` (wrapper) | **planned (late)** | Optional Dear ImGui bridge | Dear ImGui via `-DimGui` |
| `zfont` | **planned (after zimgui)** | Font rendering / shaping | FreeType + HarfBuzz optional |

---

## Middleware Integration Status

| Area | Where | Status |
|------|-------|--------|
| Re-exports (platform / vulkan / surface / swapchain) | `src/root.zig` | **shipped** |
| Render helpers: `Gpu`, `FrameRing`, `transitionImage` | `shared/gpu.zig`, `shared/frame.zig` | **shipped** |
| Platform-only module (`zgame_platform`) | `src/root_platform.zig` | **shipped** |
| Animation: raw `zclip` + unified `zgame.animation` | `shared/animation.zig` + `libs/zClip` | **partial** |
| Audio integration (`zaudio` bridge) | — | **planned** (Phase 1) |
| Asset / VFS integration (`zassets` bridge) | — | **planned** (Phase 1) |
| 2D rendering helpers (batcher, sprites, text) | — | **planned** (Phase 1–2) |
| Dear ImGui optional wrapper (`zimgui`) | — | **planned (late)** — after batcher; gates Nexus Crucible |
| Font module (`zfont`) | — | **planned (after zimgui)** |
| `App` harness (window + frame loop) | `src/app.zig` | **stub** |

---

## Phase 1: Core Completion (Q3 2026)

- [ ] Finish and stabilize Vulkan backend (memory, pipelines, descriptors)
- [ ] Add **miniaudio** as new sibling adapter (`zaudio` — primary audio path)
- [ ] Basic asset loading (glTF 2.0 + image decoding) via `zassets` bridge
- [ ] **Improve 2D rendering helpers (batcher, sprites, text)** — priority for Nexus in-game UI
- [ ] Land `hello-triangle` example (rung 2+) — first pipeline + VMA
- [ ] Animation track A1: **sprite-showcase** on raw `zclip.sprite` (zClip v0.6 ✅)

**Not in Phase 1:** Dear ImGui, fonts — optional modules come **later**.

---

## Phase 2: Polish & Usability (Q4 2026)

- [ ] Better error handling and diagnostics across adapters
- [ ] More examples: textured rendering (`space-invaders`), audio playback (`audio-demo`)
- [ ] Stabilize build system and dependency management (pinned submodule SHAs per release)
- [ ] Extended validation ladder: snake → space-invaders rungs
- [ ] Animation track A2: **gltf-viewer** (skeletal/glTF, zClip v0.7+)
- [ ] 2D batcher maturity — Nexus `Control` / HUD path depends on this

**Not primary in Phase 2:** ImGui — deferred to late optional modules.

---

## Phase 3: Late Optional Modules (2027)

Ship only when core + batcher are stable. Order matters:

1. **`zimgui`** — optional Dear ImGui via `-DimGui` ([`docs/imgui.md`](imgui.md))
   - Required by **Nexus Crucible** (Tier 3) at v1.1.0+
   - Optional for Nexus `debug-ui` rich panels
2. **`zfont`** — font rendering (**after** `zimgui`)
   - FreeType + HarfBuzz as optional sibling
   - Nexus `TextServer` consumes; not a localization system

Also in Phase 3:

- [ ] Basic networking foundation (ENet) — optional sibling
- [ ] macOS Metal/MoltenVK path maturity (see [macOS policy](#macos-platform-policy))
- [ ] Optional Tracy profiling integration
- [ ] Animation track A3–A4: `animation-browser`, `run-cycle`
- [ ] `zgame.App` harness + `app-demo` (rung 6)

---

## Example Ladder (Two Tracks)

Examples are **reference apps** — not shipped with the default `zgame` artifact.
See [`docs/examples/vision.md`](examples/vision.md) and [`docs/examples/mission.md`](examples/mission.md).

### Track A — Modular capability rungs (pay-for-what-you-use)

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
| late | `imgui-demo` | + `zimgui` (`-DimGui`) | planned (Phase 3) |

### Track B — Extended validation ladder

Game-style apps exercising adapter depth without new siblings — snake, space-invaders, etc.
See [`docs/examples/ROADMAP.md`](examples/ROADMAP.md).

### Track C — Animation (zClip sibling)

| Sub-rung | Example | zClip milestone |
|----------|---------|-----------------|
| A1 | `sprite-showcase` | v0.6.0 sprite-atlas |
| A2 | `gltf-viewer` | v0.7.0 skeletal/glTF |
| A3 | `animation-browser` | v0.9.0 unified API |
| A4 | `run-cycle` | v0.9.0 blending |

---

## Non-Goals

- **ECS / scene graph** — belongs in **Nexus** (Tier 2), not middleware.
- **Localization / `tr()`** — Nexus-only; zGameLib keeps UTF-8 I/O at most.
- **Asset pipeline / editor** — runtime hooks only; **Crucible** docs live in Nexus-engine repo.
- **Game-engine monolith** — modularity is the point.

## macOS Platform Policy

macOS is **in scope — not deferred.** CI runs `zig build` on macOS runners; contributors
validate windowed examples on real hardware before macOS-specific PRs merge.

---

## Out of Scope / Deferred

- Full multiplayer stack — optional ENet sibling only in Phase 3.
- **GUI in core** — Dear ImGui stays **optional** (`-DimGui`), implemented **late**.
- **Fonts before ImGui** — `zfont` ships **after** `zimgui`.

---

## Downstream: Nexus (Tier 2)

Nexus consumes `zgame` via path dependency. Its roadmap gates on Tier 1 milestones —
especially **2D batcher**, image decode, `zaudio`, zClip, then **late** `zimgui` for Crucible.

See [Nexus ROADMAP](https://github.com/SETA1609/Nexus-engine/blob/main/docs/ROADMAP.md) ·
[Nexus architecture](https://github.com/SETA1609/Nexus-engine/blob/main/docs/architecture.md).