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
    .three_dimensional_path = true,
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
        return initWithOptions(.{ .app_name = "gpu-test" });
    }

    fn initWithOptions(options: zgame.Gpu.Options) !Harness {
        try platform.init(.{});
        errdefer platform.deinit();
        const win = try platform.Window.create(.{ .title = "gpu-test", .renderer = .vulkan });
        errdefer win.destroy();
        const gpu = zgame.Gpu.init(win, options) catch |err| switch (err) {
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
    try std.testing.expect(@intFromPtr(h.gpu.instance) != 0);
    try std.testing.expect(h.gpu.surface != .null);
    try std.testing.expect(@intFromPtr(h.gpu.device) != 0);
    try std.testing.expect(@intFromPtr(h.gpu.queue) != 0);
}

// WHEN asking the Gpu for a swapchain sized to the window · GIVEN a brought-up Gpu · THEN the swapchain handle is non-null and it owns at least one image.
test "gpu: createSwapchain yields a non-null swapchain with images" {
    try gate(done.swapchain_from_gpu);
    var h = try Harness.init();
    defer h.deinit();
    var sc = try h.gpu.createSwapchain(extentOf(h.win));
    defer sc.deinit();
    try std.testing.expect(sc.handle != .null);
    try std.testing.expect(sc.count > 0);
}

// WHEN initialising a FrameRing(2) from the Gpu · GIVEN a brought-up Gpu · THEN it owns a command pool and starts at frame index 0.
test "frame ring: init owns a command pool and starts at index 0" {
    try gate(done.frame_ring);
    var h = try Harness.init();
    defer h.deinit();
    var frames = try zgame.FrameRing(2).init(h.gpu);
    defer frames.deinit();
    try std.testing.expect(frames.pool != .null);
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

        zgame.transitionImage(vkd, f.cmd, f.image, .undefined, .transfer_dst_optimal, .{}, .{ .transfer_write = true }, .{ .top_of_pipe = true }, .{ .transfer = true });
        const color = vk.ClearColorValue{ .float_32 = .{ 0.1, 0.2, 0.3, 1.0 } };
        vkd.cmdClearColorImage(f.cmd, f.image, .transfer_dst_optimal, &color, &.{zgame.swapchain.colorRange()});
        zgame.transitionImage(vkd, f.cmd, f.image, .transfer_dst_optimal, .present_src_khr, .{ .transfer_write = true }, .{}, .{ .transfer = true }, .{ .bottom_of_pipe = true });

        try frames.end(&sc, f, .{ .transfer = true });
        completed += 1;
    }
    h.gpu.waitIdle();
    try std.testing.expect(completed >= 4);
    try std.testing.expectEqual(completed % 2, frames.index);
}

// --- The 3D path: dynamic rendering, depth buffer, indexed mesh -------------

fn initThreeDimensionalHarness() !Harness {
    return Harness.initWithOptions(.{ .app_name = "gpu-test-3d", .enable_dynamic_rendering = true });
}

// WHEN bringing the GPU up with default options · THEN dynamic rendering stays off (the 2D path is unchanged).
test "Gpu leaves dynamic rendering off by default" {
    try gate(done.three_dimensional_path);
    var h = try Harness.init();
    defer h.deinit();
    try std.testing.expect(!h.gpu.dynamic_rendering_enabled);
}

// WHEN bringing the GPU up with enable_dynamic_rendering · THEN the device enables Vulkan 1.3 dynamic rendering.
test "Gpu enables dynamic rendering when asked" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    try std.testing.expect(h.gpu.dynamic_rendering_enabled);
}

// WHEN creating a DepthBuffer for an extent · THEN it owns a D32 depth image and view of that size.
test "DepthBuffer creates a depth image and view sized to the extent" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    var depth_buffer = try zgame.DepthBuffer.create(&h.gpu, .{ .width = 64, .height = 48 });
    defer depth_buffer.destroy();
    try std.testing.expect(depth_buffer.image != .null);
    try std.testing.expect(depth_buffer.view != .null);
    try std.testing.expectEqual(vk.Format.d32_sfloat, depth_buffer.format);
    try std.testing.expectEqual(@as(u32, 64), depth_buffer.extent.width);
    try std.testing.expectEqual(@as(u32, 48), depth_buffer.extent.height);
}

// WHEN asking which depth format to use · THEN it is a candidate the device supports as an optimal-tiling depth attachment.
test "findSupportedDepthFormat returns a candidate the device supports as a depth attachment" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    const depth_format = try zgame.findSupportedDepthFormat(&h.gpu);
    try std.testing.expect(std.mem.indexOfScalar(vk.Format, &zgame.depth_format_candidates, depth_format) != null);
    const format_properties = h.gpu.vki.getPhysicalDeviceFormatProperties(h.gpu.pdev, depth_format);
    try std.testing.expect(format_properties.optimal_tiling_features.depth_stencil_attachment);
}

// WHEN creating a DepthBuffer · THEN it uses the format findSupportedDepthFormat picks.
test "DepthBuffer.create uses the supported depth format" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    var depth_buffer = try zgame.DepthBuffer.create(&h.gpu, .{ .width = 16, .height = 16 });
    defer depth_buffer.destroy();
    try std.testing.expectEqual(try zgame.findSupportedDepthFormat(&h.gpu), depth_buffer.format);
}

// WHEN recreating a DepthBuffer for a new extent · THEN it takes the new size.
test "DepthBuffer.recreate resizes to the new extent" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    var depth_buffer = try zgame.DepthBuffer.create(&h.gpu, .{ .width = 64, .height = 48 });
    defer depth_buffer.destroy();
    try depth_buffer.recreate(&h.gpu, .{ .width = 32, .height = 16 });
    try std.testing.expectEqual(@as(u32, 32), depth_buffer.extent.width);
    try std.testing.expectEqual(@as(u32, 16), depth_buffer.extent.height);
    try std.testing.expect(depth_buffer.view != .null);
}

// WHEN uploading a quad as an IndexedMesh · THEN it owns vertex and index buffers and keeps the index count.
test "IndexedMesh uploads vertices and indices" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    const quad_positions = [_][3]f32{ .{ -1, -1, 0 }, .{ 1, -1, 0 }, .{ 1, 1, 0 }, .{ -1, 1, 0 } };
    const quad_indices = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var mesh = try zgame.IndexedMesh.create(&h.gpu, std.mem.sliceAsBytes(&quad_positions), &quad_indices);
    defer mesh.destroy();
    try std.testing.expect(mesh.vertex_buffer != .null);
    try std.testing.expect(mesh.index_buffer != .null);
    try std.testing.expectEqual(@as(u32, 6), mesh.index_count);
}

// WHEN creating an IndexedMesh with no indices · THEN it fails instead of making an empty draw.
test "IndexedMesh rejects an empty index list" {
    try gate(done.three_dimensional_path);
    var h = try initThreeDimensionalHarness();
    defer h.deinit();
    const one_position = [_][3]f32{.{ 0, 0, 0 }};
    try std.testing.expectError(error.EmptyIndexList, zgame.IndexedMesh.create(&h.gpu, std.mem.sliceAsBytes(&one_position), &.{}));
}
