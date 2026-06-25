# event-logger — rung 0 (platform-only warm-up)

A 1280×720 window that pumps events and prints each `Event` to stdout. **No Vulkan, no rendering.** ESC quits.

Full design + frame-loop walkthrough: [`../../docs/examples/event-logger.md`](../../docs/examples/event-logger.md). Where this sits in the build order: [`../../docs/examples/ladder.md`](../../docs/examples/ladder.md) (rung 0). Sprint context: [`../../docs/examples/sprint.md`](../../docs/examples/sprint.md) (items S1.3 + S1.4).

## Lib version gates

| Lib | Needed for this example |
| --- | --- |
| `platform` | **v0.6.0** — window + event pump + minimal action input (`menu_pause`→ESC) |
| `vulkan_stack` | **— (not used)** — must NOT be imported or linked; that's the whole point of the `nm` check |

The platform lib's [`v0.6.0` plan](../../libs/zig-cpp-platform-stack-adapter/docs/ROADMAP.md) covers everything this app needs; the per-app contract is spelled out in the platform lib's [`validation-apps.md`](../../libs/zig-cpp-platform-stack-adapter/docs/validation-apps.md).

## Definition of done

Mark complete only when **every** item below holds — not "compiles", but **builds and runs**:

- [ ] `zig build event-logger` builds with **no `vulkan_stack` import** in the example's module graph and **no `vulkan_stack` artifact** linked into the binary.
- [ ] Launching opens a 1280×720 window titled `event-logger`.
- [ ] Each `Event` variant prints a recognisable, one-line representation to stdout: `.key`, `.mouse_button`, `.mouse_motion`, `.mouse_scroll`, `.resize`, `.focus`, `.close`.
- [ ] Pressing ESC fires `actionJustPressed(.menu_pause)` once (not on hold/repeat) and the loop exits cleanly.
- [ ] Clicking the window-manager close button delivers a `.close` event and the loop exits cleanly.
- [ ] Resize prints a `.resize` line on every drag tick; no crash on min/max-size.
- [ ] No allocator leaks (use `std.heap.GeneralPurposeAllocator` in debug if anything allocates).
- [ ] **Decoupling check #1 is empty:**

  ```sh
  nm zig-out/bin/event-logger | grep -i 'vk[A-Z]\|VK_'   # must print NOTHING
  ```

  A non-empty result is a bug in the **platform** lib (a Vulkan symbol leaked across its public API) — fix it upstream, not here.
- [ ] Built and run on `x86_64-linux-gnu` (X11 + Wayland sessions) and `x86_64-windows-gnu`.

## Todo list — what's left to complete this example

Each `[ ]` is one atomic commit (Conventional Commits, subject ≤ 72 chars). Order matters — earlier items unblock later ones.

### Prereqs (covered by sprint 1)

- [ ] **E0.0** Confirm `build.zig.zon` has the local-path `.platform` dep enabled (sprint item **S1.1**) and `build.zig` exposes the example-exe helper (sprint item **S1.2**). If not done yet, do those first — without them, nothing here can build.

### This example

- [ ] **E0.1** Register the build step. `build.zig`: add `event-logger` via the example-exe helper, **importing only `platform` and linking only `platform`'s artifact** — do **not** add `vulkan_stack` or the `surface` module to this exe.
  - Files: `build.zig`
  - Acceptance: `zig build --help` lists `event-logger`; `zig build event-logger` compiles the stub successfully
  - Commit: `feat(build): register event-logger example (platform-only)`

- [ ] **E0.2** Window + clean shutdown. `examples/event-logger/main.zig`: `platform.init` → `Window.create({ .renderer = .none, .title = "event-logger" })` → loop on `shouldClose()` calling `pollAllEvents()` — empty body for now → `window.destroy()` → `platform.deinit()`. The `× ` button must close it.
  - Files: `examples/event-logger/main.zig`
  - Acceptance: window opens, closing the window exits with status 0
  - Commit: `feat(event-logger): open + close a window (renderer=.none)`

- [ ] **E0.3** Event printing. Drain `nextEvent()` and print each variant on its own line. Match every payload field that v0.6.0 ships (`key`/`mouse_button`/`mouse_motion`/`mouse_scroll`/`resize`/`focus`/`close`). Use `std.debug.print` (or `std.io.getStdOut().writer()` if you prefer to keep stderr clean).
  - Files: `examples/event-logger/main.zig`
  - Acceptance: every event produces exactly one stdout line; output is human-readable
  - Commit: `feat(event-logger): print each Event variant to stdout`

- [ ] **E0.4** ESC quit via action input. `platform.bindAction(.menu_pause, .{ .key = .escape })` once at startup; break the loop on `platform.actionJustPressed(.menu_pause)`.
  - Files: `examples/event-logger/main.zig`
  - Acceptance: ESC quits; holding ESC quits once, not repeatedly
  - Commit: `feat(event-logger): bind ESC to menu_pause and quit cleanly`

- [ ] **E0.5** Decoupling check #1. `scripts/nm-check.sh` (or `zig build nm-check`): assert the event-logger binary has zero `vk*` / `VK_` symbols. Wire it into CI's headless-safe job. (Sprint item **S1.4** — pull forward here if not done yet.)
  - Files: `scripts/nm-check.sh`, `.github/workflows/build.yml`
  - Acceptance: `nm zig-out/bin/event-logger | grep -i 'vk[A-Z]\|VK_'` prints nothing; script exits 0
  - Commit: `test(nm): event-logger drags zero Vulkan symbols`

- [ ] **E0.6** CI run. `.github/workflows/build.yml`: run `event-logger` under `Xvfb` on Linux (it's headless-safe: no GPU API touched) and the `nm` check on both Linux and Windows builds.
  - Files: `.github/workflows/build.yml`
  - Acceptance: CI green on Linux + Windows; the `nm` check runs and passes on both
  - Commit: `ci: run event-logger under Xvfb + nm check on linux/windows`

### Out of scope for this example

- Anything that touches `vulkan_stack` — that lives in `clear-color` (rung 1).
- Action contexts, axis modifiers, gamepad — that's platform v0.7.0+ (rung 8+).
- Filesystem paths, text input, clipboard — platform v0.8.0 (rung 11+).

## How to run

```sh
git submodule update --init --recursive   # only needed once
zig build event-logger
```

Move the mouse, press keys, click around, resize the window. Each action prints a line. ESC quits.
