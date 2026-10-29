# Changelog

Last updated: 2026-10-29T00:28Z

Changes per issue, newest first. Issues are tracked in [issues.md](issues.md). Each PR adds its entry and updates the timestamp above. History before this file: `git log`.

## Unreleased

### Issue 1 Port to Zig 0.17.0

Branch `issue-1-port-to-zig-0.17.0`.

- Submodules clone over HTTPS (`.gitmodules`), so `--recurse-submodules` works without an SSH key.
- `libs/zig-cpp-platform-stack-adapter` → `38b4c7b` and `libs/zig-cpp-vulkan-stack-adapter` → `503fc87`, their Zig 0.17.0 `main`s. `libs/zClip` → zClip's `main`, with its Zig 0.17.0 port (zClip Issue 1, which also brought its animation code and MIT license to `main`) and its devops CLI (zClip Issue 2).
- vulkan-zig `master` API in `shared/`, tests, and examples: `.null` instead of `.null_handle`; `@intFromPtr` for dispatchable handles; flag fields without `_bit` (`.color`, `.opaque_khr`).
- `b.args` → `addPassthruArgs()`. hello-triangle embeds its SPIR-V with an aligned `@embedFile` (0.17's `@import` takes Zig sources only) and passes `-fshader-stage` to glslc.
- `minimum_zig_version`, CI (Zig 0.17.0; `libshaderc-dev` in the display-tests job, since `-Dshaderc` now links the system shaderc), `docker/Dockerfile` (Zig from the release index, `glslc`, `libshaderc-dev`), and the docs say 0.17.0. `cheat_sheet.md` lists the port changes.
- Checked in a Zig 0.17.0 container (lavapipe, Xvfb): fmt and the check examples build; `zig build test` and `zig build examples` pass; test-tdd 9 passed, 3 skipped of 12; test-integration `-Dshaderc` 8 of 8; the decoupling `nm` gate finds no Vulkan-stack symbols in `event-logger`. Same counts as `main` on Zig 0.16.0.
