# Changelog

Last updated: 2026-10-29T15:00Z

Changes per issue, newest first. Issues are tracked in [issues.md](issues.md). Each PR adds its entry and updates the timestamp above. History before this file: `git log`.

## Unreleased

### Issue 2 Start the 3D path

Branch `issue-2-start-the-3d-path`. The 3D path sits beside the 2D one; nothing in the 2D API changes.

- `Gpu.Options.enable_dynamic_rendering` (default `false`) turns on Vulkan 1.3 dynamic rendering; `Gpu.dynamic_rendering_enabled` reports it. `Gpu.findMemoryTypeIndex` picks a memory type for a resource.
- `shared/camera.zig` (`zgame.camera`): `Vector3`, column-major `Matrix4` (multiply, translation, rotation around Y), and `PerspectiveCamera` (view, projection, view-projection) in Vulkan conventions: -Z forward, clip-space Y down, depth 0..1. Pure math, no GPU.
- `shared/depth.zig` (`zgame.DepthBuffer`): a D32 depth image, memory, and view sized to the swapchain, with `recreate` and a per-frame transition to the attachment layout.
- `shared/mesh.zig` (`zgame.IndexedMesh`): one vertex buffer and one 16-bit index buffer in host-visible memory, drawn with `recordDraw`; empty vertex or index lists are rejected.
- `examples/depth-cube`: a rotating, depth-tested cube drawn with `cmdBeginRendering`, a push-constant model-view-projection matrix, and glslc-compiled shaders. `-- --frames N` exits after N frames.
- Tests: `tests/camera_test.zig` (9 tests) runs under `zig build test`; `tests/gpu_test.zig` gains 6 tests for dynamic rendering, `DepthBuffer`, and `IndexedMesh`.
- Docs: theory files 11 (vectors and matrices), 12 (cameras and Vulkan clip space: the matrix chain, the clip volume, y-down NDC, 0..1 depth, push constants), and 13 (depth test, `DepthBuffer`, `IndexedMesh`, memory types, dynamic rendering), and `docs/examples/depth-cube.md`. Spec quotes checked against KhronosGroup/Vulkan-Docs at `70304594e73a`. Known limitations written down: the depth barrier does not wait for the previous frame's depth writes (one depth image, two frames in flight), and `D32_SFLOAT` has no fallback format.
- Checked in a Zig 0.17.0 container (lavapipe, Xvfb): `zig build test` 10 passed; test-tdd 15 passed, 3 skipped of 18 (the 2D suites unchanged, 6 new GPU tests pass); `zig build examples`, the check examples, fmt, and the decoupling `nm` gate pass; `depth-cube --frames 60` exits 0 with the Khronos validation layer loaded and 0 validation errors.

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
