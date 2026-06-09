//! Build for zGameLib — the game framework over the two adapter libs.
//!
//! Model (same libs-first / link-the-artifact shape as the adapters): each lib
//! under libs/ builds its own static-library artifact and exposes its Zig
//! module. The `zgame` module re-exports those modules; consumers import `zgame`
//! and link its artifact. The framework's behavioral suite (the cross-lib
//! integration + OpenGL tests) is `zig build test-tdd` — it needs a display +
//! a Vulkan/GL driver, so it's run locally / under Xvfb in CI.

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
    gltest_mod.linkLibrary(platform_dep.artifact("platform"));
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

    // The suite is also exposed as two named steps so a consumer's CI can run
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
}
