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

## What "green" means (success criteria)

- Every rung in [`ladder.md`](ladder.md) **builds and runs correctly** — not merely compiles.
- Both `nm` decoupling checks print nothing.
- `clear-color` runs with **zero validation-layer messages** and recreates its swapchain on resize without crashing.
- A consumer can read any example's source and copy the import/link pattern into their own project — importing only what they need.

## Non-goals

- Reimplementing any sibling library's own validation apps (each lib tests itself in isolation; this repo tests the **composition**).
- Shared game-project infrastructure across the examples — duplication between toys is fine and expected.
- 3D beyond a single untextured cube — `hello-cube` is a smoke test, not a renderer.
- macOS — deferred in lockstep with the platform lib's roadmap.

## See also

[`vision.md`](vision.md) · [`ROADMAP.md`](ROADMAP.md) — release sequence + lib version gates · [`ladder.md`](ladder.md) — per-rung detail · [`sprint.md`](sprint.md) — the current sprint.
