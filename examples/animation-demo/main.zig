const std = @import("std");

/// Animation-demo — rung 3.
///
/// Adds zClip (animation) to the stack. This example is a STUB —
/// the animation lib is under active development. When complete, it will
/// load a sprite atlas, advance a clip each frame, and blit to screen.
///
/// Libraries compiled: platform + vulkan_stack + zclip
/// Libraries NOT compiled: zaudio, zassets
pub fn main() !void {
    std.debug.print("animation-demo: stub — zClip animation not yet implemented\n", .{});

    // TODO:
    //   const zclip = @import("zclip");
    //   const atlas = try zclip.sprite.Atlas.parse(alloc, "assets/atlas.json");
    //   const clip = zclip.sprite.Clip.init(atlas.frames, .loop);
    //   // Frame loop: clip.advance(dt), blit current frame
}
