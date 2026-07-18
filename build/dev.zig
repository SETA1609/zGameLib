const std = @import("std");
const Modules = @import("modules.zig").Modules;
const ExampleExes = @import("examples.zig").ExampleExes;
const TestSteps = @import("tests.zig").TestSteps;

pub fn create(b: *std.Build, m: Modules, examples: ExampleExes, tests: TestSteps) void {
    const framework_step = b.step("build-framework", "Build the zGameLib framework module");

    const pipeline_step = b.step("pipeline", "Full pipeline: adapter libs → framework");
    pipeline_step.dependOn(framework_step);
    pipeline_step.dependOn(b.getInstallStep());

    b.default_step = pipeline_step;

    const dev_step = b.step("dev", "Build framework + examples + run all tests");
    dev_step.dependOn(b.default_step);
    dev_step.dependOn(examples.examples_step);
    dev_step.dependOn(tests.integration);
    dev_step.dependOn(tests.opengl);
    dev_step.dependOn(tests.gpu);
}
