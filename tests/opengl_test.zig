//! OpenGL integration test — drives **real OpenGL** through the platform
//! adapter's `.opengl` renderer path.
//!
//! The platform lib deliberately ships **no GL bindings**: it only manages the
//! context (`glCreateContext`/`glMakeCurrent`/`glSwapWindow`/…) and exposes
//! `glGetProcAddress`. The GL **loader/bindings live in the consumer**. Here the
//! consumer is this test: we **system-link `libGL`** (see `build.zig` —
//! `linkSystemLibrary("GL")` / `opengl32` / the `OpenGL` framework) and declare
//! the handful of entry points we call. That proves the hand-off end to end —
//! the lib makes the context, we drive GL — without the lib dragging in GL.
//!
//! Gated; needs a **display + a GL driver** (run under a real session or Xvfb +
//! a software GL like Mesa llvmpipe).

const std = @import("std");
const platform = @import("platform");

fn gate(implemented: bool) error{SkipZigTest}!void {
    if (!implemented) return error.SkipZigTest;
}

const done = .{
    .opengl_handoff = true,
};

// Real GL entry points, resolved at link time by the system-linked GL library.
const GLenum = c_uint;
const GLbitfield = c_uint;
const GLfloat = f32;
const GL_RENDERER: GLenum = 0x1F01;
const GL_VERSION: GLenum = 0x1F02;
const GL_COLOR_BUFFER_BIT: GLbitfield = 0x4000;
extern fn glGetString(name: GLenum) callconv(.c) ?[*:0]const u8;
extern fn glClearColor(r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) callconv(.c) void;
extern fn glClear(mask: GLbitfield) callconv(.c) void;

// WHEN driving GL through a platform `.opengl` window · GIVEN a system-linked libGL · THEN the context is made current, glGetString(GL_VERSION) returns a real string, and a clear+swap frame runs without error.
test "opengl: platform context + system-linked GL drive a frame" {
    try gate(done.opengl_handoff);

    try platform.init(.{});
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "gl-integration", .renderer = .opengl });
    defer win.destroy();

    // The lib makes + binds the context...
    const ctx = try platform.glCreateContext(win);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(win, ctx);
    platform.glSetSwapInterval(0);

    // ...and we drive real GL through the system-linked library.
    const version = glGetString(GL_VERSION) orelse return error.NoGlVersion;
    try std.testing.expect(std.mem.len(version) > 0);
    _ = glGetString(GL_RENDERER);

    glClearColor(0.1, 0.2, 0.3, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    platform.glSwapWindow(win);
}

// WHEN resolving a GL entry point via the lib's loader · GIVEN a current context · THEN a core symbol resolves non-null (the loader path, vs. the system-link path above).
test "opengl: glGetProcAddress loads a core symbol" {
    try gate(done.opengl_handoff);

    try platform.init(.{});
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "gl-loader", .renderer = .opengl });
    defer win.destroy();
    const ctx = try platform.glCreateContext(win);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(win, ctx);

    try std.testing.expect(platform.glGetProcAddress("glClear") != null);
}
