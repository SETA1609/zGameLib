//! Step: example executables.
//!
//! Creates Zig executables for each example under `examples/`. Every example
//! gets a compile-only step (`zig build <name>`) and a run step
//! (`zig build run-<name>`). The framework's platform-only and full modules
//! are wired as appropriate per example.
//!
//! Input: `Modules` (from `modules.zig`).
//! Output: `ExampleExes` — compile artifact + step lists for the orchestrator.

const std = @import("std");
const Modules = @import("modules.zig").Modules;

const ExampleOpts = struct {
    name: []const u8,
    source: []const u8,
    description: []const u8,
    zgame_mod: *std.Build.Module,
};

pub const ExampleExes = struct {
    list: std.ArrayList(*std.Build.Step.Compile),
    compile_steps: std.ArrayList(*std.Build.Step),
    run_steps: std.ArrayList(*std.Build.Step),
    examples_step: *std.Build.Step,
};

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, m: Modules) ExampleExes {
    var exes: std.ArrayList(*std.Build.Step.Compile) = .empty;
    var compile_steps: std.ArrayList(*std.Build.Step) = .empty;
    var run_steps: std.ArrayList(*std.Build.Step) = .empty;

    add(b, .{
        .name = "event-logger",
        .source = "examples/event-logger/main.zig",
        .description = "Build + run the platform-only event logger (rung 0)",
        .zgame_mod = m.zgame_platform,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    add(b, .{
        .name = "clear-color",
        .source = "examples/clear-color/main.zig",
        .description = "Build + run the reactive clear-color example (rung 1)",
        .zgame_mod = m.zgame,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    add(b, .{
        .name = "clear-color-2",
        .source = "examples/clear-color-2/main.zig",
        .description = "Build + run clear-color rebuilt on the zGameLib abstractions (rung 2)",
        .zgame_mod = m.zgame,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    // hello-triangle — first pipeline + vertex buffer, with shader compilation
    {
        const exe = b.addExecutable(.{
            .name = "hello-triangle",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/hello-triangle/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("zgame", m.zgame);

        const vert_spv = addShader(b, "triangle.vert", b.path("examples/hello-triangle/shaders/triangle.vert.glsl"));
        const frag_spv = addShader(b, "triangle.frag", b.path("examples/hello-triangle/shaders/triangle.frag.glsl"));
        exe.root_module.addAnonymousImport("shaders/triangle.vert.spv", .{ .root_source_file = vert_spv });
        exe.root_module.addAnonymousImport("shaders/triangle.frag.spv", .{ .root_source_file = frag_spv });

        exes.append(b.allocator, exe) catch @panic("OOM");

        const compile_step = b.step("hello-triangle", "Build + install the hello-triangle example (first pipeline + VMA buffer)");
        compile_step.dependOn(&exe.step);
        compile_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
        compile_steps.append(b.allocator, compile_step) catch @panic("OOM");

        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        b.step("run-hello-triangle", "Build + run the hello-triangle example")
            .dependOn(&run.step);
    }

    add(b, .{
        .name = "animation-demo",
        .source = "examples/animation-demo/main.zig",
        .description = "Build + run the animation demo (stub until zClip is ready)",
        .zgame_mod = m.zgame,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    add(b, .{
        .name = "audio-demo",
        .source = "examples/audio-demo/main.zig",
        .description = "Build + run the audio demo (stub - zaudio does not exist yet)",
        .zgame_mod = m.zgame,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    add(b, .{
        .name = "asset-demo",
        .source = "examples/asset-demo/main.zig",
        .description = "Build + run the asset demo (stub - zassets does not exist yet)",
        .zgame_mod = m.zgame,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    add(b, .{
        .name = "app-demo",
        .source = "examples/app-demo/main.zig",
        .description = "Build + run the app harness demo (stub - App not yet implemented)",
        .zgame_mod = m.zgame,
    }, &exes, &compile_steps, &run_steps, target, optimize);

    const examples_step = b.step("examples", "Build all examples (opt-in; shaders compiled via glslc from Vulkan SDK)");
    for (compile_steps.items) |cs| {
        examples_step.dependOn(cs);
    }

    return .{
        .list = exes,
        .compile_steps = compile_steps,
        .run_steps = run_steps,
        .examples_step = examples_step,
    };
}

fn add(
    b: *std.Build,
    opts: ExampleOpts,
    exes: *std.ArrayList(*std.Build.Step.Compile),
    compile_steps: *std.ArrayList(*std.Build.Step),
    run_steps: *std.ArrayList(*std.Build.Step),
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const exe = b.addExecutable(.{
        .name = opts.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(opts.source),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("zgame", opts.zgame_mod);
    exes.append(b.allocator, exe) catch @panic("OOM");

    const compile_step = b.step(opts.name, b.fmt("Compile the {s} example (no run)", .{opts.name}));
    compile_step.dependOn(&exe.step);
    compile_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
    compile_steps.append(b.allocator, compile_step) catch @panic("OOM");

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step(b.fmt("run-{s}", .{opts.name}), b.fmt("Build + run the {s} example", .{opts.name}));
    run_step.dependOn(&run.step);
    run_steps.append(b.allocator, run_step) catch @panic("OOM");
}

fn addShader(b: *std.Build, name: []const u8, glsl_path: std.Build.LazyPath) std.Build.LazyPath {
    const glslc = b.addSystemCommand(&.{"glslc"});
    glslc.addArg("-o");
    const spv_path = glslc.addOutputFileArg(b.fmt("{s}.spv", .{name}));
    glslc.addFileArg(glsl_path);
    return spv_path;
}
