# The theory of the stack — a beginner's reading path

This folder explains the **theory behind every abstraction** in zGameLib, from the
bottom (raw SDL3 and raw Vulkan) up to the framework's convenience layer (`Gpu`,
`Swapchain`, `FrameRing`, `App`). It assumes **no prior knowledge** of Vulkan,
SDL3, or graphics programming — read it top to bottom and you should come out able
to (a) read the example apps that drive this framework, and (b) write your own.

> **On the quotes.** Throughout these docs, every `>` block is a short, verbatim
> excerpt from an authoritative upstream source — the Khronos Vulkan
> specification, the SDL3 wiki, or a library's own README — with a link to where
> it came from. They are quoted for teaching/commentary; the live sources are
> authoritative. Each file ends with a **Bibliography** listing its sources.
> Excerpts are © their respective owners (The Khronos Group, the SDL
> contributors, AMD/GPUOpen, Google, the vulkan-zig author) under their licenses.

---

## The mental model: layers, raw-first, pay-for-what-you-use

There are a handful of layers between your app code and the hardware. The golden
rule of the whole framework is **raw-first / opt-in**: every layer *re-exports* the
one beneath it, so you can always drop down a level the moment a convenience helper
gets in your way. Nothing is hidden.

The second golden rule is **pay for what you use**: only the modules your
application actually touches are compiled in. A platform-only binary drags no
Vulkan symbols; an app without animation compiles no zClip code.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  YOUR APP  (clear-color, hello-triangle, …)                                │
├──────────────────────────────────────────────────────────────────────────┤
│  zGameLib — the framework (optional convenience layer)                     │
│    App · Gpu · Swapchain · FrameRing · surface bridge                      │
│    …and it RE-EXPORTS everything below, so nothing is hidden               │
├──────────────────────┬──────────────────────┬─────────────────────────────┤
│  platform adapter    │  vulkan_stack adapter │  (planned) audio · animation │
│  (windowing + input) │  (the Vulkan stack)   │   · …more sibling sub-libs   │
│    SDL3 backend       │   vk · volk · VMA …  │     e.g. miniaudio backend    │
├──────────────────────┼──────────────────────┼─────────────────────────────┤
│  SDL3 (C library)     │  Vulkan driver + … │  the relevant native libraries │
└──────────────────────┴──────────────────────┴─────────────────────────────┘
```

> **This diagram is a snapshot, not a fixed shape.** Today the sibling tier has
> **two** libraries — windowing/input and the Vulkan stack — because those
> are what the current rungs need. The tier is designed to *grow*: audio (likely a
> miniaudio-backed sub-lib), animation (zClip), asset loading, and other concerns
> are expected to arrive as their own sibling libraries over time.

The defining property is not the *count* of sub-libraries but their
**independence**: each sibling drags in only its own native dependency and knows
nothing about the others. The windowing lib drags in no Vulkan; the Vulkan lib
drags in no windowing; a future audio lib will drag in neither. Sub-libraries that
*do* need to cooperate meet at **narrow, explicit seams** that pass only raw
primitives — never a shared type. The window↔Vulkan **surface bridge** (file 03)
is the first such seam, and the template for any future one. That decoupling — and
the **pay-for-what-you-use** rule that it enables — are the single most important
design ideas in the project.

zGameLib's own module root states the principle directly:

> "Two tiers, the same opt-in / raw-first principle the libs use: 1.
> **High-level** — `App` (the loop), and the renderer/asset helpers to come. 2.
> **The building blocks, re-exported** — reach `zgame.platform`, `zgame.vk`,
> `zgame.vma`, … directly and drive the raw APIs whenever you outgrow the
> convenience layer. Nothing is hidden; you never get stuck."
> — [`src/root.zig`](../../src/root.zig)

---

## Reading order

Read them in this order — each builds on the last:

| # | File | What you learn |
| --- | --- | --- |
| 00 | **this file** | the layers + the raw-first philosophy + pay-for-what-you-use |
| 01 | [`01-sdl3-and-the-platform-adapter.md`](01-sdl3-and-the-platform-adapter.md) | what SDL3 is; how a window + an event loop + input work; how the platform adapter wraps it |
| 02 | [`02-vulkan-and-the-vulkan-stack.md`](02-vulkan-and-the-vulkan-stack.md) | what Vulkan is; the object hierarchy; what `vk`, `volk`, `VMA`, and `shaderc` each do |
| 03 | [`03-the-surface-bridge.md`](03-the-surface-bridge.md) | the one seam where windowing meets Vulkan, and why no type crosses it |
| 04 | [`04-gpu-bringup.md`](04-gpu-bringup.md) | the `Gpu` helper: loader → instance → surface → device → queue, in order |
| 05 | [`05-the-swapchain.md`](05-the-swapchain.md) | the ring of images you present to the screen; format/present-mode/resize policy |
| 06 | [`06-the-frame-ring.md`](06-the-frame-ring.md) | frames-in-flight; fences vs. semaphores; acquire → render → present |
| 07 | [`07-the-app-harness.md`](07-the-app-harness.md) | the top-level `App` loop, and when *not* to use it |
| 08 | [`08-hot-reload.md`](08-hot-reload.md) | hot reload at the foundation level — rebuild primitives, typed hooks, what Tier 1 does (and doesn't) reload |
| 09 | [`09-hazel-hazelnut-split.md`](09-hazel-hazelnut-split.md) | the Hazel/Hazelnut split — what it means for Tier 1 (keeping zGameLib engine-agnostic) |
| 10 | [`10-web-backend-strategy.md`](10-web-backend-strategy.md) | WebGPU as the web graphics backend — optional sibling module alongside Vulkan |

> **Two companion docs already live next to the code.** The framework ships
> [`shared/gpu.md`](../../shared/gpu.md) and [`shared/frame.md`](../../shared/frame.md)
> — the "why" notes for `Gpu` and `FrameRing`, written against the source. Files
> 04 and 06 here are the *beginner-facing* versions; the `shared/` ones go deeper
> into the exact calls and assume you've read these first.

---

## Why this framework exists (one paragraph)

zGameLib sits on top of sibling adapter libraries that each do one thing. It
re-exports them as a coherent namespace and adds optional convenience helpers.
The framework itself is described by its own README as:

> "A **transparent**, modular game-development middleware in Zig — built on a
> growing family of **independent, decoupled sibling libraries** that do one thing
> each. You pull in exactly what you use; nothing else compiles or ships."
> — [zGameLib README](../../README.md)

"Transparent" and "re-exports so you're never boxed in" *are* the raw-first
philosophy. "You pull in exactly what you use" is the pay-for-what-you-use rule.
Keep both phrases in mind; they explain every design choice you'll meet.

---

## Bibliography

- **zGameLib** — [`README.md`](../../README.md) and [`src/root.zig`](../../src/root.zig)
  (the framework layer documented here).
- **Khronos Vulkan specification** — <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>
- **SDL3 wiki** — <https://wiki.libsdl.org/SDL3/>
- **Nexus-engine hot reload** — upstream [08-hot-reload-nexus-engine.md](../../../docs/theory/08-hot-reload-nexus-engine.md) (Tier 2 consumer)
- **Hazel/Hazelnut split** — upstream [10-hazel-hazelnut-split.md](../../../docs/theory/10-hazel-hazelnut-split.md) and local [09-hazel-hazelnut-split.md](09-hazel-hazelnut-split.md) (Tier 1 perspective)

Quoted excerpts are © their respective owners, used here for teaching/commentary.
