//! zGameLib's swapchain: the framework's policy over the Vulkan adapter's
//! opt-in `vulkan_stack.Swapchain` helper.
//!
//! The adapter owns the mechanism: creating the swapchain and its image views,
//! recreating it with the old one handed over (and kept when the rebuild
//! fails), reporting a 0×0 surface as `error.SurfaceHasZeroExtent`, and checking
//! image usage and composite alpha against the surface. zGameLib owns the
//! policy (`framework_options`) and the timing: `FrameRing` decides when to
//! recreate. This type adds the allocator and dispatch tables the adapter's
//! calls need, so `recreate(extent)` and `deinit()` take no extra arguments.
//!
//! Transparent like the rest of zGameLib: the handle, images, views, format,
//! and extent are public fields, and `adapter_swapchain` is the adapter's
//! helper itself (with `toRaw()` for the create-info used).

const std = @import("std");
const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

/// The errors `create` and `recreate` return; the adapter's swapchain error set.
pub const Error = vulkan_stack.SwapchainError;

/// zGameLib's swapchain policy, passed to the adapter's helper: 8-bit
/// blue-green-red-alpha pixels in the standard red-green-blue colour space,
/// mailbox present mode else first-in-first-out, the surface's minimum image
/// count plus one, and transfer-destination usage so a frame can start with
/// `vkCmdClearColorImage`.
pub const framework_options: vulkan_stack.Swapchain.Options = .{
    .preferred_format = .{ .format = .b8g8r8a8_srgb, .color_space = .srgb_nonlinear_khr },
    .preferred_present_mode = .mailbox_khr,
    .desired_image_count = 0,
    .image_usage = .{ .color_attachment = true, .transfer_dst = true },
};

pub const Swapchain = struct {
    allocator: std.mem.Allocator,
    vki: vk.InstanceWrapper,
    vkd: vk.DeviceWrapper,
    pdev: vk.PhysicalDevice,
    device: vk.Device,
    surface: vk.SurfaceKHR,

    /// The adapter's helper that owns the Vulkan objects below.
    adapter_swapchain: vulkan_stack.Swapchain,

    // Mirrors of `adapter_swapchain`, refreshed after every create and recreate.
    handle: vk.SwapchainKHR,
    format: vk.SurfaceFormatKHR,
    extent: vk.Extent2D,
    images: []const vk.Image,
    views: []const vk.ImageView,
    count: u32,

    /// Create a swapchain for `surface` with `framework_options`, sized to
    /// `want` where the surface lets the swapchain choose (Wayland, headless).
    /// A 0×0 surface (a minimized window) is `error.SurfaceHasZeroExtent`.
    pub fn create(
        allocator: std.mem.Allocator,
        vki: vk.InstanceWrapper,
        vkd: vk.DeviceWrapper,
        pdev: vk.PhysicalDevice,
        device: vk.Device,
        surface: vk.SurfaceKHR,
        want: vk.Extent2D,
    ) Error!Swapchain {
        var options = framework_options;
        options.fallback_extent = want;
        const adapter_swapchain = try vulkan_stack.Swapchain.create(allocator, vki, vkd, pdev, device, surface, options);
        var swapchain = Swapchain{
            .allocator = allocator,
            .vki = vki,
            .vkd = vkd,
            .pdev = pdev,
            .device = device,
            .surface = surface,
            .adapter_swapchain = adapter_swapchain,
            .handle = undefined,
            .format = undefined,
            .extent = undefined,
            .images = undefined,
            .views = undefined,
            .count = undefined,
        };
        swapchain.refreshMirroredFields();
        return swapchain;
    }

    /// Resize / out-of-date handling: rebuild with the old swapchain handed
    /// over. On error, including `error.SurfaceHasZeroExtent`, the old
    /// swapchain is kept and still valid.
    pub fn recreate(self: *Swapchain, want: vk.Extent2D) Error!void {
        try self.adapter_swapchain.recreate(self.allocator, self.vki, self.vkd, self.pdev, self.device, self.surface, want);
        self.refreshMirroredFields();
    }

    /// Destroy the image views and the swapchain. The device must no longer use them.
    pub fn deinit(self: *Swapchain) void {
        self.adapter_swapchain.deinit(self.allocator, self.vkd, self.device);
        self.* = undefined;
    }

    fn refreshMirroredFields(self: *Swapchain) void {
        self.handle = self.adapter_swapchain.handle;
        self.format = self.adapter_swapchain.format;
        self.extent = self.adapter_swapchain.extent;
        self.images = self.adapter_swapchain.images;
        self.views = self.adapter_swapchain.views;
        self.count = @intCast(self.adapter_swapchain.images.len);
    }
};

pub fn colorRange() vk.ImageSubresourceRange {
    return .{ .aspect_mask = .{ .color = true }, .base_mip_level = 0, .level_count = 1, .base_array_layer = 0, .layer_count = 1 };
}
