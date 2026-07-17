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

    // Collect example executables and their compile steps.
    var example_exes: std.ArrayList(*std.Build.Step.Compile) = .empty;
    var example_steps: std.ArrayList(*std.Build.Step) = .empty;

    // Pass through to the vulkan stack: runtime GLSL→SPIR-V (shaderc), off by default.
    const enable_shaderc = b.option(bool, "shaderc", "Build the vulkan stack with runtime shaderc (GLSL→SPIR-V)") orelse false;

    const platform_dep = b.dependency("platform", .{ .target = target, .optimize = optimize });
    const vulkan_dep = b.dependency("vulkan_stack", .{ .target = target, .optimize = optimize, .shaderc = enable_shaderc });
    const zclip_dep = b.dependency("zclip", .{ .target = target, .optimize = optimize });

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

    // Animation abstraction (the unified timeline/playback API lifted over the
    // raw zclip lib). Same tier as gpu/frame — framework glue over a lib.
    const animation_mod = b.createModule(.{
        .root_source_file = b.path("shared/animation.zig"),
        .target = target,
        .optimize = optimize,
    });
    animation_mod.addImport("zclip", zclip_dep.module("zclip"));

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
    zgame_mod.addImport("zclip", zclip_dep.module("zclip"));
    zgame_mod.addImport("animation", animation_mod);
    zgame_mod.linkLibrary(platform_dep.artifact("platform"));
    zgame_mod.linkLibrary(vulkan_dep.artifact("vulkan_stack"));
    zgame_mod.linkLibrary(zclip_dep.artifact("zclip"));

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

    // --- Examples: consumers of the framework, opt-in (not built by default) ---
    // Each example is a standalone executable that imports `zgame` or
    // `zgame_platform`. They live in `examples/` which is excluded from
    // `.paths` in `build.zig.zon`.
    //
    // Examples are NEVER built or installed by the default `zig build` or
    // `zig build pipeline`. Use `zig build examples` to build all of them,
    // or `zig build <name>` for a specific one. Shader compilation via
    // `glslc` (from the Vulkan SDK) only runs when an example that needs
    // shaders is requested.

    // Rung 0: event-logger (platform-only, no vulkan)
    example_steps.append(b.allocator, addExample(b, .{
        .name = "event-logger",
        .source = "examples/event-logger/main.zig",
        .description = "Build + run the platform-only event logger (rung 0)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_platform_mod,
    }, &example_exes)) catch @panic("OOM");

    // Rung 1: clear-color (full framework)
    example_steps.append(b.allocator, addExample(b, .{
        .name = "clear-color",
        .source = "examples/clear-color/main.zig",
        .description = "Build + run the reactive clear-color example (rung 1)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes)) catch @panic("OOM");

    // Rung 1, reprise: clear-color-2 (built on zGameLib abstractions)
    example_steps.append(b.allocator, addExample(b, .{
        .name = "clear-color-2",
        .source = "examples/clear-color-2/main.zig",
        .description = "Build + run clear-color rebuilt on the zGameLib abstractions (rung 2)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes);

    // Rung 2+: hello-triangle (first pipeline + vertex buffer)
    addExample(b, .{
        .name = "hello-triangle",
        .source = "examples/hello-triangle/main.zig",
        .description = "Build + run the hello-triangle example (first pipeline + VMA buffer)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes);

    // Rung 3: animation-demo (zClip) — stub until zClip is ready
    addExample(b, .{
        .name = "animation-demo",
        .source = "examples/animation-demo/main.zig",
        .description = "Build + run the animation demo (stub until zClip is ready)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes);

    // Rung 4: audio-demo (zaudio) — stub until zaudio exists
    addExample(b, .{
        .name = "audio-demo",
        .source = "examples/audio-demo/main.zig",
        .description = "Build + run the audio demo (stub - zaudio does not exist yet)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes);

    // Rung 5: asset-demo (zassets) — stub until zassets exists
    addExample(b, .{
        .name = "asset-demo",
        .source = "examples/asset-demo/main.zig",
        .description = "Build + run the asset demo (stub - zassets does not exist yet)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes);

    // Rung 6: app-demo (zgame.App) — stub until App harness is ready
    addExample(b, .{
        .name = "app-demo",
        .source = "examples/app-demo/main.zig",
        .description = "Build + run the app harness demo (stub - App not yet implemented)",
        .target = target,
        .optimize = optimize,
        .zgame_mod = zgame_mod,
    }, &example_exes)) catch @panic("OOM");

    // color-logger (stub, full framework) — disabled until zgame.framework API lands
    // example_steps.append(b.allocator, addExample(b, .{
    //     .name = "color-logger",
    //     .source = "examples/color-logger/color-loger.zig",
    //     .description = "Build + run the color-logger example",
    //     .target = target,
    //     .optimize = optimize,
    //     .zgame_mod = zgame_mod,
    // }, &example_exes)) catch @panic("OOM");

    // --- Examples step (opt-in: not part of default pipeline) ---
    const examples_step = b.step("examples", "Build all examples (opt-in; shaders compiled via glslc from Vulkan SDK)");
    for (example_steps.items) |cs| {
        examples_step.dependOn(cs);
    }

    // --- Pipeline DAG steps for topological build orchestration ---
    const platform_step = b.step("build-platform",
        "Build zig-cpp-platform-stack-adapter (adapter lib)");
    platform_step.dependOn(&platform_dep.builder.install_tls.step);

    const vulkan_stack_step = b.step("build-vulkan_stack",
        "Build zig-cpp-vulkan-stack-adapter (adapter lib)");
    vulkan_stack_step.dependOn(&vulkan_dep.builder.install_tls.step);

    const zclip_step = b.step("build-zclip",
        "Build zClip (animation data lib)");
    zclip_step.dependOn(&zclip_dep.builder.install_tls.step);

    const framework_step = b.step("build-framework",
        "Build the zGameLib framework module");
    framework_step.dependOn(platform_step);
    framework_step.dependOn(vulkan_stack_step);
    framework_step.dependOn(zclip_step);

    const pipeline_step = b.step("pipeline",
        "Full pipeline: adapter libs → framework");
    pipeline_step.dependOn(framework_step);
    pipeline_step.dependOn(b.getInstallStep());

    b.default_step = pipeline_step;

    // --- `zig build dev`: framework + examples + tests — the full dev command ---
    const dev_step = b.step("dev", "Build framework + examples + run all tests");
    dev_step.dependOn(examples_step);
    dev_step.dependOn(itest_step);
    dev_step.dependOn(gltest_step);
    dev_step.dependOn(gputest_step);
}

/// Compile a GLSL shader to SPIR-V via `glslc` (Vulkan SDK).
/// Returns a `LazyPath` to the compiled `.spv` file.
fn addShader(b: *std.Build, name: []const u8, glsl_path: std.Build.LazyPath) std.Build.LazyPath {
    const glslc = b.addSystemCommand(&.{"glslc"});
    glslc.addArg("-o");
    const spv_path = glslc.addOutputFileArg(b.fmt("{s}.spv", .{name}));
    glslc.addFileArg(glsl_path);
    return spv_path;
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

/// Register an example executable + compile step + run step.
/// Returns the compile step so callers can attach it to aggregating steps.
fn addExample(b: *std.Build, opts: ExampleOpts, exes: *std.ArrayList(*std.Build.Step.Compile)) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = opts.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(opts.source),
            .target = opts.target,
            .optimize = opts.optimize,
        }),
    });
    exe.root_module.addImport("zgame", opts.zgame_mod);
    exes.append(b.allocator, exe) catch @panic("OOM");

    // Compile-only step (for CI / headless environments). Also installs so the
    // binary is at zig-out/bin/<name> (needed by the decoupling nm gate).
    const compile_step = b.step(opts.name, b.fmt("Compile the {s} example (no run)", .{opts.name}));
    compile_step.dependOn(&exe.step);
    compile_step.dependOn(&b.addInstallArtifact(exe, .{}).step);

    // Run step (needs a display + Vulkan/GL driver for windowed examples).
    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step(b.fmt("run-{s}", .{opts.name}), b.fmt("Build + run the {s} example", .{opts.name}))
        .dependOn(&run.step);

    return compile_step;
}
