# 05 — The swapchain

*The rotating set of images you actually present to the window — and the policy
decisions (format, present mode, resize handling) that Vulkan leaves entirely to
you.*

`Gpu` (file 04) gave you a device and a surface. But you still can't show anything:
you need *images* to draw into and a mechanism to hand finished ones to the display.
That's the **swapchain**. The Vulkan adapter builds it (its opt-in `Swapchain`
helper), and the framework chooses the policy and wraps it in
[`shared/swapchain.zig`](../../shared/swapchain.zig).

---

## What a swapchain is

The Vulkan cheat sheet's one-liner:

> "**Swapchain** — The ring of images you present to the surface."
> — [vulkan adapter, `docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md)

The idea: rather than drawing directly to the screen, you own a small set (commonly
2–3) of off-screen images. Each frame you draw into one, then *present* it (queue it
for display) while drawing into the next. That rotation is what gives you smooth,
tear-free animation. You don't create images per frame — you *borrow* one from the
swapchain each frame and give it back (file 06 covers that acquire/present dance).

---

## Three policy choices the swapchain bakes in

Building a swapchain means answering three questions Vulkan won't answer for you.
The Vulkan adapter answers each with a pure `select*` function over what the
surface reports; the framework decides which answer it *wants* by passing
`framework_options` (in [`shared/swapchain.zig`](../../shared/swapchain.zig)):

```zig
pub const framework_options: vulkan_stack.Swapchain.Options = .{
    .preferred_format = .{ .format = .b8g8r8a8_srgb, .color_space = .srgb_nonlinear_khr },
    .preferred_present_mode = .mailbox_khr,
    .desired_image_count = 0, // the adapter reads 0 as minImageCount + 1
    .image_usage = .{ .color_attachment = true, .transfer_dst = true },
};
```

Every field is a *wish*: the adapter clamps it against the surface's capabilities.

### 1. Which **format** (pixel layout + colour space)?

A surface supports a list of formats; you pick one. The framework asks for 8 bits
per channel in blue-green-red-alpha order, in the standard red-green-blue colour
space (`.b8g8r8a8_srgb` with `.srgb_nonlinear_khr`); `selectSurfaceFormat` returns
it when the surface lists it and otherwise falls back to the first entry, which is
always a valid choice.

### 2. Which **present mode** (how images reach the display)?

This decides how finished images wait for the display's refresh. The framework
asks for mailbox mode (`.mailbox_khr`): a newly finished image replaces the one
already waiting, so the picture never tears and the delay stays short.
`selectPresentMode` falls back to first-in-first-out mode (`.fifo_khr`): finished
images wait in a queue and the display shows one per refresh. It can *always* fall
back, because the Vulkan specification requires every driver to support
first-in-first-out mode:

> "`VK_PRESENT_MODE_FIFO_KHR` … is required to be supported."
> — [Vulkan spec, `VkPresentModeKHR`](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#VkPresentModeKHR)

As `frame.md` explains, FIFO is the safe default:

> "FIFO is the v-sync'd, tear-free queue ('first in, first out', one image per
> vertical blank) — a safe default for a toy."
> — [`shared/frame.md`](../../shared/frame.md)

### 3. What **extent** (size in pixels)?

Usually the surface dictates its own size. When it doesn't (Wayland and headless
surfaces report a "you decide" sentinel), `selectExtent` clamps the size you asked
for to the allowed range. `gpu.createSwapchain(allocator, extent)` and
`recreate(extent)` pass that size as the adapter's `fallback_extent`.

A minimized window is the odd case: its surface can report a 0×0 extent, and no
swapchain can have zero pixels. The adapter reports it as an error instead of
building a broken swapchain:

> "A 0×0 surface (a minimized window) is `SurfaceHasZeroExtent`: wait for a resize,
> then `recreate`."
> — [vulkan adapter, `docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md)

The adapter also picks the image count (`minImageCount + 1`, clamped), keeps only
the image usage the surface supports (colour attachment is required), picks a
supported composite-alpha mode, and creates one **image view** per image (a view is
how shaders/attachments reference an image).

---

## Recreation — the swapchain goes stale when the window changes

A swapchain is built for a *specific* window size. Resize the window and it no
longer fits — Vulkan reports this as `VK_ERROR_OUT_OF_DATE_KHR`:

> "A surface has changed in such a way that it is no longer compatible with the
> swapchain."
> — [Vulkan spec, return codes](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#fundamentals-errorcodes)

(The `_KHR` / `_khr` / `KHR` ending on Vulkan names marks something defined by an
extension the Khronos Group, which publishes Vulkan, has approved; swapchains and
surfaces come from such extensions. Zig's bindings drop the `VK_ERROR_` prefix, so
this error is `error.OutOfDateKHR` in code.)

So the swapchain knows how to **recreate** itself. The adapter builds the new one
with the old swapchain handed over as `oldSwapchain` (so the driver can recycle
resources), waits for the device to go idle, and only then destroys the old one:

> "`recreate` waits for the device to go idle before it destroys the old swapchain,
> and keeps the old one if building the new one fails."
> — [vulkan adapter, `docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md)

That order matters: if the rebuild fails (a 0×0 surface, a lost device), you still
hold a valid swapchain. The framework's `recreate` adds only what the adapter's call
needs and refreshes its public fields:

```zig
pub fn recreate(self: *Swapchain, want: vk.Extent2D) Error!void {
    try self.adapter_swapchain.recreate(self.allocator, self.vki, self.vkd, self.pdev, self.device, self.surface, want);
    self.refreshMirroredFields();
}
```

You won't usually call `recreate` directly — `FrameRing` (file 06) calls it for you
whenever acquire or present reports out-of-date, and treats `SurfaceHasZeroExtent`
as "skip frames until the window is restored". The swapchain owns *how* to rebuild;
the frame loop owns *when*.

---

## Mechanism in the adapter, policy in the framework

This is a deliberate, repeated theme: the libraries own the mechanism, the framework
owns the decisions. For the swapchain the split is:

| Who | Owns | Where |
| --- | --- | --- |
| Vulkan adapter | creating the swapchain and its views, recreating with the old one handed over and kept on failure, the 0×0 error, checking usage and composite alpha against the surface, the `select*` defaults | `vulkan_stack.Swapchain` |
| zGameLib | which format, present mode, image count, and usage to ask for (`framework_options`); when to recreate (`FrameRing`) | `shared/swapchain.zig`, `shared/frame.zig` |

The adapter's helper is opt-in and never blocks raw Vulkan:

> "A **two-tier** convenience over the raw `vk` swapchain API. The raw path is
> **never blocked**"
> — [vulkan adapter, `docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md)

So one copy of the Vulkan calls is tested in the adapter (its tests run on a
headless surface, without a window), and the framework stays small. Nothing is
hidden: `chain.adapter_swapchain` is the adapter's helper itself, `toRaw()` on it
returns the exact `vk.SwapchainCreateInfoKHR` used, and a different policy is a
different `Options` value passed to `vulkan_stack.Swapchain.create`.

---

## Where this sits in zGameLib

Re-exported as `zgame.swapchain`, and constructed via `Gpu`. The adapter keeps the
image and view lists on the heap, so creating a swapchain takes an allocator:

```zig
var chain = try gpu.createSwapchain(allocator, .{ .width = 1280, .height = 720 });
defer chain.deinit();
```

The public fields `handle`, `format`, `extent`, `images`, `views`, and `count`
mirror the adapter's helper after every create and recreate.

---

## Bibliography

- **zGameLib** — [`shared/swapchain.zig`](../../shared/swapchain.zig) (the policy
  and the wrapper), [`shared/frame.md`](../../shared/frame.md) (present-mode notes),
  [`src/root.zig`](../../src/root.zig) (the re-export).
- **Khronos Vulkan specification** — `VkPresentModeKHR`, WSI, error codes:
  <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>
- **vulkan_stack adapter** —
  [`docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md),
  and the `Swapchain` helper the framework builds on, in
  [`docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md) and
  [`src/swapchain.zig`](../../libs/zig-cpp-vulkan-stack-adapter/src/swapchain.zig).

Quoted excerpts are © The Khronos Group and © this project's authors, used here for
teaching/commentary; consult the live Vulkan spec for authoritative wording.
