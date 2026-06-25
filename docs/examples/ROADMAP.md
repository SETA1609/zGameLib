# Roadmap — zig-stack-adapter-examples

> The release sequence for this examples repo: which app lands when, and the adapter milestones each one gates on. Per-app validation detail: [`ladder.md`](ladder.md). Current sprint: [`sprint.md`](sprint.md).

## How releases map to the ladder

Each release is a **lib-milestone phase** that delivers the ladder rungs sharing its gate. A rung is done when it **builds and runs correctly** and the relevant `nm` decoupling check is green. The adapter columns are the *minimum* lib versions the phase builds against — earlier phases unblock later ones. Per-rung detail + the ordering rationale: [`ladder.md`](ladder.md).

| Release | Phase | Rungs delivered | platform → | vulkan → |
| --- | --- | --- | --- | --- |
| **v0.1.0** ← *in progress* | Foundation | event-logger ✅, clear-color ✅ *(both build + run; platform-only `nm` check + CI live; tag pending the headless-vulkan `nm` check)* | v0.6.0 | v0.2.0 |
| **v0.2.0** | First pipeline | hello-triangle | (v0.6.0) | v0.3.0 (VMA) |
| **v0.3.0** | Games & texturing | snake, asteroids, breakout, space-invaders, image-viewer | v0.6.0 | v0.3.0 |
| **v0.4.0** | Input depth | tetris, replay-demo | v0.7.0 | v0.3.0 |
| **v0.5.0** | Devices & persistence | pong, 2048, typing-game | v0.8.0 | v0.3.0 |
| **v0.6.0** | Shaders & compute | life, particles, shader-playground | (v0.6.0) | v0.4.0 |
| **v0.7.0** | 3D smoke *(tail)* | hello-cube | (v0.6.0) | v0.4.0 + depth |
| **v0.8.0** | Animation raw paths | sprite-showcase, gltf-viewer | — (zClip v0.6/v0.7) | — |
| **v0.9.0** | Unified animation API | animation-browser, run-cycle | — (zClip v0.9) | — |
| **v1.0.0** | Stable | every rung green; both `nm` checks pass; CI matrix green — the set is the engine's reference consumer | — | — |

Phases beyond v0.1.0 may resequence as the libs' own roadmaps firm up.

## Gates that apply to every release

- **Builds *and* runs in CI** on the supported target matrix (Linux X11 + Wayland, Windows). macOS deferred in lockstep with the platform lib.
- **Decoupling holds** — the relevant `nm` check (platform-drags-no-Vulkan / vulkan-drags-no-windowing) prints nothing.
- **Pinned submodule SHAs** — each release pins `libs/*` to the lib commits it was validated against, so the build is reproducible.

## Out of scope / deferred

- macOS target — deferred (tracks the platform lib).
- Audio-driven or networked toys — not part of the adapter-validation story.
- Textured / lit / multi-object **3D** — `hello-cube` is the 3D ceiling here by design (2D texturing lands earlier, at `space-invaders`).

## See also

[`vision.md`](vision.md) · [`mission.md`](mission.md) · [`ladder.md`](ladder.md) — what each app validates + the `nm` checks · [`sprint.md`](sprint.md).
