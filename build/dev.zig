//! Step: `zig build dev` orchestration.
//!
//! Composite step that depends on everything: default build, every example
//! executable (compiled + installed), and the full test suite. This is the
//! single step that proves the entire tree is green.
//!
//! Input: `ExampleExes` (from `examples.zig`), `TestSteps` (from `tests.zig`).
//! Produces no output of its own — purely a DAG root.

const std = @import("std");
const ExampleExes = @import("examples.zig").ExampleExes;
const TestSteps = @import("tests.zig").TestSteps;

pub fn create(b: *std.Build, examples: ExampleExes, tests: TestSteps) void {
    const framework_step = b.step("build-framework", "Build the zGameLib framework module");

    const pipeline_step = b.step("pipeline", "Full pipeline: adapter libs → framework");
    pipeline_step.dependOn(framework_step);
    pipeline_step.dependOn(b.getInstallStep());

    b.default_step = pipeline_step;

    const dev_step = b.step("dev", "Build framework + examples + run all tests");
    dev_step.dependOn(b.default_step);
    dev_step.dependOn(examples.examples_step);
    dev_step.dependOn(tests.integration);
    dev_step.dependOn(tests.gpu);
}
