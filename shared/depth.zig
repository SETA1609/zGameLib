//! A depth buffer for the 3D path: one D32 depth image, its memory, and a view,
//! sized to the swapchain extent.
//!
//! Used with dynamic rendering (`Gpu.Options.enable_dynamic_rendering`): each
//! frame, `recordTransitionToAttachment` moves the image into the depth
//! attachment layout (its old contents are discarded), and the app passes
//! `view` as the depth attachment of `cmdBeginRendering`. Transparent like the
//! rest of zGameLib: every handle is a public field.

const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

pub const DepthBuffer = struct {
    pub const depth_format: vk.Format = .d32_sfloat;

    vkd: vk.DeviceWrapper,
    device: vk.Device,
    image: vk.Image = .null,
    memory: vk.DeviceMemory = .null,
    view: vk.ImageView = .null,
    format: vk.Format = depth_format,
    extent: vk.Extent2D,

    /// `gpu` is a `*Gpu` (or anything with `.vkd`, `.device`, and `findMemoryTypeIndex`).
    pub fn create(gpu: anytype, extent: vk.Extent2D) !DepthBuffer {
        var depth_buffer = DepthBuffer{ .vkd = gpu.vkd, .device = gpu.device, .extent = extent };
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
    pub fn recordTransitionToAttachment(self: *const DepthBuffer, command_buffer: vk.CommandBuffer) void {
        const barrier = vk.ImageMemoryBarrier{
            .src_access_mask = .{},
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
            .{ .top_of_pipe = true },
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
