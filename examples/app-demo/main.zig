const std = @import("std");

/// App-demo — rung 6 (planned).
///
/// Uses the full zgame.App middleware harness. This example is a STUB —
/// the App harness is not yet implemented.
///
/// When complete, it will demonstrate:
///   1. zgame.App.init() — single call for platform + vulkan + default loop.
///   2. Registering a render callback (called each frame by App).
///   3. Registering an input callback.
///   4. Running the App loop — the framework handles acquire/present/recreate.
///
/// Even at this rung, raw access remains:
///   - zgame.platform, zgame.vk, zgame.vma are all still reachable.
///   - The App loop can be bypassed by writing your own while-loop.
///
/// Libraries compiled:
///   - All sibling libs (platform, vulkan_stack, zClip, zaudio, zassets)
///   - zgame.App middleware
///
/// Key insight: the App middleware is OPTIONAL. Every raw API is still
/// re-exported and usable directly.
pub fn main() !void {
    // TODO:
    // var app = try zgame.App.init(.{
    //     .title = "app-demo",
    //     .size = .{ .w = 1280, .h = 720 },
    // });
    // defer app.deinit();
    //
    // try app.setRenderFn(myRender);
    // try app.run();

    std.debug.print("app-demo: stub — zgame.App harness not yet implemented\n", .{});
}
