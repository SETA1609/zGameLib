# zGameLib Framework: Current State, Gaps vs Hazel/Redot, Missing Features, and Roadmap/Sprint Update (July 2026)

**Focus:** Exclusively on the framework (zGameLib / Tier 1) for the foreseeable future. Engine (Nexus) work will be minimal/integration-only until the foundation is solid.

**Date:** July 18, 2026 (updated based on current `main` branch inspection)

---

## Executive Summary

zGameLib is in an **early-to-mid development stage** with a very strong philosophical and documentary foundation. The core platform + Vulkan adapters and middleware helpers are functional. Critical gaps for enabling a 2D game in Nexus are the **2D batcher**, asset loading, and audio.

**Recommendation:** Stay laser-focused on completing the 2D pipeline (batcher + assets + audio integration) in the framework before heavy engine work. Reimplement and expand examples in the engine later.

The existing `docs/examples/ROADMAP.md` is already excellent and mostly up-to-date. This document provides a gap analysis (informed by Hazel and Redot) and specific recommendations for updating the sprint/roadmap and fixing recent git flow issues (bad rebase leading to extra merge commits).

---

## 1. What We Currently Have (Strengths of zGameLib on `main`)

### Core Philosophy & Documentation (Top-Tier)
- **Raw-first / opt-in / pay-for-what-you-use**: Every convenience layer re-exports the raw API. Sibling libraries are independent and usable standalone.
- **Excellent theory documentation** (`docs/theory/`): Layered reading order (platform → Vulkan stack → surface bridge → Gpu → swapchain → FrameRing → App → hot-reload → Hazel split → web strategy). This is one of the best aspects — educational and clear.
- **Architecture decisions** documented (see `docs/architecture-decisions.md`): Comptime modules (not static lib), script encapsulation in CI (all logic in `scripts/`), decoupling via `zgame_platform` module.
- Guiding principles solid and consistent.

### Implemented Features
- **Platform adapter**: SDL3 for windowing, input, events, time. Exposed cleanly.
- **Vulkan stack**: Full integration via `vulkan-zig`, `volk`, VMA (memory allocator), optional `shaderc`. Helpers for surface, swapchain.
- **Middleware helpers** (`shared/`): `Gpu` (device bring-up), `FrameRing` (frames-in-flight, synchronization), image transitions, etc. Very solid.
- **Examples ladder** (incremental, pay-for-what-you-use):
  - Rung 0: `event-logger` (platform only).
  - Rung 1: `clear-color` (raw Vulkan).
  - Rung 2: `clear-color-2` (with Gpu/FrameRing).
  - Partial: `hello-triangle` (VMA + pipeline + vertex buffer).
- **Animation foundation**: `zClip` (libs/zClip) — sprite atlas path live at v0.6; skeletal/glTF planned later.
- **Build system**: `build.zig` + `build.zig.zon`, module-based (comptime friendly), incremental examples, tests (`test-tdd`), Docker/CI with script encapsulation.
- **Other**: Licensing map, cheat sheet, file-tree/dependencies docs, AGENTS.md.

### Maturity
- Functional core for basic rendering and platform.
- No formal releases yet.
- Strong alignment with Nexus 2D game goal.

**Overall**: Excellent foundation and philosophy. The "transparent framework like raylib but modular" vision is well-executed at the low level.

---

## 2. Comparison to Hazel and Redot (Framework-Relevant Lessons)

### Hazel (TheCherno)
- **Core**: Static library (`Hazel/`) with `Application`, `Layer` system, event dispatcher, basic renderer, profiling, ImGui integration.
- **Editor**: Separate executable (`Hazelnut`).
- **Philosophy**: Educational (teach engine architecture), clear separation of concerns, 2D/3D support, multi-platform.
- **Strengths for us**: Clear entry point / application harness (similar to our `App`), layer-based composition for game code (inspiration for engine, not framework), static lib approach (we use modules instead — good for Zig).
- **Relevance**: zGameLib is *lower-level* (adapters + middleware) than Hazel's core engine. Our sibling modules philosophy aligns with modularity. Lesson: Keep framework lean; higher-level (layers, full app) can live in engine or optional middleware. Hazel's early ImGui integration is useful reference (we plan it late — correct for our 2D focus).

### Redot (Godot Fork)
- **Architecture**: Highly modular with clear layers — **Drivers** (low-level platform/API), **Servers** (high-level opaque subsystems like RenderingServer, PhysicsServer, AudioServer), **Scene** (Node tree + SceneTree), **Modules** (optional extensions), and Editor on top.
- **Philosophy**: Intuitive composition over deep inheritance, "all-in-one but modular", replaceable components, community-driven.
- **Important Distinction (Addressing Your Point)**:
  - **Servers** in Godot/Redot are **high-level engine subsystems**. They provide an opaque API that the Scene system and scripts build upon (e.g., RenderingServer is "the API backend for everything visible"). They sit *above* the low-level drivers/renderer.
  - Therefore, full Servers belong in the **Engine (Nexus / Tier 2)**, *not* in the low-level Framework (zGameLib / Tier 1).
- **Strengths for us (Framework level)**: The *modularity and optional-component* pattern (Modules + Servers concept) inspires our **sibling adapters** and optional middleware. The Drivers layer maps well to our platform + Vulkan stack adapters. Raw access + replaceable backends align strongly.
- **Relevance & Lesson**: Our "pay-for-what-you-use" sibling libraries + thin middleware (`Gpu`, `FrameRing`) are a great match for Redot-style modularity at the *foundation* level. We should keep zGameLib focused on lean, raw-accessible building blocks. Higher-level "Server"-style managers (opaque render managers, resource servers, etc.) are better suited for **Nexus**. This preserves the framework's transparent/raw-first nature while still benefiting from Redot's modular thinking. Scene/Node system is clearly Tier 2 (Nexus).

**Key Takeaway**: zGameLib's current design is already well-aligned with both Hazel and Redot at the *framework* level (modular, explicit, educational docs, replaceable components). We are intentionally the "framework/adapter layer" (closer to Drivers + thin middleware) rather than a full engine core (Hazel) or scene engine with high-level Servers (Redot). The Servers concept belongs in Nexus. Focus on completing the low-level 2D foundation while keeping everything modular and optional.

---

## 3. What is Missing / Gaps for a Complete Framework

### Critical Gaps (Block Nexus 2D Game)
- **2D Batcher / Renderer**: Core missing piece. Need efficient sprite/quad batching, atlas integration (beyond raw zClip), text quads, particles (2D GPU). This is the #1 priority.
- **Asset / Image Loading & Management**: `zassets` for VFS, image decode (PNG etc.), texture creation. Gates textured sprites.
- **Audio System**: `zaudio` integration (miniaudio backend) for playback/streaming. Required for complete 2D game.

### High-Priority Gaps
- **Animation Completion**: Unified `zgame.animation` API on top of zClip (raw atlas is there; integrate skeletal/glTF later). Full demo.
- **Shader & Pipeline Management**: Beyond basic hello-triangle — better abstraction or helpers for common pipelines while keeping raw access.
- **Deeper Input / Event System**: Current platform is good; expand for more robust handling or polling vs events.
- **Math Utilities**: `zmath` (SIMD-friendly vectors/matrices) — light but useful early.

### Medium Gaps
- **Hot-Reload Implementation**: Theory doc exists (`08-hot-reload.md`); needs concrete middleware support (rebuilding primitives, typed hooks).
- **Asset Pipeline Maturity**: Beyond basic decode — caching, hot-reload assets, formats.
- **Profiling / Debugging Tools**: Basic timers, GPU profiling hooks (inspired by Hazel).
- **Testing & Robustness**: Expand TDD suite, cross-platform CI (more backends?), error handling/logging.
- **Documentation Polish**: Ensure all theory files are complete; expand cheat sheet; more inline docs.

### Later / Optional (Post 2D Ship or Tool Phase)
- `zimgui` wrapper (Dear ImGui bridge) — keep late (gates editor/Crucible, not 2D game).
- `zfont` (FreeType + HarfBuzz) — after ImGui.
- Web backend: WebGPU as sibling module (theory mentions it).
- 3D primitives (hello-cube, depth, glTF skeletal via zClip) — v2.x.
- Networking sibling (`zgns` / GameNetworkingSockets).
- Full native platform backends (beyond SDL3 where beneficial).
- More advanced rendering features (compute beyond basic, etc.).

### Structural / Philosophical Notes
- **No major structural issues**: Module-based (comptime) is excellent for Zig. Philosophy is sound.
- **Potential Evolution**: We can evolve lightweight middleware helpers (building on current `Gpu`/`FrameRing`), but full high-level "Server" abstractions (opaque managers like a full RenderingServer) belong in **Nexus** (Engine), not zGameLib. This keeps the framework lean, raw-first, and engine-agnostic while still allowing modular growth.
- **Engine-Agnostic**: Good (theory doc on Hazel split). Keep framework independent of Nexus specifics.

**Summary of Missing**: The framework is ~60-70% toward enabling a basic 2D game. The biggest holes are the rendering batcher and asset/audio systems. Everything else is either implemented or well-planned.

---

## 4. How to Modify the Sprint / Roadmap (Recommendations for Update)

The existing `docs/examples/ROADMAP.md` (Updated July 2026) is **already strong** — 2D-first strategy, clear priorities, sibling table, version milestones aligned with Nexus, guiding principles. It correctly defers editor (zimgui) and 3D.

**Specific Recommended Modifications / Additions** (to incorporate into `docs/ROADMAP.md` or this analysis):

### New Section: "July 2026 Framework-Only Phase Update"
- **Current Focus**: Exclusively stabilize and complete the framework before major Nexus engine work. Minimal parallel engine integration (stubs/tests only).
- **Immediate Sprint Priorities** (next 1-2 sprints):
  1. Complete `hello-triangle` fully (robust pipeline, error handling).
  2. **Implement 2D batcher v0** (core priority — sprites, quads, atlas integration with zClip).
  3. Start/integrate `zassets` image decode + basic VFS.
  4. Expand example ladder (finish stubs for animation/audio).
- **Rationale**: These gate Nexus 2D game validation. Batcher is the critical missing piece.

### Updates to Version Milestones
- **0.2.0**: Emphasize "First complete pipeline + batcher foundation" (hello-triangle + early batcher).
- Accelerate **0.4.0 (2D batcher v0)** and **0.7.0 (zassets)** — make them earlier if possible.
- Add explicit item: "Hot-reload middleware implementation" under Target (around 0.5-0.6).
- Keep zimgui/zfont late; confirm "Tool" gating Crucible.

### Updates to Sibling Ecosystem & Middleware Tables
- Update statuses: hello-triangle closer to shipped; zClip atlas confirmed shipped.
- Add row or note for "2D Batcher" as new middleware component (high priority).
- Clarify integration points (e.g., batcher consumes zClip + zassets).

### Other Roadmap Enhancements
- **Examples Strategy**: Add note on reimplementing framework examples as higher-level engine demos in Nexus later + adding new incremental engine examples. This creates a beautiful learning path.
- **Git / CI Hygiene**: Add or reference process for clean rebases (use `git fetch + rebase origin/main`, avoid accidental merges, use `--force-with-lease`). Fix current branches with bad rebase commits.
- **Cross-References**: Link to this gap analysis file. Reference Bundle ROADMAP for Tier 2 view.
- **Success Metrics**: For each milestone — "Implementation + docs + ≥1 working example + tests passing."
- **Risks**: Over-engineering abstractions too early; scope creep into engine features.

### Overall Sprint Philosophy Update
- **Sequential > Parallel**: Framework completeness first.
- Keep all new features as optional sibling adapters where possible.
- Maintain excellent incremental example ladder in framework; plan engine re-implementations.
- Regular reviews of ROADMAP against actual progress.

The current roadmap is already very close to ideal — these are refinements for clarity and to reflect the "framework-only now" decision.

---

## 5. Next Incremental Steps (Framework Focus)

1. **Immediate**: Fix git branches (clean rebase history on affected branches). Update any CI that might create merge commits.
2. **Sprint 1**: Polish/complete current examples (hello-triangle). Expand tests.
3. **Sprint 2+**: 2D batcher implementation + integration with zClip.
4. **Ongoing**: Update theory docs as new components land. Maintain script encapsulation and module decoupling.
5. **Documentation**: Keep `docs/ROADMAP.md` as the living document; reference this analysis.
6. **When Framework Solid**: Shift primary focus to Nexus engine, reimplement examples there, add new high-level incremental examples.

This approach ensures a rock-solid foundation, clear progress, and avoids the pitfalls of parallel development.

---

**References**:
- Current zGameLib main branch inspection (July 2026).
- Existing `docs/examples/ROADMAP.md`, `docs/theory/`, `docs/architecture-decisions.md`.
- Hazel architecture insights (core static lib, layers, educational focus).
- Redot/Godot modular servers + scene philosophy (inspiration for optional components).

This document can be used to update `docs/ROADMAP.md` directly.
