# zig-c-math-stack-adapter

Vector and matrix math for 3D graphics in Zig, backed by
[cglm](https://github.com/recp/cglm) (C, MIT), which is built statically from
pinned source. The public API is Zig types (`Vector3`, `Vector4`, `Matrix4`);
cglm stays underneath.

> Interim name. The library is developed inside its first consumer's
> repository and moves to its own repository once its API settles.

## Conventions

- Right-handed, +Y up; a camera looks down −Z.
- Column vectors: `p' = M · p`. `left.multiply(right)` applies `right` first.
- Column-major storage, `columns[column][row]`: 64 contiguous bytes per
  `Matrix4`, the layout GLSL's `mat4` expects, so a matrix is uploaded as is.
- Projections target Vulkan clip space: depth 0..1, y pointing down.

## Use

```zig
const math_stack = @import("math_stack");
const Matrix4 = math_stack.Matrix4;

const view = try Matrix4.computeLookAt(.{ .x = 3, .y = 2.5, .z = 4 }, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 1, .z = 0 });
const projection = try Matrix4.computeVulkanPerspective(std.math.degreesToRadians(60.0), 16.0 / 9.0, 0.1, 100);
const view_projection = projection.multiply(view);
```

## Errors

cglm never reports failure; given a degenerate input it returns zeros,
infinities, or NaN, which draw nothing and trip no validation layer. The four
wrappers that can meet such an input return `math_stack.Error!Matrix4`:

| Function | Error | When |
| --- | --- | --- |
| `computeInverse` | `SingularMatrix` | determinant zero or not finite, or the inverse overflows |
| `computeRotationAroundAxis` | `InvalidRotation` | zero-length or non-finite axis, non-finite angle |
| `computeLookAt` | `DegenerateLookAt` | `eye == target`, view direction parallel to `up_direction` (sine of the angle ≤ `parallel_sine_tolerance`), zero up direction, non-finite input |
| `computeVulkanPerspective` | `InvalidPerspective` | field of view outside (0, π), aspect ratio ≤ 0, near ≤ 0, far ≤ near, non-finite input |

Everything else (vector arithmetic, `multiply`, `transformPoint`, `transpose`,
`computeTranslation`) cannot fail and returns its value directly. The raw
`cglm` declarations do no checking.

Raw access: `math_stack.cglm` holds the `extern` declarations of the cglm
functions the wrappers call (`src/cglm.zig`).

## Build

```sh
zig build        # the static cglm library
zig build test   # unit tests; no display or GPU needed
```

cglm is compiled with `CGLM_STATIC` and `CGLM_ALL_UNALIGNED`, so cglm's `vec4`
and `mat4` need only `f32` alignment and the `extern struct` types here are
passed to it directly.

## Licence

MIT, see [LICENSE](LICENSE). cglm is MIT, © Recep Aslantas; its licence ships
in its package (`LICENSE` in the cglm source) and must accompany binaries that
include it.
