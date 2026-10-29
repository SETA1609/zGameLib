# 12 — Matrices: transforms you can multiply

*What a matrix is in linear algebra, why 3D graphics uses 4x4 matrices with an
extra coordinate, how multiplying matrices chains transforms (and why order
matters), real-world situations that work the same way, and where zGameLib's
`Matrix4` ([`shared/camera.zig`](../../shared/camera.zig)) uses each idea. Read
[file 11](11-vectors.md) first.*

File 11 described points and directions. A game constantly *changes* them: a
character turns, a door swings open, the camera follows the player, and every
vertex must end up on screen. Each of those changes is a **transform**, and
matrices are how linear algebra writes transforms down so that a computer, or a
GPU, can apply and combine them cheaply.

> **How to read the examples.** Every number here was computed, and the claims
> about `Matrix4` are checked by
> [`tests/camera_test.zig`](../../tests/camera_test.zig) under `zig build test`.

---

## 1. A matrix is a transform, and its columns say where the axes go

A 3x3 matrix is a grid of numbers that turns one vector into another:

```
| m00 m01 m02 |   | x |   | m00·x + m01·y + m02·z |
| m10 m11 m12 | · | y | = | m10·x + m11·y + m12·z |
| m20 m21 m22 |   | z |   | m20·x + m21·y + m22·z |
```

Read the same product column by column and it says something much easier to
picture:

```
M · (x, y, z) = x · (column 0) + y · (column 1) + z · (column 2)
```

**Column 0 is where the X axis `(1, 0, 0)` lands, column 1 is where Y lands,
column 2 is where Z lands**, and every other vector follows, because it is just
some amount of X plus some amount of Y plus some amount of Z. To build a
transform, decide where the three axes should go and write those three arrows
down as columns.

**Real life.** A floor plan drawn with "1 square = 1 metre" and turned 90° on
the table: you only need to know where the plan's "right" and "up" arrows now
point, and every room follows. A recipe scaled for 3 people instead of 1 is the
same idea with every ingredient multiplied by 3.

### Linear transforms

Transforms built this way are **linear**: they keep straight lines straight,
keep evenly spaced points evenly spaced, and keep the origin where it is.

> "Most common geometric transformations that keep the origin fixed are linear,
> including rotation, scaling, shearing, reflection, and orthogonal projection"
> — [Wikipedia, *Transformation matrix*](https://en.wikipedia.org/wiki/Transformation_matrix)

The ones a game uses most:

| Transform | Where the axes go | Real life |
| --- | --- | --- |
| identity | nowhere: X stays X, Y stays Y, Z stays Z | doing nothing |
| uniform scale by k | each axis k times longer | a photocopier set to 200% |
| rotation | the axes turn together, staying unit length and at right angles | a record on a turntable |
| reflection | one axis flips | a mirror |

The **identity** matrix, ones on the diagonal, is the "do nothing" transform:
`I · M = M · I = M` for any `M` (test: "multiplying by the identity matrix
leaves a matrix unchanged"). `Matrix4.identity` is a constant.

---

## 2. Rotation around the Y axis

```zig
/// Counter-clockwise when looking down the Y axis from above: +X turns towards -Z.
pub fn computeRotationAroundYAxis(angle_radians: f32) Matrix4
```

A turntable spins around the vertical axis: Y stays put and the X–Z plane turns.
Use the column rule from section 1. Turning by an angle θ, the X axis lands on
`(cos θ, 0, −sin θ)` and the Z axis lands on `(sin θ, 0, cos θ)`, and those are
the first and third columns:

```
| cos θ  0  sin θ |
|   0    1    0   |
| −sin θ 0  cos θ |
```

At θ = 90° the X axis lands on `(0, 0, −1)` and Z lands on `(1, 0, 0)`:
"+X turns into −Z, forward" (test: "rotating 90 degrees around the Y axis
turns +X into -Z"). `depth-cube` turns its cube by 0.01 radians more each
frame with this matrix.

**Rotations have a cheap undo.** Their columns are unit length and at right
angles to each other, so the inverse of a rotation is its **transpose**
(rows and columns swapped): R · Rᵀ = I, checked numerically for a 0.7-radian
turn. Section 6 uses this to build the view matrix.

---

## 3. Why 4x4: moving things needs one more coordinate

There is a transform no 3x3 matrix can do: **translation**, plain moving. A 3x3
matrix times `(0, 0, 0)` is always `(0, 0, 0)`, so it can never move the origin.
Translation is not linear in the strict sense.

The standard fix is to go up one dimension:

> "Some transformations that are non-linear on an n-dimensional Euclidean space
> **R**<sup>n</sup> can be represented as linear transformations on the
> n+1-dimensional space **R**<sup>n+1</sup>. These include both affine
> transformations (such as translation) and projective transformations. For
> this reason, 4×4 transformation matrices are widely used in 3D computer
> graphics, as they allow to perform translation, scaling, and rotation of
> objects by repeated matrix multiplication."
> — [Wikipedia, *Transformation matrix*](https://en.wikipedia.org/wiki/Transformation_matrix)

The extra coordinate is called **w**, and this representation is
**homogeneous coordinates**:

- a **point** is `(x, y, z, 1)`;
- a **direction** is `(x, y, z, 0)`.

The 3x3 rotation or scale sits in the top-left corner, and the move goes in the
**fourth column**, where it multiplies `w`:

```
| 1 0 0 ox |   | x |   | x + ox·w |
| 0 1 0 oy | · | y | = | y + oy·w |
| 0 0 1 oz |   | z |   | z + oz·w |
| 0 0 0 1  |   | w |   |    w     |
```

With `w = 1` a point moves by the offset (test: "a translation moves a point by
its offset"). With `w = 0` nothing is added: moving the world by 5 m along X
leaves the direction `(0, 1, 0, 0)` exactly `(0, 1, 0, 0)`. That is file 11's
point/direction rule, now enforced by the arithmetic.

**Real life.** Carry a compass across the room: your position changes, north
does not. Points have `w = 1` and move; directions have `w = 0` and do not.

In zGameLib, `Matrix4.transformPoint` takes a `Vector3`, appends `w = 1`, and
returns all four results, `w` included, because file 13 needs that `w`:

```zig
/// The point as homogeneous coordinates `(x, y, z, 1)`, transformed.
pub fn transformPoint(matrix: Matrix4, point: Vector3) [4]f32
```

### The same trick gives perspective

Homogeneous coordinates do one more job, and it is the one 3D rendering depends
on:

> "Formulas involving homogeneous coordinates are often simpler and more
> symmetric than their Cartesian counterparts. Homogeneous coordinates have a
> range of applications, including computer graphics and 3D computer vision,
> where they allow affine transformations and, in general, projective
> transformations to be easily represented by a matrix."
> — [Wikipedia, *Homogeneous coordinates*](https://en.wikipedia.org/wiki/Homogeneous_coordinates)

**Real life: the pinhole camera.** Light from a point passes through a pinhole
onto the back wall. By similar triangles, a point 2 m to the right and 10 m away
lands 2 / 10 = 0.2 units off-centre for a wall 1 unit behind the hole: things
look smaller in proportion to their distance. Renaissance painters drew
perspective the same way, with strings from the eye through a window.

Dividing by distance is not something a matrix can do, but the GPU divides x, y,
and z by `w` after the vertex shader. So the projection matrix copies the
distance into `w`, and the hardware's divide does the perspective. File 13
builds that matrix.

---

## 4. Multiplying matrices chains transforms, right to left

> "Matrix multiplication was first described by the French mathematician
> Jacques Philippe Marie Binet in 1812, to represent the composition of linear
> maps that are represented by matrices."
> — [Wikipedia, *Matrix multiplication*](https://en.wikipedia.org/wiki/Matrix_multiplication)

"Composition" means doing one transform, then another. With points written as
columns, `(A · B) · p = A · (B · p)`: **B happens first**, then A. Read a chain
from right to left.

```zig
/// `left * right`: applying the result applies `right` first, then `left`.
pub fn multiply(left: Matrix4, right: Matrix4) Matrix4
```

Each entry of the product is a dot product (file 11) of a row of `left` with a
column of `right`; that is the inner loop in the source:

```zig
for (0..4) |inner| sum += left.columns[inner][row] * right.columns[column][inner];
```

### Order matters

Matrix multiplication is **non-commutative**: `A · B` is usually not `B · A`
([Wikipedia, *Matrix multiplication*](https://en.wikipedia.org/wiki/Matrix_multiplication)).
Take the point `(1, 0, 0)`, a 90° turn around Y, and a 5 m move along X:

| Chain | Means | Result |
| --- | --- | --- |
| `move · rotate` | rotate first, then move | `(5, 0, −1)` |
| `rotate · move` | move first, then rotate | `(0, 0, −6)` |

**Real life.** "Turn left, then walk 5 m" and "walk 5 m, then turn left" end in
different places. Socks, then shoes, is not shoes, then socks.

**The usual order for an object** is scale, then rotate, then move:
`model = translation · rotation · scale`. Scaling first keeps the scale along
the object's own axes, and moving last means the object turns around its own
centre, not around the world origin. For example, scaling `(1, 1, 1)` by 2 and
then moving it 3 m forward gives `(2, 2, −1)`.

### One matrix for the whole chain

Because a chain multiplies down to a single 4x4 matrix, the GPU does one
matrix-times-vector per vertex (16 multiplications) no matter how many
transforms were combined. `depth-cube` multiplies projection · view · model on
the CPU once per frame and sends the result to the shader; file 13 follows it
there.

---

## 5. The inverse: undoing a transform

The **inverse** of `M`, written M⁻¹, undoes it: `M⁻¹ · M = I`. Moving 5 m right
is undone by moving 5 m left; a rotation is undone by its transpose (section 2).
The inverse of a chain reverses the order: `(A · B)⁻¹ = B⁻¹ · A⁻¹`. To undo
socks-then-shoes, take off the shoes first.

### The view matrix is an inverse

A camera is placed in the world like any object: rotated to face its target,
then moved to its position. The **view matrix** is the inverse of that
placement. Instead of moving the camera, it moves the whole world the opposite
way, so the camera ends up at the origin looking down −Z.

**Real life.** Sit in a train at a station while the train next to yours starts
moving: for a moment you cannot tell which one is moving. Moving the camera
right and moving the world left look identical, and the GPU only knows how to do
the second.

Using section 2's shortcut, the inverse of the camera's rotation is its
transpose, so the camera's axes become the **rows** of the view matrix, and the
translation is undone with dot products (file 11, section 5).
`computeViewMatrix` writes exactly that. For `depth-cube`'s camera at
`(3, 2.5, 4)`, the view matrix sends the camera's position to `(0, 0, 0)` and
the target, the origin, to `(0, 0, −5.5902)`: straight ahead, 5.5902 m away
(test: "the view matrix puts the camera at the origin and the target on the
negative Z axis").

---

## 6. Storing a matrix: column-major, `columns[column][row]`

```zig
pub const Matrix4 = extern struct {
    /// Column-major: `columns[column][row]`.
    columns: [4][4]f32,
    ...
};
```

Two separate choices, often confused:

1. **Math convention: column vectors.** A point is a column and the matrix sits
   to its left, `p' = M · p`. Everything in these docs and in zGameLib uses
   this.
2. **Memory layout: column-major.** The 16 floats are stored one column after
   another: `columns[3]` is the fourth column, the translation.

zGameLib uses both because GLSL does: a `mat4` is column-major by default and
`matrix * vector` treats the vector as a column. So a `Matrix4` is copied to the
GPU byte for byte, with no transposing (file 13, section 5). `extern struct`
fixes the layout to C's rules: 16 floats, 64 contiguous bytes.

**Beware mixing conventions.** Some math libraries, DirectXMath for example,
use row vectors (`p' = p · M`): every matrix is the transpose of ours and chains
read left to right. Copying a matrix between the two conventions without
transposing makes rotations turn the wrong way and puts the translation in the
wrong place, a classic bug when porting math code.

The source writes matrices one column per inner array, so the rotation from
section 2 appears transposed on screen:

```zig
return .{ .columns = .{
    .{ cosine, 0, -sine, 0 }, // column 0: where X lands
    .{ 0, 1, 0, 0 },          // column 1: where Y lands
    .{ sine, 0, cosine, 0 },  // column 2: where Z lands
    .{ 0, 0, 0, 1 },          // column 3: no translation
} };
```

---

## 7. Where zGameLib uses each idea

| Idea | In zGameLib | Why |
| --- | --- | --- |
| identity | `Matrix4.identity` | the starting point for building transforms; tests |
| translation in column 3 | `Matrix4.computeTranslation` | moving needs the 4th coordinate |
| rotation | `Matrix4.computeRotationAroundYAxis` | `depth-cube` spins its cube |
| homogeneous point (`w = 1`) | `Matrix4.transformPoint` | keeps `w` for the perspective divide; the CPU-side check of what the GPU computes |
| composition | `Matrix4.multiply` | collapses model, view, and projection into one matrix per frame |
| inverse via transpose | `PerspectiveCamera.computeViewMatrix` | the view matrix undoes the camera's placement |
| projective `w` | `PerspectiveCamera.computeProjectionMatrix` | perspective: distance goes into `w` (file 13) |
| column-major storage | `Matrix4.columns`, `extern struct` | matches GLSL's `mat4`, copied to the GPU as is |

Not built yet, and added when a feature needs them: scale matrices, rotation
around other axes or a general axis, a general inverse, and quaternions for
smooth rotation blending in animation.

---

## Further reading

- Gilbert Strang, *Introduction to Linear Algebra*, 6th edition (2023):
  <https://math.mit.edu/~gs/linearalgebra/>. Matrices as linear maps,
  multiplication, inverses, and transposes.
- 3Blue1Brown, linear algebra video series:
  <https://www.3blue1brown.com/topics/linear-algebra>. "Columns are where the
  axes land" and composition as a picture.
- J. Ström, K. Åström, and T. Akenine-Möller, *Immersive Linear Algebra*:
  <https://immersivemath.com/ila/index.html>.
- Joey de Vries, *LearnOpenGL*, "Transformations":
  <https://learnopengl.com/Getting-started/Transformations>. Scale, rotation,
  translation, and homogeneous coordinates for graphics, in OpenGL's
  conventions.

## Bibliography

- **zGameLib**: [`shared/camera.zig`](../../shared/camera.zig),
  [`tests/camera_test.zig`](../../tests/camera_test.zig).
- **Wikipedia**, [*Transformation matrix*](https://en.wikipedia.org/wiki/Transformation_matrix),
  [*Homogeneous coordinates*](https://en.wikipedia.org/wiki/Homogeneous_coordinates),
  and [*Matrix multiplication*](https://en.wikipedia.org/wiki/Matrix_multiplication),
  quoted from the article source as fetched on 2026-10-29, with wiki markup
  rendered as text. Text © Wikipedia contributors, CC BY-SA 4.0.
