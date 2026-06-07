//! The high-level application harness — window + frame loop, built on the
//! re-exported `platform` (and, for GPU rendering, the vulkan stack + the
//! surface/swapchain glue). Opt-in: you can ignore `App` entirely and drive
//! `zgame.platform` / `zgame.vk` yourself.
//!
//! Stub for now — bodies `@panic` until the loop + renderer land. See ROADMAP.

const std = @import("std");
const platform = @import("platform");

pub const App = struct {
    window: *platform.Window,

    pub const Options = struct {
        title: []const u8 = "zGame",
        width: u32 = 1280,
        height: u32 = 720,
        /// Which renderer the window binds (see `platform.Renderer`).
        renderer: platform.Renderer = .vulkan,
    };

    /// Bring the platform up and open the window. Caller owns it — `deinit`.
    pub fn init(options: Options) !App {
        _ = options;
        @panic("not implemented");
    }

    /// Tear down the window + platform.
    pub fn deinit(self: *App) void {
        _ = self;
        @panic("not implemented");
    }

    /// `true` until the window is asked to close — drives the main loop.
    pub fn running(self: *App) bool {
        _ = self;
        @panic("not implemented");
    }

    /// Pump one frame of events (call once per loop iteration).
    pub fn pumpEvents(self: *App) void {
        _ = self;
        @panic("not implemented");
    }
};
