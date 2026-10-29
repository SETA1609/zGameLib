# 13 — Depth buffers, indexed meshes, and dynamic rendering

*The three GPU pieces of the 3D path: the depth buffer that sorts surfaces per
pixel, the indexed mesh that shares vertices between triangles, and the
render-pass-free way of drawing that both plug into. Read
[file 12](12-cameras-and-vulkan-clip-space.md) first.*

File 12 ended with every vertex at a pixel position plus a **depth**, a number
from 0 (near plane) to 1 (far plane). This file is about what the GPU does with
that depth, how the vertices get to the GPU, and how a frame is recorded without
a render pass.

| Piece | Source | Test |
| --- | --- | --- |
| `Gpu.Options.enable_dynamic_rendering` | [`shared/gpu.zig`](../../shared/gpu.zig) | "Gpu enables dynamic rendering when asked", "Gpu leaves dynamic rendering off by default" |
| `Gpu.findMemoryTypeIndex` | [`shared/gpu.zig`](../../shared/gpu.zig) | used by every test below |
| `DepthBuffer` | [`shared/depth.zig`](../../shared/depth.zig) | "DepthBuffer creates a depth image and view sized to the extent", "DepthBuffer.recreate resizes to the new extent" |
| `IndexedMesh` | [`shared/mesh.zig`](../../shared/mesh.zig) | "IndexedMesh uploads vertices and indices", "IndexedMesh rejects an empty index list" |

The GPU tests are in [`tests/gpu_test.zig`](../../tests/gpu_test.zig) and run
under `zig build test-tdd` (they need a display and a Vulkan driver; lavapipe
under Xvfb works).

---

## 1. Why a depth buffer?

Draw a cube's six faces in any order and, without help, whichever face is drawn
*last* covers the others, even if it is at the back. The 2D path never meets
this problem because sprites are drawn back to front on purpose. In 3D, sorting
whole triangles does not work in general (triangles can intersect, or overlap in
a cycle), so the GPU sorts **per pixel** instead.

A **depth buffer** is an image the size of the framebuffer that stores one depth
value per pixel: the depth of the nearest surface drawn there so far. For every
fragment (a candidate pixel from a triangle) the GPU compares the fragment's
depth with the stored one:

> "z<sub>f</sub> and z<sub>a</sub> are used as the *reference* and *test*
> values, respectively, in the operation specified by the `VkCompareOp`.
> If the comparison evaluates to false, the coverage for the sample is set to
> `0`."
> — [Vulkan spec, *Depth Comparison*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#fragops-depth-comparison)

z<sub>f</sub> is the fragment's depth from the viewport transform (file 12,
section 4); z<sub>a</sub> is the value already in the depth attachment. "Coverage
set to 0" means the fragment is thrown away. `depth-cube` uses `.less`:

> "`VK_COMPARE_OP_LESS` specifies that the comparison evaluates
> *reference* < *test*."
> — [Vulkan spec, `VkCompareOp`](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#VkCompareOp)

So a fragment survives only if it is **nearer** than what is there. And when it
survives, it becomes the new nearest:

> "If depth writes are enabled […] and the comparison evaluated to true, the
> depth attachment value z<sub>a</sub> is set to the sample's depth value
> z<sub>f</sub>."
> — [Vulkan spec, *Depth Attachment Writes*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#fragops-depth-write)

That is the whole algorithm. Three settings make it work, and `depth-cube` sets
all three:

```zig
// pipeline: test and write, keep the nearer fragment
.depth_test_enable = .true,
.depth_write_enable = .true,
.depth_compare_op = .less,

// each frame: start from "everything is infinitely far"
.load_op = .clear,
.clear_value = .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0 } },
```

Clearing to 1.0, the far plane, means the first fragment drawn on any pixel
always passes. Depth 1.0 is the largest value the projection produces (file 12,
section 4), so nothing visible is ever rejected by the clear value.

### What `DepthBuffer` owns

```zig
pub const DepthBuffer = struct {
    pub const depth_format: vk.Format = .d32_sfloat;
    vkd: vk.DeviceWrapper,
    device: vk.Device,
    image: vk.Image = .null,
    memory: vk.DeviceMemory = .null,
    view: vk.ImageView = .null,
    format: vk.Format = depth_format,
    extent: vk.Extent2D,
    ...
};
```

- **Format `D32_SFLOAT`**: one 32-bit float per pixel, no stencil. Float depth
  keeps more precision far from the camera than 16- or 24-bit fixed point (file
  12, section 6 explains why that matters). It is **not guaranteed** everywhere.
  The spec's required format support says the depth/stencil attachment feature
  "must be supported for at least one of `VK_FORMAT_X8_D24_UNORM_PACK32` and
  `VK_FORMAT_D32_SFLOAT`"
  ([*Required Format Support*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#features-required-format-support)).
  Desktop drivers and lavapipe support `D32_SFLOAT`; `DepthBuffer` has no
  fallback yet, so on a device without it image creation fails. Querying
  `vkGetPhysicalDeviceFormatProperties` and falling back to `X8_D24` is on the
  list in section 4.
- **Image + memory + view**: the three objects every Vulkan image needs: the
  image (its shape and usage, here `depth_stencil_attachment`), the memory that
  backs it (device-local, fastest for the GPU, from `findMemoryTypeIndex`), and
  the view (how a pipeline sees it, here the depth aspect of mip 0, layer 0).
- **Sized to the swapchain**. A depth buffer must match the colour image it is
  drawn with. When the window resizes, the swapchain is recreated and the depth
  buffer must follow: `recreate(gpu, new_extent)` destroys and rebuilds the
  three objects. `depth-cube` checks the extents every frame and calls it after
  `gpu.waitIdle()`, because the old image may still be in use by frames in
  flight.
- **Transparent**: every handle is a public field, like the rest of zGameLib.

### Layout transition, every frame

A Vulkan image has a **layout** (file 04, section 5), and a depth attachment
must be in `DEPTH_ATTACHMENT_OPTIMAL` while it is rendered to.
`recordTransitionToAttachment` records that transition with a pipeline barrier.
It transitions from `UNDEFINED`, which tells the driver the old contents may be
discarded. That is correct because the depth is cleared at the start of every
frame anyway, and it saves the GPU from preserving data nobody reads.

> **Known limitation: one depth image shared by frames in flight.** The barrier's
> source stage is `TOP_OF_PIPE` with no source access. The spec says what that
> means as a source:
>
> > "`VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT` is equivalent to
> > `VK_PIPELINE_STAGE_ALL_COMMANDS_BIT` with `VkAccessFlags` set to `0` when
> > specified in the second synchronization scope, but specifies no stage of
> > execution when specified in the first scope."
> > — [Vulkan spec, *Pipeline Stages*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#synchronization-pipeline-stages)
>
> So the barrier does not wait for the *previous* frame's depth writes.
> `depth-cube` runs 2 frames in flight with one depth image, so frame N+1's clear
> may race frame N's depth tests on the GPU: a write-after-write hazard. Standard
> validation does not report it, and lavapipe happens to run frames in order;
> the synchronization validation layer would flag it. The fix is a source stage
> of `EARLY_FRAGMENT_TESTS | LATE_FRAGMENT_TESTS` with source access
> `DEPTH_STENCIL_ATTACHMENT_WRITE`, or one depth image per frame in flight.

---

## 2. Indexed meshes: sharing vertices

A cube has 8 corners but 12 triangles (2 per face × 6 faces), so 36 triangle
corners. Without indices, every triangle lists its three vertices in full, and
each corner is stored 4 or 5 times. With indices, the 8 unique vertices are
stored once in a **vertex buffer**, and each triangle corner is a small integer
pointing into it, stored in an **index buffer**:

```zig
const cube_vertices = [_]CubeVertex{ ... }; // 8 × (position + colour) = 8 × 24 bytes
const cube_indices = [_]u16{                // 36 × 2 bytes
    0, 1, 2, 2, 3, 0, // back (-Z)
    ...
};
```

| | Vertex data | Index data | Total |
| --- | --- | --- | --- |
| Not indexed: 36 full vertices | 36 × 24 = 864 bytes | none | 864 bytes |
| Indexed: 8 vertices + 36 indices | 8 × 24 = 192 bytes | 36 × 2 = 72 bytes | 264 bytes |

The GPU also caches recently transformed vertices, so a shared vertex is often
run through the vertex shader once instead of once per triangle that uses it.

**The catch: a vertex is everything about it.** Sharing works only if a corner
has the same attributes in every triangle that uses it. `depth-cube`'s cube has
one colour per corner, so its 8 corners really are 8 vertices. A cube with flat
per-face shading needs a different normal on each face, so each corner becomes 3
distinct vertices: 24 vertices, still with 36 indices.

### What `IndexedMesh` owns

```zig
pub const IndexedMesh = struct {
    vertex_buffer: vk.Buffer = .null,
    vertex_memory: vk.DeviceMemory = .null,
    index_buffer: vk.Buffer = .null,
    index_memory: vk.DeviceMemory = .null,
    index_count: u32 = 0,
    pub const index_type: vk.IndexType = .uint16;
    ...
};
```

- **Vertex bytes are opaque.** `IndexedMesh.create` takes `[]const u8`. It does
  not know or care what a vertex is; the pipeline's vertex input state defines
  that (`depth-cube`: position at location 0, colour at location 1, stride
  `@sizeOf(CubeVertex)`). One mesh type serves every vertex layout.
- **16-bit indices** address up to 65 536 vertices per mesh, plenty for now, at
  half the size of 32-bit indices.
- **Empty lists are rejected** (`error.EmptyVertexList`, `error.EmptyIndexList`)
  instead of producing a draw that silently draws nothing.
- **Host-visible, host-coherent memory.** The CPU writes the bytes directly with
  `mapMemory` + `memcpy`; no staging buffer, no copy command, no extra
  synchronization. GPU reads from such memory can be slower than from
  device-local memory, which does not matter for a 264-byte cube. A staging
  upload into device-local memory is the later step for big meshes.

`recordDraw` binds both buffers and draws every index once:

```zig
self.vkd.cmdBindVertexBuffers(command_buffer, 0, &.{self.vertex_buffer}, &vertex_buffer_offsets);
self.vkd.cmdBindIndexBuffer(command_buffer, self.index_buffer, 0, index_type);
self.vkd.cmdDrawIndexed(command_buffer, self.index_count, 1, 0, 0, 0);
```

### Picking memory: `findMemoryTypeIndex`

Every Vulkan buffer and image reports which **memory types** it can live in, as
a bit mask (`memory_type_bits`). Each memory type has property flags:
device-local, host-visible, host-coherent, and so on. `findMemoryTypeIndex`
returns the first type that is both allowed by the mask and has every required
flag, or `error.NoSuitableMemoryType`. `DepthBuffer` asks for `device_local`;
`IndexedMesh` asks for `host_visible` and `host_coherent`. The hello-triangle
example lets VMA make this choice; the 3D path does it by hand to keep the
helpers small and the choice visible.

---

## 3. Dynamic rendering: drawing without a render pass

Vulkan requires draws to happen inside a *render pass instance*:

> "Draw commands must be recorded within a *render pass instance*. Each render
> pass instance defines a set of image resources, referred to as *attachments*,
> used during rendering."
> — [Vulkan spec, *Render Pass*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#renderpass)

The `hello-triangle` example uses the original way to make one: a
`VkRenderPass` object plus a `VkFramebuffer` per swapchain image, created up
front. That works, but
every change of attachments means new objects, and the pipeline is tied to a
render pass. Vulkan 1.3 adds **dynamic rendering**: the attachments are named
directly in the command buffer.

> "After beginning a render pass instance, the command buffer is ready to record
> draw commands."
> — [Vulkan spec, `vkCmdBeginRendering`](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vkCmdBeginRendering)

### Step 1: enable it on the device

Dynamic rendering is core in Vulkan 1.3, but it is a *feature* that must be
switched on when the device is created. `Gpu` does that only when asked, so the
2D path's devices are exactly as before:

```zig
var vulkan_1_3_features = vk.PhysicalDeviceVulkan13Features{ .dynamic_rendering = .true };
const device = try vki.createDevice(pdev, &.{
    .p_next = if (options.enable_dynamic_rendering) &vulkan_1_3_features else null,
    ...
});
```

`p_next` is Vulkan's extension chain: a pointer to more structures that extend
the create info. `Gpu.dynamic_rendering_enabled` records the choice so tests
and apps can check it.

### Step 2: tell the pipeline the attachment formats

Without a render pass, the pipeline still needs to know what it will draw into.
`VkPipelineRenderingCreateInfo`, chained into the pipeline's `p_next`, carries
the formats, and `render_pass` is null:

```zig
const rendering_create_info = vk.PipelineRenderingCreateInfo{
    .color_attachment_count = color_attachment_formats.len,
    .p_color_attachment_formats = &color_attachment_formats, // the swapchain format
    .depth_attachment_format = depth_format,                  // DepthBuffer.depth_format
    ...
};
```

### Step 3: begin and end rendering in the command buffer

Each frame, `depth-cube` names the colour attachment (this frame's swapchain
image view) and the depth attachment (`depth_buffer.view`), each with its load
and store operations, then draws between `cmdBeginRendering` and
`cmdEndRendering`:

| Attachment | `load_op` | `store_op` | Why |
| --- | --- | --- | --- |
| colour (swapchain image) | `clear` | `store` | the result is presented |
| depth (`DepthBuffer`) | `clear` to 1.0 | `dont_care` | depth is only needed during the frame |

`store_op = dont_care` on depth lets tile-based GPUs (most phones) skip writing
the depth buffer back to memory at all.

### The whole frame

```
transitionImage(swapchain image: UNDEFINED → COLOR_ATTACHMENT_OPTIMAL)
depth_buffer.recordTransitionToAttachment()      UNDEFINED → DEPTH_ATTACHMENT_OPTIMAL
cmdBeginRendering(colour + depth attachments, both cleared)
    cmdSetViewport / cmdSetScissor                whole swapchain, depth 0..1
    cmdBindPipeline
    cmdPushConstants(model-view-projection)       file 12, section 5
    cube_mesh.recordDraw()                        bind vertex + index buffers, draw 36 indices
cmdEndRendering
transitionImage(swapchain image: COLOR_ATTACHMENT_OPTIMAL → PRESENT_SRC_KHR)
```

`FrameRing.end` is passed `color_attachment_output` and `early_fragment_tests`
as the stages that wait for the swapchain image to be acquired, because both
the colour and the depth work start at those stages.

---

## 4. Where the 3D path goes next

None of these are built yet; each would be its own issue.

- Fix the depth barrier's source scope (section 1).
- Pick the depth format from what the device supports, with an `X8_D24`
  fallback (section 1).
- Back-face culling, with `front_face` chosen for the flipped Y (file 12,
  section 4).
- Staging uploads into device-local memory for large meshes.
- Reverse-Z for large scenes (file 12, section 6).
- An orthographic projection, and a camera stored as position + rotation for
  free-look.

---

## Bibliography

- **zGameLib**: [`shared/depth.zig`](../../shared/depth.zig),
  [`shared/mesh.zig`](../../shared/mesh.zig),
  [`shared/gpu.zig`](../../shared/gpu.zig),
  [`tests/gpu_test.zig`](../../tests/gpu_test.zig),
  [`examples/depth-cube/main.zig`](../../examples/depth-cube/main.zig).
- **Khronos Vulkan specification**:
  [*Depth Comparison*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#fragops-depth-comparison),
  [*Depth Attachment Writes*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#fragops-depth-write),
  [`VkCompareOp`](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#VkCompareOp),
  [*Required Format Support*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#features-required-format-support),
  [*Pipeline Stages*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#synchronization-pipeline-stages),
  [*Render Pass*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#renderpass),
  [`vkCmdBeginRendering`](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vkCmdBeginRendering).
  Quotes checked against the spec source,
  [KhronosGroup/Vulkan-Docs](https://github.com/KhronosGroup/Vulkan-Docs)
  `chapters/fragops.adoc`, `samplers.adoc`, `synchronization.adoc`,
  `renderpass.adoc`, and `formats.adoc` at commit `70304594e73a` (2026-10-29), with AsciiDoc markup
  rendered as text.

Quoted excerpts are © The Khronos Group, used here for teaching/commentary;
consult the live specification for authoritative wording.
