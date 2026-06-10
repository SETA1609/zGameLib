# 03 — The surface bridge

*The one seam where windowing meets rendering — and the rule that no shared type is
allowed to cross it.*

Files 01 and 02 introduced two independent sub-libraries: one knows about windows,
the other about the GPU. Neither imports the other. But to draw into a window,
Vulkan needs a handle *to* that window — so somewhere the two must meet. That
somewhere is **exactly one file**: [`shared/surface.zig`](../../shared/surface.zig).
This doc explains what it does and, more importantly, the discipline it enforces.

---

## What a "surface" is

A Vulkan **surface** (`vk.SurfaceKHR`) is the abstract handle that represents "the
window I will present to". The Vulkan spec defines it as the bridge between the OS
window and the GPU:

> "Native platform surface or window objects are abstracted by surface objects."
> — [Vulkan spec, *WSI*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_wsi_surface)

WSI ("Window System Integration") is deliberately *not* in core Vulkan — it's a set
of extensions, because how you reference a window is OS-specific. So creating a
surface always means: take an OS-native window handle, and call the matching
`vkCreate*SurfaceKHR` for that OS.

---

## The decoupling invariant — the heart of the project

Here is the rule that makes the whole architecture work, stated in the bridge's own
source comment:

> "Pairs the platform adapter's per-OS native-handle getter with the vulkan
> adapter's matching surface creator, branching on the target OS at comptime and
> passing **raw OS primitives** — no shared type crosses the boundary. This is the
> single place the two libs meet."
> — [`shared/surface.zig`](../../shared/surface.zig)

Read that twice. The two sub-libraries do **not** share a type. The windowing lib
hands out raw OS pointers and integers (an X11 `Display*` + a window XID; a Wayland
`wl_display*` + `wl_surface*`; a Win32 `HINSTANCE` + `HWND`). The Vulkan lib accepts
those same raw primitives and produces a surface. The bridge just *pairs them up*.

Why go to this trouble instead of letting SDL make the surface directly? SDL *can*
do it — but using it would re-couple the libraries. The framework's `gpu.md` is
explicit:

> "SDL *can* make the surface for you with `SDL_Vulkan_CreateSurface` … We
> deliberately do **not** use it: routing the raw handle through our own bridge is
> what keeps the windowing lib free of Vulkan types and the vulkan lib free of
> SDL."
> — [`shared/gpu.md`](../../shared/gpu.md)

That's the payoff: the windowing lib could be swapped for a native (non-SDL)
backend, or the Vulkan lib paired with a totally different window source, and
*neither change touches the other*. The bridge is the firewall.

---

## How it actually works — comptime OS branching

The window's display server is known partly at compile time (which OS) and partly
at runtime (on Linux: X11 *or* Wayland). The bridge handles both. Here is the whole
file's logic:

```zig
pub fn createSurface(instance: vk.Instance, window: *platform.Window) Error!vk.SurfaceKHR {
    if (comptime builtin.target.abi == .android) {
        const h = platform.getAndroidHandle(window) orelse return error.NoSupportedSurface;
        return vulkan_stack.createAndroidSurface(instance, h.window);
    }
    switch (comptime builtin.target.os.tag) {
        .linux => {
            if (platform.getX11Handle(window)) |h|
                return vulkan_stack.createX11Surface(instance, h.display, h.window);
            if (platform.getWaylandHandle(window)) |h|
                return vulkan_stack.createWaylandSurface(instance, h.display, h.surface);
            return error.NoSupportedSurface;
        },
        .windows => {
            const h = platform.getWin32Handle(window) orelse return error.NoSupportedSurface;
            return vulkan_stack.createWin32Surface(instance, h.hinstance, h.hwnd);
        },
        else => @compileError("surface bridge: unsupported target OS"),
    }
}
```

Notice the symmetry: every line is `platform.getXxxHandle(...)` feeding
`vulkan_stack.createXxxSurface(...)`. The left side is from file 01, the right side
from file 02, and the *only* values passed between them are raw OS primitives
(`h.display`, `h.window`, `h.surface`, `h.hinstance`, `h.hwnd`). On Linux it tries
X11 first, then Wayland, because either could be the active session. Other OSes have
exactly one path, chosen at `comptime`.

---

## The decoupling is *tested*, not just intended

This invariant is important enough that the project guards it with `nm` symbol
checks on the compiled binaries (the "decoupling checks"). In short:

- A **windowing-only** binary (renderer `.none`) must contain **none** of the
  Vulkan stack's symbols — no `vk.`-namespaced wrappers, no `volk`/`vma`/`shaderc_`.
- A **headless Vulkan** binary (no window) must contain **zero**
  `SDL_`/`x11`/`wayland` symbols.

A symbol leaking across that boundary is treated as a bug to fix immediately, not to
work around. That's how "the libs don't touch each other" stays *true* over time
rather than just being a nice intention.

---

## A template for future seams

This is the spot where the future-proofing note from the overview pays off. When a
new sub-library is added that must cooperate with another (say, an audio lib that
needs a window handle, or a video lib that shares a GPU device), the *pattern* is
already set: a tiny dedicated bridge file, branching where it must, passing only raw
primitives, sharing no type. The surface bridge is the first instance of a reusable
idea, not a one-off.

---

## Where this sits in zGameLib

Re-exported as `zgame.surface`, with `Gpu.init` (file 04) calling it for you:

> "The comptime platform↔vulkan **surface bridge** — the one place the two libs
> meet, passing raw OS primitives. `createSurface(instance, window)`."
> — [`src/root.zig`](../../src/root.zig)

You rarely call `surface.createSurface` directly — `Gpu` does — but knowing it
exists, and *why* it's a separate file, is the key to understanding the whole
project's shape.

---

## Bibliography

- **zGameLib** — [`shared/surface.zig`](../../shared/surface.zig) (the bridge),
  [`shared/gpu.md`](../../shared/gpu.md) (the "no `SDL_Vulkan_CreateSurface`"
  rationale), [`src/root.zig`](../../src/root.zig) (the re-export).
- **Khronos Vulkan specification** — WSI / surfaces:
  <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_wsi_surface>
- **platform adapter** — native-handle getters,
  [`docs/api.md`](../../libs/zig-cpp-platform-stack-adapter/docs/api.md).
- **vulkan_stack adapter** — surface creators,
  [`docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md).

Quoted excerpts are © The Khronos Group and © this project's authors, used here for
teaching/commentary; consult the live Vulkan spec for authoritative wording.
