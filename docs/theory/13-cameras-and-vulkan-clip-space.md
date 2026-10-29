# 13 — Cameras and Vulkan clip space: from a world point to a pixel

*How the model, view, and projection matrices are built, what Vulkan does with
the result, and why zGameLib's projection has a negative Y and a 0..1 depth
formula. Read [file 11](11-vectors.md) and [file 12](12-matrices.md) first.*

A vertex goes through five coordinate spaces on its way to the screen. You write
the first three steps as matrices; Vulkan's fixed-function hardware does the last
two for you:

```
 object space ──model──▶ world space ──view──▶ view space ──projection──▶ clip space
   (mesh)      (you)                (you)                    (you)          │
                                                                            │ GPU: clip, then
                                                                            │ divide by w
                                                                            ▼
                         framebuffer (pixels + depth) ◀──viewport── normalized device coordinates
                                                         (GPU)
```

In `depth-cube`, the three matrices are multiplied on the CPU into one
**model-view-projection** (MVP) matrix per frame:

```zig
const model_view_projection = camera.computeViewProjectionMatrix(aspect_ratio)
    .multiply(zgame.Matrix4.computeRotationAroundYAxis(rotation_angle_radians));
```

Read right to left (file 12, section 4): rotate the cube (model), then view, then
project. `computeViewProjectionMatrix` is `projection · view` (test: "the
view-projection matrix is the projection times the view").

---

## 1. Model: object space → world space

A mesh is authored around its own origin: the cube's corners are at ±1. The
**model matrix** places that object in the world: rotate it, scale it, move it.
`depth-cube` uses only a rotation, so the cube spins in place at the world
origin. A scene with many objects has one model matrix per object; the view and
projection are shared.

---

## 2. View: world space → view space

The GPU has no concept of a camera. "Moving the camera right" is done by moving
the *whole world* left. The **view matrix** is that move: it re-expresses every
world point in the camera's own axes, with the camera at the origin looking down
**-Z** (the right-handed convention from file 11, section 1). It is the inverse of
the camera's placement in the world (file 12, section 5).

`PerspectiveCamera` describes the camera by where it is and what it looks at:

```zig
pub const PerspectiveCamera = struct {
    position: Vector3,
    target: Vector3,
    up_direction: Vector3 = .{ .x = 0, .y = 1, .z = 0 },
    vertical_field_of_view_radians: f32,
    near_plane_distance: f32,
    far_plane_distance: f32,
    ...
};
```

`computeViewMatrix` builds the camera's three axes with the vector operations
from file 11 (sections 4–6):

```zig
const forward = camera.target.subtract(camera.position).normalize();
const right = forward.computeCrossProduct(camera.up_direction).normalize();
const up = right.computeCrossProduct(forward);
```

1. **forward**: the unit arrow from the camera to its target.
2. **right**: perpendicular to forward and the up hint. `up_direction` does not
   have to be exactly perpendicular to forward; it only says which way is
   roughly "up", and the cross product extracts the true sideways axis.
3. **up**: perpendicular to right and forward. Both inputs are unit length and at
   right angles, so the result is already unit length.

Now each axis becomes a **row** of the matrix. Multiplying a point by a row is a
dot product, which measures the point along that axis (file 11, section 5):

```
| right.x     right.y     right.z    −right·position   |
| up.x        up.y        up.z       −up·position      |
| −forward.x  −forward.y  −forward.z  forward·position |
| 0           0           0           1                |
```

- Row 1 answers "how far right of the camera?", row 2 "how far up?", row 3 "how
  far *behind*?", negated because the camera looks down -Z, so a point in front
  of the camera must end up with a negative z.
- The last column subtracts the camera's own position, measured the same way,
  which puts the camera at the origin (test: "the view matrix puts the camera at
  the origin and the target on the negative Z axis").

The source writes the same matrix one column at a time, which is why it looks
transposed there: `.{ right.x, up.x, -forward.x, 0 }` is the first column.

---

## 3. Projection: view space → clip space

The projection does two jobs: it squeezes the visible region, a truncated
pyramid called the **view frustum**, into a box, and it prepares the
**perspective divide** that makes far things small.

```
          top view (looking down Y)

        far plane  ─────────────────────   z = −far
                    ╲                 ╱
                     ╲   visible     ╱
                      ╲   region    ╱
         near plane    ╲───────────╱       z = −near
                        ╲         ╱
                         ╲  fov  ╱
                          ╲     ╱
                           ╲   ╱
                          camera            z = 0
```

### Perspective comes from `w`

Things look smaller in proportion to their distance. A point at distance `d` in
front of the camera should be drawn at `x / d`, `y / d`. A matrix cannot divide,
but the hardware will: after the vertex shader, the GPU divides x, y, and z by
`w`. So the projection's job is to put the distance into `w`. For a point in
front of the camera, view-space z is negative and the distance is `−z`, hence the
`−1` in the projection's fourth row: `w_clip = −z_view`.

### The matrix

```zig
const focal_length = 1.0 / @tan(camera.vertical_field_of_view_radians / 2.0);
```

```
| focal_length / aspect   0              0                   0                  |
| 0                       −focal_length  0                   0                  |
| 0                       0              far / (near − far)  near·far / (near − far) |
| 0                       0              −1                  0                  |
```

Row by row:

- **x**: `focal_length` scales the view so that the edge of the vertical field
  of view lands exactly at ±1 after the divide. Wider angles give a smaller
  focal length, so more of the world fits. Dividing by `aspect_ratio` (width /
  height) keeps a square a square on a wide window (test: "the aspect ratio
  narrows the horizontal extent of the view").
- **y**: the same scale, **negated**, because of Vulkan's Y convention (next
  section).
- **z**: chosen so depth comes out 0 at the near plane and 1 at the far plane.
- **w**: `−z_view`, the distance, for the perspective divide.

---

## 4. The Vulkan conventions, and why they shape the matrix

Clip space and the coordinates after the divide are defined by Vulkan, not by
us:

> "Perspective division on clip coordinates yields *normalized device
> coordinates*, followed by a *viewport* transformation (see Controlling the
> Viewport) to convert these coordinates into *framebuffer coordinates*."
> — [Vulkan spec, *Coordinate Transformations*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-coord-transform)

Three rules from that chapter decide the projection matrix.

### Rule 1: the clip volume is −w ≤ x ≤ w, −w ≤ y ≤ w, 0 ≤ z ≤ w

> "In clip coordinates, the *view volume* is defined by:
> −w<sub>c</sub> ≤ x<sub>c</sub> ≤ w<sub>c</sub>,
> −w<sub>c</sub> ≤ y<sub>c</sub> ≤ w<sub>c</sub>,
> z<sub>m</sub> ≤ z<sub>c</sub> ≤ w<sub>c</sub> […]
> z<sub>m</sub> is equal to zero."
> — [Vulkan spec, *Primitive Clipping*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-clipping)
> (z<sub>m</sub> is −w<sub>c</sub> only with the `VK_EXT_depth_clip_control`
> option `negativeOneToOne`, which zGameLib does not use)

Primitives outside this volume are clipped (cut off) before rasterization. After
dividing by `w`, the visible region becomes **normalized device coordinates**
(NDC): x and y in −1..1, z in **0..1**.

OpenGL's z range is −1..1; Vulkan's is 0..1. That is why the z row is not the
classic OpenGL projection. Check it at the two planes (n = near, f = far):

```
at z_view = −n:  z_clip = f·(−n)/(n−f) + n·f/(n−f) = 0           w = n   →  depth 0
at z_view = −f:  z_clip = f·(−f)/(n−f) + n·f/(n−f) = f·(n−f)/(n−f) = f
                                                                  w = f   →  depth 1
```

Test: "the projection maps the near plane to depth 0 and the far plane to depth
1".

### Rule 2: NDC y = −1 is the top of the framebuffer

Vulkan's framebuffer origin is the top-left corner and y grows *downwards*, like
most image formats. The viewport is positioned by that corner:

> "`x` and `y` are the viewport's upper left corner (x,y)."
> — [Vulkan spec, *Controlling the Viewport*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-viewport)

 OpenGL's NDC has y pointing up. Our world has y pointing up
too, so the projection negates y: a point above the centre of the view gets a
*negative* NDC y, which Vulkan draws in the top half (test: "a point above the
view centre lands at negative clip-space Y (Vulkan Y points down)").

**Porting from OpenGL or GLM?** A GLM `perspective()` matrix assumes OpenGL's
−1..1 depth and y-up NDC. It needs `GLM_FORCE_DEPTH_ZERO_TO_ONE`, and either a
negated `[1][1]` or a viewport with negative height, which the spec allows:

> "The application can specify a negative term for `height`, which has the
> effect of negating the y coordinate in clip space before performing the
> transform."
> — [Vulkan spec, *Controlling the Viewport*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-viewport)

zGameLib negates y in `computeProjectionMatrix` instead, so the viewport stays
the plain swapchain rectangle and nothing else has to know.

Flipping y mirrors the image, which also swaps which triangles count as
clockwise. `depth-cube` sets `cull_mode = .{}` (no culling) and lets the depth
test decide visibility, so winding does not matter there. A pipeline that culls
back faces must set `front_face` with the flip in mind.

### Rule 3: the viewport maps NDC to pixels

After the divide, the **viewport transform** scales NDC to the framebuffer. The
spec writes it as x<sub>f</sub> = (p<sub>x</sub> / 2) x<sub>d</sub> + o<sub>x</sub>,
with p<sub>x</sub> = `width` and o<sub>x</sub> = `x + width / 2`, and the same for
y; depth is z<sub>f</sub> = p<sub>z</sub> · z<sub>d</sub> + o<sub>z</sub>, with
p<sub>z</sub> = `maxDepth − minDepth` and o<sub>z</sub> = `minDepth`
([*Controlling the Viewport*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-viewport)). Rearranged:

```
x_pixel = viewport.x + (x_ndc + 1) / 2 · viewport.width
y_pixel = viewport.y + (y_ndc + 1) / 2 · viewport.height
depth   = min_depth + z_ndc · (max_depth − min_depth)
```

`depth-cube` sets the viewport to the whole swapchain extent with `min_depth = 0`
and `max_depth = 1`, so the depth written to the depth buffer is exactly NDC z.

---

## 5. How the matrix reaches the shader

The MVP matrix changes every frame and is only 64 bytes, so `depth-cube` sends it
as a **push constant**: a small block of data recorded straight into the command
buffer, with no buffer to allocate or synchronize. How much fits is a device
limit:

> "`maxPushConstantsSize` is the maximum size, in bytes, of the pool of push
> constant memory."
> — [Vulkan spec, *Limits*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#limits-maxPushConstantsSize)

The spec's table of required limits sets its minimum at 128 bytes for Vulkan
1.0–1.3 and 256 for 1.4, so one 64-byte `mat4` always fits.

**On the CPU side**, the pipeline layout declares the range, sized from the Zig
type:

```zig
.p_push_constant_ranges = &[_]vk.PushConstantRange{.{
    .stage_flags = .{ .vertex = true },
    .offset = 0,
    .size = @sizeOf(zgame.Matrix4),
}},
```

and each frame records the bytes:

```zig
vkd.cmdPushConstants(command_buffer, pipeline_layout, .{ .vertex = true }, 0, @sizeOf(zgame.Matrix4), model_view_projection);
```

**On the GPU side**, the vertex shader
([`cube.vert.glsl`](../../examples/depth-cube/shaders/cube.vert.glsl)) declares a
matching block and does the one multiplication:

```glsl
layout(push_constant) uniform PushConstants {
    mat4 model_view_projection;
} push_constants;

void main() {
    gl_Position = push_constants.model_view_projection * vec4(vertex_position, 1.0);
    fragment_color = vertex_color;
}
```

Three things line up here, and all three are deliberate:

1. **Layout.** GLSL stores a `mat4` column-major by default, and `Matrix4` is
   column-major, `extern struct`, 64 contiguous bytes. The bytes are copied as
   they are; no transpose.
2. **Convention.** GLSL's `matrix * vector` treats the vector as a column, the
   same column-vector convention as `Matrix4.multiply` and `transformPoint`.
3. **Homogeneous point.** `vec4(vertex_position, 1.0)` is the `w = 1` point from
   file 12, section 3. `gl_Position` is the clip-space position, and the GPU does the
   clipping, the divide by `w`, and the viewport transform from section 4.

`transformPoint` on the CPU computes exactly what this shader computes on the
GPU, which is why the camera tests can check the whole chain without a GPU:
they call `transformPoint`, divide by `w`, and compare with what Vulkan will do.

---

## 6. Depth precision: why the near plane matters

After the divide, depth is not linear in distance. For a point at distance `d`:

```
depth(d) = f / (f − n) · (1 − n / d)
```

Half of the 0..1 range is used up between `n` and `2n`. With `near = 0.1`, the
first 0.2 units in front of the camera take half the depth values, and
everything beyond shares the rest. That is fine for `depth-cube`
(`near = 0.1`, `far = 100`). For large outdoor scenes, it causes **z-fighting**:
far surfaces that are close together get the same depth value and flicker.

Two rules of thumb follow. Push the near plane out as far as the game allows,
since it matters far more than the far plane. And when that is not enough, the
standard fix is **reverse-Z** (depth 1 at near and 0 at far, with a float depth
buffer), which spreads float precision more evenly. zGameLib does not do
reverse-Z yet; it would be a new projection function, not a change to this one.

---

## 7. Limits of this camera

- **Looking straight up or down.** If `target − position` is parallel to
  `up_direction`, the cross product is zero, `normalize` keeps it zero, and the
  view matrix collapses. A camera that can look straight up needs a different up
  hint, or an orientation stored as a rotation instead of a look-at target.
- **`target == position`.** Forward is the zero vector; same collapse.
- **Perspective only.** No orthographic projection yet.

---

## Bibliography

- **zGameLib**: [`shared/camera.zig`](../../shared/camera.zig),
  [`tests/camera_test.zig`](../../tests/camera_test.zig),
  [`examples/depth-cube/main.zig`](../../examples/depth-cube/main.zig) and its
  [shaders](../../examples/depth-cube/shaders/).
- **Khronos Vulkan specification**: [*Coordinate Transformations*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-coord-transform),
  [*Primitive Clipping*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-clipping),
  [*Controlling the Viewport*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-viewport),
  [*Limits*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#limits-maxPushConstantsSize). Quotes checked against the
  spec source, [KhronosGroup/Vulkan-Docs](https://github.com/KhronosGroup/Vulkan-Docs)
  `chapters/vertexpostproc.adoc` and `chapters/limits.adoc` at commit
  `70304594e73a` (2026-10-29), with AsciiDoc markup rendered as text.
- **OpenGL Shading Language specification**, layout qualifiers (`push_constant`
  in the Vulkan GLSL extension, `column_major` default):
  <https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.html>
