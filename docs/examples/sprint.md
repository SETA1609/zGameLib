# Sprint 1 — Foundation + clear-color

> The first miniproject: wire the libs-first build, then land the first app that drives **both** adapters together. Bundles the rung-0 warm-up (`event-logger`, platform only) so the first `nm` decoupling check lands alongside it. Roadmap context: [`ROADMAP.md`](ROADMAP.md). App design: [`clear-color.md`](clear-color.md).
>
> **Goal:** tag examples **v0.1.0**.
>
> **Definition of done:** `zig build clear-color` opens a window whose clear-colour animates (a cycling palette), recreates its swapchain on resize, and quits on window close with **zero validation-layer messages**; `zig build event-logger` runs platform-only; **both `nm` decoupling checks print nothing**; CI builds every example on Linux + Windows and runs the headless-safe ones.
>
> **Status:** S1.1–S1.6, S1.8 done (build wired; both Foundation rungs build + run; the platform-only `nm` decoupling check + CI are live via `scripts/ci.sh` + `.github/workflows/build.yml`). Remaining for the v0.1.0 tag: the headless-vulkan `nm` decoupling check (S1.7) and the tag itself (S1.9).
>
> Prereq: submodules added + pinned (`platform` → v0.6.0, `vulkan` → v0.2.0+) — see [`../../libs/README.md`](../../libs/README.md). ✅ submodules are already added.

Each `[ ]` is one atomic commit (Conventional Commits, subject ≤ 72 chars).

## Items

- [x] **S1.1** Enable the local-path deps. `build.zig.zon`: uncomment the `.platform` + `.vulkan_stack` path entries.
  - Files: `build.zig.zon`
  - Acceptance: `zig build` resolves both deps from the local checkout (no network fetch)
  - Commit: `chore(zon): enable local-path deps into libs/`

- [x] **S1.2** Wire the build shell. `build.zig`: pull both `b.dependency(...)`, create the `surface` module (importing both lib modules), and add a small helper that builds one `examples/<name>/main.zig` exe — `addImport` the two lib modules + `surface`, `linkLibrary` both lib artifacts — plus a named run step. Remove the `_ = target/optimize` placeholders.
  - Files: `build.zig`
  - Acceptance: the helper compiles; `zig build --help` lists the example steps
  - Commit: `feat(build): wire deps + surface module + example exe helper`

- [x] **S1.3** Rung 0 — event-logger (platform only). `examples/event-logger/main.zig`: `renderer = .none`, pump events, print each `Event` + `actionJustPressed(.menu_pause)`; ESC quits. **No `vulkan_stack` import.**
  - Files: `examples/event-logger/main.zig`, `build.zig` (register step)
  - Acceptance: `zig build event-logger` runs; events print; ESC quits
  - Commit: `feat(event-logger): platform-only event + action logger`

- [x] **S1.4** Decoupling check #1 (`scripts/ci.sh decoupling`): assert the event-logger binary pulls in **none of our Vulkan stack** (vulkan-zig wrappers / volk / VMA / shaderc). Bare `vk*` C symbols are excluded — SDL3 ships its own Vulkan loader (see `ladder.md` § Decoupling checks).
  - Files: `scripts/ci.sh`
  - Acceptance: `nm <event-logger> | grep -E 'vk\.[A-Za-z]|volk[A-Z]|[Vv]ma[A-Z]|shaderc_[a-z]'` prints nothing; the script exits 0
  - Commit: `test(nm): platform-only binary drags no Vulkan symbols`

- [x] **S1.5** The surface bridge. `shared/surface.zig`: implement `createSurface(instance, window)` — a comptime switch on the target OS pairing platform's native-handle getter with vulkan's matching creator (X11/Wayland on Linux, Win32 on Windows). Per [`clear-color.md`](clear-color.md) § The surface bridge.
  - Files: `shared/surface.zig`
  - Acceptance: compiles for `x86_64-linux-gnu` + `x86_64-windows-gnu`; the correct arm is selected at comptime
  - Commit: `feat(surface): comptime platform↔vulkan surface bridge`

- [x] **S1.6** Rung 1 — clear-color. `examples/clear-color/main.zig`: implement the full setup → loop → teardown from [`clear-color.md`](clear-color.md) — window, instance, surface via the bridge, device + swapchain (via the new `shared/swapchain.zig` helper), per-frame acquire → clear → present, swapchain-recreate on resize.
  - Files: `examples/clear-color/main.zig`, `shared/swapchain.zig`, `build.zig` (register step)
  - Acceptance: window opens; resize recreates the swapchain without crashing; quits on window close
  - Note (as shipped): the clear-colour cycles a 6-colour palette one colour per second (a `platform.now()`-driven timer) rather than tracking mouse/keys, and quits on window close rather than ESC. The swapchain landed as a reusable `shared/swapchain.zig` helper.
  - Commit: `feat(clear-color): reactive clear-colour driving both adapters`

- [ ] **S1.7** Decoupling check #2. A minimal headless-vulkan sketch (no window, offscreen image) → assert **no windowing symbols** (`SDL_`/`x11`/`wayland`). May be a `tests/` sketch built only for the check.
  - Files: `examples/headless-vulkan/main.zig` (or `tests/headless.zig`), `scripts/nm-check.sh`
  - Acceptance: `nm <bin> | grep -i 'SDL_\|x11\|wayland'` prints nothing
  - Commit: `test(nm): headless-vulkan binary drags no windowing symbols`

- [x] **S1.8** CI. `.github/workflows/build.yml`: build **every** example on `ubuntu-latest` + `windows-latest`; run the headless-safe ones (event-logger under `Xvfb`, the `nm` checks); do **not** run the windowed Vulkan app in CI. Replace the bare `zig build run` step (no such step exists once steps are named) with explicit per-example build/run. Drop macOS to `continue-on-error` (deferred) or remove it. Add `zig fmt --check`.
  - Files: `.github/workflows/build.yml`
  - Acceptance: CI green on Linux + Windows
  - Commit: `ci: build all examples + run headless-safe ones on linux/windows`

- [ ] **S1.9** Tag `v0.1.0`. Pin `libs/*` to the validated lib commits; flip the [`ROADMAP.md`](ROADMAP.md) v0.1.0 row to ✅.

## Out of this sprint (next rungs)

- v0.2.0 — **First pipeline**: hello-triangle (first graphics pipeline + vertex buffer + precompiled shaders; vulkan v0.3.0 / VMA).
- v0.3.0 — **Games & texturing**: snake, asteroids, breakout, then **space-invaders** (introduces the texture path) and image-viewer (`file_drop`).
- Later — input depth (tetris, replay-demo), devices & persistence (pong, 2048, typing-game), shaders & compute (life, particles, shader-playground), 3D smoke (hello-cube). See [`ROADMAP.md`](ROADMAP.md).
