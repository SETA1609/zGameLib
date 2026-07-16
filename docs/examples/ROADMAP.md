# Roadmap — example ladder releases

> The release sequence for the modular example ladder: which rungs land when,
> and the library milestones each one gates on. Per-rung detail:
> [`ladder.md`](ladder.md).

**2D-first alignment:** examples through **v1.0.0** exercise **2D batching, sprites, and
orthographic games**. **`hello-cube` and glTF examples move to v2.x** — after Nexus ships
its first 2D game. See [zGameLib ROADMAP](../ROADMAP.md) and
[Bundle ROADMAP](https://github.com/SETA1609/Link_and_nexus_bundle/blob/main/ROADMAP.md).

---

## How releases map to the ladder

Each release delivers a set of rungs that add **one new capability** to the
stack — and only that one. No library is pulled in before it's needed.

| Release | Phase | Rungs delivered | Incremental cost | 2D game? |
|---------|-------|-----------------|------------------|----------|
| **v0.1.0** — *Foundation* | shipped | event-logger ✅, clear-color ✅ | platform only → +vulkan_stack | 🎯 |
| **v0.2.0** | First pipeline | clear-color-2 + hello-triangle | +Gpu/FrameRing (no new libs) | 🎯 |
| **v0.3.0** | **2D games** | snake, asteroids, breakout, space-invaders, image-viewer | (same libs, new skills) | 🎯 |
| **v0.4.0** | **2D batcher** | breakout (batched), particles (2D) | +batcher helpers | 🎯 |
| **v0.5.0** | Input depth | tetris, replay-demo | — | 🎯 |
| **v0.6.0** | Shaders & sprites | life, shader-playground, **sprite-showcase** | +zClip sprite atlas | 🎯 |
| **v0.7.0** | **Assets** | image-viewer, asset-demo (partial) | +zassets | 🎯 |
| **v0.8.0** | Batcher maturity | space-invaders (polish), typing-game | — | 🎯 |
| **v0.9.0** | Audio | audio-demo | +zaudio | 🎯 |
| **v1.0.0** | Ship-ready assets | asset-demo (stable) | +zassets maturity | 🎯 |
| **v1.1.0** | Editor gate | imgui-demo | +zimgui | 🔧 |
| **v2.0.0** ⏳ | **3D smoke** | hello-cube | +depth | ⏳ |
| **v2.1.0** ⏳ | **3D animation** | gltf-viewer, animation-browser, run-cycle | +zClip skeletal | ⏳ |
| **v2.2.0** ⏳ | Networking | net-echo | +GNS sibling | ⏳ |
| **v2.3.0** | App middleware | app-demo | +zgame.App (optional) | stretch |

Animation rungs A2–A4 (glTF, blending) align with **v2.1.0 ⏳**, not the 2D ship path.

---

## Gates that apply to every release

- **Builds *and* runs in CI** on the supported target matrix (Linux X11 + Wayland, Windows). macOS: **build gates in CI** (container/VM runners); **runtime/display runs verified by contributors** on hardware — see [zGameLib macOS policy](../ROADMAP.md#macos-platform-policy).
- **Decoupling holds** — the relevant `nm` check (platform-drags-no-Vulkan / vulkan-drags-no-windowing) prints nothing.
- **Pinned submodule SHAs** — each release pins `libs/*` to the lib commits it was validated against.

---

## Out of scope / deferred

- Audio-driven or networked toys — not part of the **2D** example ladder (net at v2.2.0 ⏳).
- Textured / lit / multi-object **3D** — `hello-cube` is the 3D entry at **v2.0.0 ⏳** by design.

---

## See also

[`vision.md`](vision.md) · [`mission.md`](mission.md) · [`ladder.md`](ladder.md) — what each app validates + the `nm` checks · [`sprint.md`](sprint.md).