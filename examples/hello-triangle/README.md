# hello-triangle — rung 2+ (first pipeline + VMA)

A coloured triangle drawn via Vulkan, using the `zgame.Gpu` and `zgame.FrameRing`
helpers. Demonstrates:
- VMA vertex buffer allocation + upload
- Graphics pipeline creation (embedded SPIR-V)
- Dynamic viewport/scissor
- `FrameRing`-managed acquire/render/present

## Libraries compiled

| Library | Used? |
|---------|-------|
| `platform` | ✅ window + event pump |
| `vulkan_stack` | ✅ VMA + Vulkan device |
| `zClip` | ❌ not linked |
| `zaudio` | ❌ not linked (doesn't exist yet) |
| `zassets` | ❌ not linked (doesn't exist yet) |

## Build

```sh
zig build hello-triangle
```

Requires a display + Vulkan driver. Exit with ESC or window-close.
