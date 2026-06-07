//! Comptime platform↔vulkan surface bridge, reused by every example.
//!
//! Pairs the platform adapter's per-OS native-handle getter with the vulkan
//! adapter's matching surface creator, branching on the target OS at comptime
//! and passing **raw OS primitives** — no shared type crosses the boundary.
//! This is the single place the two libs meet. Design: ../docs/clear-color.md.

const builtin = @import("builtin");
const platform = @import("platform");
const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

pub const Error = error{NoSupportedSurface} || vulkan_stack.SurfaceError;

/// Turn a platform window's native handle into a `vk.SurfaceKHR`. On Linux the
/// session may be X11 *or* Wayland, so we try each at runtime; other targets
/// have exactly one path, chosen at comptime.
pub fn createSurface(instance: vk.Instance, window: *platform.Window) Error!vk.SurfaceKHR {
    // Android is `os.tag == .linux` with `abi == .android`, so check abi first.
    if (comptime builtin.target.abi == .android) {
        const h = platform.getAndroidHandle(window) orelse return error.NoSupportedSurface;
        return vulkan_stack.createAndroidSurface(instance, h.window);
    }
    switch (comptime builtin.target.os.tag) {
        .linux => {
            if (platform.getX11Handle(window)) |h|
                return vulkan_stack.createX11Surface(instance, h.display, h.window);
            if (platform.getWaylandHandle(window)) |h|
                return vulkan_stack.createWaylandSurface(instance, h.display, h.surface);
            return error.NoSupportedSurface;
        },
        .windows => {
            const h = platform.getWin32Handle(window) orelse return error.NoSupportedSurface;
            return vulkan_stack.createWin32Surface(instance, h.hinstance, h.hwnd);
        },
        else => @compileError("surface bridge: unsupported target OS"),
    }
}
