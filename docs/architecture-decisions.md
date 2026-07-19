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

## ADR-002: CI Scripts — Python for Pipeline, Bash for Local Linux Dev

**Decision:** CI pipeline logic lives in the Python script `scripts/ci.py`, while bash scripts (`ci.sh`, `build-in-docker.sh`, etc.) are kept for Linux local development and Docker usage.

**Rationale:**
- Keeps `.github/workflows/` minimal and declarative (triggers, matrix, OS selection only).
- Python runs natively on Linux, macOS, and Windows without needing a bash emulation layer, avoiding CRLF/line-ending issues with `zig fmt` on Windows runners.
- Bash scripts remain available for interactive local debugging and for use inside the Docker container.
- `uv` (fast Python package manager) is installed in the Docker image so the Python scripts work inside the container too.

**Affects:** `.github/workflows/build.yml`, `scripts/ci.py`, `scripts/ci.sh`, `docker/Dockerfile`, local development workflow.

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

## ADR-007: OpenGL Path Deferred Until Post-1.0

**Decision:** The OpenGL renderer path and its test suite (`test-opengl`) are removed from the current codebase and deferred until after the 1.0 release, contingent on funding or contributor sponsorship.

**Rationale:**
- Vulkan is the primary and only graphics path for the 1.0 milestone.
- Maintaining the OpenGL path adds build complexity (system GL linking, Mesa software GL in CI, per-platform GL library names) and CI gate maintenance with no current consumer.
- The platform adapter library (`zig-cpp-platform-stack-adapter`) still ships the SDL3 `SDL_GL_*` wrapper code in its source — it can be revived from git history when funding or contributor demand materialises.
- Deferral aligns with the "pay for what you use" philosophy: no one pays CI time or maintenance attention for a path no consumer uses.
- If and when funding (sponsorship, contract work, or a paying Nexus customer) requires OpenGL support, the path can be restored from the commit history — both the framework's `tests/opengl_test.zig` (removed at commit `ad1293f`) and the adapter's `13_gl_context_test.zig` TDD suite remain in the git log.

**Affects:** `tests/opengl_test.zig` (removed), `build/tests.zig`, `build/dev.zig`, `scripts/ci.py`, `.github/workflows/build.yml`, documentation.

---

## ADR-008: Monorepo-First Sibling Libraries — MIT Licensed

**Decision:** All sibling library modules under `libs/` are developed in-tree as git submodules first, then exported to their own standalone GitHub repositories. The framework (zGameLib) is Apache 2.0 licensed; sibling libraries are MIT licensed.

**Rationale:**
- Developing in-tree first keeps the development loop tight — changes to a sibling library and its consumer in the framework can be tested in a single commit, then the sibling's commit is pushed to its own repo.
- This is how the three current sibling libraries (`zig-cpp-platform-stack-adapter`, `zig-cpp-vulkan-stack-adapter`, `zClip`) were created: prototyped and stabilized inside zGameLib, then split to their own repos when the interface settled.
- New sibling libraries follow the same pattern: create the directory under `libs/`, copy conventions (build structure, CI layout, docs skeleton, test harness) from an existing sibling, implement iteratively, and export when mature.
- **Dual licensing:** zGameLib (the framework layer) uses Apache 2.0 to give consumers broad patent protection and compatibility with the Zig ecosystem. Sibling libraries use MIT — the standard choice for small, focused, single-author libraries — so they can be consumed by any project (proprietary or open-source) with zero friction.
- Each sibling library remains independently versioned and releasable; the submodule pin in zGameLib tracks the exact revision the framework was tested against.

**Affects:** `libs/` directory, submodule workflow, licensing headers, CI for sibling repos.

---

## See Also

- [`FRAMEWORK_GAP_ANALYSIS_AND_ROADMAP_UPDATE.md`](FRAMEWORK_GAP_ANALYSIS_AND_ROADMAP_UPDATE.md) — detailed analysis and context for these decisions.
- [`docs/ROADMAP.md`](ROADMAP.md) — framework-level roadmap and priorities.
- [`docs/theory/README.md`](theory/README.md) — beginner-friendly explanation of the architecture.
