//! Reactive clear-color — the first rung that drives BOTH adapters together.
//!
//! Opens a window (platform), builds a Vulkan instance + surface + swapchain,
//! and clears the swapchain image each frame to an animated colour, presenting
//! it. Quits on window close; recreates the swapchain on resize. No
//! pipeline/shaders — the clear is a vkCmdClearColorImage with manual layout
//! transitions.
//!
//! Everything is reached through the framework: `zgame.platform`,
//! `zgame.vulkan_stack`/`zgame.vk`/`zgame.volk`, and the `zgame.surface` bridge
//! + `zgame.swapchain` helper (all sharing one coherent module graph).

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;
const vulkan_stack = zgame.vulkan_stack;
const vk = zgame.vk;
const volk = zgame.volk;
const surface_bridge = zgame.surface;
const sc_mod = zgame.swapchain;
const Swapchain = sc_mod.Swapchain;

const max_frames = 2;

pub fn main() !void {
    // ---- platform lib: window + the Vulkan handshake inputs ----
    try platform.init(.{});
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "clear-color", .size = .{ .w = 800, .h = 600 }, .renderer = .vulkan });
    defer win.destroy();

    // ---- vulkan lib: loader → instance ----
    try volk.loadBase();
    const gipa = volk.getInstanceProcAddr();
    const vkb = vk.BaseWrapper.load(gipa);
    const app_info = vk.ApplicationInfo{
        .application_version = 0,
        .engine_version = 0,
        .api_version = @bitCast(vk.API_VERSION_1_3),
    };
    const exts = platform.requiredVulkanInstanceExtensions();
    const instance = try vkb.createInstance(&.{
        .p_application_info = &app_info,
        .enabled_extension_count = @intCast(exts.len),
        .pp_enabled_extension_names = exts.ptr,
    }, null);
    const vki = vk.InstanceWrapper.load(instance, gipa);
    defer vki.destroyInstance(instance, null);

    // ---- the one cross-lib seam: native handle → surface (no shared type) ----
    const surface = try surface_bridge.createSurface(instance, win);
    defer vki.destroySurfaceKHR(instance, surface, null);

    // ---- device with a present-capable queue + the swapchain extension ----
    var pdev: vk.PhysicalDevice = undefined;
    var pn: u32 = 1;
    _ = try vki.enumeratePhysicalDevices(instance, &pn, @ptrCast(&pdev));
    const qfam = try presentQueueFamily(vki, pdev, surface);

    const prio = [_]f32{1.0};
    const sc_ext: [*:0]const u8 = "VK_KHR_swapchain";
    const device = try vki.createDevice(pdev, &.{
        .queue_create_info_count = 1,
        .p_queue_create_infos = &[_]vk.DeviceQueueCreateInfo{.{
            .queue_family_index = qfam,
            .queue_count = 1,
            .p_queue_priorities = &prio,
        }},
        .enabled_extension_count = 1,
        .pp_enabled_extension_names = @ptrCast(&sc_ext),
    }, null);
    const vkd = vk.DeviceWrapper.load(device, vki.dispatch.vkGetDeviceProcAddr.?);
    defer vkd.destroyDevice(device, null);
    const queue = vkd.getDeviceQueue(device, qfam, 0);

    // ---- swapchain (the shared helper) ----
    var sc = Swapchain{ .vki = vki, .vkd = vkd, .pdev = pdev, .device = device, .surface = surface };
    try sc.init(extentOf(win));
    defer sc.deinit();

    // ---- per-frame command buffers + sync ----
    const pool = try vkd.createCommandPool(device, &.{
        .queue_family_index = qfam,
        .flags = .{ .reset_command_buffer_bit = true },
    }, null);
    defer vkd.destroyCommandPool(device, pool, null);
    var cmds: [max_frames]vk.CommandBuffer = undefined;
    try vkd.allocateCommandBuffers(device, &.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = max_frames,
    }, &cmds);

    var img_avail: [max_frames]vk.Semaphore = undefined;
    var done: [max_frames]vk.Semaphore = undefined;
    var in_flight: [max_frames]vk.Fence = undefined;
    for (0..max_frames) |i| {
        img_avail[i] = try vkd.createSemaphore(device, &.{}, null);
        done[i] = try vkd.createSemaphore(device, &.{}, null);
        in_flight[i] = try vkd.createFence(device, &.{ .flags = .{ .signaled_bit = true } }, null);
    }
    defer for (0..max_frames) |i| {
        vkd.destroySemaphore(device, img_avail[i], null);
        vkd.destroySemaphore(device, done[i], null);
        vkd.destroyFence(device, in_flight[i], null);
    };

    // One palette entry per second, cycling.
    const palette = [_][4]f32{
        .{ 0.85, 0.20, 0.20, 1.0 }, // red
        .{ 0.90, 0.55, 0.15, 1.0 }, // orange
        .{ 0.90, 0.85, 0.20, 1.0 }, // yellow
        .{ 0.25, 0.75, 0.30, 1.0 }, // green
        .{ 0.20, 0.45, 0.85, 1.0 }, // blue
        .{ 0.55, 0.30, 0.80, 1.0 }, // violet
    };

    // ---- frame loop ----
    var frame: usize = 0;
    while (!win.shouldClose()) {
        platform.pollAllEvents();
        const ev = platform.events();
        if (ev.close_requested) break;
        if (ev.resizes.len > 0) try sc.recreate(extentOf(win));

        _ = try vkd.waitForFences(device, &.{in_flight[frame]}, .true, std.math.maxInt(u64));

        const acq = vkd.acquireNextImageKHR(device, sc.handle, std.math.maxInt(u64), img_avail[frame], .null_handle) catch |err| switch (err) {
            error.OutOfDateKHR => {
                try sc.recreate(extentOf(win));
                continue;
            },
            else => return err,
        };

        try vkd.resetFences(device, &.{in_flight[frame]});

        // record: UNDEFINED → TRANSFER_DST, clear to an animated colour, → PRESENT_SRC
        const cmd = cmds[frame];
        try vkd.resetCommandBuffer(cmd, .{});
        try vkd.beginCommandBuffer(cmd, &.{});
        const image = sc.images[acq.image_index];
        barrier(vkd, cmd, image, .undefined, .transfer_dst_optimal, .{}, .{ .transfer_write_bit = true }, .{ .top_of_pipe_bit = true }, .{ .transfer_bit = true });
        const second = platform.now() / std.time.ns_per_s; // now() is nanoseconds
        const color = vk.ClearColorValue{ .float_32 = palette[second % palette.len] };
        const range = sc_mod.colorRange();
        vkd.cmdClearColorImage(cmd, image, .transfer_dst_optimal, &color, &.{range});
        barrier(vkd, cmd, image, .transfer_dst_optimal, .present_src_khr, .{ .transfer_write_bit = true }, .{}, .{ .transfer_bit = true }, .{ .bottom_of_pipe_bit = true });
        try vkd.endCommandBuffer(cmd);

        const wait_stage = vk.PipelineStageFlags{ .transfer_bit = true };
        try vkd.queueSubmit(queue, &.{.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&img_avail[frame]),
            .p_wait_dst_stage_mask = @ptrCast(&wait_stage),
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&cmd),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(&done[frame]),
        }}, in_flight[frame]);

        _ = vkd.queuePresentKHR(queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&done[frame]),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&sc.handle),
            .p_image_indices = @ptrCast(&acq.image_index),
        }) catch |err| switch (err) {
            error.OutOfDateKHR => try sc.recreate(extentOf(win)),
            else => return err,
        };

        frame = (frame + 1) % max_frames;
    }
    try vkd.deviceWaitIdle(device);
}

fn extentOf(win: *platform.Window) vk.Extent2D {
    const s = win.size();
    return .{ .width = s.w, .height = s.h };
}

fn presentQueueFamily(vki: vk.InstanceWrapper, pdev: vk.PhysicalDevice, surface: vk.SurfaceKHR) !u32 {
    var n: u32 = 0;
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &n, null);
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        if ((try vki.getPhysicalDeviceSurfaceSupportKHR(pdev, i, surface)) == .true) return i;
    }
    return error.NoPresentQueue;
}

fn barrier(
    vkd: vk.DeviceWrapper,
    cmd: vk.CommandBuffer,
    image: vk.Image,
    old: vk.ImageLayout,
    new: vk.ImageLayout,
    src_access: vk.AccessFlags,
    dst_access: vk.AccessFlags,
    src_stage: vk.PipelineStageFlags,
    dst_stage: vk.PipelineStageFlags,
) void {
    const b = vk.ImageMemoryBarrier{
        .src_access_mask = src_access,
        .dst_access_mask = dst_access,
        .old_layout = old,
        .new_layout = new,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresource_range = sc_mod.colorRange(),
    };
    vkd.cmdPipelineBarrier(cmd, src_stage, dst_stage, .{}, null, null, &.{b});
}
