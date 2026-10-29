# Issues — math-stack adapter

Each issue is one PR. Status is `todo`, `doing`, `review`, `done`, or `dropped`. The changelog entry for an issue uses its number.

---

## Issue 1 — Wrap cglm vector and matrix math

Status: doing
Needs: —

Build cglm (pinned by commit) as a static library and wrap the vector and matrix operations a 3D renderer needs as Zig types: `Vector3` (add, subtract, scale, dot, cross, length, normalize), `Vector4`, and `Matrix4` (identity, multiply, transform, transpose, inverse, translation, rotation around an axis, right-handed look-at, and a Vulkan perspective with depth 0..1 and y pointing down). Column vectors, column-major storage. The C boundary is a short list of `extern` declarations of cglm's `glmc_*` functions.

Done when: `zig build test` passes with no display or GPU, every wrapper has a test with known values, and the README states the conventions.
