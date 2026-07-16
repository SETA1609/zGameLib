# App-demo — design (rung 6, planned)

> The sixth rung of the [ladder](ladder.md): demonstrates the **optional**
> `zgame.App` convenience harness. This is where zGameLib's middleware layer
> becomes visible as an opt-in convenience.

**Status: stub.** The `App` harness at `src/app.zig` is not yet implemented.
When complete, this example will show:

1. `zgame.App.init(.{ .title = "app-demo", .size = .{ .w = 1280, .h = 720 } })` —
   a single call that handles platform init, Vulkan bring-up, swapchain, and the
   frame loop.
2. Registering callbacks: `app.setRenderFn(myRender)` and input handlers.
3. Running `app.run()` — the framework calls your render function each frame,
   handles acquire/present/resize/recreate automatically.

## Key: App is OPTIONAL

Even at this top rung, every raw API remains available:

```zig
const zgame = @import("zgame");

// Via the App harness:
var app = try zgame.App.init(.{ ... });
app.setRenderFn(myRender);
try app.run();

// OR: raw access (bypassing App entirely):
const vk = zgame.vk;
const platform = zgame.platform;
const my_surface = try zgame.surface.createSurface(instance, window);
// ... do it yourself
```

The `zgame.readme` states this directly: the building blocks stay re-exported
and reachable at all times. The App harness is sugar, not a cage.

## Pay-for-what-you-use demonstration

At rung 6, **every** sibling library is available, but only the ones actually
used by the application are compiled in. The App harness itself only pulls in
what you configure it to use. If your app doesn't need audio, zaudio isn't
compiled — even when using App.

## Libraries available at rung 6

| Library | Status | When compiled |
|---------|--------|---------------|
| platform | ✅ | always (needed for window) |
| vulkan_stack | ✅ | always (needed for GPU) |
| zClip | ⬜ optional | only if animation is configured |
| zaudio | ⬜ optional | only if audio is configured |
| zassets | ⬜ optional | only if assets are configured |

## Build

```sh
zig build app-demo    # requires zgame.App v0.1.0+
```
