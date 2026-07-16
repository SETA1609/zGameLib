# Animation-demo — design (rung 3)

> The third rung of the [ladder](ladder.md): adds **zClip** (animation) to the
> stack from rung 2. Only the animation lib is new — no audio, no assets.

**Status: stub.** The zClip animation lib is under active development
([roadmap](../../libs/zClip/docs/ROADMAP.md)). When complete, this example will:

1. Load a sprite-atlas texture (PNG + JSON metadata).
2. Construct a `zclip.sprite.Clip` from the atlas frames.
3. Every frame, advance the clip's phase by `dt`.
4. Blit the current frame rect to the swapchain image.

## Pay-for-what-you-use demonstration

| Library | Rung 2 (clear-color-2) | Rung 3 (animation-demo) |
|---------|------------------------|-------------------------|
| platform | ✅ | ✅ |
| vulkan_stack | ✅ | ✅ |
| Gpu/FrameRing | ✅ | ✅ |
| **zClip** | ❌ | **✅ (new)** |
| zaudio | ❌ | ❌ |
| zassets | ❌ | ❌ |

Adding animation does **not** pull in audio, assets, or any other library.

## What it proves

- The zClip sprite-atlas path works end-to-end: JSON parse → clip → advance → GPU blit.
- The sibling library pattern works: zClip adds its own dependency (cgltf for skeletal)
  without affecting the rest of the stack.
- A consumer can add animation to an existing Vulkan app without changing the
  platform, renderer, or build configuration.

## Design

See [`sprite-showcase.md`](sprite-showcase.md) (sub-rung A1) for the raw
`zclip.sprite` path design, and [`animation-browser.md`](animation-browser.md)
(sub-rung A3) for the unified `zgame.animation` abstraction.

## Build

```sh
zig build animation-demo    # requires zClip v0.6.0+
```
