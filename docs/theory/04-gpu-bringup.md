# 04 — GPU bring-up: the `Gpu` helper

*The framework's first convenience layer: one call that builds the whole Vulkan
object chain — loader → instance → surface → device → queue — in the only order
that works.*

File 02 showed that Vulkan objects form a strict hierarchy, each depending on the
one before. Building that chain is identical for every app — `clear-color`,
`hello-triangle`, and every later rung do exactly the same handshake. So the
framework lifts it into one helper, `Gpu`, in [`shared/gpu.zig`](../../shared/gpu.zig).

> This file is the **beginner-facing** tour. The framework also ships
> [`shared/gpu.md`](../../shared/gpu.md), a deeper "why" note written against the
> exact `vk` calls — read that next once this clicks.

---

## The chain you must build

`gpu.md` draws the dependency chain — each link needs the one before it:

```
volk loader  →  VkInstance  →  VkSurfaceKHR  →  VkPhysicalDevice
                                                      ↓
                              VkQueue  ←  VkDevice (+ VK_KHR_swapchain)
```

> "`Gpu.init(window, .{})` builds that chain once and hands back every handle as a
> public field. None of it is app-specific — it is identical for `clear-color`,
> `hello-triangle`, and every later rung — which is exactly why it belongs in the
> framework rather than copy-pasted into each `main.zig`."
> — [`shared/gpu.md`](../../shared/gpu.md)

Your whole interaction is one line:

```zig
var gpu = try zgame.Gpu.init(window, .{});
defer gpu.deinit();
```

Now let's walk the five steps it does for you.

---

## 1. The loader and the instance

First, load Vulkan's entry points (file 02, "idea 1") with `volk`, then create the
**instance** — the root of the whole object model:

> "There is no global state in Vulkan and all per-application state is stored in a
> `VkInstance` object."
> — [Vulkan spec, *Instances*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#initialization-instances)

The subtle part is **which extensions** to enable on the instance. WSI is
platform-specific, and only the windowing layer knows which extensions a surface
will need. So `Gpu` asks the window:

> "Get the Vulkan instance extensions needed for creating a Vulkan surface."
> — [SDL3 `SDL_Vulkan_GetInstanceExtensions`](https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetInstanceExtensions)

That's exactly what `platform.requiredVulkanInstanceExtensions()` returns, and
`Gpu.init` feeds it straight into instance creation. As `gpu.md` warns:

> "Skip this and surface creation later will fail — the surface extension simply
> won't be enabled on the instance."
> — [`shared/gpu.md`](../../shared/gpu.md)

This is the concrete reason file 01's `requiredVulkanInstanceExtensions()` and file
03's surface bridge are two ends of the same thread.

---

## 2. The surface — the cross-lib seam

`Gpu` now turns the window into a `vk.SurfaceKHR` by calling the bridge from file
03 (`surface.createSurface(instance, window)`). This is the *one* point where
windowing and rendering meet, passing only raw OS primitives. Nothing more to say
here that file 03 didn't — but note that `Gpu` is the thing that *calls* the bridge,
so in practice you get the surface "for free" as a field on `gpu`.

---

## 3. Physical device + a present-capable queue family

A **physical device** is a GPU as the driver reports it. Work is submitted to
*queues*, which come from *families* with different capabilities — and crucially,
being able to *present* to your surface is a property you must **query**, not
assume:

> "Not all physical devices will include WSI support."
> — [Vulkan spec, *WSI*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_wsi_surface)

`Gpu` walks the queue families calling `vkGetPhysicalDeviceSurfaceSupportKHR` and
takes the first that supports the surface (or errors with `NoPresentQueue`). As
`gpu.md` is candid about, the policy is intentionally minimal:

> "These toys pick the **first** physical device and a **single** present-capable
> family — fine for 2D smoke tests, and the one honest place to add real selection
> later."
> — [`shared/gpu.md`](../../shared/gpu.md)

This is the raw-first philosophy in miniature: `Gpu` makes a simple choice and
leaves every handle public so you can make a smarter one when you need to.

---

## 4. The logical device, the queue, and `VK_KHR_swapchain`

From the physical device, `Gpu` creates a **logical device** (`VkDevice`) — the
handle through which nearly all work flows — and fetches the **queue** to submit
to. Two details `gpu.md` flags:

> "We request the **`VK_KHR_swapchain`** *device* extension. WSI is split: the
> surface lives at instance scope, but the swapchain (the actual rotating set of
> presentable images) is a device-level extension and must be enabled here."
> — [`shared/gpu.md`](../../shared/gpu.md)

and it requests Vulkan **API version 1.3** so later stages (and VMA) have the
modern entry points available. After `vkCreateDevice`, it loads the *device-level*
dispatch (faster — "idea 1" again) and grabs queue 0 of the chosen family.

---

## 5. `transitionImage` — a bonus helper for image layouts

`Gpu` also exposes a free function, `transitionImage`. A Vulkan image isn't just
memory — it has a **layout**, and the GPU expects the right layout for each use
(one layout to clear into, another to hand to the display). You change layout, and
order GPU work, with a *pipeline barrier*:

> "Vulkan provides synchronization primitives that allow the application to control
> the order of execution of operations on the device."
> — [Vulkan spec, *Synchronization and Cache Control*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization)

`transitionImage` fills in the boilerplate of an image-memory barrier and exposes
only the parts that vary (the two layouts and four masks), so each rung can do its
`UNDEFINED → … → PRESENT_SRC` layout dance without re-typing it.

---

## What you get back

Every step's result is a **public field** on the returned `Gpu`:

```zig
pub const Gpu = struct {
    instance: vk.Instance,
    vkb: vk.BaseWrapper,
    vki: vk.InstanceWrapper,
    surface: vk.SurfaceKHR,
    pdev: vk.PhysicalDevice,
    qfam: u32,
    device: vk.Device,
    vkd: vk.DeviceWrapper,
    queue: vk.Queue,
    // ...
};
```

Plus two conveniences: `gpu.createSwapchain(extent)` (file 05) and `gpu.waitIdle()`
(call before tearing down frame resources). The transparency is the whole point, as
the source says:

> "Stays **transparent** like the rest of zGameLib: every handle and dispatch table
> is a public field, so an app that outgrows this drops straight to the raw `vk`
> calls — nothing is hidden."
> — [`shared/gpu.zig`](../../shared/gpu.zig)

---

## Why this is framework policy, not lib API

The vulkan_stack adapter (file 02) deliberately stops at "here are the typed `vk`
calls + the surface creators". *Which* device, *which* queue, *whether* to enable
the swapchain extension — those are **consumer decisions**:

> "*Which* device to pick, *which* queue, *whether* to enable the swapchain
> extension — that is **renderer policy**, the consumer's call. `Gpu` encodes one
> reasonable policy for these examples while keeping every handle public."
> — [`shared/gpu.md`](../../shared/gpu.md)

That's why `Gpu` lives in zGameLib (in `shared/`, next to `surface.zig` and
`swapchain.zig`) and *not* inside the Vulkan lib.

---

## Bibliography

- **zGameLib** — [`shared/gpu.zig`](../../shared/gpu.zig) (the implementation),
  [`shared/gpu.md`](../../shared/gpu.md) (the deep "why" note),
  [`src/root.zig`](../../src/root.zig) (the `Gpu` re-export).
- **Khronos Vulkan specification** — Initialization/Instances, Devices & Queues,
  WSI, Synchronization:
  <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>
- **SDL3 wiki** — `SDL_Vulkan_GetInstanceExtensions`:
  <https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetInstanceExtensions>

Quoted excerpts are © The Khronos Group, © the SDL contributors, and © this
project's authors, used here for teaching/commentary; consult the live specs for
authoritative wording.
