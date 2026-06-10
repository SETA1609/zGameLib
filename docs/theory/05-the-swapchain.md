# 05 — The swapchain

*The rotating set of images you actually present to the window — and the policy
decisions (format, present mode, resize handling) that Vulkan leaves entirely to
you.*

`Gpu` (file 04) gave you a device and a surface. But you still can't show anything:
you need *images* to draw into and a mechanism to hand finished ones to the display.
That's the **swapchain**, and the framework's reusable implementation lives in
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
The framework's `Swapchain.build` makes a sensible default for each.

### 1. Which **format** (pixel layout + colour space)?

A surface supports a list of formats; you pick one. The framework prefers a
standard 8-bit sRGB format and falls back to whatever's first:

```zig
fn chooseFormat(...) !vk.SurfaceFormatKHR {
    // ... query the supported formats ...
    for (buf[0..n]) |f|
        if (f.format == .b8g8r8a8_srgb and f.color_space == .srgb_nonlinear_khr) return f;
    return buf[0]; // the first entry is always a valid choice
}
```

### 2. Which **present mode** (how images reach the display)?

This decides the vsync behaviour. The framework prefers `MAILBOX` (low-latency,
tear-free) but falls back to `FIFO` — and it can *always* fall back, because the
Vulkan spec guarantees FIFO exists everywhere:

> "`VK_PRESENT_MODE_FIFO_KHR` … is required to be supported."
> — [Vulkan spec, `VkPresentModeKHR`](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#VkPresentModeKHR)

As `frame.md` explains, FIFO is the safe default:

> "FIFO is the v-sync'd, tear-free queue ('first in, first out', one image per
> vertical blank) — a safe default for a toy."
> — [`shared/frame.md`](../../shared/frame.md)

```zig
fn choosePresentMode(...) !vk.PresentModeKHR {
    // ...
    for (buf[0..n]) |m| if (m == .mailbox_khr) return m;
    return .fifo_khr; // always present
}
```

### 3. What **extent** (size in pixels)?

Usually the surface dictates its own size; when it doesn't (some platforms report a
"you decide" sentinel), the framework clamps your requested size to the allowed
range:

```zig
fn chooseExtent(caps: vk.SurfaceCapabilitiesKHR, want: vk.Extent2D) vk.Extent2D {
    if (caps.current_extent.width != std.math.maxInt(u32)) return caps.current_extent;
    return .{ .width = std.math.clamp(want.width, caps.min_image_extent.width, caps.max_image_extent.width), ... };
}
```

It also picks an image count (`minImageCount + 1`, clamped) and creates one
**image view** per image (a view is how shaders/attachments reference an image).

---

## Recreation — the swapchain goes stale when the window changes

A swapchain is built for a *specific* window size. Resize the window and it no
longer fits — Vulkan reports this as `VK_ERROR_OUT_OF_DATE_KHR`:

> "A surface has changed in such a way that it is no longer compatible with the
> swapchain."
> — [Vulkan spec, return codes](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#fundamentals-errorcodes)

So the swapchain knows how to **recreate** itself. It waits for the device to idle,
builds a new one — handing the old swapchain over as `oldSwapchain` so the driver
can recycle resources — then destroys the old:

```zig
pub fn recreate(self: *Swapchain, want: vk.Extent2D) !void {
    try self.vkd.deviceWaitIdle(self.device);
    const old = self.handle;
    self.destroyViews();
    try self.build(want, old);          // pass old as oldSwapchain
    if (old != .null_handle) self.vkd.destroySwapchainKHR(self.device, old, null);
}
```

You won't usually call `recreate` directly — `FrameRing` (file 06) calls it for you
whenever acquire or present reports out-of-date. The swapchain just owns *how* to
rebuild; the frame loop owns *when*.

---

## Why this is framework policy, not lib API

This is a deliberate, repeated theme. The vulkan_stack adapter *does* ship its own
optional swapchain helper, but the framework keeps its own copy here in `shared/`,
because format/present-mode/recreation are **renderer policy** — consumer
decisions. The source says so:

> "Lives here in the examples repo (next to surface.zig), **not** in the vulkan lib
> — it's renderer policy (format/present-mode choice, recreation), which the lib
> deliberately leaves to the consumer."
> — [`shared/swapchain.zig`](../../shared/swapchain.zig)

And it is reused by every rung that draws, which is why it lives in the framework's
`shared/` tier alongside the surface bridge:

> "Owns the swapchain + its image views and knows how to recreate on resize. Reused
> by every rung from clear-color up."
> — [`shared/swapchain.zig`](../../shared/swapchain.zig)

So: the Vulkan lib gives you the raw `vkCreateSwapchainKHR`; the framework gives you
one conventional way to drive it; and your app gets a working swapchain in one
`gpu.createSwapchain(extent)` call — while every field stays public for when you
need a different policy.

---

## Where this sits in zGameLib

Re-exported as `zgame.swapchain`, and constructed via `Gpu`:

```zig
var chain = try gpu.createSwapchain(.{ .width = 1280, .height = 720 });
defer chain.deinit();
```

> "A reusable **swapchain** (renderer policy: format/present-mode/recreation)."
> — [`src/root.zig`](../../src/root.zig)

---

## Bibliography

- **zGameLib** — [`shared/swapchain.zig`](../../shared/swapchain.zig) (the
  implementation), [`shared/frame.md`](../../shared/frame.md) (present-mode notes),
  [`src/root.zig`](../../src/root.zig) (the re-export).
- **Khronos Vulkan specification** — `VkPresentModeKHR`, WSI, error codes:
  <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>
- **vulkan_stack adapter** —
  [`docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md),
  and its own optional `Swapchain` helper in
  [`docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md).

Quoted excerpts are © The Khronos Group and © this project's authors, used here for
teaching/commentary; consult the live Vulkan spec for authoritative wording.
