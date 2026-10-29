# Issues — zGameLib

Each issue is one PR. Status is `todo`, `doing`, `review`, `done`, or `dropped`. The changelog entry for an issue uses its number.

---

## Issue 7 — Add a cglm math adapter

Status: review
Needs: —

Add `libs/zig-c-math-stack-adapter` (interim name), a standalone Zig package shaped like the platform and Vulkan adapters (own `build.zig`, `build.zig.zon`, `LICENSE`, `README.md`, `issues.md`, `CHANGELOG.md`, tests), which builds cglm (C, MIT, pinned by commit) as a static library and wraps it as Zig types: `Vector3`, `Vector4`, `Matrix4` with multiply, transform, transpose, inverse, translation, rotation, right-handed look-at, and a Vulkan perspective (depth 0..1, y down). It lives in this repository, not as a submodule, until its API settles; then it moves to its own repository like the other adapters. zGameLib imports it as a path dependency and re-exports it as `zgame.math_stack`. `shared/camera.zig` is not changed by this issue.

Done when: the adapter's `zig build test` passes with no display or GPU; zGameLib's `zig build`, `zig build test`, and the decoupling gate pass; the adapter's README states its conventions.

---

## Issue 1 — Port to Zig 0.17.0

Status: review

Zig 0.17.0 changed the build API (`Build.args` removed), `@import` (Zig sources only), and enum builtins, and the 0.17 Vulkan adapter brings vulkan-zig `master`, whose generated bindings changed (`.null` handles, pointer dispatchable handles, flags without `_bit`). Move the adapter and zClip submodules to their 0.17.0 versions, port `shared/`, tests, and examples, and move CI, the Docker image, and the docs to 0.17.0. `-Dshaderc` now needs the system shaderc library (`libshaderc-dev` or the Vulkan SDK).

Done when: the `check` and `decoupling` gates pass; `zig build test`, `zig build examples`, test-tdd, and test-integration `-Dshaderc` give the same results as on 0.16.0.

---

## Issue 2 — Start the 3D path

Status: review
Needs: Issue 1

Add a 3D render path beside the 2D one without changing the 2D API: a depth attachment, a perspective camera, and one indexed mesh drawn with dynamic rendering. Engine-neutral: no game content.

Done when: an example draws a depth-tested mesh; the 2D examples render unchanged; `depth-cube` runs with no synchronization-validation errors (`scripts/ci.py sync-validation`).

---

## Issue 5 — Order swapchain image transitions after image acquire

Status: todo
Needs: Issue 2

The examples transition the acquired swapchain image out of `UNDEFINED` with source stage `TOP_OF_PIPE`, but `FrameRing.end` waits on the image-acquire semaphore at a later stage (`TRANSFER` in `clear-color-2`). The transition is then not ordered after the wait and can run while the presentation engine still reads the image. Synchronization validation reports `SYNC-HAZARD-WRITE-AFTER-READ` on every frame: 27,368 times in 25 seconds of `clear-color-2`. Issue 2 fixed the same pattern in `depth-cube`.

Use the semaphore's wait stage as each transition's source stage, in every example and test that records one, and say in `transitionImage`'s doc comment that the source stage must chain with the acquire wait. Extend `scripts/ci.py sync-validation` to every example that renders, with a frame limit like `depth-cube`'s `--frames N`, so the check covers them all.

Done when: `scripts/ci.py sync-validation` runs `clear-color`, `clear-color-2`, and `depth-cube` with no validation errors.

---

## Issue 6 — Fix hello-triangle's validation errors

Status: todo
Needs: —

With the Khronos validation layer loaded, `hello-triangle` reports `VUID-VkGraphicsPipelineCreateInfo-pDynamicStates-04130` and `-04131` at pipeline creation and `VUID-VkRenderPassBeginInfo-framebuffer-parameter` when it begins its render pass, then aborts. Without the layer it runs. Find and fix each cause (the viewport and scissor state of a pipeline with dynamic viewport and scissor; which framebuffer is passed after the swapchain is created or recreated), and add a frame limit so the example can run in `scripts/ci.py sync-validation`.

Done when: `hello-triangle` runs under the validation layer, with synchronization validation, with no validation errors, and is part of the `sync-validation` check.

---

## Issue 4 — Design the API before the tests

Status: review

Write down the commit order every behaviour change follows: the API with stub bodies, then failing tests against it, then the implementation, which makes the tests pass without changing them or the public signatures. Each step is its own commit, and the tests commit records the failing run. Issue 2 is the first issue done this way.

Done when: `CLAUDE.md` has the workflow section.

---

## Issue 3 — Run agents in a dev container

Status: review

Run coding agents (Claude Code) on zGameLib with their own login, kept apart from the host's Claude Code account. Add `docker/agent.Dockerfile` on top of the build image (Claude Code, Node 22, uv, a user with the host's uid and gid) and `scripts/agent.sh`, which mounts a named home volume (`personal-agent-home`, shared with other repos that use the same volume name) for the Claude login and git identity. The host's `~/.claude`, `~/.gitconfig`, and SSH keys are not mounted: the agent commits, and the owner pushes from the host. When the checkout is a submodule or worktree, its git directory is mounted too.

Done when: `./scripts/agent.sh claude --version` prints the pinned version; `git status` and `zig build test` work inside the container from a standalone clone and from a submodule checkout; files it writes belong to the host user.
