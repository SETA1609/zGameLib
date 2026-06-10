# 01 — SDL3 and the platform adapter

*The bottom-left of the stack: getting a window on screen and reading input,
without your code ever touching the OS directly.*

Before anything can be drawn, three boring-but-essential things must happen:
something has to **open a window**, **deliver input** (keyboard, mouse, resize,
"user clicked the close button"), and — for a GPU app — **hand the renderer a
reference to that window**. None of that is graphics; it's the operating system's
job, and every OS does it differently (X11 and Wayland on Linux, Win32 on Windows,
Cocoa on macOS, the NDK on Android). The **platform adapter** exists so your code
never has to care which one it's running on.

---

## What SDL3 is

The platform adapter is a thin Zig API over **SDL3**. SDL is the industry-standard
way to abstract those OS differences. The adapter's own cheat sheet defines it:

> "[SDL](https://www.libsdl.org/) (Simple DirectMedia Layer) is a cross-platform C
> library that abstracts the OS-specific bits of a desktop/mobile app: creating
> windows, reading keyboard/mouse/gamepad input, timers, audio, clipboard, and the
> hand-off to a GPU API (Vulkan / OpenGL / Metal / D3D). **SDL3** is the current
> major version (zlib-licensed)."
> — [platform adapter, `docs/sdl3-cheat-sheet.md`](../../libs/zig-cpp-platform-stack-adapter/docs/sdl3-cheat-sheet.md)

The shape of every SDL app is the same three-act structure — **init → loop →
quit** — which the cheat sheet draws like this:

```
SDL_Init(flags)                     // bring up subsystems (video/audio/gamepad)
  └─ SDL_CreateWindow(...)          // one or more windows
       loop:
         SDL_PollEvent(&e)          // drain the OS event queue into SDL_Event
         ... react, render ...
SDL_Quit()                          // tear everything down
```

> "SDL owns a global event queue fed by the OS; you pump it once per frame and SDL
> hands you normalized `SDL_Event`s."
> — [platform adapter, `docs/sdl3-cheat-sheet.md`](../../libs/zig-cpp-platform-stack-adapter/docs/sdl3-cheat-sheet.md)

That's the whole runtime model: **you pump the queue once per frame, and react to
whatever comes out.**

---

## Why an *adapter* and not just SDL directly?

Because the goal is a stable, idiomatic-Zig API that doesn't leak SDL into your
code. The adapter's README states the contract:

> "Your code imports `platform` and calls a stable API; it never sees the backend.
> The backend is **SDL3** today and could become a native backend or a future SDL
> without your code changing — that decoupling is the whole reason this exists as
> its own library."
> — [platform adapter README](../../libs/zig-cpp-platform-stack-adapter/README.md)

This is enforced by **design rule 1** — *"no `SDL_*` types cross [the API]"* — so
SDL is an implementation detail confined to one backend file. The practical payoff
for you: you learn one small Zig API (below), not the thousand-function SDL
surface.

---

## The abstraction, in five concepts

Everything the platform adapter gives you falls into five buckets. (Full
signatures: [the adapter's `docs/api.md`](../../libs/zig-cpp-platform-stack-adapter/docs/api.md).)

### 1. Lifecycle — `init` / `deinit`

`platform.init(.{})` brings the backend up; `platform.deinit()` tears it down.
Call them once each, at the very start and end of `main`.

### 2. The `Window` — and the renderer it binds to

`platform.Window.create(.{ .title = "...", .renderer = .vulkan })` opens a window.
The key idea is the `renderer` field: **a window is bound to one GPU API at
creation**, and for every GPU case the adapter hands you only *raw OS primitives*
and links no graphics library. The README lays out the six paths:

> "Six paths hang off the same window, chosen via `WindowOptions.renderer` — in
> every GPU case the library hands back **raw OS primitives** and links no graphics
> API"
> — [platform adapter README](../../libs/zig-cpp-platform-stack-adapter/README.md)

The paths are `.none` (window + events only, headless), `.vulkan` (what this
framework uses), `.opengl`, `.cpu` (a software framebuffer), `.metal`, and
`.directx`. For zGameLib you'll almost always pick `.vulkan`.

### 3. Events — the per-frame queue

Once per frame you call `pollAllEvents()` to drain the OS queue, then consume what
came out. There are two equally valid styles, and you pick one per frame:

```zig
platform.pollAllEvents();                     // drive the backend pump once
while (platform.nextEvent()) |ev| switch (ev) {  // (1) array-of-structs: drain
    .close  => running = false,
    .resize => |r| { /* recreate the swapchain at r.w × r.h */ },
    else => {},
};
```

`nextEvent()` returns an `Event` — a tagged union with variants like `key`,
`mouse_button`, `mouse_motion`, `resize`, `focus`, `close`, and more. The
alternative, `events()`, returns the *same* frame's events grouped by type
(struct-of-arrays) for batch processing. One important caveat from the API doc:

> "Every slice borrows backend storage valid only until the next `pollAllEvents()`
> — copy out anything you keep."
> — [platform adapter, `docs/api.md`](../../libs/zig-cpp-platform-stack-adapter/docs/api.md)

The `.resize` and `.close` events are the two you'll handle in even the simplest
renderer: `.close` ends the loop, and `.resize` tells you the swapchain (file 05)
no longer matches the window.

### 4. Action-mapped input — bind *meaning*, not keys

Rather than scattering `if (key == .space)` through your code, you bind an
**action** (your own meaning, like `jump`) to a key, then query the action. The
adapter is deliberately neutral about *what* your actions are:

> "Action-mapped input — `bindAction` / `actionPressed` / `actionValue`, stackable
> input contexts, synthetic injection. The action/context **vocabulary is yours**
> (pass your own enum); the library names none, and raw key codes stay inside the
> backend."
> — [platform adapter README](../../libs/zig-cpp-platform-stack-adapter/README.md)

```zig
const Action = enum(u16) { quit, jump };
platform.bindAction(Action.quit, .{ .key = .escape });
// ... later, in the loop:
if (platform.actionJustPressed(Action.quit)) running = false;
```

This indirection is what makes key-rebinding possible later without touching game
logic — the binding table changes, the `actionPressed(.quit)` call doesn't.

### 5. The renderer hand-off — raw native handles

This is the bucket that connects windowing to the rendering sub-library across a
narrow seam (file 03). For a Vulkan window, the adapter exposes per-OS getters that
return **only raw OS pointers and integers — no Vulkan types**:

```zig
pub fn getX11Handle(window: *Window) ?struct { display: *anyopaque, window: u64 };
pub fn getWaylandHandle(window: *Window) ?struct { display: *anyopaque, surface: *anyopaque };
pub fn getWin32Handle(window: *Window) ?struct { hinstance: *anyopaque, hwnd: *anyopaque };
pub fn requiredVulkanInstanceExtensions() []const [*:0]const u8;   // C strings; no Vulkan types
```

> "Raw OS primitives only — **no Vulkan types**. Feed these to a Vulkan renderer's
> matching `create*Surface`"
> — [platform adapter, `docs/api.md`](../../libs/zig-cpp-platform-stack-adapter/docs/api.md)

Two of these matter enormously for what comes next:

- `requiredVulkanInstanceExtensions()` — the list of Vulkan extensions the window
  needs (used in file 04, GPU bring-up). Under the hood this is SDL telling you
  what it needs: *"Get the Vulkan instance extensions needed for creating a Vulkan
  surface."* — [SDL3 `SDL_Vulkan_GetInstanceExtensions`](https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetInstanceExtensions).
- the `getX11Handle` / `getWaylandHandle` / `getWin32Handle` getters — the raw
  handle the surface bridge (file 03) turns into a Vulkan surface.

Each getter returns `null` when the active OS / display server isn't that one, so
on Linux you try X11, then Wayland. Internally SDL stores these in *window
properties* (the cheat sheet calls this "the SDL3 way to reach native handles").

---

## A minimal window + input loop

Putting the five buckets together — this is the smallest complete platform app,
straight from the API doc:

```zig
const platform = @import("platform");

try platform.init(.{});
defer platform.deinit();

const win = try platform.Window.create(.{ .title = "demo", .renderer = .vulkan });
defer win.destroy();

platform.bindAction(.menu_pause, .{ .key = .escape });
while (!win.shouldClose()) {
    platform.pollAllEvents();
    while (platform.nextEvent()) |ev| switch (ev) {
        .resize => |r| { _ = r; /* recreate swapchain */ },
        else => {},
    };
    if (platform.actionJustPressed(.menu_pause)) break;
    // render with your GPU API of choice ...
}
```

`event-logger` (the first example app) is essentially this loop with the events
printed instead of dropped — a window with **no renderer at all** (`.none`), which
is how the project proves the windowing lib pulls in *zero* Vulkan.

---

## Where this sits in zGameLib

The framework re-exports the whole platform adapter unchanged as `zgame.platform`:

> "`pub const platform = @import("platform");` — Windowing + input (SDL3 backend)."
> — [`src/root.zig`](../../src/root.zig)

So everything above is reachable as `zgame.platform.*`. The high-level `App` (file
07) wraps the `init → loop → deinit` skeleton for you, but you can always reach
past it to the raw platform API.

---

## Bibliography

- **platform adapter** (this framework's windowing lib) —
  [`README.md`](../../libs/zig-cpp-platform-stack-adapter/README.md),
  [`docs/api.md`](../../libs/zig-cpp-platform-stack-adapter/docs/api.md),
  [`docs/sdl3-cheat-sheet.md`](../../libs/zig-cpp-platform-stack-adapter/docs/sdl3-cheat-sheet.md).
- **SDL3 wiki** — `SDL_Init`, `SDL_CreateWindow`, `SDL_PollEvent`,
  `SDL_GetWindowProperties`, `SDL_Vulkan_GetInstanceExtensions:`
  <https://wiki.libsdl.org/SDL3/>
- **SDL homepage** — <https://www.libsdl.org/>
- **zGameLib** — [`src/root.zig`](../../src/root.zig) (the `platform` re-export).

Quoted excerpts are © the SDL contributors and © this project's authors, used here
for teaching/commentary; consult the live SDL3 wiki for authoritative wording.
