//! Event logger — rung 0 warm-up, PLATFORM ONLY.
//!
//! Opens a window with `renderer = .none`, pumps events, prints each `Event`
//! to stdout, and quits on ESC. Reaches the platform adapter through the
//! framework (`zgame.platform`) and **touches no vulkan** — this binary is the
//! gate for the first `nm` decoupling check (no `vk*` / `VK_` symbols).
//!
//! Full design — frame loop, exact lib calls, success criteria:
//!   ../../docs/event-logger.md
//! Definition of done + todo list:
//!   ./README.md
//!
//! Intentionally a stub — write the implementation by hand.

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;

const Action = enum(u16) {
    menu_pause,
};

pub fn main() !void {
    try platform.init(.{});
    defer platform.deinit();
    const window = try platform.Window.create(.{
        .title = "event-logger",
        .size = .{ .w = 800, .h = 600 },
        .renderer = .none,
    });
    defer window.destroy();

    platform.bindAction(Action.menu_pause, .{ .key = .escape });

    while (!window.shouldClose()) {
        platform.pollAllEvents();

        while (platform.nextEvent()) |ev| {
            std.debug.print("{any}\n", .{ev});
            if (ev == .close) return;
        }
        if (platform.actionJustPressed(Action.menu_pause)) return;
    }
}
