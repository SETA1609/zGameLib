# Mission — example ladder

> The concrete commitments that turn the [vision](vision.md) into a working set
> of examples: how each rung is built, how the "pay for what you use" principle
> is enforced, and what "green" means.

## What we will build

1. **A modular ladder of runnable examples**, each consuming only the sibling
   libraries it needs. Each rung adds exactly one capability (platform, vulkan,
   Gpu/FrameRing, zClip animation, audio, assets, App middleware). A consumer
   can read any example's source and replicate the pattern — only import what
   you use.

2. **The "pay for what you use" rule is visible and checkable.** A rung-0
   binary (`event-logger`) must show **zero** of our Vulkan stack symbols via
   `nm`. A rung-1 binary must show **zero** zClip, audio, or asset symbols.
   Every future rung follows the same pattern.

3. **One comptime surface bridge** — [`shared/surface.zig`](../../shared/surface.zig)
   pairs a platform native-handle *getter* with a vulkan surface *creator*,
   branched on the target OS at comptime. No shared type crosses it. This is
   the single seam where the platform and vulkan adapters meet.

4. **Two `nm` decoupling checks, kept green.** Platform-only and headless-vulkan
   binaries must each show zero of the other's symbols.

5. **Hand-written example code.** The scaffolding (build shell, stubs, docs) is
   provided; the example implementations are written by hand — this is a
   learning repo, and the wiring/implementation is the point.

6. **CI builds *and runs* each landed example** on the supported target matrix,
   so "compiles" never gets mistaken for "works".

7. **An animation track** (sprite-atlas flipbook, glTF skeletal, unified
   `zgame.animation`) exercises the zClip sibling lib alongside the adapter
   pair, gated on zClip milestones rather than platform/vulkan ones. Design
   docs: [`sprite-showcase.md`](sprite-showcase.md), [`gltf-viewer.md`](gltf-viewer.md),
   [`animation-browser.md`](animation-browser.md), [`run-cycle.md`](run-cycle.md).

8. **Extended validation apps** (snake, space-invaders, `hello-cube`, …) reuse
   the same adapters to drive **milestone depth** without adding new siblings —
   see Track B in [`ladder.md`](ladder.md) and release phases in [`ROADMAP.md`](ROADMAP.md).

## What "green" means (success criteria)

- Every rung in [`ladder.md`](ladder.md) **builds and runs correctly** — not merely compiles.
- Both `nm` decoupling checks print nothing.
- `clear-color` runs with **zero validation-layer messages** and recreates its swapchain on resize without crashing.
- A consumer can read any example's source and copy the import/link pattern into their own project — importing only what they need.

## Non-goals

- Reimplementing any sibling library's own validation apps (each lib tests itself in isolation; this repo tests the **composition**).
- Shared game-project infrastructure across the examples — duplication between toys is fine and expected.
- 3D beyond a single untextured cube — `hello-cube` is a smoke test, not a renderer.
- macOS runtime QA on maintainer hardware — macOS is **in scope** (Redot-informed Cocoa/Metal hand-off); CI covers builds in container pipelines; **contributors validate windowed runs** on real Macs before macOS-specific PRs land.

## See also

[`vision.md`](vision.md) · [`ROADMAP.md`](ROADMAP.md) — release sequence + lib version gates · [`ladder.md`](ladder.md) — per-rung detail · [`sprint.md`](sprint.md) — the current sprint.
