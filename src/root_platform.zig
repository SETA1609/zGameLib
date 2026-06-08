//! zGameLib — **platform-only** entry.
//!
//! Same framework, windowing/input slice only: re-exports `platform` and links
//! **just** the platform adapter — it drags **no vulkan**. This is the import
//! path for binaries that must prove zero `vk*`/`VK_` symbols (the rung-0
//! decoupling gate, the OpenGL hand-off) while still reaching the adapter
//! *through* zGameLib rather than depending on it directly.
//!
//! Because the vulkan stack is absent here, `@import("zgame").vk` & friends
//! simply don't exist on this module — the decoupling is enforced by the type
//! system, not just by an `nm` check. Reach for the full `zgame` module when
//! you need the GPU stack.

/// Windowing + input (SDL3 backend). See the platform-stack adapter.
pub const platform = @import("platform");

test {
    @import("std").testing.refAllDecls(@This());
}
