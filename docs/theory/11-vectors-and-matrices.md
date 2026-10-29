# 11 — Vectors and matrices: the math under the 3D path

*What a 3D vector and a 4x4 matrix are, the handful of operations a renderer
needs, and how each one maps to a function in
[`shared/camera.zig`](../../shared/camera.zig).*

Files 01–06 drew flat images: the 2D path hands the GPU positions that are
already in screen terms. A 3D scene is different. Every point lives in a
*world* with its own coordinates, and something has to turn "the corner of a
cube, three metres in front of the camera" into "this pixel". That something is
a chain of matrices. This file is the math; file 12 builds the chain from it
and shows how it meets Vulkan; file 13 covers the depth buffer and the mesh.

> **The tests are the specification.** Every claim in this file has a test in
> [`tests/camera_test.zig`](../../tests/camera_test.zig), which runs under
> `zig build test` with no GPU. When this file and a test disagree, the test
> is right.

---

## 1. A vector is three numbers with a meaning

```zig
pub const Vector3 = struct { x: f32, y: f32, z: f32, ... };
```

`Vector3` is used two ways, and the math is the same for both:

- as a **point**: a position, "where", for example the camera's `position`;
- as a **direction**: an arrow with a length, "which way and how far", for
  example `up_direction`.

zGameLib's world is **right-handed**: hold your right hand with the thumb along
+X (right) and the index finger along +Y (up); your middle finger points along
+Z, *towards you*. So "forward, into the screen" is **-Z**. Keep that in mind;
it explains every minus sign in file 12.

### Subtraction: from one point to another

`target.subtract(position)` is the arrow that starts at `position` and ends at
`target`. The camera uses exactly this to find which way it is looking.

### Length and `normalize`

A vector's length is `sqrt(x² + y² + z²)`. Dividing each component by the length
gives a vector of length 1 pointing the same way, a **unit vector**. Directions
in a camera must be unit vectors, or every later step scales the picture by the
wrong amount.

```zig
/// The same direction with length 1. The zero vector stays zero.
pub fn normalize(vector: Vector3) Vector3
```

The zero vector has no direction, so `normalize` hands it back unchanged rather
than dividing by zero. That keeps the function total, but it means a camera
whose `target` equals its `position` produces a meaningless matrix (see the
limits at the end of file 12).

### Dot product: "how much do two arrows agree?"

```
a · b = a.x·b.x + a.y·b.y + a.z·b.z
```

For unit vectors the dot product is the cosine of the angle between them: 1 when
they point the same way, 0 at right angles, -1 when opposite. For a unit vector
`u` and any vector `v`, `u · v` is the length of `v` measured along `u`, its
**projection** onto `u`. The view matrix (file 12) uses this to ask "how far to
the right of the camera is this point?"

### Cross product: "the arrow at right angles to both"

```
a × b = ( a.y·b.z − a.z·b.y,
          a.z·b.x − a.x·b.z,
          a.x·b.y − a.y·b.x )
```

The result is perpendicular to both inputs, and its direction follows the
right-hand rule: curl your right-hand fingers from `a` towards `b`, and your
thumb points along `a × b`. Order matters: `b × a = −(a × b)`. If `a` and `b`
are parallel, the result is the zero vector.

A worked example the camera relies on: looking forward `(0, 0, −1)` with up
`(0, 1, 0)`:

```
forward × up = ( 0·0 − (−1)·1,  (−1)·0 − 0·0,  0·1 − 0·0 ) = (1, 0, 0)
```

That is +X, the camera's **right**. Two crosses build a whole camera frame out
of one forward direction and a rough "up" hint (file 12).

---

## 2. Why 4x4 matrices for 3D?

A renderer needs three kinds of transform: **rotate**, **scale**, and
**translate** (move). A 3x3 matrix can rotate and scale, but it cannot move a
point: multiplying any 3x3 matrix by `(0, 0, 0)` gives `(0, 0, 0)` back.

The fix is **homogeneous coordinates**: add a fourth component `w`.

- A **point** is `(x, y, z, 1)`. The 1 lets the fourth column of a 4x4 matrix add
  an offset.
- A **direction** would be `(x, y, z, 0)`, so translations do not affect it,
  which is right: moving a camera does not change which way "up" points.

`Matrix4.transformPoint` takes a `Vector3`, treats it as `(x, y, z, 1)`, and
returns all four transformed components, `w` included, because file 12 needs
that `w`:

```zig
/// The point as homogeneous coordinates `(x, y, z, 1)`, transformed.
pub fn transformPoint(matrix: Matrix4, point: Vector3) [4]f32
```

The payoff is that rotate, scale, translate, *and* the perspective projection
are all 4x4 matrices, so any chain of them multiplies down to **one** matrix.
The GPU then does a single matrix-times-vector per vertex, no matter how many
steps the chain had.

---

## 3. The layout: column-major, `columns[column][row]`

```zig
pub const Matrix4 = extern struct {
    /// Column-major: `columns[column][row]`.
    columns: [4][4]f32,
    ...
};
```

Two separate questions, often confused:

1. **Math convention: column vectors.** A point is a column, and the matrix
   sits to its left: `p' = M · p`. Element `M[row][column]` multiplies the
   point's component number `column` into output component number `row`.
2. **Memory layout: column-major.** The 16 floats are stored one column after
   another. In this struct, `columns[2]` is the third column, and
   `columns[2][1]` is row 1 of that column.

Column-major is chosen because it is what GLSL uses for `mat4` by default, so a
`Matrix4` can be copied to the GPU byte for byte with no transposition (file 12,
section 5). `extern struct` fixes the memory layout to C's rules, so the
16 floats are exactly 64 contiguous bytes in that order.

A translation shows the layout clearly: the offset goes in the **last column**,
where it multiplies the point's `w = 1`.

```zig
pub fn computeTranslation(offset: Vector3) Matrix4 {
    var translation = identity;
    translation.columns[3] = .{ offset.x, offset.y, offset.z, 1 };
    return translation;
}
```

```
| 1 0 0 ox |   | x |   | x + ox |
| 0 1 0 oy | · | y | = | y + oy |      test: "a translation moves a point by its offset"
| 0 0 1 oz |   | z |   | z + oz |
| 0 0 0 1  |   | 1 |   |   1    |
```

---

## 4. Multiplication and its order

```zig
/// `left * right`: applying the result applies `right` first, then `left`.
pub fn multiply(left: Matrix4, right: Matrix4) Matrix4
```

Each element of the product is a dot product of a row of `left` with a column of
`right`. In the code that is the inner loop:

```zig
for (0..4) |inner| sum += left.columns[inner][row] * right.columns[column][inner];
```

With column vectors, `(A · B) · p = A · (B · p)`: **B is applied first**, then A.
Read a chain from right to left. Matrix multiplication is *not* commutative:
"rotate, then move" and "move, then rotate" put an object in different places.

The **identity** matrix (ones on the diagonal) is the "do nothing" transform:
`I · M = M · I = M` (test: "multiplying by the identity matrix leaves a matrix
unchanged").

---

## 5. Rotation around the Y axis

```zig
/// Counter-clockwise when looking down the Y axis from above: +X turns towards -Z.
pub fn computeRotationAroundYAxis(angle_radians: f32) Matrix4
```

Rotating around Y leaves `y` alone and turns the X–Z plane:

```
| cos θ  0  sin θ  0 |
|   0    1    0    0 |      x' =  cos θ · x + sin θ · z
| −sin θ 0  cos θ  0 |      z' = −sin θ · x + cos θ · z
|   0    0    0    1 |
```

At θ = 90°, `(1, 0, 0)` becomes `(0, 0, −1)`: +X turns into -Z, "forward" (test:
"rotating 90 degrees around the Y axis turns +X into -Z"). The `depth-cube`
example spins its cube with this matrix by a fixed angle per frame.

In memory, the first column is `(cos θ, 0, −sin θ, 0)`, which is how the source
writes it: one inner array per column, not per row.

---

## 6. What you need for the rest of the 3D path

| Concept | Function | Used for |
| --- | --- | --- |
| point − point | `Vector3.subtract` | the camera's forward direction |
| unit vector | `Vector3.normalize` | keeping the camera's axes length 1 |
| dot product | `Vector3.computeDotProduct` | measuring a point along a camera axis |
| cross product | `Vector3.computeCrossProduct` | building the camera's right and up axes |
| homogeneous point | `Matrix4.transformPoint` | keeping `w` for the perspective divide |
| composition | `Matrix4.multiply` | collapsing model, view, projection into one matrix |
| translation, rotation | `computeTranslation`, `computeRotationAroundYAxis` | placing objects (the model matrix) |

File 12 assembles these into the model-view-projection matrix and follows a
vertex from the world to a pixel through Vulkan's fixed-function stages.

---

## Bibliography

- **zGameLib**: [`shared/camera.zig`](../../shared/camera.zig) (the
  implementation), [`tests/camera_test.zig`](../../tests/camera_test.zig) (the
  executable specification).
- **OpenGL Shading Language specification**, section *Matrix Constructors* and
  the layout qualifiers section on `column_major` (GLSL's default matrix
  layout): <https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.html>
- **Khronos Vulkan specification**, [*Coordinate Transformations*](https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#vertexpostproc-coord-transform)
  (what happens to the 4-component position a vertex shader writes; see file 12).
