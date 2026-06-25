# Animation-browser — design

> Rung A3 of the [animation track](ladder.md#animation-track-zclip). Drives both a sprite clip and a skeletal clip through the unified `zgame.animation` API — the `Cursor`/`Animator` timeline policy that the framework lifts over the raw zClip paths. Proves that a consumer swaps clip type without changing call sites.

## What it does

Loads one sprite-atlas clip and one glTF skeletal clip side-by-side. Each gets its own `zgame.animation.Cursor` (duration, play mode, speed) and is drawn through the single `Animator` interface. Keys switch focus between the two clips, change play mode, and adjust speed — all through the same API regardless of clip type.

## What building it forces into existence

| Lib | Milestone | Pieces used |
| --- | --- | --- |
| platform | v0.6.0 | window + event pump + `now()` |
| vulkan | v0.3.0 | device + VMA + (sprite: atlas texture, blit) + (skeletal: depth, joint palette, skinning) |
| zClip | v0.6.0 / v0.7.0 | both `zclip.sprite` and `zclip.skeletal` under the hood |
| framework | **v0.9.0** | `zgame.animation.Cursor`, `zgame.animation.Animator`, `zgame.animation.PlayMode`, `zgame.animation.ClipType` |
| this repo | — | `shared/animation.zig` + the usual surface/swapchain/gpu/frame |

## Frame loop

**Setup**
1. Platform + Vulkan init; load both assets (atlas sprite clip + glTF skeletal clip).
2. Create `zgame.animation.Animator` wrapping the sprite clip.
3. Create a second `zgame.animation.Animator` wrapping the skeletal clip.
4. Set initial `Cursor` on each (duration, `PlayMode.loop`, speed 1.0).

**Loop** (until close / ESC)
5. Poll events; handle focus-switch key (tab between clips), play-mode keys, speed keys.
6. For each animator: `animator.advance(dt)` — the `Cursor` ticks; internally calls the appropriate raw zClip advance.
7. `animator.currentPose()` — returns a tagged union: for sprite → frame rect; for skeletal → joint palette.
8. Draw each clip in its viewport (split-screen: sprite left, skeletal right).

**Teardown**: standard.

## Done when

- Both clips play simultaneously in split-screen, each controlled individually.
- Switching play mode on either clip (once → loop → ping-pong) works through the same `Cursor` field.
- Speed changes affect each clip independently.
- Pressing tab focuses the other clip; keyboard controls apply to the focused one.
- The call site for advance/draw is identical for both clip types.

## Build

```sh
zig build animation-browser
```

## Framework surface exercised

| `zgame.animation` API | How it's used |
| --------------------- | ------------- |
| `Cursor` | Duration, phase, play mode, speed — one per clip |
| `Animator` | Wrap either clip type; single `advance(dt)` call |
| `Animator.currentPose()` | Returns sprite frame or skeletal palette, same call |
| `PlayMode` | Toggled per-cursor through the unified API |
