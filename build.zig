//! Build for zGameLib — the game framework over the two adapter libs.
//!
//! Model (same libs-first / link-the-artifact shape as the adapters): each lib
//! under libs/ builds its own static-library artifact and exposes its Zig
//! module. The `zgame` module re-exports those modules; consumers import `zgame`
//! and link its artifact.
//!
//! This file orchestrates the DAG of build steps, each defined in its own file
//! under build/:
//!   1. build/modules.zig   — dependencies + shared + framework modules
//!   2. build/tests.zig     — test targets (unit, integration, gpu)
//!   3. build/examples.zig  — example executables
//!   4. build/dev.zig       — pipeline + dev orchestration steps

const std = @import("std");

const modules = @import("build/modules.zig");
const tests = @import("build/tests.zig");
const examples = @import("build/examples.zig");
const dev = @import("build/dev.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_shaderc = b.option(bool, "shaderc", "Build the vulkan stack with runtime shaderc (GLSL→SPIR-V)") orelse false;

    const gfx_backend = b.option([]const u8, "gfx-backend", "Graphics backend: vulkan (default), metal, directx12") orelse "vulkan";

    const mods = modules.create(b, target, optimize, enable_shaderc, gfx_backend);

    const test_steps = tests.create(b, target, optimize, mods);

    const example_exes = examples.create(b, target, optimize, mods);

    dev.create(b, example_exes, test_steps);
}
