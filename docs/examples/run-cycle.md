# Run-cycle — design

> Rung A4 of the [animation track](ladder.md#animation-track-zclip). A 2D character with multiple animations (idle, walk, run, jump) driven by keyboard input, using crossfade blending and fixed-timestep game-loop integration through `zgame.animation`. Proves the framework's animation API survives a real game loop.

## What it does

A simple character on a ground plane. The character has four sprite-atlas clips — idle (looping), walk (looping), run (looping), jump (once). Keys move the character: left/right to walk/run, space to jump. The `Animator` crossfades between clips on transitions (e.g. idle→walk blends over 0.15 s). A fixed timestep (60 Hz) decouples animation advance from frame rendering.

## What building it forces into existence

| Lib | Milestone | Pieces used |
| --- | --- | --- |
| platform | v0.6.0 | window + event + keyboard bindings + `now()` |
| vulkan | v0.3.0 | device + VMA + atlas texture + blit pipeline |
| zClip | v0.6.0 / v0.9.0 | sprite clips under the hood |
| framework | **v0.9.0** | `Cursor`/`Animator` + crossfade + fixed-timestep helpers |
| this repo | — | `shared/animation.zig` + usual surface/swapchain/gpu/frame |

## Frame loop

**Setup**
1. Platform + Vulkan init; load four sprite clips: idle, walk, run, jump.
2. Create one `Animator` for the character.
3. Set initial state: `Animator.play(idle_clip, .loop)`.

**Loop** (until close / ESC)
4. `platform.pollAllEvents()`; read keyboard: left/right → direction + speed; space → jump.
5. Determine desired clip based on state:

   ```
   grounded + idle   → idle
   grounded + moving → walk or run (speed threshold)
   airborne          → jump (plays once, then back to idle)
   ```

6. If desired clip ≠ current: `animator.crossfade(desired, duration=0.15)`.
7. Fixed-timestep accumulator: add dt; while accumulator ≥ 1/60: `animator.advance(fixed_dt)`; accumulator -= 1/60.
8. Update character position based on current animation root motion.
9. Record command buffer: draw character at position with current sprite frame → present.
10. On `.resize`: recreate swapchain.

**Teardown**: standard.

## Done when

- Character displays idle animation while standing still.
- Walking/running blends smoothly from idle (no snap).
- Jump starts immediately, plays once, blends back to idle on landing.
- Crossfade is visibly smooth (no pop between clips).
- Animation looks correct at 30 fps and 60 fps (fixed timestep decouples from display rate).
- Resize doesn't crash; ESC quits.

## Build

```sh
zig build run-cycle
```

## Framework surface exercised

| `zgame.animation` API | How it's used |
| --------------------- | ------------- |
| `Animator.play(clip, mode)` | Transition to a new clip immediately |
| `Animator.crossfade(clip, duration)` | Smooth blend between clips |
| `Cursor.speed` | Adjust playback rate per state |
| Fixed-timestep advance | `animator.advance(1/60)` decoupled from frame dt |
