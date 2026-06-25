const std = @import("std");
const zgame = @import("zgame");

pub fn main() !void {
    const init_options: zgame.framework.InitOptions = .{ .app_name = "color-logger" };
    const framework = try zgame.framework.init(init_options);
    defer framework.deinit();

    const win = try zgame.Window.create(zgame.WindowOptions{
        .title = "color-logger",
        .size = .{ .w = 800, .h = 600 },
        .renderer = .vulkan,
    });
    defer win.destroy();

    while (!win.shouldClose()) {
        framework.pollEvents();
        const ev = framework.events();
        if (ev.close_requested) break;

        // todo
    }
}
