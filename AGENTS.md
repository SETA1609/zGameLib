# zGameLib — agent instructions

## Build

```sh
zig build              # compile framework (default: pipeline)
zig build test         # analyze + link the framework module
zig build test-tdd     # behavioral suite (needs display + Vulkan/GL)
zig build examples     # build all examples (opt-in)
```

Requires Zig **0.17.0**.

## Architecture decisions

Locked-in decisions at [`docs/architecture-decisions.md`](docs/architecture-decisions.md):
comptime foundation tier, Python CI scripts (cross-platform), bash for local Linux/Docker dev.

## CI scripts (pipeline)

```sh
python scripts/ci.py              # fmt + compile-check (default: check)
python scripts/ci.py decoupling   # nm gate (Linux only)
python scripts/ci.py integration  # test-integration -Dshaderc
python scripts/ci.py tdd          # full behavioral suite
```

## Docker development (bash scripts — local Linux dev only)

```sh
./scripts/build-in-docker.sh         # runs `zig build pipeline` in Docker
./scripts/build-in-docker.sh test    # runs tests in Docker
./scripts/build-in-docker.sh examples # builds all examples in Docker
./scripts/shell.sh                   # interactive container shell
./scripts/clean.sh                   # remove volumes + build artifacts
# ci.sh also available for local Linux debugging (same commands as ci.py)
```

## Agent container

```sh
./scripts/agent.sh          # bash in the agent image (build image + Claude Code, Node 22, uv)
./scripts/agent.sh claude   # Claude Code directly
```

The home is the named volume `personal-agent-home` (override with `AGENT_HOME_VOLUME`), which keeps the agent's Claude login and git identity apart from the host's. One-time setup inside: run `claude` and `/login`, then `git config --global user.name` / `user.email`. The host's `~/.claude`, `~/.gitconfig`, and SSH keys are not mounted, so the container commits but cannot push; push from the host.

## CI

Reusable workflow: `.github/workflows/reusable/build.yml`.
Main CI: `.github/workflows/build.yml` — builds framework + display tests.
Auto-rebase: `.github/workflows/rebase-branches.yml` — on push to main, rebases all branches onto it (skips conflicts, logs failures).
