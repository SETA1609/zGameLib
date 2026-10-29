//! The `test` step: unit tests for the `math_stack` module, linked against the
//! static cglm library. Pure math, so no display or GPU is needed.

const std = @import("std");
const Modules = @import("modules.zig").Modules;

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, m: Modules) void {
    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/math_stack_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_module.addImport("math_stack", m.math_stack_module);
    const unit_tests = b.addTest(.{ .root_module = test_module });
    const unit = b.step("test", "Run the math_stack unit tests");
    unit.dependOn(&b.addRunArtifact(unit_tests).step);
}
