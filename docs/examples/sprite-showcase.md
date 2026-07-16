# Sprite-showcase — design

> Rung A1 of the [animation track](ladder.md#animation-track-zclip). Opens a window, loads a sprite-atlas texture, and plays a flipbook animation through the raw `zclip.sprite` path. Proves the sprite-atlas pipeline end-to-end: atlas JSON parse → sprite clip construction → phase-based frame advance → GPU upload → per-frame blit.

## What it does

Initialises the platform + Vulkan stack (same as `clear-color`), loads a sprite atlas (PNG + JSON metadata), constructs a `zclip.sprite.Clip` from it, and every frame advances the clip's phase by `dt` and draws the current frame rect to the swapchain image. The animation loops by default; keys toggle looping mode (`once` / `loop` / `ping-pong`) and adjust playback speed.

## What building it forces into existence

| Lib | Milestone | Pieces used |
| --- | --- | --- |
| platform | v0.6.0 | window + event pump + `now()` for dt |
| vulkan | v0.3.0 (VMA) | device + VMA allocator + combined-image-sampler + staging-buffer upload |
| zClip | **v0.6.0** | `zclip.sprite.Atlas` (JSON parse), `zclip.sprite.Clip` (phase-based frame sequence), `zclip.PlayMode` (once/loop/ping-pong), frame-event callbacks |
| this repo | — | `shared/surface.zig`, `shared/swapchain.zig`, `shared/gpu.zig`, `shared/frame.zig` |

## Frame loop

**Setup**
1. `platform.init(.{})`; `platform.Window.create(.{ .renderer = .vulkan })`.
2. `Gpu.init(window)` → instance + surface + device + VMA allocator.
3. Load atlas: `zclip.sprite.Atlás.parse(bmp_path, json_path)` → array of `Frame`.
4. Create `Clip` with the frame list + default `PlayMode.loop`.
5. Upload atlas texture to GPU (staging buffer → VkImage + `VkImageView` + sampler).

**Loop** (until close / ESC)
6. `platform.pollAllEvents()`; handle `.close`, `.resize`, key presses.
7. Calculate dt: `const dt = platform.now() - last_time`.
8. `clip.advance(dt)` — phase increments; frame index updates; fires frame events on boundaries.
9. Record command buffer: transition → blit current frame rect from atlas → present.
10. On `.resize`: recreate swapchain + update surface dimensions.

**Teardown**: `Gpu.deinit()` → `window.destroy()` → `platform.deinit()`.

## Done when

- Window opens with a sprite animating in place at the correct frame rate.
- `once` mode plays through and stops on the last frame; `loop` mode restarts; `ping-pong` mode reverses.
- Speed multiplier (2×, 0.5×) visibly changes playback rate.
- Resizing doesn't crash; ESC quits cleanly.

## Build

```sh
zig build sprite-showcase
```

## zClip surface exercised

| zClip API | How it's used |
| --------- | ------------- |
| `zclip.sprite.Atlás.parse` | Load sprite metadata from disk |
| `zclip.sprite.Clip` | Frame sequence with phase-based advance |
| `Clip.advance(dt)` | Step animation; fires frame events |
| `PlayMode` | Toggle between once / loop / ping-pong |
| `currentFrame()` | Get the visible frame rect for the current phase |
