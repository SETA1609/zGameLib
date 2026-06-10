# 07 — The `App` harness

*The top of the stack: the high-level loop that ties a window to a frame loop — and
the deliberate reason you can ignore it entirely.*

Everything so far has been a building block: a window (file 01), the Vulkan stack
(file 02), the surface bridge (03), and the three render helpers `Gpu` / `Swapchain`
/ `FrameRing` (04–06). `App` is the layer that's *meant* to wire them together into
a single "open a window and run" object, so a simple app doesn't even assemble the
pieces by hand.

---

## Status: a stub by design

Be honest with yourself reading the source — `App` is **not implemented yet**. Its
bodies `@panic`:

> "The high-level application harness — window + frame loop … Stub for now — bodies
> `@panic` until the loop + renderer land. See ROADMAP."
> — [`src/app.zig`](../../src/app.zig)

This is the expected state of the project's top rung, not a bug. The framework's
README is upfront about it:

> "the high-level layer (`App`, renderer, assets) is being built out."
> — [zGameLib README](../../README.md)

So this doc describes the *intended* shape and, more usefully, the principle that
governs it.

---

## The intended shape

`App` is meant to own the boring lifecycle skeleton — bring the platform up, open a
window, expose "are we still running?", and pump events — so your `main` is a tight
loop. The intended surface, from the source:

```zig
pub const App = struct {
    window: *platform.Window,

    pub const Options = struct {
        title: []const u8 = "zGame",
        width: u32 = 1280,
        height: u32 = 720,
        renderer: platform.Renderer = .vulkan,   // which renderer the window binds
    };

    pub fn init(options: Options) !App;     // bring platform up + open the window
    pub fn deinit(self: *App) void;          // tear window + platform down
    pub fn running(self: *App) bool;         // true until asked to close — drives the loop
    pub fn pumpEvents(self: *App) void;      // pump one frame of events
};
```

Read against file 01, every method maps to something you already know: `init` is
`platform.init` + `Window.create`; `running` is `!window.shouldClose()`; `pumpEvents`
is `pollAllEvents` + draining the queue. `App` is sugar over the platform loop — and
in time it will also wire in the `Gpu`/`Swapchain`/`FrameRing` render path.

---

## The principle: you are never forced to use it

This is the most important thing to take from this doc, and it's the same raw-first
rule from the overview applied at the very top. The `App` source states it plainly:

> "Opt-in: you can ignore `App` entirely and drive `zgame.platform` / `zgame.vk`
> yourself."
> — [`src/app.zig`](../../src/app.zig)

and the module root frames the two tiers:

> "1. **High-level** — `App` (the loop), and the renderer/asset helpers to come. 2.
> **The building blocks, re-exported** — reach `zgame.platform`, `zgame.vk`,
> `zgame.vma`, … directly and drive the raw APIs whenever you outgrow the
> convenience layer. Nothing is hidden; you never get stuck."
> — [`src/root.zig`](../../src/root.zig)

So there are always (at least) two ways to write a zGameLib app:

1. **Top-down with `App`** (once it lands) — `App.init`, loop on `App.running`,
   `App.pumpEvents`. Shortest for a conventional app.
2. **Bottom-up with the building blocks** — assemble `platform.Window` + `Gpu` +
   `Swapchain` + `FrameRing` yourself. This is exactly what today's example apps do,
   and what you'll do the moment your loop is non-standard.

Neither is "the wrong way". The framework's value is that climbing down from (1) to
(2) — or mixing them — never means fighting a hidden abstraction, because every
layer re-exported the one below it.

---

## How it fits the future-proofing note

`App`'s `Options` already carries a `renderer` field and the README mentions
"renderer, assets" helpers to come. As new sibling sub-libraries arrive (audio,
animation — see the overview), `App` is the natural place their lifecycle gets
wired in too: one `App.init` bringing up window + GPU + audio, one loop pumping all
of them. The stub is small today precisely so it can grow without locking in a
shape.

---

## Bibliography

- **zGameLib** — [`src/app.zig`](../../src/app.zig) (the harness, currently a stub),
  [`src/root.zig`](../../src/root.zig) (the two-tier statement + re-exports),
  [`README.md`](../../README.md) (status of the high-level layer).
- **platform adapter** — `Window`, `Renderer`, the event loop:
  [`docs/api.md`](../../libs/zig-cpp-platform-stack-adapter/docs/api.md).

Quoted excerpts are © this project's authors, used here for teaching/commentary.
