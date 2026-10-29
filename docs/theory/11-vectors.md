# 11 — Vectors: positions, directions, and the products that compare them

*What a vector is in linear algebra, the operations a 3D renderer and a game
need, real-world situations that behave the same way, and where each one is
used in zGameLib's 3D path ([`shared/camera.zig`](../../shared/camera.zig)).
File 12 does the same for matrices.*

Files 01–06 drew flat images. A 3D scene is different: every object has a
position in a *world*, every camera looks in a *direction*, and the renderer has
to turn "the corner of a cube, a few metres in front of the camera" into "this
pixel". The math for that is **linear algebra**, the branch of mathematics about
vectors and the maps between them that keep straight lines straight. A game uses
a small, very practical slice of it: vectors (this file), matrices (file 12),
and one projective trick for perspective (files 12 and 13).

> **How to read the examples.** Every number in this file was computed, not
> worked out by hand, and the claims about `camera.zig` are checked by
> [`tests/camera_test.zig`](../../tests/camera_test.zig) (`zig build test`,
> no GPU needed). When this file and a test disagree, the test is right.

---

## 1. What a vector is

A vector in 3D is three numbers, one per axis:

```zig
pub const Vector3 = struct { x: f32, y: f32, z: f32, ... };
```

Linear algebra gives two pictures of the same three numbers, and both are
useful:

- **an arrow**: a direction and a length, drawn anywhere. "Walk 3 blocks east
  and 4 blocks north" is an arrow; it does not say where you start.
- **a list of coordinates**: how far to go along each axis. With east as +X and
  north as −Z, that walk is `(3, 0, −4)`.

The numbers only mean something once the axes are agreed. "3 blocks east" is
useless to someone who does not know which way east is. In linear-algebra terms,
coordinates are relative to a **basis**, a choice of axes. Changing basis, for
example from world axes to the camera's own right/up/forward axes, is exactly
what the view matrix does (file 13).

### zGameLib's axes

zGameLib's world is **right-handed** with **+Y up**. Point your right thumb along
+X (right) and your index finger along +Y (up); your middle finger points along
+Z, *towards you*. So "forward", into the screen, is **−Z**.

A real-world check: a normal (right-handed) screw or bottle cap. Turn it from +X
towards +Y, counter-clockwise as seen from the front, and it moves along +Z,
towards you. Every minus sign around "forward" in files 12 and 13 comes from
this convention. It is the classic OpenGL camera convention too. Vulkan itself
defines no view space at all, only clip space (file 13), so the choice is ours.

### Points and directions are different things

`Vector3` stores both, but they behave differently, and mixing them up is a
classic bug:

| | Real-life version | In zGameLib |
| --- | --- | --- |
| **point**: a place | a street address | `PerspectiveCamera.position`, `target`, a mesh's vertex positions |
| **direction**: a displacement | "100 m north from wherever you are" | `up_direction`, the camera's forward/right/up axes |

The rules match common sense:

- point − point = direction (address B minus address A = how to walk from A to
  B);
- point + direction = point (start at an address, walk, arrive at an address);
- direction + direction = direction (walk, then walk again);
- point + point is meaningless (adding two addresses gives nothing useful).

Mathematicians call this structure an *affine space*. File 12 shows how a 4th
coordinate, `w`, makes matrices respect it: points get `w = 1`, directions
`w = 0`, and moving the world moves points but not directions.

---

## 2. Adding, subtracting, and scaling

Component by component:

```
a + b = (a.x + b.x, a.y + b.y, a.z + b.z)
a − b = (a.x − b.x, a.y − b.y, a.z − b.z)
k · a = (k·a.x, k·a.y, k·a.z)
```

**Real life.** A boat's velocity over the ground is its velocity through the
water plus the current: vector addition. Walking 3 blocks east then 4 blocks
north adds up to one arrow `(3, 0, −4)`. Distance travelled is velocity times
time: scaling.

**In a game.** Movement is `position + velocity · time_step`; with a fixed 30 Hz
simulation the time step is 1/30 s.

**In zGameLib.** `Vector3.subtract` is the one the camera needs:
`target.subtract(position)` is the arrow from the camera to what it looks at.
`Vector3` has no `add` or `scale` yet; they come with the first code that needs
them, in the same API-then-tests order as everything else.

---

## 3. Length and distance

The length (also *magnitude* or *norm*) is Pythagoras in 3D:

```
|a| = sqrt(a.x² + a.y² + a.z²)
```

The walk `(3, 0, −4)` has length 5: you end up 5 blocks from where you started,
the 3-4-5 right triangle. The **distance** between two points is the length of
their difference.

**In a game.** "Is the player within 10 m of the trigger?" is
`|player − trigger| < 10`. A common optimisation is to compare squared lengths,
`(player − trigger) · (player − trigger) < 100`, which gives the same answer
without a square root. Section 5 explains why `a · a` is the squared length.

---

## 4. Unit vectors and `normalize`

A **unit vector** has length 1. It is a pure direction, like a compass heading
with the distance thrown away. Dividing a vector by its length gives the unit
vector pointing the same way:

```zig
/// The same direction with length 1. The zero vector stays zero.
pub fn normalize(vector: Vector3) Vector3
```

**Why the camera needs it.** The camera's axes must be unit length, or every
point measured along them comes out scaled by the wrong amount and the picture
stretches. `depth-cube`'s camera sits at `(3, 2.5, 4)` and looks at the origin;
the arrow between them is 5.5902 long, and normalizing gives the forward
direction `(−0.5367, −0.4472, −0.7155)`.

**The zero vector has no direction.** `normalize` returns it unchanged instead of
dividing by zero, so the function never produces NaN. The cost: a camera whose
`target` equals its `position` silently gets a meaningless matrix (file 13,
section 7).

---

## 5. The dot product: how much two directions agree

> "Algebraically, the dot product is the sum of the products of the
> corresponding entries of the two sequences of numbers. Geometrically, the
> scalar product of two vectors is the product of their lengths and the cosine
> of the angle between them."
> — [Wikipedia, *Dot product*](https://en.wikipedia.org/wiki/Dot_product)

```
a · b = a.x·b.x + a.y·b.y + a.z·b.z  =  |a| · |b| · cos(angle between a and b)
```

The two definitions being equal is what makes the dot product so useful: the
left side is cheap arithmetic, and the right side is geometry. For two **unit**
vectors it is simply the cosine of the angle between them:

| Dot of two unit vectors | Meaning |
| --- | --- |
| 1 | same direction |
| between 0 and 1 | less than 90° apart |
| 0 | at right angles (*perpendicular*, *orthogonal*) |
| below 0 | more than 90° apart |
| −1 | opposite |

And `a · a = |a|²`, the squared length (section 3).

### Real-life examples

- **Work in physics.** Pull a sled with 100 N along a rope at 30° above the
  ground and move it 10 m: the work done is force · displacement = 866.03 J.
  Only the part of the pull along the ground moves the sled; the dot product
  extracts exactly that part.
- **Sunlight on a solar panel.** A flat panel facing straight up, with the sun
  45° above the horizon: the dot of the panel's unit normal and the unit
  direction to the sun is 0.7071, so it receives about 71% of the light it
  would get with the sun overhead. This is Lambert's cosine law, and it is the
  same formula a renderer uses for diffuse lighting: `brightness = max(0, N · L)`.
- **Shadows and projection.** For a unit vector `u`, `v · u` is the length of
  `v`'s shadow on a line along `u`, the **projection**. The point `(3, 4, 0)`
  projected onto the X axis `(1, 0, 0)` is 3: how far it is "along X".

### In a game

**"Is the enemy in front of me?"** Take my unit facing direction `(0, 0, −1)`
and the unit direction to the enemy. For an enemy at `(2, 0, −5)` the dot is
0.9285, about 21.8° off-centre: ahead. For one at `(1, 0, 3)` it is −0.9487:
behind. To ask "inside a 60° field of view?", compare with cos(30°) = 0.866,
the half-angle: 0.9285 > 0.866, so that enemy is visible. No angles or
trigonometry at run time, just a dot product and a precomputed cosine.

### In zGameLib

The view matrix (file 13) measures every world point along the camera's right,
up, and forward axes, and each measurement is a dot product with a unit axis,
the projection idea above. Its last column is `−right · position`,
`−up · position`, `forward · position`: the camera's own position measured the
same way. The camera's three axes are mutually perpendicular, so every pair has
dot product 0; for `depth-cube`'s camera, right · forward and up · forward are 0
to six decimal places.

---

## 6. The cross product: the direction at right angles to both

> "The cross product **a** × **b** is defined as a vector **c** that is
> perpendicular (orthogonal) to both **a** and **b**, with a direction given by
> the right-hand rule and a magnitude equal to the area of the parallelogram
> that the vectors span."
> — [Wikipedia, *Cross product*](https://en.wikipedia.org/wiki/Cross_product)

```
a × b = ( a.y·b.z − a.z·b.y,
          a.z·b.x − a.x·b.z,
          a.x·b.y − a.y·b.x )
```

Properties that matter in practice:

- **Order matters.** `b × a = −(a × b)`: swap the inputs and the result flips.
- **Parallel inputs give zero.** Two arrows along the same line span no
  parallelogram, so there is no unique perpendicular direction.
- **Only in 3D.** Unlike the dot product, the cross product is specific to
  three dimensions.

### Real-life examples

- **Torque.** Push on the end of a wrench: the turning effect is
  lever arm × force. Push at right angles to the handle and you get the most
  torque; push along the handle and you get none (parallel vectors, zero cross
  product). The torque vector points along the bolt, and the right-hand rule
  says which way it turns, the same rule as the screw in section 1.
- **Which way is "out" of a surface.** Two edges of a flat sheet, crossed, give
  the direction straight out of the sheet: its **normal**.

### In a game

**Triangle normals.** For a triangle with corners `a = (0, 0, 0)`,
`b = (1, 0, 0)`, `c = (0, 1, 0)`, the normal is `(b − a) × (c − a) = (0, 0, 1)`,
pointing at the viewer. List the corners in the other order and the normal flips.
That is why mesh *winding order* (counter-clockwise or clockwise corners)
decides which side of a triangle is its front, for lighting and for back-face
culling.

### In zGameLib

The camera builds its whole frame of axes from one forward direction and a rough
"up" hint, with two cross products:

```zig
const forward = camera.target.subtract(camera.position).normalize();
const right = forward.computeCrossProduct(camera.up_direction).normalize();
const up = right.computeCrossProduct(forward);
```

Looking straight ahead, forward `(0, 0, −1)` × up `(0, 1, 0)` = `(1, 0, 0)`,
which is +X, right. For `depth-cube`'s camera the result is right
`(0.8, 0, −0.6)` and up `(−0.2683, 0.8944, −0.3578)`, both unit length, both
perpendicular to forward. The second cross needs no `normalize` because right and
forward are already unit length and at right angles, and then the parallelogram
they span has area 1.

The parallel-inputs rule explains the camera's one blind spot: looking straight
up or down makes forward parallel to `up_direction`, the first cross product is
zero, and the view matrix collapses (file 13, section 7).

---

## 7. Floats are not real numbers

Linear algebra is done on paper with exact real numbers; zGameLib uses 32-bit
floats (`f32`), which carry about 7 significant decimal digits. Three practical
consequences:

- **Never compare floats with `==`.** The camera tests compare with a tolerance
  (`expectApproxEqAbs`, 1e-5).
- **Unit vectors drift.** A vector normalized once, then rotated many times, is
  slowly no longer exactly length 1. Re-normalize derived axes instead of
  updating them incrementally; `computeViewMatrix` rebuilds the axes from
  scratch every call for that reason.
- **Precision is relative.** A float has as many significant digits at 10 000 m
  as at 1 m, so the *absolute* error grows with distance from the origin. Huge
  open worlds re-centre their coordinates near the camera. The same effect hits
  the depth buffer (file 13, section 6).

---

## 8. Where zGameLib uses each operation

| Operation | Function | Used in | Why |
| --- | --- | --- | --- |
| point − point | `Vector3.subtract` | `computeViewMatrix` | the arrow from camera to target is the view direction |
| normalize | `Vector3.normalize` | `computeViewMatrix` | camera axes must be unit length, or the image is scaled wrongly |
| dot product | `Vector3.computeDotProduct` | `computeViewMatrix`, `normalize` | measure a point along a camera axis; squared length |
| cross product | `Vector3.computeCrossProduct` | `computeViewMatrix` | build the right and up axes from forward and an up hint |
| (later) add, scale | not yet | movement, physics | position + velocity · time step |
| (later) dot for lighting | in shaders | lighting | `max(0, N · L)` |

File 12 turns these vectors into matrices; file 13 assembles the camera from
both.

---

## Further reading

- Gilbert Strang, *Introduction to Linear Algebra*, 6th edition (2023),
  Wellesley-Cambridge Press, and his MIT course 18.06:
  <https://math.mit.edu/~gs/linearalgebra/>. The standard textbook; chapter 1
  covers vectors, lengths, and dot products.
- 3Blue1Brown, linear algebra video series:
  <https://www.3blue1brown.com/topics/linear-algebra>. Visual intuition for
  vectors, bases, and the dot and cross products.
- J. Ström, K. Åström, and T. Akenine-Möller, *Immersive Linear Algebra*, a free
  interactive book: <https://immersivemath.com/ila/index.html>.
- Joey de Vries, *LearnOpenGL*, "Transformations":
  <https://learnopengl.com/Getting-started/Transformations>. Vectors and matrices
  explained for graphics programmers (OpenGL conventions: see file 13 for where
  Vulkan differs).

## Bibliography

- **zGameLib**: [`shared/camera.zig`](../../shared/camera.zig),
  [`tests/camera_test.zig`](../../tests/camera_test.zig).
- **Wikipedia**, [*Dot product*](https://en.wikipedia.org/wiki/Dot_product) and
  [*Cross product*](https://en.wikipedia.org/wiki/Cross_product), quoted from the
  article source as fetched on 2026-10-29, with wiki markup rendered as text.
  Text © Wikipedia contributors, CC BY-SA 4.0.
