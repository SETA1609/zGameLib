//! Framework animation abstraction — the unified animation API zGameLib lifts
//! over the raw `zclip` lib, the same way surface/swapchain/gpu/frame abstract
//! the platform and vulkan adapters.
//!
//! `zclip` provides two raw paths (sprite-atlas, skeletal-from-glTF) and no
//! timeline logic. This module is where that timeline/playback policy lives:
//! the clip-agnostic cursor (duration, looping/ping-pong, speed) plus a single
//! `Animator` that plays *either* path through one interface, so a consumer
//! swaps a sprite clip for a skeletal one without changing call sites.
//!
//! Structure only — nothing implemented. See ../libs/zClip/PLAN.md.

const zclip = @import("zclip");

// Intended surface (built out later):
//   - PlayMode { once, loop, ping_pong } and a Cursor that advances by dt.
//   - Animator(Path) — drives a zclip.sprite or zclip.skeletal clip from a
//     Cursor and exposes the current pose (frame rect / joint palette).
// Kept as a doc scaffold so the framework wiring (build.zig + root.zig
// re-export) is in place before the API lands.
comptime {
    _ = zclip;
}
