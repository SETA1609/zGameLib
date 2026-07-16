const std = @import("std");

/// Asset-demo — rung 5 (planned).
///
/// Adds zassets (asset loading / VFS) to the stack. This example is a STUB —
/// the zassets library does not exist yet.
///
/// When complete, it will:
///   1. Initialise the virtual filesystem (zassets.VFS).
///   2. Mount a game asset pack.
///   3. Load a textured mesh from the VFS.
///   4. Render it with Vulkan.
///
/// Libraries compiled:
///   - platform (windowing + input)
///   - vulkan_stack (rendering)
///   - zassets (asset loading / VFS)
///
/// Libraries NOT compiled (pay-for-what-you-use):
///   - zClip ❌ (no animation)
///   - zaudio ❌ (no audio)
///
/// This demonstrates adding asset loading without pulling in unrelated deps.
pub fn main() !void {
    // TODO: platform.init(.{})
    // TODO: var vfs = try zassets.VFS.init(alloc);
    // TODO: try vfs.mount("assets/game.pack");
    // TODO: const mesh_data = try vfs.read("models/cube.glb");
    // TODO: Render mesh with Vulkan (same pattern as hello-triangle)

    std.debug.print("asset-demo: stub — zassets lib does not exist yet\n", .{});
}
