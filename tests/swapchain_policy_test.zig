//! Spec for zGameLib's swapchain policy, `swapchain.framework_options`: the
//! options zGameLib passes to the Vulkan adapter's `Swapchain` helper. Pure
//! data and the adapter's pure `select*` functions, so it runs under
//! `zig build test` with no display or GPU.

const std = @import("std");
const swapchain = @import("swapchain");
const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

const AdapterSwapchain = vulkan_stack.Swapchain;

// WHEN reading the framework policy · THEN it prefers sRGB BGRA in the sRGB non-linear colour space.
test "framework policy prefers sRGB BGRA" {
    try std.testing.expectEqual(vk.Format.b8g8r8a8_srgb, swapchain.framework_options.preferred_format.format);
    try std.testing.expectEqual(vk.ColorSpaceKHR.srgb_nonlinear_khr, swapchain.framework_options.preferred_format.color_space);
}

// WHEN a surface offers mailbox · GIVEN the framework policy · THEN mailbox is chosen.
test "framework policy chooses mailbox when the surface offers it" {
    const available = [_]vk.PresentModeKHR{ .fifo_khr, .mailbox_khr, .immediate_khr };
    const chosen = AdapterSwapchain.selectPresentMode(&available, swapchain.framework_options.preferred_present_mode);
    try std.testing.expectEqual(vk.PresentModeKHR.mailbox_khr, chosen);
}

// WHEN a surface offers no mailbox · GIVEN the framework policy · THEN FIFO is chosen (always supported).
test "framework policy falls back to FIFO without mailbox" {
    const available = [_]vk.PresentModeKHR{ .immediate_khr, .fifo_khr };
    const chosen = AdapterSwapchain.selectPresentMode(&available, swapchain.framework_options.preferred_present_mode);
    try std.testing.expectEqual(vk.PresentModeKHR.fifo_khr, chosen);
}

// WHEN a surface reports a minimum of 2 images and no maximum · GIVEN the framework policy · THEN it asks for 3 (minimum + 1).
test "framework policy asks for one image more than the minimum" {
    var capabilities = std.mem.zeroes(vk.SurfaceCapabilitiesKHR);
    capabilities.min_image_count = 2;
    capabilities.max_image_count = 0;
    const image_count = AdapterSwapchain.selectImageCount(capabilities, swapchain.framework_options.desired_image_count);
    try std.testing.expectEqual(@as(u32, 3), image_count);
}

// WHEN reading the framework policy · THEN swapchain images are colour attachments and transfer destinations (for clears).
test "framework policy asks for colour-attachment and transfer-destination usage" {
    try std.testing.expect(swapchain.framework_options.image_usage.color_attachment);
    try std.testing.expect(swapchain.framework_options.image_usage.transfer_dst);
}
