//! A minimal, reusable swapchain over the re-exported `vk`. Lives here in the
//! examples repo (next to surface.zig), **not** in the vulkan lib — it's
//! renderer policy (format/present-mode choice, recreation), which the lib
//! deliberately leaves to the consumer. Owns the swapchain + its image views
//! and knows how to recreate on resize. Reused by every rung from clear-color up.

const std = @import("std");
const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

pub const Swapchain = struct {
    const max_images = 8;

    vki: vk.InstanceWrapper,
    vkd: vk.DeviceWrapper,
    pdev: vk.PhysicalDevice,
    device: vk.Device,
    surface: vk.SurfaceKHR,

    handle: vk.SwapchainKHR = .null_handle,
    format: vk.SurfaceFormatKHR = undefined,
    extent: vk.Extent2D = undefined,
    images: [max_images]vk.Image = undefined,
    views: [max_images]vk.ImageView = undefined,
    count: u32 = 0,

    pub fn init(self: *Swapchain, want: vk.Extent2D) !void {
        try self.build(want, .null_handle);
    }

    /// Resize / out-of-date handling: rebuild, handing the old one over so the
    /// implementation can reuse resources, then destroy the old one.
    pub fn recreate(self: *Swapchain, want: vk.Extent2D) !void {
        try self.vkd.deviceWaitIdle(self.device);
        const old = self.handle;
        self.destroyViews();
        try self.build(want, old);
        if (old != .null_handle) self.vkd.destroySwapchainKHR(self.device, old, null);
    }

    fn build(self: *Swapchain, want: vk.Extent2D, old: vk.SwapchainKHR) !void {
        const caps = try self.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(self.pdev, self.surface);
        self.format = try chooseFormat(self.vki, self.pdev, self.surface);
        const mode = try choosePresentMode(self.vki, self.pdev, self.surface);
        self.extent = chooseExtent(caps, want);

        var min = caps.min_image_count + 1;
        if (caps.max_image_count > 0 and min > caps.max_image_count) min = caps.max_image_count;

        self.handle = try self.vkd.createSwapchainKHR(self.device, &.{
            .surface = self.surface,
            .min_image_count = min,
            .image_format = self.format.format,
            .image_color_space = self.format.color_space,
            .image_extent = self.extent,
            .image_array_layers = 1,
            // TRANSFER_DST so we can vkCmdClearColorImage straight into it.
            .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
            .image_sharing_mode = .exclusive,
            .pre_transform = caps.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = mode,
            .clipped = .true,
            .old_swapchain = old,
        }, null);

        var n: u32 = self.images.len;
        _ = try self.vkd.getSwapchainImagesKHR(self.device, self.handle, &n, &self.images);
        self.count = n;

        for (self.images[0..n], 0..) |img, i| {
            self.views[i] = try self.vkd.createImageView(self.device, &.{
                .image = img,
                .view_type = .@"2d",
                .format = self.format.format,
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
                .subresource_range = colorRange(),
            }, null);
        }
    }

    fn destroyViews(self: *Swapchain) void {
        for (self.views[0..self.count]) |v| self.vkd.destroyImageView(self.device, v, null);
        self.count = 0;
    }

    pub fn deinit(self: *Swapchain) void {
        self.destroyViews();
        if (self.handle != .null_handle) self.vkd.destroySwapchainKHR(self.device, self.handle, null);
    }
};

// --- the pure "select" helpers (the only swapchain bit that might earn lib-tier) ---

fn chooseFormat(vki: vk.InstanceWrapper, pdev: vk.PhysicalDevice, surface: vk.SurfaceKHR) !vk.SurfaceFormatKHR {
    var buf: [32]vk.SurfaceFormatKHR = undefined;
    var n: u32 = buf.len;
    _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &n, &buf);
    for (buf[0..n]) |f|
        if (f.format == .b8g8r8a8_srgb and f.color_space == .srgb_nonlinear_khr) return f;
    return buf[0]; // the first entry is always a valid choice
}

fn choosePresentMode(vki: vk.InstanceWrapper, pdev: vk.PhysicalDevice, surface: vk.SurfaceKHR) !vk.PresentModeKHR {
    var buf: [8]vk.PresentModeKHR = undefined;
    var n: u32 = buf.len;
    _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &n, &buf);
    for (buf[0..n]) |m| if (m == .mailbox_khr) return m;
    return .fifo_khr; // always present
}

fn chooseExtent(caps: vk.SurfaceCapabilitiesKHR, want: vk.Extent2D) vk.Extent2D {
    if (caps.current_extent.width != std.math.maxInt(u32)) return caps.current_extent;
    return .{
        .width = std.math.clamp(want.width, caps.min_image_extent.width, caps.max_image_extent.width),
        .height = std.math.clamp(want.height, caps.min_image_extent.height, caps.max_image_extent.height),
    };
}

pub fn colorRange() vk.ImageSubresourceRange {
    return .{ .aspect_mask = .{ .color_bit = true }, .base_mip_level = 0, .level_count = 1, .base_array_layer = 0, .layer_count = 1 };
}
