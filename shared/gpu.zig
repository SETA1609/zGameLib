//! GPU bring-up — the Vulkan boilerplate every rung repeats, in one place.
//!
//! `Gpu.init(window, .{})` does the whole handshake the raw clear-color spells
//! out by hand: load volk → create the instance (with the platform's required
//! extensions) → bridge the window to a surface → pick a physical device + a
//! present-capable queue family → create the device + queue. It owns the
//! instance/surface/device and tears them down in `deinit`.
//!
//! Stays **transparent** like the rest of zGameLib: every handle and dispatch
//! table is a public field, so an app that outgrows this drops straight to the
//! raw `vk` calls — nothing is hidden. Lives next to surface.zig/swapchain.zig
//! because it is the same tier: reusable renderer policy the libs leave to us.

const std = @import("std");
const platform = @import("platform");
const vulkan_stack = @import("vulkan_stack");
const surface_bridge = @import("surface");
const sc = @import("swapchain");
const vk = vulkan_stack.vk;
const volk = vulkan_stack.volk;

pub const Gpu = struct {
    instance: vk.Instance,
    vkb: vk.BaseWrapper,
    vki: vk.InstanceWrapper,
    surface: vk.SurfaceKHR,
    pdev: vk.PhysicalDevice,
    qfam: u32,
    device: vk.Device,
    vkd: vk.DeviceWrapper,
    queue: vk.Queue,

    pub const Options = struct {
        app_name: [*:0]const u8 = "zgame",
        /// Packed as `@bitCast(vk.API_VERSION_x_y)`.
        api_version: u32 = @bitCast(vk.API_VERSION_1_3),
    };

    /// Loader → instance → surface → device → queue. The window supplies both
    /// the required instance extensions and the native handle for the surface.
    pub fn init(window: *platform.Window, options: Options) !Gpu {
        try volk.loadBase();
        const gipa = volk.getInstanceProcAddr();
        const vkb = vk.BaseWrapper.load(gipa);

        const app_info = vk.ApplicationInfo{
            .p_application_name = options.app_name,
            .application_version = 0,
            .engine_version = 0,
            .api_version = options.api_version,
        };
        const exts = platform.requiredVulkanInstanceExtensions();
        const instance = try vkb.createInstance(&.{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(exts.len),
            .pp_enabled_extension_names = exts.ptr,
        }, null);
        const vki = vk.InstanceWrapper.load(instance, gipa);
        errdefer vki.destroyInstance(instance, null);

        // The one cross-lib seam: native handle → surface (no shared type).
        const surf = try surface_bridge.createSurface(instance, window);
        errdefer vki.destroySurfaceKHR(instance, surf, null);

        var pdev: vk.PhysicalDevice = undefined;
        var pn: u32 = 1;
        _ = try vki.enumeratePhysicalDevices(instance, &pn, @ptrCast(&pdev));
        const qfam = try presentQueueFamily(vki, pdev, surf);

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
        errdefer vkd.destroyDevice(device, null);
        const queue = vkd.getDeviceQueue(device, qfam, 0);

        return .{
            .instance = instance,
            .vkb = vkb,
            .vki = vki,
            .surface = surf,
            .pdev = pdev,
            .qfam = qfam,
            .device = device,
            .vkd = vkd,
            .queue = queue,
        };
    }

    pub fn deinit(self: *Gpu) void {
        self.vkd.destroyDevice(self.device, null);
        self.vki.destroySurfaceKHR(self.instance, self.surface, null);
        self.vki.destroyInstance(self.instance, null);
    }

    /// A swapchain bound to this device/surface, sized to `want`. The
    /// `Swapchain` keeps its own copies of the dispatch tables — see swapchain.zig.
    pub fn createSwapchain(self: *Gpu, want: vk.Extent2D) !sc.Swapchain {
        var chain = sc.Swapchain{
            .vki = self.vki,
            .vkd = self.vkd,
            .pdev = self.pdev,
            .device = self.device,
            .surface = self.surface,
        };
        try chain.init(want);
        return chain;
    }

    /// Block until the device is idle — call before tearing frame resources down.
    pub fn waitIdle(self: *Gpu) void {
        self.vkd.deviceWaitIdle(self.device) catch {};
    }
};

fn presentQueueFamily(vki: vk.InstanceWrapper, pdev: vk.PhysicalDevice, surface: vk.SurfaceKHR) !u32 {
    var n: u32 = 0;
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &n, null);
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        if ((try vki.getPhysicalDeviceSurfaceSupportKHR(pdev, i, surface)) == .true) return i;
    }
    return error.NoPresentQueue;
}

/// Record a full-subresource colour-image layout transition (one image memory
/// barrier) — the layout dance every swapchain-targeting rung repeats. A free
/// function (not a `Gpu` method): it needs only a device dispatch + a command
/// buffer, so it composes with whatever recording the app is doing.
pub fn transitionImage(
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
        .subresource_range = sc.colorRange(),
    };
    vkd.cmdPipelineBarrier(cmd, src_stage, dst_stage, .{}, null, null, &.{b});
}
