//! The frames-in-flight ring — the per-frame command buffers + sync and the
//! acquire/submit/present dance every rendering rung repeats.
//!
//! `FrameRing(N)` owns one command buffer + an (image-available, render-done)
//! semaphore pair + an in-flight fence per frame, plus the command pool. The
//! loop is a **begin → record → end** seam: `begin` waits the frame's fence,
//! acquires a swapchain image, and opens its command buffer; the app records
//! whatever it likes into `frame.cmd`/`frame.image`; `end` closes, submits, and
//! presents. Swapchain recreation on `OutOfDateKHR` is handled in both halves —
//! `begin` returns `null` (skip this iteration) when it had to recreate.
//!
//! Transparent like the rest of zGameLib: the pool, command buffers and sync
//! objects are all public fields, so an app that needs a different submit shape
//! can drop to the raw `vkd` calls. Lives beside swapchain.zig — same tier.

const std = @import("std");
const vulkan_stack = @import("vulkan_stack");
const sc = @import("swapchain");
const vk = vulkan_stack.vk;

/// `max_frames` frames in flight. Comptime so the rings are fixed-size arrays
/// with no allocation — the count an app picks (typically 2) is part of its type.
pub fn FrameRing(comptime max_frames: u32) type {
    return struct {
        const Self = @This();

        vkd: vk.DeviceWrapper,
        device: vk.Device,
        queue: vk.Queue,
        pool: vk.CommandPool,
        cmds: [max_frames]vk.CommandBuffer,
        img_avail: [max_frames]vk.Semaphore,
        done: [max_frames]vk.Semaphore,
        in_flight: [max_frames]vk.Fence,
        index: u32 = 0,
        /// The extent `begin` was last given — reused by `end` to recreate the
        /// swapchain on an out-of-date present without re-threading it through.
        want: vk.Extent2D = undefined,

        /// One in-flight frame, handed to the caller between begin/end.
        pub const Frame = struct {
            cmd: vk.CommandBuffer,
            image: vk.Image,
            image_index: u32,
        };

        /// Allocate the pool, the per-frame command buffers, and the sync set.
        /// `gpu` is anything exposing `.vkd`/`.device`/`.queue`/`.qfam` (a `Gpu`).
        pub fn init(gpu: anytype) !Self {
            const vkd = gpu.vkd;
            const device = gpu.device;

            const pool = try vkd.createCommandPool(device, &.{
                .queue_family_index = gpu.qfam,
                .flags = .{ .reset_command_buffer_bit = true },
            }, null);
            errdefer vkd.destroyCommandPool(device, pool, null);

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
                // Start signalled so the first wait on each frame returns immediately.
                in_flight[i] = try vkd.createFence(device, &.{ .flags = .{ .signaled_bit = true } }, null);
            }

            return .{
                .vkd = vkd,
                .device = device,
                .queue = gpu.queue,
                .pool = pool,
                .cmds = cmds,
                .img_avail = img_avail,
                .done = done,
                .in_flight = in_flight,
            };
        }

        pub fn deinit(self: *Self) void {
            for (0..max_frames) |i| {
                self.vkd.destroySemaphore(self.device, self.img_avail[i], null);
                self.vkd.destroySemaphore(self.device, self.done[i], null);
                self.vkd.destroyFence(self.device, self.in_flight[i], null);
            }
            self.vkd.destroyCommandPool(self.device, self.pool, null);
        }

        /// Begin the current frame: wait its fence, acquire a swapchain image,
        /// reset the fence, and open the command buffer. Returns `null` (and
        /// recreates `chain`) when the swapchain was out of date — the caller
        /// should `continue` its loop. `want` is the desired extent on recreate.
        pub fn begin(self: *Self, chain: *sc.Swapchain, want: vk.Extent2D) !?Frame {
            self.want = want;
            const i = self.index;

            _ = try self.vkd.waitForFences(self.device, &.{self.in_flight[i]}, .true, std.math.maxInt(u64));

            const acq = self.vkd.acquireNextImageKHR(self.device, chain.handle, std.math.maxInt(u64), self.img_avail[i], .null_handle) catch |err| switch (err) {
                error.OutOfDateKHR => {
                    try chain.recreate(want);
                    return null;
                },
                else => return err,
            };

            try self.vkd.resetFences(self.device, &.{self.in_flight[i]});

            const cmd = self.cmds[i];
            try self.vkd.resetCommandBuffer(cmd, .{});
            try self.vkd.beginCommandBuffer(cmd, &.{});
            return .{ .cmd = cmd, .image = chain.images[acq.image_index], .image_index = acq.image_index };
        }

        /// End the frame: close the command buffer, submit it (waiting on the
        /// image-available semaphore at `wait_stage`, signalling render-done +
        /// the in-flight fence), then present. Recreates `chain` on an
        /// out-of-date present and advances to the next frame either way.
        pub fn end(self: *Self, chain: *sc.Swapchain, frame: Frame, wait_stage: vk.PipelineStageFlags) !void {
            const i = self.index;
            const cmd = frame.cmd;
            try self.vkd.endCommandBuffer(cmd);

            const stage = wait_stage;
            try self.vkd.queueSubmit(self.queue, &.{.{
                .wait_semaphore_count = 1,
                .p_wait_semaphores = @ptrCast(&self.img_avail[i]),
                .p_wait_dst_stage_mask = @ptrCast(&stage),
                .command_buffer_count = 1,
                .p_command_buffers = @ptrCast(&cmd),
                .signal_semaphore_count = 1,
                .p_signal_semaphores = @ptrCast(&self.done[i]),
            }}, self.in_flight[i]);

            var image_index = frame.image_index;
            _ = self.vkd.queuePresentKHR(self.queue, &.{
                .wait_semaphore_count = 1,
                .p_wait_semaphores = @ptrCast(&self.done[i]),
                .swapchain_count = 1,
                .p_swapchains = @ptrCast(&chain.handle),
                .p_image_indices = @ptrCast(&image_index),
            }) catch |err| switch (err) {
                error.OutOfDateKHR => try chain.recreate(self.want),
                else => return err,
            };

            self.index = (i + 1) % max_frames;
        }
    };
}
