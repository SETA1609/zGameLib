# Reactive clear-color — design (rung 1)

> **Status: implemented** — `examples/clear-color/main.zig` builds and runs (`zig build clear-color`). The surface bridge shipped as [`../../shared/surface.zig`](../../shared/surface.zig) and the swapchain as the reusable [`../../shared/swapchain.zig`](../../shared/swapchain.zig) helper (renderer policy — it lives in this repo, not the vulkan lib). As shipped, the clear-colour cycles a 6-colour palette one colour per second (a `platform.now()` timer) rather than tracking mouse/keys, and the app quits on window close. The rest of this doc is the original design.

> **Rung 1** of the [ladder](ladder.md) — the first app that exercises **both**
> adapters together (platform + vulkan, joined at the comptime surface bridge).
> It's deliberately the smallest such program, so it isolates *"do the two libs
> talk to each other?"* from *"can I draw geometry?"*. If this runs clean under
> the validation layers, the whole decoupled-adapter architecture is proven.

## What it does

Opens a window through `platform`, builds a Vulkan surface + swapchain through `vulkan_stack`, and every frame clears the swapchain image to a colour that **reacts to input** (mouse X → hue, or a keypress cycles it). Resize recreates the swapchain; ESC quits. **No vertex buffers, no shaders** — just acquire → clear → present.

## What building it forces into existence

| Lib | Milestone | Pieces used |
| --- | --- | --- |
| platform | **v0.6.0** | window + event pump + `getX11Handle`/`getWin32Handle` + `requiredVulkanInstanceExtensions()` + minimal `bindAction`/`actionJustPressed` |
| vulkan | **v0.2.0** | `vk` re-export (v0.1.0) + volk loader + `createX11Surface`/`createWin32Surface` |
| this repo | — | `shared/surface.zig` (the bridge) + `shared/swapchain.zig` (the swapchain helper) |

## The surface bridge (`shared/surface.zig`)

The one place the two adapters meet — comptime-branched on the target OS so each build contains only the matching arm. No shared type crosses; it pairs a platform *getter* with a vulkan *creator*:

```
createSurface(instance, window):
  comptime switch (target.os):
    .linux:   if getWaylandHandle(window) |h| → createWaylandSurface(instance, h.display, h.surface)
              else getX11Handle(window) |h|    → createX11Surface(instance, h.display, h.window)
    .windows: getWin32Handle(window) |h|       → createWin32Surface(instance, h.hinstance, h.hwnd)
```

## Frame loop (the lib calls, in order)

**Setup**
1. `platform.init(.{})`; `platform.Window.create(.{ .renderer = .vulkan })`.
2. `const exts = platform.requiredVulkanInstanceExtensions();` → create `vk.Instance` (those extensions + `VK_LAYER_KHRONOS_validation` in debug).
3. `const surf = try surface.createSurface(instance, window);` (the bridge above).
4. Pick physical device + graphics/present queue → `vk.Device` → swapchain + image views → command pool + per-frame command buffer + acquire/submit semaphores + in-flight fence.

**Loop** (until close / ESC)
5. `platform.pollAllEvents()`; drain `platform.nextEvent()`:
   - `.close` → stop · `.resize` → flag swapchain-recreate · `.mouse_motion` / `.key` → update target colour.
6. `if (platform.actionJustPressed(.menu_pause)) break;`
7. Acquire image → record a clear to `target_color` (`vkCmdClearColorImage`, or a render pass with `loadOp = .clear`) → submit → present. On `error.OutOfDateKHR`, recreate the swapchain.

**Teardown**: `vkDeviceWaitIdle` → destroy Vulkan objects → `window.destroy()` → `platform.deinit()`.

## Done when

- Window opens; the background colour visibly tracks input; resizing doesn't crash (swapchain recreates); ESC quits cleanly.
- **Zero validation-layer messages**; steady 60 fps with vsync.

## Build

Per the [libs-first / link-the-artifact model](../../libs/README.md): the example imports the adapters' Zig modules and links their compiled static artifacts. It is already wired in [`../../build.zig`](../../build.zig):

```sh
zig build clear-color
```
