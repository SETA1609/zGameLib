# Mission — zig-stack-adapter-examples

> The concrete commitments that turn the [vision](vision.md) into a working harness: how every app is built, how the two adapters meet, and what "green" means.

## What we will build

1. **A ladder of apps, each consuming both adapters via `libs/`** — local-path `build.zig.zon` deps into the submodules, the lib's Zig **module** imported for the API, the lib's compiled **static-library artifact** linked for the code. SDL3 / VMA / glslang compile once, inside each lib. See [`../../libs/README.md`](../../libs/README.md).

2. **One comptime surface bridge — the single place the adapters meet.** [`../../shared/surface.zig`](../../shared/surface.zig) pairs a platform native-handle *getter* with a vulkan surface *creator*, branched on the target OS at comptime. **No shared type crosses** — it hands raw OS primitives from one lib to the other. Reused unchanged by every app.

3. **Two `nm` decoupling checks, kept green.** A platform-only binary (`renderer = .none`) must show **zero `vk*` symbols**; a headless-vulkan binary (no window) must show **zero windowing symbols**. These are required gates, not nice-to-haves — [`ladder.md`](ladder.md) § Decoupling checks.

4. **Each app pinned to a lib milestone.** An app builds only against the lib versions it needs (the ladder's version columns), and its existence *drives* those versions into being.

5. **Hand-written app code.** The scaffolding (build shell, stubs, docs) is provided; the app implementations are written by hand — this is a learning repo, and the wiring/implementation is the point.

6. **CI builds *and runs* each landed app** on the supported target matrix, so "compiles" never gets mistaken for "works".

## What "green" means (success criteria)

- Every rung in [`ladder.md`](ladder.md) **builds and runs correctly** — not merely compiles.
- Both `nm` decoupling checks print nothing.
- `clear-color` runs with **zero validation-layer messages** and recreates its swapchain on resize without crashing.
- A consumer can read any example's `build.zig` wiring and copy the libs-first / link-the-artifact pattern into their own project.

## Non-goals

- Reimplementing either lib's own validation apps (each lib tests itself in isolation; this repo tests the **pair**).
- Shared game-engine infrastructure across the apps — duplication between toys is fine and expected.
- 3D beyond a single untextured cube — `hello-cube` is a smoke test, not a renderer.
- macOS — deferred in lockstep with the platform lib's roadmap.

## See also

[`vision.md`](vision.md) · [`ROADMAP.md`](ROADMAP.md) — release sequence + lib version gates · [`sprint.md`](sprint.md) — the current sprint.
