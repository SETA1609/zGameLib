//! Root build entry point for the **math-stack adapter**.
//!
//! Delegates to `build/modules.zig` (the `math_stack` module and the static
//! cglm library) and `build/tests.zig` (the unit test step).
//!
//! ## Build steps
//!
//! | Command | Target |
//! |---------|--------|
//! | `zig build` | build the static cglm library |
//! | `zig build test` | run the unit tests (no GPU, no display) |

const std = @import("std");

const modules = @import("build/modules.zig");
const tests = @import("build/tests.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const m = modules.create(b, target, optimize);
    tests.create(b, target, optimize, m);
}
