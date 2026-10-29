# Changelog

Last updated: 2026-10-29T21:46Z

Changes per issue, newest first. Issues are tracked in [issues.md](issues.md). Each PR adds its entry and updates the timestamp above. History before this file: `git log`.

## Unreleased

### Issue 7 Add a cglm math adapter

Branch `issue-7-add-a-cglm-math-adapter`.

- `libs/zig-c-math-stack-adapter` (interim name): a standalone package shaped like the platform and Vulkan adapters, kept in this repository until its API settles. It builds cglm v0.9.6 (MIT, pinned by commit) as a static library and wraps it as Zig types: `Vector3`, `Vector4`, `Matrix4` (multiply, transform, transpose, inverse, translation, rotation around an axis, right-handed look-at, Vulkan perspective with depth 0..1 and y down). Own `README.md`, `issues.md`, `CHANGELOG.md`, MIT `LICENSE`, and 33 tests.
- Error handling, as in the Vulkan and platform adapters: `math_stack.Error` with `SingularMatrix`, `InvalidRotation`, `DegenerateLookAt`, and `InvalidPerspective`. `computeInverse`, `computeRotationAroundAxis`, `computeLookAt`, and `computeVulkanPerspective` return `Error!Matrix4` instead of the zeros, infinities, or NaN cglm gives for those inputs; the per-frame arithmetic stays infallible.
- zGameLib imports it as a path dependency and re-exports it as `zgame.math_stack`; `shared/camera.zig` is unchanged.
- Checked in a Zig 0.17.0 container: the adapter's `zig build test` passes 33 of 33 in Debug and ReleaseFast (20 of 21 failed against the first stubs, then 22 of 33 against the error-handling stubs); zGameLib's `zig build`, `zig build test`, `ci.py check`, and the decoupling gate pass; the platform-only `event-logger` contains no cglm symbols.

### Issue 2 Start the 3D path

Branch `issue-2-start-the-3d-path`. The 3D path sits beside the 2D one; nothing in the 2D API changes.

- `Gpu.Options.enable_dynamic_rendering` (default `false`) turns on Vulkan 1.3 dynamic rendering; `Gpu.dynamic_rendering_enabled` reports it. `Gpu.findMemoryTypeIndex` picks a memory type for a resource.
- `shared/camera.zig` (`zgame.camera`): `Vector3`, column-major `Matrix4` (multiply, translation, rotation around Y), and `PerspectiveCamera` (view, projection, view-projection) in Vulkan conventions: -Z forward, clip-space Y down, depth 0..1. Pure math, no GPU.
- `shared/depth.zig` (`zgame.DepthBuffer`): a depth image, memory, and view sized to the swapchain, with `recreate` and a per-frame transition to the attachment layout that waits for the previous frame's depth writes. The format is `D32_SFLOAT` when the device supports it as a depth attachment, else `X8_D24_UNORM_PACK32` (`findSupportedDepthFormat`, `chooseFirstSupportedDepthFormat`, `depth_format_candidates`).
- `shared/mesh.zig` (`zgame.IndexedMesh`): one vertex buffer and one 16-bit index buffer in host-visible memory, drawn with `recordDraw`; empty vertex or index lists are rejected.
- `examples/depth-cube`: a rotating, depth-tested cube drawn with `cmdBeginRendering`, a push-constant model-view-projection matrix, and glslc-compiled shaders. `-- --frames N` exits after N frames.
- Tests: `tests/camera_test.zig` (10 tests, including the order of `multiply`) and `tests/depth_format_test.zig` (4 tests, the format fallback) run under `zig build test`; `tests/gpu_test.zig` gains 8 tests for dynamic rendering, `DepthBuffer`, the depth format, and `IndexedMesh`. `python scripts/ci.py sync-validation` runs `depth-cube` under Khronos synchronization validation and fails on any validation error.
- Docs: theory files 11 (vectors) and 12 (matrices), linear algebra with worked examples, real-life analogies, and where zGameLib uses each operation; 13 (cameras and Vulkan clip space: the matrix chain, the clip volume, y-down NDC, 0..1 depth, push constants); and 14 (depth test, `DepthBuffer`, `IndexedMesh`, memory types, dynamic rendering); and `docs/examples/depth-cube.md`. Spec quotes checked against KhronosGroup/Vulkan-Docs at `70304594e73a`; linear-algebra quotes from Wikipedia (CC BY-SA 4.0) as fetched on 2026-10-29. Known limitations written down: the depth barrier does not wait for the previous frame's depth writes (one depth image, two frames in flight), and `D32_SFLOAT` has no fallback format.
- Checked in a Zig 0.17.0 container (lavapipe, Xvfb): `zig build test` passes; test-tdd passes (the GPU suite 12 of 12, the 2D suites unchanged); `ci.py check`, `decoupling`, and `sync-validation` pass; `depth-cube --frames 60` exits 0 with the Khronos validation layer and no validation messages. Before the barrier fixes, `sync-validation` reported 29 write-after-write hazards on the depth image and 30 write-after-read hazards on the swapchain images in 30 frames.

### Issue 4 Design the API before the tests

Branch `issue-4-design-the-api-before-the-tests`.

- `CLAUDE.md` gets a Workflow section: each behaviour change is three commits in order, the API with stub bodies, failing tests against it (the failing run recorded), and the implementation, which leaves the tests and public signatures unchanged.

### Issue 3 Run agents in a dev container

Branch `issue-3-run-agents-in-a-dev-container`.

- `docker/agent.Dockerfile`: the build image plus Claude Code 2.1.312, Node 22.23.4 (SHA-256 pinned), uv 0.10.12 (digest pinned), and an `agent` user with the host's uid and gid. No GitHub credentials.
- `scripts/agent.sh [command...]` (default `bash`): mounts the checkout at its host path, its git directory when `.git` is a file (submodule or worktree), and the named home volume `personal-agent-home` (`AGENT_HOME_VOLUME` overrides it) that keeps the Claude login and git identity.
- Checked from a submodule checkout: `claude --version` prints 2.1.312; `git status` and `git submodule status` work; `zig build test` passes; files written inside belong to the host user.

## 2026-10-29

### Issue 1 Port to Zig 0.17.0 (#12)

- Submodules clone over HTTPS (`.gitmodules`), so `--recurse-submodules` works without an SSH key.
- `libs/zig-cpp-platform-stack-adapter` → `7e6630c` and `libs/zig-cpp-vulkan-stack-adapter` → `912b245`, their Zig 0.17.0 `main`s. `libs/zClip` → zClip's `main`, with its Zig 0.17.0 port (zClip Issue 1, which also brought its animation code and MIT license to `main`) and its devops CLI (zClip Issue 2).
- vulkan-zig `master` API in `shared/`, tests, and examples: `.null` instead of `.null_handle`; `@intFromPtr` for dispatchable handles; flag fields without `_bit` (`.color`, `.opaque_khr`).
- `b.args` → `addPassthruArgs()`. hello-triangle embeds its SPIR-V with an aligned `@embedFile` (0.17's `@import` takes Zig sources only) and passes `-fshader-stage` to glslc.
- `minimum_zig_version`, CI (Zig 0.17.0; `libshaderc-dev` in the display-tests job, since `-Dshaderc` now links the system shaderc), `docker/Dockerfile` (Zig from the release index, `glslc`, `libshaderc-dev`), and the docs say 0.17.0. `cheat_sheet.md` lists the port changes.
- Checked in a Zig 0.17.0 container (lavapipe, Xvfb): fmt and the check examples build; `zig build test` and `zig build examples` pass; test-tdd 9 passed, 3 skipped of 12; test-integration `-Dshaderc` 8 of 8; the decoupling `nm` gate finds no Vulkan-stack symbols in `event-logger`. Same counts as `main` on Zig 0.16.0.
