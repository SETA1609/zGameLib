# Changelog

Last updated: 2026-10-29T09:40Z

Changes per issue, newest first. Issues are tracked in [issues.md](issues.md). Each PR adds its entry and updates the timestamp above. History before this file: `git log`.

## Unreleased

### Issue 3 Run agents in a dev container

Branch `issue-3-run-agents-in-a-dev-container`.

- `docker/agent.Dockerfile`: the build image plus Claude Code 2.1.312, Node 22.23.4 (SHA-256 pinned), uv 0.10.12 (digest pinned), and an `agent` user with the host's uid and gid. No GitHub credentials.
- `scripts/agent.sh [command...]` (default `bash`): mounts the checkout at its host path, its git directory when `.git` is a file (submodule or worktree), and the named home volume `personal-agent-home` (`AGENT_HOME_VOLUME` overrides it) that keeps the Claude login and git identity.
- Checked from a submodule checkout: `claude --version` prints 2.1.312; `git status` and `git submodule status` work; `zig build test` passes; files written inside belong to the host user.

### Issue 1 Port to Zig 0.17.0

Branch `issue-1-port-to-zig-0.17.0`.

- Submodules clone over HTTPS (`.gitmodules`), so `--recurse-submodules` works without an SSH key.
- `libs/zig-cpp-platform-stack-adapter` → `7e6630c` and `libs/zig-cpp-vulkan-stack-adapter` → `912b245`, their Zig 0.17.0 `main`s. `libs/zClip` → zClip's `main`, with its Zig 0.17.0 port (zClip Issue 1, which also brought its animation code and MIT license to `main`) and its devops CLI (zClip Issue 2).
- vulkan-zig `master` API in `shared/`, tests, and examples: `.null` instead of `.null_handle`; `@intFromPtr` for dispatchable handles; flag fields without `_bit` (`.color`, `.opaque_khr`).
- `b.args` → `addPassthruArgs()`. hello-triangle embeds its SPIR-V with an aligned `@embedFile` (0.17's `@import` takes Zig sources only) and passes `-fshader-stage` to glslc.
- `minimum_zig_version`, CI (Zig 0.17.0; `libshaderc-dev` in the display-tests job, since `-Dshaderc` now links the system shaderc), `docker/Dockerfile` (Zig from the release index, `glslc`, `libshaderc-dev`), and the docs say 0.17.0. `cheat_sheet.md` lists the port changes.
- Checked in a Zig 0.17.0 container (lavapipe, Xvfb): fmt and the check examples build; `zig build test` and `zig build examples` pass; test-tdd 9 passed, 3 skipped of 12; test-integration `-Dshaderc` 8 of 8; the decoupling `nm` gate finds no Vulkan-stack symbols in `event-logger`. Same counts as `main` on Zig 0.16.0.
