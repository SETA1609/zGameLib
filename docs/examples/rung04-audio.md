# Audio-demo — design (rung 4, planned)

> The fourth rung of the [ladder](ladder.md): adds **zaudio** (audio playback) to
> the stack. Only the audio lib is new — no animation, no assets, not even Vulkan
> if the demo is headless.

**Status: planned.** The `zaudio` library does not exist yet. When it does,
this example will demonstrate:

1. Initialise `zaudio` with the miniaudio backend.
2. Load a WAV file.
3. Play it back with start/stop/volume controls.
4. (Optionally) show a minimal window with playback status.

## Pay-for-what-you-use demonstration

| Library | Rung 3 (animation) | Rung 4 (audio-demo) |
|---------|--------------------|----------------------|
| platform | ✅ | ✅ |
| vulkan_stack | ✅ | ❌ (if headless) |
| zClip | ✅ | ❌ |
| **zaudio** | ❌ | **✅ (new)** |
| zassets | ❌ | ❌ |

Key demonstration: an audio-only tool compiles **no GPU code**. The `zaudio`
library drags in miniaudio (its native backend) and nothing else. No Vulkan
device, no VMA, no shaderc, no zClip.

## What it proves

- Audio is an independent concern, decoupled from rendering.
- The sibling library pattern works for non-GPU libraries too.
- A tool that only plays sound (a music player, a sound test bench) compiles
  in seconds, not minutes.

## Build

```sh
zig build audio-demo    # requires zaudio v0.1.0+
```
