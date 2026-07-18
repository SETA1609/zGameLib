//! Step: test targets.
//!
//! Registers all test steps: unit analysis (refAllDecls), cross-lib integration,
//! OpenGL hand-off, GPU abstraction spec, and the composite `test-tdd` suite.
//! Each step is backed by a separate test binary with its own module imports.
//!
//! Input: `Modules` (from `modules.zig`).
//! Output: `TestSteps` — the individual step references for DAG wiring.

const std = @import("std");
const Modules = @import("modules.zig").Modules;

pub const TestSteps = struct {
    unit: *std.Build.Step,
    integration: *std.Build.Step,
    opengl: *std.Build.Step,
    gpu: *std.Build.Step,
    tdd: *std.Build.Step,
};

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, m: Modules) TestSteps {
    const unit_tests = b.addTest(.{ .root_module = m.zgame });
    const unit = b.step("test", "Analyze + link the framework module");
    unit.dependOn(&b.addRunArtifact(unit_tests).step);

    const itest_mod = b.createModule(.{
        .root_source_file = b.path("tests/integration_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    itest_mod.addImport("platform", m.platform_dep.module("platform"));
    itest_mod.addImport("vulkan_stack", m.vulkan_dep.module("vulkan_stack"));
    itest_mod.linkLibrary(m.platform_dep.artifact("platform"));
    itest_mod.linkLibrary(m.vulkan_dep.artifact("vulkan_stack"));
    const itests = b.addTest(.{ .root_module = itest_mod });
    const integration = b.step("test-integration", "Cross-lib integration test (window → surface → device → present; needs a display + Vulkan)");
    integration.dependOn(&b.addRunArtifact(itests).step);

    const gltest_mod = b.createModule(.{
        .root_source_file = b.path("tests/opengl_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gltest_mod.addImport("platform", m.platform_dep.module("platform"));
    gltest_mod.addImport("surface", m.surface);
    gltest_mod.addImport("vulkan_stack", m.vulkan_dep.module("vulkan_stack"));
    gltest_mod.linkLibrary(m.platform_dep.artifact("platform"));
    gltest_mod.linkLibrary(m.vulkan_dep.artifact("vulkan_stack"));
    switch (target.result.os.tag) {
        .windows => gltest_mod.linkSystemLibrary("opengl32", .{}),
        .macos => gltest_mod.linkFramework("OpenGL", .{}),
        else => gltest_mod.linkSystemLibrary("GL", .{}),
    }
    const gltests = b.addTest(.{ .root_module = gltest_mod });
    const opengl = b.step("test-opengl", "OpenGL hand-off test (system-linked GL; needs a display + a GL driver)");
    opengl.dependOn(&b.addRunArtifact(gltests).step);

    const gputest_mod = b.createModule(.{
        .root_source_file = b.path("tests/gpu_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gputest_mod.addImport("zgame", m.zgame);
    const gputests = b.addTest(.{ .root_module = gputest_mod });
    const gpu = b.step("test-gpu", "Render-abstractions spec (Gpu + FrameRing + transitionImage; needs a display + Vulkan)");
    gpu.dependOn(&b.addRunArtifact(gputests).step);

    const tdd = b.step("test-tdd", "Run the framework's behavioral suite (integration + opengl + gpu; needs a display + Vulkan/GL)");
    tdd.dependOn(integration);
    tdd.dependOn(opengl);
    tdd.dependOn(gpu);

    return .{
        .unit = unit,
        .integration = integration,
        .opengl = opengl,
        .gpu = gpu,
        .tdd = tdd,
    };
}
