//! A depth buffer for the 3D path: one depth image, its memory, and a view,
//! sized to the swapchain extent. The format is D32 when the device supports
//! it as a depth attachment, else X8_D24 (`findSupportedDepthFormat`).
//!
//! Used with dynamic rendering (`Gpu.Options.enable_dynamic_rendering`): each
//! frame, `recordTransitionToAttachment` moves the image into the depth
//! attachment layout (its old contents are discarded), and the app passes
//! `view` as the depth attachment of `cmdBeginRendering`. Transparent like the
//! rest of zGameLib: every handle is a public field.

const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

/// Depth formats `DepthBuffer` can use, most preferred first. The Vulkan spec
/// requires depth-attachment support for at least one of the two.
pub const depth_format_candidates = [_]vk.Format{ .d32_sfloat, .x8_d24_unorm_pack32 };

/// The first of `candidates` that is also in `supported_depth_formats`, or null.
/// Pure, so the fallback order is testable without a GPU.
pub fn chooseFirstSupportedDepthFormat(candidates: []const vk.Format, supported_depth_formats: []const vk.Format) ?vk.Format {
    for (candidates) |candidate| {
        for (supported_depth_formats) |supported_depth_format| {
            if (candidate == supported_depth_format) return candidate;
        }
    }
    return null;
}

/// The first of `depth_format_candidates` the device supports as an optimal-tiling
/// depth attachment. `gpu` is a `*Gpu` (or anything with `.vki` and `.pdev`).
pub fn findSupportedDepthFormat(gpu: anytype) error{NoSupportedDepthFormat}!vk.Format {
    var supported_depth_formats: [depth_format_candidates.len]vk.Format = undefined;
    var supported_count: usize = 0;
    for (depth_format_candidates) |candidate| {
        const format_properties = gpu.vki.getPhysicalDeviceFormatProperties(gpu.pdev, candidate);
        if (format_properties.optimal_tiling_features.depth_stencil_attachment) {
            supported_depth_formats[supported_count] = candidate;
            supported_count += 1;
        }
    }
    return chooseFirstSupportedDepthFormat(&depth_format_candidates, supported_depth_formats[0..supported_count]) orelse
        error.NoSupportedDepthFormat;
}

pub const DepthBuffer = struct {
    /// The preferred format; `create` falls back to the next candidate when the device lacks it.
    pub const depth_format: vk.Format = .d32_sfloat;

    vkd: vk.DeviceWrapper,
    device: vk.Device,
    image: vk.Image = .null,
    memory: vk.DeviceMemory = .null,
    view: vk.ImageView = .null,
    format: vk.Format = depth_format,
    extent: vk.Extent2D,

    /// Uses `findSupportedDepthFormat`. `gpu` is a `*Gpu` (or anything with `.vkd`,
    /// `.device`, `.vki`, `.pdev`, and `findMemoryTypeIndex`).
    pub fn create(gpu: anytype, extent: vk.Extent2D) !DepthBuffer {
        var depth_buffer = DepthBuffer{
            .vkd = gpu.vkd,
            .device = gpu.device,
            .format = try findSupportedDepthFormat(gpu),
            .extent = extent,
        };
        try depth_buffer.createImageMemoryAndView(gpu);
        return depth_buffer;
    }

    pub fn destroy(self: *DepthBuffer) void {
        if (self.view != .null) self.vkd.destroyImageView(self.device, self.view, null);
        if (self.image != .null) self.vkd.destroyImage(self.device, self.image, null);
        if (self.memory != .null) self.vkd.freeMemory(self.device, self.memory, null);
        self.view = .null;
        self.image = .null;
        self.memory = .null;
    }

    /// Rebuild for a new extent (after the swapchain was recreated). The device must be idle.
    pub fn recreate(self: *DepthBuffer, gpu: anytype, extent: vk.Extent2D) !void {
        self.destroy();
        self.extent = extent;
        try self.createImageMemoryAndView(gpu);
    }

    /// Move the image to `depth_attachment_optimal` before rendering. The previous
    /// contents are discarded, which is what a depth buffer cleared every frame wants.
    /// The barrier waits for earlier depth writes (the previous frame in flight uses
    /// the same image), so the transition cannot overwrite them while they run.
    pub fn recordTransitionToAttachment(self: *const DepthBuffer, command_buffer: vk.CommandBuffer) void {
        const barrier = vk.ImageMemoryBarrier{
            .src_access_mask = .{ .depth_stencil_attachment_write = true },
            .dst_access_mask = .{ .depth_stencil_attachment_read = true, .depth_stencil_attachment_write = true },
            .old_layout = .undefined,
            .new_layout = .depth_attachment_optimal,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .image = self.image,
            .subresource_range = depthSubresourceRange(),
        };
        self.vkd.cmdPipelineBarrier(
            command_buffer,
            .{ .early_fragment_tests = true, .late_fragment_tests = true },
            .{ .early_fragment_tests = true, .late_fragment_tests = true },
            .{},
            null,
            null,
            &.{barrier},
        );
    }

    fn createImageMemoryAndView(self: *DepthBuffer, gpu: anytype) !void {
        errdefer self.destroy();
        self.image = try self.vkd.createImage(self.device, &.{
            .image_type = .@"2d",
            .format = self.format,
            .extent = .{ .width = self.extent.width, .height = self.extent.height, .depth = 1 },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{ .@"1" = true },
            .tiling = .optimal,
            .usage = .{ .depth_stencil_attachment = true },
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        }, null);
        const memory_requirements = self.vkd.getImageMemoryRequirements(self.device, self.image);
        self.memory = try self.vkd.allocateMemory(self.device, &.{
            .allocation_size = memory_requirements.size,
            .memory_type_index = try gpu.findMemoryTypeIndex(memory_requirements.memory_type_bits, .{ .device_local = true }),
        }, null);
        try self.vkd.bindImageMemory(self.device, self.image, self.memory, 0);
        self.view = try self.vkd.createImageView(self.device, &.{
            .image = self.image,
            .view_type = .@"2d",
            .format = self.format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = depthSubresourceRange(),
        }, null);
    }
};

pub fn depthSubresourceRange() vk.ImageSubresourceRange {
    return .{
        .aspect_mask = .{ .depth = true },
        .base_mip_level = 0,
        .level_count = 1,
        .base_array_layer = 0,
        .layer_count = 1,
    };
}
