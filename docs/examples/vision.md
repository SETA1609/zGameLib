# Vision — modular example ladder

> A ladder of tiny, real apps that prove the modular, pay-for-what-you-use
> architecture: each sibling library is genuinely **decoupled** from the others,
> and you only compile what you need.

## The north star

A green ladder *is* the proof. When every rung runs clean — from rung 0
(platform only, zero GPU symbols) through rung 6 (optional App middleware) —
the modular architecture is proven end-to-end.

Each rung:
- Adds **exactly one new capability** to the stack
- Links **only the libraries needed** for that capability
- Lets the developer stop there and continue with **raw access** to everything beneath

## Three jobs, every example

| Job | What it means |
| --- | --- |
| **Integration test** | drives the sibling libs together through the surface bridge — the path unit tests can't reach |
| **Usage example** | shows a consumer wiring the libs the canonical way (import the module, link the artifact) |
| **Modularity proof** | demonstrates that adding this capability does **not** pull in unrelated libraries |

## Consumed the way a real project consumes them

The libs live under `libs/` as git submodules, get **built once into static
artifacts**, and the examples **link the compiled artifact** — not the source.
The heavy C/C++ (SDL3, VMA, glslang) compiles once and is reused across every
example. This is the exact consumption shape a real game project uses.

## Toys, not an engine

The examples stay **2D (quads + ortho)** on purpose — enough to exercise window,
surface, buffers, shaders, and input without drifting into building a renderer.
One **3D smoke test** (`hello-cube`) sits at the *tail*, after the 2D ladder is
green, to prove the stack survives perspective + a depth attachment.

## Non-vision

- A game framework, an ECS, or a scene graph — these are throwaway toys, not a library.
- A renderer or a material system — the examples call the sibling libs; they don't abstract them.
- A test of any sibling lib *in isolation* — that's each lib's own validation suite.

## See also

[`mission.md`](mission.md) — the concrete commitments · [`ROADMAP.md`](ROADMAP.md) — the release sequence · [`ladder.md`](ladder.md) — the per-rung detail.
