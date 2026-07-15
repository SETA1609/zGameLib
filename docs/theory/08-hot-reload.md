# 08 — Hot reload at the foundation level

*What zGameLib can (and cannot) hot-reload, and how Tier 2 consumers hook into it.*

> **Release alignment:** Data hot reload primitives **v0.8.0** (alongside the 2D
> batcher); code hot reload out of scope for v1.

Hot reload means different things at different layers. At the **Tier 1** level —
a library of platform, GPU, and decode primitives — there is no "game" to reload,
no scene to patch, no script to swap. What zGameLib *can* offer is:

1. **Safe teardown and recreation** of GPU resources (swapchain, pipelines, buffers).
2. **Cache invalidation hooks** for decode results (images, meshes, audio).
3. **Event primitives** that Tier 2 uses to signal "something changed."

This document states what zGameLib provides and, equally important, what it
deliberately does **not** provide — so Tier 2 knows where the boundary lies.

---

## What hot reload means in a foundation library

zGameLib's modules are **stateless build-and-forget** for the most part: you call
`zgame.Gpu.init(window)`, you get a handle; you call `zassets.decodeImage(bytes)`,
you get pixels. There is no "running service" whose data needs live patching —
except where the library manages long-lived GPU or platform state.

```ascii
HOT RELOAD SCOPE BY MODULE
┌──────────────────────────────────────────────────────────────────┐
│ zgame.platform  —  window recreating, event pump, input rebind   │
│ zgame.Gpu       —  swapchain resize ✓ · device lost ✓            │
│ zgame.Swapchain —  rebuild on resize (always handled)            │
│ zgame.FrameRing —  no reload needed (transient per frame)        │
│ zgame.zassets   —  decode cache invalidate (consumer calls)      │
│ zgame.zclip     —  clip data swap (consumer calls)               │
│ zgame.zimgui    —  font atlas rebuild, style update              │
│ zgame.zfont     —  font atlas rebuild                            │
└──────────────────────────────────────────────────────────────────┘
```

None of these are "hot reload" in the game-engine sense. They are **library-level
lifecycle events** that a Tier 2 consumer can trigger in response to external
signals (file watcher, editor command, user action).

---

## Swapchain recreation — the one implicit hot reload

Every Vulkan application already handles one kind of hot reload: **swapchain
recreation**. When the window resizes, the old swapchain images no longer match
the drawable area, and the app must tear down and rebuild them. zGameLib's
`Swapchain` module handles this explicitly:

```zig
// From shared/swapchain.zig — pseudocode
pub fn rebuild(swapchain: *Swapchain, gpu: *Gpu, extent: vk.Extent2D) !void {
    gpu.device.deviceWaitIdle();
    swapchain.deinit(gpu);
    swapchain.* = try build(gpu, extent);
}
```

The `App` harness (file 07) calls this automatically on `.resize` events.
Any Tier 2 consumer that drives its own loop should do the same.

### Device lost — the hard reload

Vulkan can lose the device (driver crash, GPU removed, overlay interference).
When `vkAcquireNextImageKHR` or `vkQueuePresentKHR` returns
`VK_ERROR_DEVICE_LOST`, the entire GPU state must be rebuilt:

```zig
fn handleDeviceLost(gpu: *Gpu, window: *platform.Window) !void {
    gpu.deinit();
    gpu.* = try Gpu.init(window, .{});
    // Consumer must re-upload all GPU resources
}
```

zGameLib cannot abstract this away — the **consumer** owns the shaders, pipelines,
and buffers that live on the GPU. What zGameLib provides is the `Gpu.deinit` /
`Gpu.init` round-trip that leaves the handles in a known state. Tier 2's
`RenderingServer` is responsible for re-uploading its resource tables.

---

## Assets: decode cache is Tier 2's problem

zGameLib's planned `zassets` module is **decode-only**: it reads bytes and returns
CPU structs. It does not cache, track UIDs, or manage lifetimes. That means:

- **zGameLib has no "asset hot reload" to offer** — it doesn't know what an asset is.
- The consumer calls `zassets.decodeImage(bytes)` and gets pixels back. If the
  file changes on disk, it is the consumer's job to re-read, re-decode, and
  re-upload.

What zGameLib *can* provide is a **decode-once helper** that a Tier 2 resource
manager can wrap:

```zig
// illustrative — zgame.zassets might offer:
pub const ImageCache = struct {
    entries: std.StringHashMap(DecodedImage),

    pub fn getOrDecode(self: *ImageCache, path: []const u8, bytes: []const u8) !*DecodedImage {
        if (self.entries.get(path)) |existing| return existing;
        const decoded = try decodeImage(bytes);
        try self.entries.put(path, decoded);
        return self.entries.getPtr(path).?;
    }

    pub fn invalidate(self: *ImageCache, path: []const u8) void {
        _ = self.entries.remove(path);
    }
};
```

But the cache itself lives at **Tier 2** (ResourceDB in Nexus-engine, or an
equivalent in any consumer). zGameLib's role is to be **reentrant and stateless**
so that re-decoding is always safe.

---

## Platform input rebinding

The platform adapter (file 01) already supports action-mapped input:

```zig
platform.bindAction(Action.jump, .{ .key = .space });
```

Changing these bindings at runtime (in response to a settings file change or an
editor command) is **trivial** — the binding table is mutable state owned by the
platform module. There is no teardown, no re-init. This is the simplest form of
hot reload in the entire stack:

```zig
// Called when user edits keybinds
pub fn reloadBindings(bindings: []const BindingEntry) void {
    platform.clearActions();
    for (bindings) |b| platform.bindAction(b.action, b.input);
}
```

---

## Dear ImGui style update (Tier 1 optional)

When `zgame.zimgui` ships (late roadmap), it will expose:

```zig
pub fn reloadFontAtlas(imgui: *Imgui) void {
    imgui.io.fonts.clear();
    imgui.io.fonts.addFontFromFile("...");
    imgui.rebuildFontAtlas();
}

pub fn applyStyle(style: ImguiStyle) void {
    imgui.style = style;
}
```

This is genuine hot reload — editors and debug tools use it constantly. It is
immediate-mode by nature: the next frame draws with the new style or font. No
scene patching required.

---

## What zGameLib explicitly will NOT hot-reload

| Area | Why not |
|------|---------|
| **Scene data** | zGameLib has no scene concept |
| **Game logic** | zGameLib is not a runtime — it's a library |
| **Shader source → SPIR-V** | shaderc is a build-time or opt-in runtime tool; hot shader reload is a Tier 2 concern |
| **Audio streams** | Audio decoding is stateless; swapping clips is consumer-driven |

---

## Event hooks for Tier 2

zGameLib does not impose an event system. Instead, it exposes simple **callback
registration** on long-lived objects, and the consumer (Nexus-engine) bridges
these into its own `ReloadEventBus`:

```zig
// zgame.Swapchain
pub const OnResize = *const fn (new_extent: vk.Extent2D) void;
pub fn setResizeCallback(swapchain: *Swapchain, cb: OnResize) void;

// zgame.platform
pub const OnFileChange = *const fn (path: []const u8) void;
pub fn setFileWatcherCallback(cb: OnFileChange) void;  // optional, platform-permitting
```

These are narrow, typed hooks — not a general pub/sub system. Tier 2 wires them
into its own event bus (see the Nexus-engine hot reload doc).

---

## Summary

| Capability | zGameLib provides | Consumer must do |
|------------|-------------------|------------------|
| Swapchain resize | `Swapchain.rebuild()` | Handle `.resize` events |
| Device lost | `Gpu.deinit/init` round-trip | Re-upload all GPU resources |
| Image/asset re-decode | Stateless decode functions | Manage cache, re-upload |
| Input rebinding | Mutable action table (no teardown) | Call `bindAction` / `clearActions` |
| ImGui style/font | `reloadFontAtlas`, `applyStyle` | Trigger on file change |
| File watching | Optional callback on `platform` | Route to ResourceDB or editor |

**The principle:** zGameLib provides **safe rebuild primitives** and **typed
hooks**. It never owns the reload policy. That belongs to Tier 2.

---

## Comparison with other foundation layers

| Library | Hot reload approach |
|---------|---------------------|
| **SDL3** | No concept; application handles resize + device loss |
| **GLFW** | Same as SDL3 — callback per event |
| **Bevy** (as foundation) | Assets → `AssetServer` reload on file change; built-in event |
| **winit** (Rust) | Event loop owns resize; no asset concept |
| **zGameLib** | Rebuild primitives + typed hooks; policy deferred to consumer |

**zGameLib's design:** be a better C foundation layer, not a Bevy competitor.
Don't cache what the consumer should own; do provide clean teardown paths.

---

## Bibliography

- **zGameLib** — [`shared/swapchain.zig`](../../shared/swapchain.zig) (rebuild),
  [`shared/gpu.md`](../../shared/gpu.md) (device lost policy),
  [`shared/frame.md`](../../shared/frame.md) (acquire/present error handling).
- **Vulkan spec** — [`VK_ERROR_DEVICE_LOST`](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_devicelost),
  [Swapchain recreation](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#_swapchain_recreation).
- **Dear ImGui** — [Fonts and hot loading](https://github.com/ocornut/imgui/blob/master/docs/FONTS.md).
- **Nexus-engine hot reload** — [08-hot-reload-nexus-engine.md](../../../docs/theory/08-hot-reload-nexus-engine.md)
  (Tier 2 consumer of these primitives).

Quoted excerpts are © The Khronos Group and © this project's authors, used here
for teaching/commentary; consult the live Vulkan spec for authoritative wording.
