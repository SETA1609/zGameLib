# Vision — zig-stack-adapter-examples

> A ladder of tiny, real apps that prove the two adapters — [platform](https://github.com/SETA1609/zig-cpp-platform-stack-adapter) (windowing + input) and [vulkan-stack](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) (the Vulkan stack) — are genuinely **decoupled** yet **interoperate** cleanly through one comptime surface bridge, consumed exactly the way the engine will consume them.

## The north star

A green ladder *is* the proof. The two adapters are decoupled by design — the platform side drags no Vulkan, the vulkan side drags no windowing — and they meet only at one comptime surface bridge. The standalone unit tests inside each lib can't show that the two halves talk to each other, nor that a real consumer can wire them together. **These apps are the only thing that does.** When every rung runs clean (and both `nm` decoupling checks stay empty), the decoupled-adapter architecture is proven end-to-end.

## Three jobs, every app

Each app in the [ladder](ladder.md) does three things at once:

| Job | What it means |
| --- | --- |
| **Integration test** | drives both adapters together through the surface bridge — the one path unit tests can't reach |
| **Usage example** | shows a real consumer wiring the libs the canonical way (import the module, link the artifact) |
| **Milestone driver** | building it *justifies* the next slice of each library — the app is the reason a lib version exists |

## Consumed the way the engine consumes them

The libs live under `libs/` as git submodules, get **built once into static artifacts**, and the apps **link the compiled artifact** — not the source. The heavy C/C++ (SDL3, VMA, glslang) compiles once and is reused as a binary across every app. This is the exact consumption shape the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) engine uses, so what these apps validate is what the engine relies on. Full rationale: [`../../libs/README.md`](../../libs/README.md).

## Toys, not an engine

The apps stay **2D (quads + ortho)** on purpose — enough to exercise window, surface, buffers, shaders, and input without drifting into building a renderer. One **3D smoke test** (`hello-cube`) sits at the *tail*, after the 2D ladder is green, to prove the stack survives perspective + a depth attachment — see [`ladder.md`](ladder.md).

## Non-vision

- A game framework, an ECS, or a scene graph — these are throwaway toys, not a library.
- A renderer or a material system — the apps call the adapters; they don't abstract them.
- A test of either lib *in isolation* — that's each lib's own `validation-apps.md`. This repo tests them **together**.

## See also

[`mission.md`](mission.md) — the concrete commitments · [`ROADMAP.md`](ROADMAP.md) — the release sequence · [`ladder.md`](ladder.md) — the per-app validation ladder.
