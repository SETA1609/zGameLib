//! Build for zGameLib — the game framework over the two adapter libs.
//!
//! Model (same libs-first / link-the-artifact shape as the adapters): each lib
//! under libs/ builds its own static-library artifact and exposes its Zig
//! module. The `zgame` module re-exports those modules; consumers import `zgame`
//! and link its artifact. The framework's behavioral suite (the cross-lib
//! integration + OpenGL tests) is `zig build test-tdd` — it needs a display +
//! a Vulkan/GL driver, so it's run locally / under Xvfb in CI.
//!
//! Examples live in `examples/` and are built as consumers of the framework
//! (importing `zgame` or `zgame_platform`). They are NOT part of the library
//! package — `examples/` is excluded from `.paths` in `build.zig.zon`.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Pass through to the vulkan stack: runtime GLSL→SPIR-V (shaderc), off by default.
    const enable_shaderc = b.option(bool, "shaderc", "Build the vulkan stack with runtime shaderc (GLSL→SPIR-V)") orelse false;

    const platform_dep = b.dependency("platform", .{ .target = target, .optimize = optimize });
    const vulkan_dep = b.dependency("vulkan_stack", .{ .target = target, .optimize = optimize, .shaderc = enable_shaderc });

    // Shared glue (renderer policy the libs leave to the consumer): the comptime
    // surface bridge + a reusable swapchain.
    const surface_mod = b.createModule(.{
        .root_source_file = b.path("shared/surface.zig"),
        .target = target,
        .optimize = optimize,
    });
    surface_mod.addImport("platform", platform_dep.module("platform"));
    surface_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));

    const swapchain_mod = b.createModule(.{
        .root_source_file = b.path("shared/swapchain.zig"),
        .target = target,
        .optimize = optimize,
    });
    swapchain_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));

    // Render helpers (the boilerplate lifted out of the examples): Vulkan
    // bring-up + the frames-in-flight ring. Same tier as surface/swapchain.
    const gpu_mod = b.createModule(.{
        .root_source_file = b.path("shared/gpu.zig"),
        .target = target,
        .optimize = optimize,
    });
    gpu_mod.addImport("platform", platform_dep.module("platform"));
    gpu_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    gpu_mod.addImport("surface", surface_mod);
    gpu_mod.addImport("swapchain", swapchain_mod);

    const frame_mod = b.createModule(.{
        .root_source_file = b.path("shared/frame.zig"),
        .target = target,
        .optimize = optimize,
    });
    frame_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    frame_mod.addImport("swapchain", swapchain_mod);

    // The framework module — re-exports the building blocks + the glue.
    const zgame_mod = b.addModule("zgame", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgame_mod.addImport("platform", platform_dep.module("platform"));
    zgame_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    zgame_mod.addImport("surface", surface_mod);
    zgame_mod.addImport("swapchain", swapchain_mod);
    zgame_mod.addImport("gpu", gpu_mod);
    zgame_mod.addImport("frame", frame_mod);
    zgame_mod.linkLibrary(platform_dep.artifact("platform"));
    zgame_mod.linkLibrary(vulkan_dep.artifact("vulkan_stack"));

    // The **platform-only** flavour of the framework — re-exports `platform` and
    // links ONLY the platform artifact (drags no vulkan). Consumers whose binary
    // must show zero vk*/VK_ symbols (the decoupling gate, the OpenGL hand-off)
    // import this instead of the full `zgame`, yet still reach the adapter
    // *through* the framework rather than depending on it directly.
    const zgame_platform_mod = b.addModule("zgame_platform", .{
        .root_source_file = b.path("src/root_platform.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgame_platform_mod.addImport("platform", platform_dep.module("platform"));
    zgame_platform_mod.linkLibrary(platform_dep.artifact("platform"));

    // `zig build test` — analyze + link the framework module (refAllDecls).
    const mod_tests = b.addTest(.{ .root_module = zgame_mod });
    b.step("test", "Analyze + link the framework module")
        .dependOn(&b.addRunArtifact(mod_tests).step);

    // `zig build test-tdd` — the framework's behavioral suite = the cross-lib
    // integration tests + the OpenGL hand-off test. Needs a display + a
    // Vulkan/GL driver (run locally or under Xvfb + Mesa software drivers).
    const itest_mod = b.createModule(.{
        .root_source_file = b.path("tests/integration_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    itest_mod.addImport("platform", platform_dep.module("platform"));
    itest_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    itest_mod.linkLibrary(platform_dep.artifact("platform"));
    itest_mod.linkLibrary(vulkan_dep.artifact("vulkan_stack"));
    const itests = b.addTest(.{ .root_module = itest_mod });

    const gltest_mod = b.createModule(.{
        .root_source_file = b.path("tests/opengl_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gltest_mod.addImport("platform", platform_dep.module("platform"));
    gltest_mod.addImport("surface", surface_mod);
    gltest_mod.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    gltest_mod.linkLibrary(platform_dep.artifact("platform"));
    gltest_mod.linkLibrary(vulkan_dep.artifact("vulkan_stack"));
    switch (target.result.os.tag) {
        .windows => gltest_mod.linkSystemLibrary("opengl32", .{}),
        .macos => gltest_mod.linkFramework("OpenGL", .{}),
        else => gltest_mod.linkSystemLibrary("GL", .{}),
    }
    const gltests = b.addTest(.{ .root_module = gltest_mod });

    // The render-abstractions spec: drives the framework's OWN api (`zgame.Gpu`,
    // `zgame.FrameRing`, `zgame.transitionImage`), so it imports the `zgame`
    // module rather than the adapters directly. Importing `zgame` propagates its
    // linked artifacts. Needs a display + a Vulkan loader (skips otherwise).
    const gputest_mod = b.createModule(.{
        .root_source_file = b.path("tests/gpu_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gputest_mod.addImport("zgame", zgame_mod);
    const gputests = b.addTest(.{ .root_module = gputest_mod });

    // The suite is also exposed as named steps so a consumer's CI can run
    // them with different gating (e.g. OpenGL gates, lavapipe-Vulkan is
    // informational). `test-tdd` runs both.
    const itest_step = b.step("test-integration", "Cross-lib integration test (window → surface → device → present; needs a display + Vulkan)");
    itest_step.dependOn(&b.addRunArtifact(itests).step);

    const gltest_step = b.step("test-opengl", "OpenGL hand-off test (system-linked GL; needs a display + a GL driver)");
    gltest_step.dependOn(&b.addRunArtifact(gltests).step);

    const gputest_step = b.step("test-gpu", "Render-abstractions spec (Gpu + FrameRing + transitionImage; needs a display + Vulkan)");
    gputest_step.dependOn(&b.addRunArtifact(gputests).step);

    const tdd = b.step("test-tdd", "Run the framework's behavioral suite (integration + opengl + gpu; needs a display + Vulkan/GL)");
    tdd.dependOn(itest_step);
    tdd.dependOn(gltest_step);
    tdd.dependOn(gputest_step);

    // --- Examples: consumers of the framework, NOT part of the library -------
    // Each example is a standalone executable that imports `zgame` or
    // `zgame_platform`. They live in `examples/` which is excluded from
    // `.paths` in `build.zig.zon`.

    // Rung 0: event-logger (platform-only, no vulkan)
    addExample(b, .{
        .name = "event-logger",
        .source = "examples/event-logger/main.zig",
        .description = "Build + run the platform-only event logger (rung 0)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_platform_mod,
    });

    // Rung 1: clear-color (full framework)
    addExample(b, .{
        .name = "clear-color",
        .source = "examples/clear-color/main.zig",
        .description = "Build + run the reactive clear-color example (rung 1)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    });

    // Rung 1, reprise: clear-color-2 (built on zGameLib abstractions)
    addExample(b, .{
        .name = "clear-color-2",
        .source = "examples/clear-color-2/main.zig",
        .description = "Build + run clear-color rebuilt on the zGameLib abstractions",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    });

    // color-logger (stub, full framework)
    addExample(b, .{
        .name = "color-logger",
        .source = "examples/color-logger/color-loger.zig",
        .description = "Build + run the color-logger example",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    });
}

const ExampleOpts = struct {
    name: []const u8,
    source: []const u8,
    description: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// The zGameLib module this example imports as `zgame` (full or platform-only).
    zgame_mod: *std.Build.Module,
};

fn addExample(b: *std.Build, opts: ExampleOpts) void {
    const exe = b.addExecutable(.{
        .name = opts.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(opts.source),
            .target = opts.target,
            .optimize = opts.optimize,
        }),
    });
    exe.root_module.addImport("zgame", opts.zgame_mod);
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step(opts.name, opts.description).dependOn(&run.step);
}
