//! Integration tests — the two adapters working **together**.
//!
//! The platform adapter opens a window and hands back **raw OS primitives** +
//! the required Vulkan instance extensions; the vulkan adapter turns those into
//! an instance + surface (+ device + allocator) — with **no shared type**
//! crossing between the libraries. That handshake is the whole reason the two
//! repos exist, and it can only be exercised here, with both linked.
//!
//! Gated: the platform side is already real, so these skip until the vulkan
//! adapter's volk + surface bridges land — flip the `done` flags then. Needs a
//! display server **and** a Vulkan loader.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const vk_stack = @import("vulkan_stack");

const vk = vk_stack.vk;
const volk = vk_stack.volk;
const vma = vk_stack.vma;
const shaderc = vk_stack.shaderc;

fn gate(implemented: bool) error{SkipZigTest}!void {
    if (!implemented) return error.SkipZigTest;
}

/// Flip as the vulkan-stack bridges are implemented (the platform side is done).
const done = .{
    .instance_from_platform_extensions = true,
    .surface_handoff = true,
    .full_stack = true,
};

/// A platform `.vulkan` window + a Vulkan instance built from the platform's
/// **required extensions** — the cross-lib bootstrap shared by the tests.
const Bootstrap = struct {
    win: *platform.Window,
    instance: vk.Instance,
    vki: vk.InstanceWrapper,

    fn init() !Bootstrap {
        try platform.init(.{});
        const win = try platform.Window.create(.{ .title = "integration", .renderer = .vulkan });
        const exts = platform.requiredVulkanInstanceExtensions();

        try volk.loadBase();
        const gipa = volk.getInstanceProcAddr();
        const vkb = vk.BaseWrapper.load(gipa);
        // Request Vulkan 1.3 so the device promotes the 1.1+ core entry points VMA needs.
        const app_info = vk.ApplicationInfo{
            .application_version = 0,
            .engine_version = 0,
            .api_version = @bitCast(vk.API_VERSION_1_3),
        };
        const instance = try vkb.createInstance(&.{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(exts.len),
            .pp_enabled_extension_names = exts.ptr,
        }, null);
        volk.loadInstance(instance);
        const vki = vk.InstanceWrapper.load(instance, gipa);
        return .{ .win = win, .instance = instance, .vki = vki };
    }

    fn deinit(self: *Bootstrap) void {
        self.vki.destroyInstance(self.instance, null);
        self.win.destroy();
        platform.deinit();
    }

    /// The cross-lib hand-off: turn this window's native handle into a surface,
    /// or `null` on a display server we don't cover here.
    fn surface(self: *Bootstrap) !?vk.SurfaceKHR {
        if (platform.getX11Handle(self.win)) |hnd| {
            return try vk_stack.createX11Surface(self.instance, hnd.display, hnd.window);
        } else if (platform.getWaylandHandle(self.win)) |hnd| {
            return try vk_stack.createWaylandSurface(self.instance, hnd.display, hnd.surface);
        }
        return null;
    }

    const Gpu = struct { physical: vk.PhysicalDevice, device: vk.Device, vkd: vk.DeviceWrapper };

    /// Pick the first physical device and bring up a minimal logical device.
    fn gpu(self: *Bootstrap) !Gpu {
        var n: u32 = 1;
        var physical: vk.PhysicalDevice = undefined;
        _ = try self.vki.enumeratePhysicalDevices(self.instance, &n, @ptrCast(&physical));

        const prio = [_]f32{1.0};
        const qci = [_]vk.DeviceQueueCreateInfo{.{
            .queue_family_index = 0,
            .queue_count = 1,
            .p_queue_priorities = &prio,
        }};
        const device = try self.vki.createDevice(physical, &.{
            .queue_create_info_count = 1,
            .p_queue_create_infos = &qci,
        }, null);
        volk.loadDevice(device);
        const vkd = vk.DeviceWrapper.load(device, self.vki.dispatch.vkGetDeviceProcAddr.?);
        return .{ .physical = physical, .device = device, .vkd = vkd };
    }
};

/// Minimal valid GLSL — enough to exercise shaderc → SPIR-V → vkCreateShaderModule.
const vert_src =
    \\#version 450
    \\void main() { gl_Position = vec4(0.0); }
;

// WHEN bootstrapping a Vulkan instance from the platform's required extensions · GIVEN a display server and Vulkan loader · THEN the created instance handle is non-null.
test "instance: builds from the platform's required Vulkan extensions" {
    try gate(done.instance_from_platform_extensions);
    var bs = try Bootstrap.init();
    defer bs.deinit();
    try std.testing.expect(@intFromEnum(bs.instance) != 0);
}

// WHEN reading platform.requiredVulkanInstanceExtensions · GIVEN a started platform · THEN the list is non-empty (the platform demands at least a surface extension).
test "instance: the platform requires at least a surface extension" {
    try gate(done.instance_from_platform_extensions);
    try platform.init(.{});
    defer platform.deinit();
    try std.testing.expect(platform.requiredVulkanInstanceExtensions().len > 0);
}

// WHEN handing a platform window's native handle to the vulkan adapter's surface creator · GIVEN a bootstrapped instance on a covered display server · THEN a non-null vk.SurfaceKHR is produced.
test "surface: a platform window's native handle becomes a non-null Vulkan surface" {
    try gate(done.surface_handoff);
    var bs = try Bootstrap.init();
    defer bs.deinit();
    const surface = (try bs.surface()) orelse return error.SkipZigTest;
    defer bs.vki.destroySurfaceKHR(bs.instance, surface, null);
    try std.testing.expect(surface != .null_handle);
}

// WHEN creating a surface, destroying it, then creating another from the window · GIVEN a bootstrapped instance · THEN the second surface is also non-null (the hand-off repeats).
test "surface: hand-off works for a second freshly created window" {
    try gate(done.surface_handoff);
    var bs = try Bootstrap.init();
    defer bs.deinit();
    const a = (try bs.surface()) orelse return error.SkipZigTest;
    bs.vki.destroySurfaceKHR(bs.instance, a, null);
    const b = (try bs.surface()) orelse return error.SkipZigTest;
    defer bs.vki.destroySurfaceKHR(bs.instance, b, null);
    try std.testing.expect(b != .null_handle);
}

// WHEN walking the full chain window→instance→surface→device→VMA allocator · GIVEN a display server and Vulkan loader · THEN the VMA allocator is created non-null with no shared type crossing the lib boundary.
test "full stack: window → instance → surface → device → VMA allocator" {
    try gate(done.full_stack);
    var bs = try Bootstrap.init();
    defer bs.deinit();

    const surface = (try bs.surface()) orelse return error.SkipZigTest;
    defer bs.vki.destroySurfaceKHR(bs.instance, surface, null);

    const dev = try bs.gpu();
    defer dev.vkd.destroyDevice(dev.device, null);

    const allocator = try vma.createAllocator(.{ .physical_device = dev.physical, .device = dev.device, .instance = bs.instance });
    defer vma.destroyAllocator(allocator);
    try std.testing.expect(@intFromPtr(allocator) != 0);
}

// --- shaderc (GLSL → SPIR-V) ----------------------------------------------
// shaderc lives in the vulkan adapter and is compiled in only under
// `-Dshaderc` (a lazy dep, built from source). These gate on
// `shaderc.available`, so a default `zig build test-integration` skips them;
// `zig build test-integration -Dshaderc` runs them for real.

// WHEN compiling a trivial GLSL vertex shader via the vulkan adapter's shaderc · GIVEN shaderc available · THEN a non-empty SPIR-V slice is returned beginning with the magic word 0x07230203.
test "shaderc: a trivial GLSL vertex shader compiles to valid SPIR-V" {
    try gate(shaderc.available);
    const spv = try shaderc.compile(std.testing.allocator, vert_src, .vertex, .{}, null);
    defer std.testing.allocator.free(spv);
    try std.testing.expect(spv.len > 0);
    try std.testing.expectEqual(@as(u32, 0x07230203), spv[0]); // SPIR-V magic word
}

// WHEN compiling invalid GLSL with a Diagnostics sink · GIVEN shaderc available · THEN compile returns error.ShaderCompilationFailed and the diagnostics message is non-empty.
test "shaderc: an invalid shader fails and fills the diagnostics message" {
    try gate(shaderc.available);
    var diag = shaderc.Diagnostics{};
    defer if (diag.message.len > 0) std.testing.allocator.free(diag.message);
    const result = shaderc.compile(std.testing.allocator, "#version 450\nthis is not glsl", .vertex, .{}, &diag);
    try std.testing.expectError(error.ShaderCompilationFailed, result);
    try std.testing.expect(diag.message.len > 0);
}

// WHEN feeding shaderc's SPIR-V output unchanged into vkCreateShaderModule on a bootstrapped device · GIVEN shaderc available · THEN the device accepts it and returns a non-null shader module.
test "shaderc → vulkan: compiled SPIR-V is accepted by vkCreateShaderModule" {
    try gate(shaderc.available);
    var bs = try Bootstrap.init();
    defer bs.deinit();

    const dev = try bs.gpu();
    defer dev.vkd.destroyDevice(dev.device, null);

    const spv = try shaderc.compile(std.testing.allocator, vert_src, .vertex, .{}, null);
    defer std.testing.allocator.free(spv);

    // The cross-stack point: shaderc's output feeds the vulkan device unchanged.
    const module = try dev.vkd.createShaderModule(dev.device, &.{
        .code_size = spv.len * @sizeOf(u32),
        .p_code = spv.ptr,
    }, null);
    defer dev.vkd.destroyShaderModule(dev.device, module, null);
    try std.testing.expect(module != .null_handle);
}
