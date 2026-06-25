# Event logger — design

> Rung 0 of the [ladder](ladder.md) — the platform-only warm-up. Opens a window, pumps events, prints them, and quits on ESC. **No Vulkan, no rendering.** Its job is to (a) prove `platform` v0.6.0 actually opens and pumps a window, and (b) act as the binary for the first `nm` decoupling check — the platform adapter must drag **zero `vk*` / `VK_`** symbols into a binary that doesn't ask for them.

## What it does

Initialises `platform`, creates a window with `renderer = .none`, then loops: pump events, drain the queue, print each `Event` (one line each), and break when ESC fires `actionJustPressed(.menu_pause)` or the window's close event arrives. No GPU API touched, no `vulkan_stack` import.

## What building it forces into existence

| Lib | Milestone | Pieces used |
| --- | --- | --- |
| platform | **v0.6.0** | `init`/`deinit`, `Window.create({ .renderer = .none })`/`destroy`/`shouldClose`, `Event` union + payload structs, `pollAllEvents`/`nextEvent`, `bindAction`/`actionJustPressed` (key bindings only) |
| vulkan | **— (not used)** | nothing — and that's the point; this is the binary the `nm` check inspects |
| this repo | — | no `shared/surface.zig` (the bridge is for the both-libs apps) |

## Frame loop (the lib calls, in order)

**Setup**
1. `try platform.init(.{})` · `defer platform.deinit()`.
2. `const win = try platform.Window.create(.{ .title = "event-logger", .renderer = .none })` · `defer win.destroy()`.
3. `platform.bindAction(.menu_pause, .{ .key = .escape })`.

**Loop** (until `win.shouldClose()` or `.close` or ESC)
4. `platform.pollAllEvents()`.
5. `while (platform.nextEvent()) |ev| { print(ev); switch (ev) { .close => break_out, else => {} } }`.
6. `if (platform.actionJustPressed(.menu_pause)) break;`.

**Teardown**: deferred — `window.destroy()` then `platform.deinit()`.

## Done when

- `zig build event-logger` launches a 1280×720 window.
- Moving the mouse, pressing keys, clicking, scrolling, and resizing each prints a recognisable line to stdout (one `Event` → one line).
- ESC quits cleanly; closing the window (window-manager × button) quits cleanly.
- **Decoupling check #1 passes:**

  ```sh
  # none of OUR vulkan stack (vulkan-zig wrappers / volk / VMA / shaderc):
  nm zig-out/bin/event-logger | grep -E 'vk\.[A-Za-z]|volk[A-Z]|[Vv]ma[A-Z]|shaderc_[a-z]'   # must print NOTHING
  ```

  A hit means the **platform** lib pulled in our Vulkan stack — fix it there, not
  here. (Bare `vk*` C symbols are *not* checked: SDL3 ships its own Vulkan loader,
  so they appear in every SDL3-linked binary — see `ladder.md` § Decoupling
  checks. `scripts/ci.sh decoupling` is the source of truth.)
- Zero crashes, zero validation-layer messages (there is no Vulkan to validate — listed for symmetry with `clear-color.md`).

## Build

Per the [libs-first / link-the-artifact model](../../libs/README.md), the example imports only the `platform` module and links only `platform`'s static-library artifact — **do not import or link `vulkan_stack`**. Wire it in [`../../build.zig`](../../build.zig), then:

```sh
zig build event-logger
```

## Why this is rung 0 (not rung 1)

Two reasons:

1. **It pre-validates the platform half before the surface bridge gets involved.** If event-logger is broken, the surface in `clear-color` will be broken too — and you'd be debugging two libs at once.
2. **It's the only app that can carry the platform-side `nm` check.** Any binary that imports `vulkan_stack` drags Vulkan symbols by definition. Rung 0 stays platform-only so the `nm` baseline exists.

A v0.1.0 release of this examples repo is **both** event-logger + clear-color green, with **both** `nm` checks empty. The headless-vulkan sketch carries the other side of the check.
