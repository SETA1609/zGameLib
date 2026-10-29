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
        _ = .{ gpu, extent };
        @panic("not implemented");
    }

    pub fn destroy(self: *DepthBuffer) void {
        _ = self;
        @panic("not implemented");
    }

    /// Rebuild for a new extent (after the swapchain was recreated). The device must be idle.
    pub fn recreate(self: *DepthBuffer, gpu: anytype, extent: vk.Extent2D) !void {
        _ = .{ self, gpu, extent };
        @panic("not implemented");
    }

    /// Move the image to `depth_attachment_optimal` before rendering. The previous
    /// contents are discarded, which is what a depth buffer cleared every frame wants.
    pub fn recordTransitionToAttachment(self: *const DepthBuffer, command_buffer: vk.CommandBuffer) void {
        _ = .{ self, command_buffer };
        @panic("not implemented");
    }
};

pub fn depthSubresourceRange() vk.ImageSubresourceRange {
    @panic("not implemented");
}
