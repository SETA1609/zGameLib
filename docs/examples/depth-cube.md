# Depth-cube — design

> The first rung of the 3D path. Builds on the `Gpu` + `FrameRing` helpers from
> rung 2 and adds the 3D building blocks: dynamic rendering, `DepthBuffer`,
> `IndexedMesh`, and `PerspectiveCamera`. It is the `hello-cube` row of the
> [ladder](ladder.md)'s validation track. Theory:
> [11](../theory/11-vectors.md),
> [12](../theory/12-matrices.md),
> [13](../theory/13-cameras-and-vulkan-clip-space.md),
> [14](../theory/14-depth-buffers-meshes-and-dynamic-rendering.md).

## What, why, and what for

- **What:** the smallest complete 3D program on zGameLib: a spinning, depth-tested cube drawn with dynamic rendering.
- **Why:** it is the first app that uses every 3D building block together, so it proves they fit and shows the order to call them in.
- **For what:** a template to copy when starting 3D work, a smoke test (`--frames N` under Xvfb with the validation layer), and the running example in theory files 11–14.

## What it does

Opens an 800x600 window and draws a cube with a different colour at each corner,
seen from above and to the side, spinning around the vertical axis. Faces hide
each other correctly because of the depth test. The cube turns a fixed angle per
frame (0.01 radians), not per second, so every run draws the same frames.

## What building it forces into existence

| Piece | Needed for |
|-------|-----------|
| `zgame.Gpu` with `.enable_dynamic_rendering = true` | Vulkan 1.3 device with dynamic rendering switched on |
| `zgame.FrameRing(2)` | two frames in flight: command buffers, sync, acquire/submit/present |
| `zgame.DepthBuffer` | D32 depth image + view, recreated when the swapchain changes size |
| `zgame.IndexedMesh` | 8 vertices + 36 16-bit indices in host-visible buffers |
| `zgame.PerspectiveCamera`, `zgame.Matrix4` | the model-view-projection matrix |
| SPIR-V shaders | `cube.vert.spv` + `cube.frag.spv`, compiled from GLSL by `glslc` at build time |
| **Not used** | VMA (the 3D helpers allocate memory directly), render pass, framebuffers, zClip, audio |

## Frame loop

**Setup**
1. `platform.init(.{})`; `Window.create(.{ .renderer = .vulkan })`.
2. `Gpu.init(window, .{ .enable_dynamic_rendering = true })`.
3. `gpu.createSwapchain(extent)`; `FrameRing(2).init(gpu)`.
4. `DepthBuffer.create(&gpu, swapchain.extent)`.
5. `IndexedMesh.create(&gpu, cube vertex bytes, cube indices)`.
6. Pipeline layout with one 64-byte vertex-stage push constant range (`@sizeOf(Matrix4)`).
7. Graphics pipeline: `VkPipelineRenderingCreateInfo` with the swapchain colour
   format and `DepthBuffer.depth_format`, `render_pass = .null`; depth test and
   write on, compare `.less`; no culling; dynamic viewport and scissor.
8. `PerspectiveCamera` at `(3, 2.5, 4)` looking at the origin, 60° vertical
   field of view, near 0.1, far 100.

**Loop** (until close, or until `--frames N` frames were presented)
9. `platform.pollAllEvents()`; on resize, `swapchain.recreate`.
10. `frame_ring.begin` → wait for the frame's fence, acquire an image.
11. If the swapchain extent changed: `gpu.waitIdle()`, `depth_buffer.recreate`.
12. MVP = `camera.computeViewProjectionMatrix(aspect)` · `computeRotationAroundYAxis(angle)`.
13. Record: colour image to attachment layout, `depth_buffer.recordTransitionToAttachment`,
    `cmdBeginRendering` (colour cleared to dark blue, depth cleared to 1.0),
    viewport + scissor, bind pipeline, `cmdPushConstants(MVP)`,
    `cube_mesh.recordDraw`, `cmdEndRendering`, colour image to present layout.
14. `frame_ring.end(.., .{ .color_attachment_output = true, .early_fragment_tests = true })` → submit + present.

**Teardown** (in `defer` order): `gpu.waitIdle()` → pipeline → pipeline layout →
mesh → depth buffer → frame ring → swapchain → `Gpu` → window → platform.

## How the math reaches the screen

The cube's corners are at ±1 in its own space. Each frame the CPU multiplies one
matrix, projection · view · model, and pushes its 64 bytes; the vertex shader
does `mvp * vec4(position, 1.0)`; Vulkan clips, divides by `w`, and maps to
pixels and a 0..1 depth; the depth test keeps the nearest fragment. File 13 walks
through each step with the formulas, and `tests/camera_test.zig` checks them on
the CPU.

## Done when

- The cube renders with hidden faces hidden, from any rotation angle.
- Resizing works: the swapchain and the depth buffer are recreated.
- `zig build run-depth-cube -- --frames 60` exits 0 under Xvfb + lavapipe with the
  Khronos validation layer loaded and no validation messages.

## Known limitation

The depth buffer is one image shared by both frames in flight, and its per-frame
barrier does not wait for the previous frame's depth writes. See
[file 14, "Known limitation"](../theory/14-depth-buffers-meshes-and-dynamic-rendering.md#known-limitation-one-depth-image-shared-by-frames-in-flight).
Standard validation does not report it; the synchronization validation layer
would.

## Build

```sh
zig build depth-cube                        # needs glslc (Vulkan SDK) on PATH
zig build run-depth-cube                    # needs a display + a Vulkan 1.3 driver
zig build run-depth-cube -- --frames 60     # exit after 60 presented frames
```

## If you want to go raw

- Replace `DepthBuffer` with your own `vkCreateImage` + `vkAllocateMemory` +
  `vkCreateImageView` (it is about 40 lines; every handle is a public field).
- Replace `IndexedMesh` with VMA buffers, as hello-triangle does, or a staging
  upload to device-local memory.
- Replace `PerspectiveCamera` with any math library, as long as the matrix is
  column-major, maps depth to 0..1, and has Vulkan's y-down clip space (or use a
  negative-height viewport).
- Replace dynamic rendering with a `VkRenderPass` + framebuffers; the pipeline
  then takes the render pass instead of `VkPipelineRenderingCreateInfo`.
