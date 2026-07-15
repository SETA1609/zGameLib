# Roadmap — example ladder releases

> The release sequence for the modular example ladder: which rungs land when,
> and the library milestones each one gates on. Per-rung detail:
> [`ladder.md`](ladder.md).

## How releases map to the ladder

Each release delivers a set of rungs that add **one new capability** to the
stack — and only that one. No library is pulled in before it's needed.

| Release | Phase | Rungs delivered | Incremental cost |
|---------|-------|-----------------|------------------|
| **v0.1.0** — *Foundation* | shipped | event-logger ✅, clear-color ✅ | platform only → +vulkan_stack |
| **v0.2.0** | First pipeline | clear-color-2 + hello-triangle | +Gpu/FrameRing (no new libs) |
| **v0.3.0** | Games & texturing | snake, asteroids, breakout, space-invaders, image-viewer | (same libs, new skills) |
| **v0.4.0** | Input depth | tetris, replay-demo | — |
| **v0.5.0** | Devices & persistence | pong, 2048, typing-game | — |
| **v0.6.0** | Shaders & compute | life, particles, shader-playground | — |
| **v0.7.0** | 3D smoke | hello-cube | +depth |
| **v0.8.0** | **Animation** | sprite-showcase, gltf-viewer | +zClip only |
| **v0.9.0** | Unified animation | animation-browser, run-cycle | +zgame.animation only |
| **v1.0.0** | Audio | audio-demo | +zaudio |
| **v1.1.0** | Assets | asset-demo | +zassets |
| **v2.0.0** | App middleware | app-demo | +zgame.App (optional) |

Animation and later rungs (audio, assets, App) are gated on their respective
sibling library roadmaps, not on the adapter libs.

## Gates that apply to every release

- **Builds *and* runs in CI** on the supported target matrix (Linux X11 + Wayland, Windows). macOS: **build gates in CI** (container/VM runners); **runtime/display runs verified by contributors** on hardware — see [zGameLib macOS policy](../ROADMAP.md#macos-platform-policy).
- **Decoupling holds** — the relevant `nm` check (platform-drags-no-Vulkan / vulkan-drags-no-windowing) prints nothing.
- **Pinned submodule SHAs** — each release pins `libs/*` to the lib commits it was validated against.

## Out of scope / deferred

- Audio-driven or networked toys — not part of the example ladder.
- Textured / lit / multi-object **3D** — `hello-cube` is the 3D ceiling here by design.

## See also

[`vision.md`](vision.md) · [`mission.md`](mission.md) · [`ladder.md`](ladder.md) — what each app validates + the `nm` checks · [`sprint.md`](sprint.md).
