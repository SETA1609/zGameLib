# Hello-triangle — design

> Rung 2+ of the [ladder](ladder.md) — adds the first graphics pipeline, vertex
> buffer (via VMA), and draw command. Built on the `Gpu` + `FrameRing` helpers
> from rung 2.

## What it does

Opens a window, sets up the Vulkan device + swapchain via `zgame.Gpu` and
`zgame.FrameRing`, loads embedded SPIR-V shaders, creates a graphics pipeline,
uploads vertex data (positions + per-vertex colours) via VMA, and draws a
single triangle. Quits on window close; recreates swapchain on resize.

## What building it forces into existence

| Piece | Needed for |
|-------|-----------|
| `platform` (v0.6.0) | window + event pump |
| `vulkan_stack` (v0.3.0) | VMA for vertex buffer; full device + swapchain |
| `zgame.Gpu` | Vulkan bring-up (loader → instance → surface → device → queue) |
| `zgame.FrameRing` | frames-in-flight: command buffers + sync + acquire/submit/present |
| `zgame.swapchain` | swapchain + render pass (from `Gpu.createSwapchain`) |
| SPIR-V shaders | `triangle.vert.spv` + `triangle.frag.spv` (embedded at compile time) |
| **Not linked** | zClip, audio, assets, shaderc (shaders are pre-compiled SPIR-V) |

## Pay-for-what-you-use demonstration

This example adds **no new sibling libraries** compared to rung 2. It adds only
code within the application itself: a pipeline, a vertex buffer, and shaders.
No animation lib, no audio lib — those aren't needed.

A developer building a game at this rung has: windowing, input, GPU rendering,
and vertex buffers. That's it. If they don't need animation or audio, they stop
here and ship.

## Frame loop

**Setup**
1. `platform.init(.{})`; `Window.create(.{ .renderer = .vulkan })`.
2. `Gpu.init(window)` → instance + surface + device + VMA allocator + present queue.
3. `gpu.createSwapchain(extent)` → swapchain + render pass.
4. `FrameRing(N).init(gpu)` → per-frame command buffers + sync primitives.
5. Load SPIR-V → `vkCreateShaderModule` (vertex + fragment).
6. Create `VkPipelineLayout` + `VkPipeline` (graphics pipeline: vertex input, assembly, rasterization, blending).
7. Upload vertex data via VMA (`createBuffer` + `mapMemory` + `memcpy` + `unmapMemory`).

**Loop** (until close)
8. `platform.pollAllEvents()`; handle `.close` and `.resize`.
9. `frames.begin(&sc, extent)` → wait for in-flight fence, acquire image.
10. Set dynamic viewport + scissor to window extent.
11. `vkCmdBindPipeline` → `vkCmdBindVertexBuffers` → `vkCmdDraw`.
12. `frames.end(&sc, frame)` → queue submit + present.

**Teardown**: `gpu.waitIdle()` → destroy pipeline/layout/shader-modules/buffer → `FrameRing.deinit` → `Swapchain.deinit` → `Gpu.deinit` → `window.destroy` → `platform.deinit()`.

## Shaders

Shaders are compiled from GLSL to SPIR-V by the build system via `glslc` (Vulkan SDK)
when the `hello-triangle` example is built. The compiled shaders are imported into
the binary via anonymous imports (`@import`). The GLSL sources live alongside the
example in `shaders/` for reference.

To regenerate the shaders manually:

```sh
glslc examples/hello-triangle/shaders/triangle.vert.glsl -o examples/hello-triangle/shaders/triangle.vert.spv
glslc examples/hello-triangle/shaders/triangle.frag.glsl -o examples/hello-triangle/shaders/triangle.frag.spv
```

## Done when

- Window opens with a single triangle in the centre (red/green/blue per vertex).
- Resizing doesn't crash (swapchain recreates; viewport/scissor update).
- Closing the window quits cleanly.
- Zero validation-layer messages.

## Build

```sh
zig build hello-triangle    # needs a display + Vulkan driver + glslc (Vulkan SDK)
```

## If you want to go raw

Replace `Gpu.init` with manual volk → instance → device bring-up.
Replace `FrameRing` with manual command buffers + fences + semaphores.
Replace `createSwapchain` with manual `vkGetSwapchainImagesKHR` + image views.
The shaders remain the same — those are raw `VkShaderModule`s either way.
