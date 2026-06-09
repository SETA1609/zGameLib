# `gpu.zig` — the theory behind Vulkan bring-up

Companion to [`gpu.zig`](./gpu.zig). It explains *why* `Gpu.init` does the five
things it does, in the order it does them, and what each one means in the Vulkan
and SDL3 models. The code is the "how"; this is the "why".

> **On the quotes below.** Each `>` block is a short excerpt from the official
> Khronos Vulkan specification or the SDL3 wiki, with a link to the source. They
> are quoted for commentary/teaching; the live specs are authoritative — follow
> the links for the full, current wording. Excerpts © The Khronos Group /
> © the SDL contributors under their respective licenses.

---

## The shape of the problem

A Vulkan app cannot draw until a chain of objects exists, and each link depends
on the one before it:

```
volk loader  →  VkInstance  →  VkSurfaceKHR  →  VkPhysicalDevice
                                                      ↓
                              VkQueue  ←  VkDevice (+ VK_KHR_swapchain)
```

`Gpu.init(window, .{})` builds that chain once and hands back every handle as a
public field. None of it is app-specific — it is identical for `clear-color`,
`hello-triangle`, and every later rung — which is exactly why it belongs in the
framework rather than copy-pasted into each `main.zig`.

---

## 1. The loader and the instance

Vulkan is not a normal shared library you call directly; the entry points must
be *loaded*. We use **volk** to load the base entry points (`volk.loadBase()`),
then create a `VkInstance`. The instance is the per-application Vulkan handle.

The Vulkan spec describes the instance as the root of the API's object model:

> "There is no global state in Vulkan and all per-application state is stored in
> a `VkInstance` object."
> — [Vulkan spec, *Instances*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#initialization-instances)

### Why the window picks the extensions

WSI (Window System Integration) is *not* in core Vulkan — it's a set of
extensions, and which ones you need depends on the platform (X11 vs Wayland vs
Win32 vs …). The windowing layer is the only thing that knows. In our stack the
platform adapter wraps SDL3, whose job is precisely this:

> "Get the Vulkan instance extensions needed for creating a Vulkan surface."
> — [SDL3 `SDL_Vulkan_GetInstanceExtensions`](https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetInstanceExtensions)

That is what `platform.requiredVulkanInstanceExtensions()` returns, and why
`Gpu.init` feeds it straight into `VkInstanceCreateInfo.ppEnabledExtensionNames`.
Skip this and surface creation later will fail — the surface extension simply
won't be enabled on the instance.

---

## 2. The surface — the one cross-lib seam

A `VkSurfaceKHR` is the abstract handle Vulkan uses for "the thing you present
to". It is the bridge between the OS window and the GPU:

> "Native platform surface or window objects are abstracted by surface objects."
> — [Vulkan spec, *WSI*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_wsi_surface)

Crucially, **no shared type crosses the lib boundary here**. The platform adapter
hands out *raw OS primitives* (an X11 `Display*` + window XID, a Wayland
`wl_display*` + `wl_surface*`, …) — pulled from SDL via its window properties,
e.g. `SDL_PROP_WINDOW_X11_DISPLAY_POINTER`
([SDL3 `SDL_GetWindowProperties`](https://wiki.libsdl.org/SDL3/SDL_GetWindowProperties)) —
and the vulkan adapter turns them into a surface with the matching
`vkCreate*SurfaceKHR`. `Gpu.init` reaches this through `surface.createSurface`
(see [`surface.zig`](./surface.zig)), so the two adapters stay decoupled.

> Note: SDL *can* make the surface for you with `SDL_Vulkan_CreateSurface`
> ("Create a Vulkan rendering surface for a window" —
> [SDL3](https://wiki.libsdl.org/SDL3/SDL_Vulkan_CreateSurface)). We deliberately
> do **not** use it: routing the raw handle through our own bridge is what keeps
> the windowing lib free of Vulkan types and the vulkan lib free of SDL.

---

## 3. Physical device + the present queue family

A `VkPhysicalDevice` is a GPU as the driver reports it. Work is submitted to
*queues*, and queues come from *families* with different capabilities. For
presentation we need a family that supports our surface — a property you must
*query*, because graphics-capable and present-capable are not guaranteed to be
the same family:

> "Not all physical devices will include WSI support."
> — [Vulkan spec, *WSI*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_wsi_surface)

`presentQueueFamily` walks the families calling
`vkGetPhysicalDeviceSurfaceSupportKHR` and returns the first that says yes (or
`error.NoPresentQueue`). These toys pick the **first** physical device and a
**single** present-capable family — fine for 2D smoke tests, and the one honest
place to add real selection later.

---

## 4. The logical device, the queue, and `VK_KHR_swapchain`

The `VkDevice` is the logical handle through which nearly all work is done; from
it we retrieve the `VkQueue` we submit to. Two details matter:

- We request the **`VK_KHR_swapchain`** *device* extension. WSI is split: the
  surface lives at instance scope, but the swapchain (the actual rotating set of
  presentable images) is a device-level extension and must be enabled here.
- We request **API version 1.3** on the instance (`Gpu.Options.api_version`), so
  the core 1.1+ entry points later stages (and VMA) rely on are promoted in.

After `vkCreateDevice` we load the device-level entry points
(`vk.DeviceWrapper.load`) and fetch queue 0 of our family with
`vkGetDeviceQueue`.

---

## 5. `transitionImage` — image layouts and pipeline barriers

This free function is small but encodes a core Vulkan idea: an image is not just
memory, it has a **layout**, and the GPU expects the right layout for each use
(transfer-dst to clear into, present-src to hand to the display). You change
layout — and order GPU work — with a *pipeline barrier*.

> "Vulkan provides synchronization primitives that allow the application to
> control the order of execution of operations on the device."
> — [Vulkan spec, *Synchronization and Cache Control*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization)

A `VkImageMemoryBarrier` does two jobs at once:

1. **Execution + memory dependency** — `srcStageMask`/`dstStageMask` plus the
   access masks make sure earlier writes are *finished and visible* before the
   later use reads them (avoiding read-before-write hazards).
2. **Layout transition** — `oldLayout` → `newLayout` reorganizes the image for
   its next purpose.

`transitionImage` fixes the boring parts (full colour subresource range,
`QUEUE_FAMILY_IGNORED` since we don't transfer ownership) and exposes only the
four masks + two layouts that actually vary per call. `hello-triangle` will reuse
it unchanged for the `UNDEFINED → COLOR_ATTACHMENT_OPTIMAL → PRESENT_SRC` dance.

---

## Why this lives in zGameLib, not the vulkan adapter

The vulkan adapter deliberately stops at "here are the typed `vk` calls + the
surface creators". *Which* device to pick, *which* queue, *whether* to enable the
swapchain extension — that is **renderer policy**, the consumer's call. `Gpu`
encodes one reasonable policy for these examples while keeping every handle
public, so an app that needs a different one drops to the raw `vk` calls without
fighting the abstraction. Same principle as [`swapchain.zig`](./swapchain.zig).

---

## Sources

- Khronos **Vulkan 1.3 specification** — Initialization, Devices and Queues, WSI,
  Synchronization: <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>
- **SDL3 wiki** — `SDL_Vulkan_GetInstanceExtensions`, `SDL_Vulkan_CreateSurface`,
  `SDL_GetWindowProperties`: <https://wiki.libsdl.org/SDL3/>

Quoted excerpts are © The Khronos Group and © the SDL contributors, used here for
teaching/commentary; consult the live specs for authoritative wording.
