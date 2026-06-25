# The validation-app ladder

Each app consumes both adapters via `libs/` (built + linked as artifacts) and pulls a specific adapter milestone into existence. Build them in order — earlier rungs unblock later ones; a rung that *needs* a capability (e.g. texturing) always sits after the rung that *introduces* it. Most rungs introduce **one** new lib capability; a few (`asteroids`, `particles`, `shader-playground`) add no *new* surface — they're there for practice and fast iteration.

| # | App | Develops platform → | Develops vulkan → | Validates |
| --- | --- | --- | --- | --- |
| 0 ✅ | **event-logger** *(warm-up, platform only)* | v0.6.0 | — | window + `Event` mapping; `nm` shows **no `vk*`** — *implemented, builds + runs* |
| 1 ✅ | **clear-color** ← *first both-libs milestone* | v0.6.0 | v0.2.0 | the surface bridge end-to-end (window → surface → swapchain → clear → present) — *implemented, builds + runs; swapchain lives in `../../shared/swapchain.zig`* |
| 2 | **hello-triangle** | (v0.6.0) | v0.3.0 (VMA) | first graphics pipeline + first vertex buffer + (precompiled) shaders — one static triangle |
| 3 | **snake** | (v0.6.0) | v0.3.0 | a real fixed-timestep game loop, timing, action input — first actual *game* (reuses the triangle's pipeline for its quads) |
| 4 | **asteroids** | (v0.6.0) | v0.3.0 | continuous float-physics loop + screen-wrap + transient entities — *no new lib surface; reinforces the loop* |
| 5 | **breakout** | (v0.6.0) | v0.3.0 | instancing / batching throughput through VMA (solid quads) |
| 6 | **space-invaders** | (v0.6.0) | v0.3.0 | **texturing** — VMA `createImage` + sampler + combined-image-sampler + atlas UVs on top of the batch (sprite sheet) |
| 7 | **image-viewer** | v0.6.0 (file_drop) | v0.3.0 | the `file_drop` event + image upload — drop a PNG and it appears (reuses the texturing path) |
| 8 | **tetris** | v0.7.0 (input contexts) | v0.3.0 | pushing `ui_menu` on pause masks gameplay actions |
| 9 | **replay-demo** | v0.7.0 (injection) | v0.3.0 | `injectAction` synthetic injection — record inputs, replay them as a deterministic ghost |
| 10 | **pong** | v0.8.0 (gamepads) | v0.3.0 | multi-gamepad + analog axis modifiers |
| 11 | **2048** | v0.8.0 (paths) | v0.3.0 | filesystem paths — save best score/board to `applicationDataDirectory`; bitmap-font text |
| 12 | **typing-game** | v0.8.0 (text input) | v0.3.0 | `text_input` / IME — type the falling words; bitmap-font text |
| 13 | **life** | (v0.6.0) | v0.4.0 (shaders) | runtime GLSL→SPIR-V (shaderc) + compute + large dynamic buffer churn |
| 14 | **particles** | (v0.6.0) | v0.4.0 | compute-driven particles — an SSBO stepped in a compute shader, drawn instanced |
| 15 | **shader-playground** | (v0.6.0) | v0.4.0 | shaderc **runtime compile + hot-reload** — a fullscreen-quad fragment-shader scratchpad |
| 16 | **hello-cube** ← *tail / 3D smoke* | (v0.6.0) | v0.4.0 (shaders) + depth | perspective MVP + a depth attachment — the stack survives 3D (untextured single cube) |

## Decoupling checks (`nm`)

The architecture rests on each adapter dragging only its own concern. Two apps prove it — treat these as required:

- **event-logger** (`renderer = .none`, platform only) → `nm <bin> | grep -E 'vk\.[A-Za-z]|volk[A-Z]|[Vv]ma[A-Z]|shaderc_[a-z]'` must print **nothing** (platform drags none of *our* Vulkan stack).
- A **headless vulkan** sketch (no window, offscreen render) → `nm <bin> | grep -i 'SDL_\|x11\|wayland'` must print **nothing** (vulkan drags no windowing).

> **Why not a bare `vk*` grep?** SDL3 (the platform backend) ships its own Vulkan
> support — `SDL_Vulkan_CreateSurface` and an internal `vk*` function-pointer
> table — so *any* SDL3-linked binary, even `renderer = .none`, contains bare
> `vk*` symbols. Those belong to the platform backend, not to a Vulkan-stack leak.
> The invariant we actually protect is "importing the platform adapter doesn't
> drag in **our** Vulkan stack," so the check matches what's unique to it:
> vulkan-zig's `vk.`-namespaced Zig wrappers (e.g. `vk.DeviceWrapper…`) plus the
> volk / VMA / shaderc symbols. The bare `vk*` C names from SDL3 are expected and
> ignored. Source of truth: `scripts/ci.sh decoupling`.

## Why hello-triangle sits between clear-color and snake

`clear-color` (rung 1) only does acquire → clear → present — **no pipeline, no geometry**. `snake` (rung 3) is a whole *game*. Dropping the first graphics pipeline, the first vertex buffer, *and* a game loop into one rung would conflate three new things. `hello-triangle` (rung 2) isolates the first of them: stand up a `VkPipeline` + a VMA vertex buffer + a vertex/fragment shader pair (precompiled SPIR-V) and draw **one static triangle**. snake then reuses that pipeline and only adds the loop.

## Why the cube is the tail, not the lead

A textured, lit, spinning cube is a typical engine's *first 3D milestone* — leading with it here would just pre-build a renderer. So the ladder stays **2D (quads + ortho)** through rung 15, exercising the adapters (window, surface, buffers, shaders, input) without turning into an engine.

`hello-cube` (rung 16) is the one deliberate exception, placed **last**: once the 2D ladder is green, a single **untextured** cube is a cheap, honest 3D smoke test. It adds exactly two things over `life` — a **perspective MVP** (a uniform buffer feeding a vertex shader) and a **depth attachment** — and nothing more (no textures, no lighting, no scene). That proves the adapters survive 3D without the repo becoming a renderer.
