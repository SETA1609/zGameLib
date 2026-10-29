# Issues — zGameLib

Each issue is one PR. Status is `todo`, `doing`, `review`, `done`, or `dropped`. The changelog entry for an issue uses its number.

---

## Issue 1 — Port to Zig 0.17.0

Status: review

Zig 0.17.0 changed the build API (`Build.args` removed), `@import` (Zig sources only), and enum builtins, and the 0.17 Vulkan adapter brings vulkan-zig `master`, whose generated bindings changed (`.null` handles, pointer dispatchable handles, flags without `_bit`). Move the adapter and zClip submodules to their 0.17.0 versions, port `shared/`, tests, and examples, and move CI, the Docker image, and the docs to 0.17.0. `-Dshaderc` now needs the system shaderc library (`libshaderc-dev` or the Vulkan SDK).

Done when: the `check` and `decoupling` gates pass; `zig build test`, `zig build examples`, test-tdd, and test-integration `-Dshaderc` give the same results as on 0.16.0.

---

## Issue 2 — Start the 3D path

Status: todo
Needs: Issue 1

Add a 3D render path beside the 2D one without changing the 2D API: a depth attachment, a perspective camera, and one indexed mesh drawn with dynamic rendering. Engine-neutral: no game content.

Done when: an example draws a depth-tested mesh; the 2D examples render unchanged.
