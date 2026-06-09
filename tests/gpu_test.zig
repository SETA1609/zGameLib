//! TDD spec for the zGameLib render abstractions lifted out of the raw
//! clear-color example:
//!
//!   - `zgame.Gpu`            — Vulkan bring-up (instance → surface → device → queue)
//!   - `zgame.FrameRing(N)`   — frames-in-flight: command buffers + sync + the
//!                              begin/record/end (acquire → submit → present) seam
//!   - `zgame.transitionImage`— the full-subresource layout-transition helper
//!
//! Unlike integration_test.zig (which drives the two adapters directly), these
//! drive the **framework's own** API by importing `zgame`. Gated + needs a
//! display and a Vulkan loader (run under `test-tdd` / Xvfb); skips on a display
//! server the surface bridge doesn't cover, just like the integration suite.

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;
const vk = zgame.vk;

fn gate(implemented: bool) error{SkipZigTest}!void {
    if (!implemented) return error.SkipZigTest;
}

/// Flip as the abstractions land. They're implemented alongside this spec, so
/// all three start true — a default run still skips when there's no display.
const done = .{
    .gpu_bringup = true,
    .swapchain_from_gpu = true,
    .frame_ring = true,
};

fn extentOf(win: *platform.Window) vk.Extent2D {
    const s = win.size();
    return .{ .width = s.w, .height = s.h };
}

/// Open a `.vulkan` window and bring the GPU up through the framework. Returns
/// SkipZigTest on a display server the surface bridge doesn't cover (a headless
/// CI leg with no X11/Wayland), mirroring the integration suite's behaviour.
const Harness = struct {
    win: *platform.Window,
    gpu: zgame.Gpu,

    fn init() !Harness {
        try platform.init(.{});
        errdefer platform.deinit();
        const win = try platform.Window.create(.{ .title = "gpu-test", .renderer = .vulkan });
        errdefer win.destroy();
        const gpu = zgame.Gpu.init(win, .{ .app_name = "gpu-test" }) catch |err| switch (err) {
            error.NoSupportedSurface => return error.SkipZigTest,
            else => return err,
        };
        return .{ .win = win, .gpu = gpu };
    }

    fn deinit(self: *Harness) void {
        self.gpu.deinit();
        self.win.destroy();
        platform.deinit();
    }
};

// WHEN bringing the GPU up via zgame.Gpu.init on a .vulkan window · GIVEN a display + Vulkan loader · THEN instance, surface, device and queue are all non-null (a present-capable queue family was found, else init would have errored).
test "gpu: init brings up instance + surface + device + present queue" {
    try gate(done.gpu_bringup);
    var h = try Harness.init();
    defer h.deinit();
    try std.testing.expect(@intFromEnum(h.gpu.instance) != 0);
    try std.testing.expect(h.gpu.surface != .null_handle);
    try std.testing.expect(@intFromEnum(h.gpu.device) != 0);
    try std.testing.expect(@intFromEnum(h.gpu.queue) != 0);
}

// WHEN asking the Gpu for a swapchain sized to the window · GIVEN a brought-up Gpu · THEN the swapchain handle is non-null and it owns at least one image.
test "gpu: createSwapchain yields a non-null swapchain with images" {
    try gate(done.swapchain_from_gpu);
    var h = try Harness.init();
    defer h.deinit();
    var sc = try h.gpu.createSwapchain(extentOf(h.win));
    defer sc.deinit();
    try std.testing.expect(sc.handle != .null_handle);
    try std.testing.expect(sc.count > 0);
}

// WHEN initialising a FrameRing(2) from the Gpu · GIVEN a brought-up Gpu · THEN it owns a command pool and starts at frame index 0.
test "frame ring: init owns a command pool and starts at index 0" {
    try gate(done.frame_ring);
    var h = try Harness.init();
    defer h.deinit();
    var frames = try zgame.FrameRing(2).init(h.gpu);
    defer frames.deinit();
    try std.testing.expect(frames.pool != .null_handle);
    try std.testing.expectEqual(@as(u32, 0), frames.index);
}

// WHEN running begin → record a clear → end for several frames · GIVEN a Gpu + swapchain + FrameRing(2) · THEN each frame completes and the ring's index ends at completed-count modulo the frame count (begin advances nothing on a skip; end advances by one).
test "frame ring: begin/record/end completes frames and cycles the index" {
    try gate(done.frame_ring);
    var h = try Harness.init();
    defer h.deinit();
    var sc = try h.gpu.createSwapchain(extentOf(h.win));
    defer sc.deinit();
    var frames = try zgame.FrameRing(2).init(h.gpu);
    defer frames.deinit();

    const vkd = h.gpu.vkd;
    var completed: u32 = 0;
    var tries: u32 = 0;
    while (completed < 4 and tries < 16) : (tries += 1) {
        const f = (try frames.begin(&sc, extentOf(h.win))) orelse continue;

        zgame.transitionImage(vkd, f.cmd, f.image, .undefined, .transfer_dst_optimal, .{}, .{ .transfer_write_bit = true }, .{ .top_of_pipe_bit = true }, .{ .transfer_bit = true });
        const color = vk.ClearColorValue{ .float_32 = .{ 0.1, 0.2, 0.3, 1.0 } };
        vkd.cmdClearColorImage(f.cmd, f.image, .transfer_dst_optimal, &color, &.{zgame.swapchain.colorRange()});
        zgame.transitionImage(vkd, f.cmd, f.image, .transfer_dst_optimal, .present_src_khr, .{ .transfer_write_bit = true }, .{}, .{ .transfer_bit = true }, .{ .bottom_of_pipe_bit = true });

        try frames.end(&sc, f, .{ .transfer_bit = true });
        completed += 1;
    }
    h.gpu.waitIdle();
    try std.testing.expect(completed >= 4);
    try std.testing.expectEqual(completed % 2, frames.index);
}
