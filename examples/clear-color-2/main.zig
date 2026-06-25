//! Clear-color, rebuilt on the zGameLib abstractions.
//!
//! Identical behaviour to `../clear-color` — an animated full-screen clear,
//! presented every frame, swapchain recreated on resize — but the Vulkan
//! bring-up and the frames-in-flight machinery now come from the framework:
//!
//!   - `zgame.Gpu`            — loader → instance → surface → device → queue
//!   - `zgame.FrameRing(N)`   — command buffers + sync + the begin/record/end seam
//!   - `zgame.transitionImage`— the layout-transition barrier
//!
//! What's left here is the part that is actually *this app*: picking a colour
//! and recording the clear. Diff this against ../clear-color/main.zig to see the
//! ~130 lines of boilerplate that moved into the lib (and are now reusable +
//! covered by zGameLib's `test-gpu` spec).

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;
const vk = zgame.vk;

const max_frames = 2;

pub fn main() !void {
    try platform.init(.{});
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "clear-color-2", .size = .{ .w = 800, .h = 600 }, .renderer = .vulkan });
    defer win.destroy();

    // Vulkan bring-up: instance → surface → device → queue, in one call.
    var gpu = try zgame.Gpu.init(win, .{ .app_name = "clear-color-2" });
    defer gpu.deinit();

    var sc = try gpu.createSwapchain(extentOf(win));
    defer sc.deinit();

    // Frames-in-flight: command buffers + per-frame sync, owned by the ring.
    var frames = try zgame.FrameRing(max_frames).init(gpu);
    defer frames.deinit();

    // One palette entry per second, cycling.
    const palette = [_][4]f32{
        .{ 0.85, 0.20, 0.20, 1.0 }, // red
        .{ 0.90, 0.55, 0.15, 1.0 }, // orange
        .{ 0.90, 0.85, 0.20, 1.0 }, // yellow
        .{ 0.25, 0.75, 0.30, 1.0 }, // green
        .{ 0.20, 0.45, 0.85, 1.0 }, // blue
        .{ 0.55, 0.30, 0.80, 1.0 }, // violet
    };

    while (!win.shouldClose()) {
        platform.pollAllEvents();
        const ev = platform.events();
        if (ev.close_requested) break;
        if (ev.resizes.len > 0) try sc.recreate(extentOf(win));

        // begin → record → end: the ring waits/acquires/submits/presents (and
        // recreates the swapchain on out-of-date); we only record the clear.
        // `null` means the swapchain was just recreated — skip this iteration.
        const f = (try frames.begin(&sc, extentOf(win))) orelse continue;

        zgame.transitionImage(gpu.vkd, f.cmd, f.image, .undefined, .transfer_dst_optimal, .{}, .{ .transfer_write_bit = true }, .{ .top_of_pipe_bit = true }, .{ .transfer_bit = true });
        const second = platform.now() / std.time.ns_per_s; // now() is nanoseconds
        const color = vk.ClearColorValue{ .float_32 = palette[second % palette.len] };
        gpu.vkd.cmdClearColorImage(f.cmd, f.image, .transfer_dst_optimal, &color, &.{zgame.swapchain.colorRange()});
        zgame.transitionImage(gpu.vkd, f.cmd, f.image, .transfer_dst_optimal, .present_src_khr, .{ .transfer_write_bit = true }, .{}, .{ .transfer_bit = true }, .{ .bottom_of_pipe_bit = true });

        try frames.end(&sc, f, .{ .transfer_bit = true });
    }
    gpu.waitIdle();
}

fn extentOf(win: *platform.Window) vk.Extent2D {
    const s = win.size();
    return .{ .width = s.w, .height = s.h };
}
