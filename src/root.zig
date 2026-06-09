//! zGameLib — a light, **transparent** game framework over the sibling adapter
//! libs (windowing/input + the Vulkan stack).
//!
//! Two tiers, the same opt-in / raw-first principle the libs use:
//!
//!  1. **High-level** — `App` (the loop), and the renderer/asset helpers to come.
//!  2. **The building blocks, re-exported** — reach `zgame.platform`, `zgame.vk`,
//!     `zgame.vma`, … directly and drive the raw APIs whenever you outgrow the
//!     convenience layer. Nothing is hidden; you never get stuck.
//!
//! Re-exports go **through** the libs (not parallel deps), so the vulkan stack's
//! version coherence (vk.xml ↔ VMA ↔ shaderc) and the SDL3 backend are inherited
//! intact.

const std = @import("std");

// --- Transparent re-exports: the building blocks --------------------------

/// Windowing + input (SDL3 backend). See the platform-stack adapter.
pub const platform = @import("platform");

/// The bundled Vulkan stack (vk + volk + VMA + shaderc) + per-OS surface creators.
pub const vulkan_stack = @import("vulkan_stack");

/// vulkan-zig's typed Vulkan API, re-exported through the stack.
pub const vk = vulkan_stack.vk;
/// Vulkan loader (volk).
pub const volk = vulkan_stack.volk;
/// GPU memory allocator (VMA).
pub const vma = vulkan_stack.vma;
/// GLSL → SPIR-V (shaderc; opt-in `-Dshaderc`).
pub const shaderc = vulkan_stack.shaderc;

/// The comptime platform↔vulkan **surface bridge** — the one place the two libs
/// meet, passing raw OS primitives. `createSurface(instance, window)`.
pub const surface = @import("surface");
/// A reusable **swapchain** (renderer policy: format/present-mode/recreation).
pub const swapchain = @import("swapchain");

// --- Render helpers (the boilerplate lifted out of the examples) ----------
// Same tier as surface/swapchain — reusable renderer policy the libs leave to
// the consumer, wired as their own modules in build.zig.

const gpu_mod = @import("gpu");
const frame_mod = @import("frame");

/// Vulkan **bring-up**: `Gpu.init(window, .{})` → instance + surface + device +
/// present queue, all as public fields. See gpu.zig.
pub const Gpu = gpu_mod.Gpu;
/// Record a full-subresource colour-image layout transition (one barrier).
pub const transitionImage = gpu_mod.transitionImage;
/// The **frames-in-flight** ring + the begin/record/end frame seam. See frame.zig.
pub const FrameRing = frame_mod.FrameRing;

// --- High-level framework layer -------------------------------------------

/// The application harness: window + frame loop. *(stub — being built out)*
pub const App = @import("app.zig").App;

test {
    // Force semantic analysis of the framework surface + the re-exports.
    std.testing.refAllDecls(@This());
}
