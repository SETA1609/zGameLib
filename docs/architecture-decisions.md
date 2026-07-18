# Architecture Decisions — zGameLib

> Key decisions behind zGameLib's architecture. Each entry records a decision, its rationale, and what it affects.

---

## ADR-001: Comptime Modules Over Static Libraries

**Decision:** Use Zig comptime modules (via `build.zig` + `build.zig.zon`) rather than static libraries for the framework layer.

**Rationale:**
- Zig's comptime is a first-class language feature; modules are the idiomatic Zig approach.
- Modules enable zero-cost abstractions, comptime polymorphism, and avoid the link-time overhead of static libs.
- The sibling adapter libraries (platform, vulkan-stack) are built as static artifacts (they contain C/C++ code), but the Zig framework layer wraps them as modules.
- The Nexus engine static library (Tier 2) re-exports zGameLib modules to its consumers.

**Affects:** Build system, dependency graph, decoupling checks.

---

## ADR-002: Script Encapsulation in CI

**Decision:** All CI logic lives in `scripts/ci.sh`, not inline in workflow YAML.

**Rationale:**
- Keeps `.github/workflows/` minimal and declarative (triggers, matrix, OS selection only).
- The actual build/test/check logic is runnable locally with the same script.
- Single source of truth for CI gates, avoiding YAML-language quirks and duplication across matrix entries.

**Affects:** `.github/workflows/build.yml`, `scripts/ci.sh`, local development workflow.

---

## ADR-003: Decoupling via `zgame_platform` Module

**Decision:** The framework ships a separate `zgame_platform` module that exposes the platform adapter *without* the Vulkan stack.

**Rationale:**
- Enables the `nm` decoupling check (platform-only binary must drag in zero Vulkan symbols).
- Consumers who only need windowing/input don't pay the compile-time or link-time cost of the Vulkan stack.
- Reinforces the sibling independence principle at the framework level.

**Affects:** `src/root_platform.zig`, `build.zig`, decoupling CI checks.

---

## ADR-004: Surface Bridge — No Shared Type Crosses

**Decision:** The windowing↔Vulkan seam passes only raw OS primitives (native window handles), never a shared framework type.

**Rationale:**
- Prevents the two adapter libraries from developing a dependency on each other or on a shared type.
- The surface bridge is a comptime switch on target OS, pairing a platform native-handle getter with a Vulkan surface creator.
- This is the template for all future inter-adapter seams.

**Affects:** `shared/surface.zig`, all future inter-adapter bridges.

---

## ADR-005: High-Level Servers Belong in the Engine, Not the Framework

**Decision:** Opaque high-level subsystems (e.g., RenderingServer, AudioServer, PhysicsServer) are the responsibility of the Engine (Nexus / Tier 2), not the Framework (zGameLib / Tier 1).

**Rationale:**
- Inspired by Redot/Godot's layered architecture: Drivers → Servers → Scene → Editor.
- zGameLib provides the **Drivers layer** (platform, Vulkan stack) and **thin middleware helpers** (Gpu, FrameRing, 2D batcher, etc.) — these are low-level, opt-in, and transparent.
- Full Servers are opaque high-level managers that sit above the renderer/drivers. They belong in Nexus because they embody engine-level policy (resource lifetime, scene-level coordination, etc.).
- Keeping Servers out of the framework preserves:
  - **Raw-first transparency** — the framework never hides the underlying API behind an opaque manager.
  - **Engine-agnosticism** — zGameLib can be consumed by any engine, not just Nexus.
  - **Scope control** — prevents the framework from bloating into an engine.

**Affects:** Scope of zGameLib vs Nexus, future middleware design, roadmap priorities.

---

## ADR-006: Examples Are Framework Consumers, Not Part of the Library

**Decision:** Example apps live in `examples/` and consume the framework via `build.zig.zon` dependency, but are not bundled with the library package.

**Rationale:**
- Examples prove the framework works from an external consumer's perspective.
- They validate the exact consumption pattern Nexus will use (import module, link artifact).
- Keeping them separate prevents the library package from shipping example code that consumers don't need.

**Affects:** `examples/` directory structure, `build.zig`, packaging.

---

## See Also

- [`FRAMEWORK_GAP_ANALYSIS_AND_ROADMAP_UPDATE.md`](FRAMEWORK_GAP_ANALYSIS_AND_ROADMAP_UPDATE.md) — detailed analysis and context for these decisions.
- [`docs/ROADMAP.md`](ROADMAP.md) — framework-level roadmap and priorities.
- [`docs/theory/README.md`](theory/README.md) — beginner-friendly explanation of the architecture.
