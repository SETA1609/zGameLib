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
