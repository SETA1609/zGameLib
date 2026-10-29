# Changelog

Last updated: 2026-10-29T21:46Z

Changes per issue, newest first. Issues are tracked in [issues.md](issues.md). Each PR adds its entry and updates the timestamp above.

## Unreleased

### Issue 1 Wrap cglm vector and matrix math

Status: review.

- cglm v0.9.6 (MIT), pinned by commit `144d1e7c`, built as a static library from its `src/` and `src/clipspace/` sources with `CGLM_STATIC` and `CGLM_ALL_UNALIGNED`.
- `src/cglm.zig`: the C boundary, `extern` declarations of the 16 `glmc_*` functions wrapped.
- `src/root.zig`: `Vector3` (add, subtract, scale, dot, cross, length, normalize), `Vector4`, and `Matrix4` (identity, multiply, transformVector4, transformPoint, transpose, computeInverse, computeTranslation, computeRotationAroundAxis, computeLookAt, computeVulkanPerspective). Column vectors, column-major storage; the Vulkan perspective is cglm's right-handed 0..1 projection with y negated.
- `tests/math_stack_test.zig`: 21 tests with known values; they failed 20 of 21 against the API stubs first. They pass in Debug and ReleaseFast.
- Error handling: `math_stack.Error` (`SingularMatrix`, `InvalidRotation`, `DegenerateLookAt`, `InvalidPerspective`). `computeInverse`, `computeRotationAroundAxis`, `computeLookAt`, and `computeVulkanPerspective` return `Error!Matrix4` instead of the zeros, infinities, or NaN cglm produces for those inputs; `computeInverse` checks `glmc_mat4_det` and the result. `parallel_sine_tolerance` (1e-6) is the look-at's parallel test. 12 more tests (33 in all); 22 of 33 failed against the stubs first, and all pass in Debug and ReleaseFast.
