//! Spec for choosing `DepthBuffer`'s format (`shared/depth.zig`). Pure: the
//! supported formats are passed in, so the fallback order is checked without a
//! GPU and runs under `zig build test`.

const std = @import("std");
const depth = @import("depth");
const vk = @import("vulkan_stack").vk;

test "the preferred depth format is chosen when the device supports it" {
    const supported = [_]vk.Format{ .x8_d24_unorm_pack32, .d32_sfloat };
    try std.testing.expectEqual(@as(?vk.Format, .d32_sfloat), depth.chooseFirstSupportedDepthFormat(&depth.depth_format_candidates, &supported));
}

test "the fallback depth format is chosen when only it is supported" {
    const supported = [_]vk.Format{ .d16_unorm, .x8_d24_unorm_pack32 };
    try std.testing.expectEqual(@as(?vk.Format, .x8_d24_unorm_pack32), depth.chooseFirstSupportedDepthFormat(&depth.depth_format_candidates, &supported));
}

test "no depth format is chosen when no candidate is supported" {
    const supported = [_]vk.Format{.d16_unorm};
    try std.testing.expectEqual(@as(?vk.Format, null), depth.chooseFirstSupportedDepthFormat(&depth.depth_format_candidates, &supported));
}

test "D32 is the most preferred candidate" {
    try std.testing.expectEqual(vk.Format.d32_sfloat, depth.depth_format_candidates[0]);
}
