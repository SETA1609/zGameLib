# Asset-demo — design (rung 5, planned)

> The fifth rung of the [ladder](ladder.md): adds **zassets** (asset loading/VFS)
> to the stack. Only the asset lib is new.

**Status: planned.** The `zassets` library does not exist yet. When it does,
this example will demonstrate:

1. Initialise `zassets.VFS` with a mounted game asset pack.
2. Load a textured mesh from the VFS.
3. Render it with Vulkan (reusing the pipeline/VMA setup from rung 2+).

## Pay-for-what-you-use demonstration

| Library | Rung 4 (audio) | Rung 5 (asset-demo) |
|---------|----------------|----------------------|
| platform | ✅ | ✅ |
| vulkan_stack | ❌ (if headless) | ✅ |
| zClip | ❌ | ❌ |
| zaudio | ✅ | ❌ |
| **zassets** | ❌ | **✅ (new)** |

Adding asset loading pulls in the VFS and its decompression/parsing
dependencies but does **not** add animation or audio.

## Build

```sh
zig build asset-demo    # requires zassets v0.1.0+
```
