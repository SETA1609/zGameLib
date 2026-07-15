# Roadmap — zGameLib

> The modular, composable, pay-for-what-you-use game-development stack.

This roadmap describes the **overall project vision** — the middleware layer
(zGameLib) plus the ecosystem of **independent sibling libraries** it composes.
Each sibling library has its own roadmap; this one tracks their integration into
a coherent whole.

**Repository layout:** [`file-tree.yml`](file-tree.yml) — machine-readable
zGameLib tree (this repo only). Tier 2 (Nexus-engine) maintains its own
[`file-tree.yml`](https://github.com/SETA1609/Nexus-engine/blob/main/docs/file-tree.yml).

**Dependencies:** [`dependencies.yml`](dependencies.yml) — Zig packages, native
transitives, and downstream consumers. Nexus-engine:
[`dependencies.yml`](https://github.com/SETA1609/Nexus-engine/blob/main/docs/dependencies.yml).

## Design axioms

Every decision flows from these axioms (see [`README.md`](../README.md) for the
full philosophy):

1. **Pay for what you use.** Only the libraries you explicitly add to your
   dependency graph are compiled and linked. A platform-only app compiles no
   Vulkan, no audio, no animation.
2. **Independent sibling libraries.** Each does one thing (windowing, Vulkan,
   audio, animation, assets) and is usable standalone or inside zGameLib.
3. **zGameLib is optional middleware.** It re-exports the siblings and provides
   lightweight helpers (`Gpu`, `FrameRing`, `App`). You can skip it entirely and
   use the siblings directly.
4. **Raw access always.** Every convenience layer re-exports the raw API beneath
   it. Pros bypass zGameLib at any point.
5. **Replaceable backends.** The platform backend (SDL3 → native), renderer,
   and audio backend are swappable independently.

## The sibling library ecosystem

Each sibling is an **independent, reusable Zig library** that follows the same
design rules:

| Library | Status | Purpose | Backend(s) |
|---------|--------|---------|------------|
| `zig-cpp-platform-stack-adapter` | **shipped** v0.6+ | Windowing, input, time, native handles | SDL3 (native planned) |
| `zig-cpp-vulkan-stack-adapter` | **shipped** v0.2+ | Vulkan stack: vk + volk + VMA + shaderc | vulkan-zig |
| `zClip` | **scaffold** | Animation: sprite-atlas + skeletal/glTF | cgltf |
| `zaudio` | **planned** | Audio playback + streaming | miniaudio |
| `zassets` | **planned** | Asset loading / VFS | — |
| `zmath` | **planned** | SIMD-friendly math | — |

**The "pay for what you use" rule in action:** Your app can use `platform`
standalone (headless tools, GL-only), add `vulkan_stack` for GPU rendering,
optionally add `zClip` for animation and `zaudio` for sound — and each addition
links *only* its own dependencies. No library pulls in unrelated code.

## zGameLib middleware roadmap

zGameLib sits above the siblings and provides:

- **Re-exports** — everything from every sibling, namespaced under `zgame.*`
- **Helpers** — composable policy objects (`Gpu`, `FrameRing`, `Swapchain`,
  `surface` bridge, `animation` unified API)
- **Harness** — `zgame.App` (optional convenience loop)

| Area | Where | Status |
|------|-------|--------|
| Re-exports (platform / vulkan / surface / swapchain) | `src/root.zig` | **shipped** |
| Render helpers: `Gpu`, `FrameRing`, `transitionImage` | `shared/gpu.zig`, `shared/frame.zig` | **shipped** |
| Platform-only module (`zgame_platform` — no vulkan) | `src/root_platform.zig` | **shipped** |
| Animation: raw `zclip` + unified `zgame.animation` | `shared/animation.zig` + `libs/zClip` | **scaffold** — see [zClip roadmap](libs/zClip/docs/ROADMAP.md) |
| Audio integration (`zaudio` bridge) | — | **planned** |
| Asset / VFS integration (`zassets` bridge) | — | **planned** |
| `App` harness (window + frame loop) | `src/app.zig` | **stub** |

## Example ladder roadmap

The examples in `examples/` demonstrate the modular progression:

| Release | Rungs | What it proves |
|---------|-------|----------------|
| **v0.1.0** | Rung 0–1 | Platform standalone + platform+vulkan surface hand-off ✅ |
| **v0.2.0** | Rung 2 | First pipeline + VMA vertex buffer |
| **v0.3.0** | Rung 2++ | 2D games, texturing, instancing |
| **v0.4.0** | Rung 3 | Animation with zClip (sprite + skeletal) |
| **v0.5.0** | Rung 4 | Audio with zaudio |
| **v0.6.0** | Rung 5 | Asset loading with zassets |
| **v1.0.0** | Rung 6 | Full `zgame.App` middleware + all rungs green |

See [`docs/examples/ladder.md`](examples/ladder.md) for the full per-rung design.

## Non-goals

- **ECS / scene graph** — these belong in your game, not in the middleware.
- **Asset pipeline / editor** — zGameLib provides the runtime hooks, not a GUI
  editor or a complex build pipeline.
- **macOS target** — deferred (tracks the platform lib).
- **Game-engine monolith** — the whole point is modularity. zGameLib will never
  become a single "everything but the kitchen sink" dependency.

## Out of scope

- Network / multiplayer libraries — beyond the scope of this project.
- GUI toolkit — use your own or Dear ImGui via the platform adapter's raw
  native handles.
