//! Step: module creation.
//!
//! Creates and wires all Zig modules used by the framework and its consumers:
//! dependency resolution (platform, vulkan_stack), shared middleware modules
//! (surface, swapchain, gpu, frame, and the 3D path's camera, depth, mesh), and the top-level framework modules
//! (zgame, zgame_platform).
//!
//! Output: `Modules` — a struct holding every module + dependency reference.
//! Consumed by `tests.zig` and `examples.zig`.

const std = @import("std");

pub const Modules = struct {
    surface: *std.Build.Module,
    swapchain: *std.Build.Module,
    gpu: *std.Build.Module,
    frame: *std.Build.Module,
    camera: *std.Build.Module,
    depth: *std.Build.Module,
    mesh: *std.Build.Module,
    animation: *std.Build.Module,
    zgame: *std.Build.Module,
    zgame_platform: *std.Build.Module,
    platform_dep: *std.Build.Dependency,
    vulkan_dep: *std.Build.Dependency,
    zclip_dep: *std.Build.Dependency,
    math_stack_dep: *std.Build.Dependency,
};

pub fn create(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    enable_shaderc: bool,
    gfx_backend: []const u8,
) Modules {
    const platform_dep = b.dependency("platform", .{ .target = target, .optimize = optimize });
    const vulkan_dep = b.dependency("vulkan_stack", .{ .target = target, .optimize = optimize, .shaderc = enable_shaderc });
    const zclip_dep = b.dependency("zclip", .{ .target = target, .optimize = optimize });
    const math_stack_dep = b.dependency("math_stack", .{ .target = target, .optimize = optimize });

    const zgame_opts = b.addOptions();
    zgame_opts.addOption([]const u8, "gfx_backend", gfx_backend);

    const backend_mod = b.createModule(.{
        .root_source_file = b.path("shared/backend.zig"),
        .target = target,
        .optimize = optimize,
    });

    const surface = b.createModule(.{
        .root_source_file = b.path("shared/surface.zig"),
        .target = target,
        .optimize = optimize,
    });
    surface.addImport("platform", platform_dep.module("platform"));
    surface.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    surface.addImport("backend", backend_mod);
    surface.addOptions("zgame_options", zgame_opts);

    const swapchain = b.createModule(.{
        .root_source_file = b.path("shared/swapchain.zig"),
        .target = target,
        .optimize = optimize,
    });
    swapchain.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));

    const gpu = b.createModule(.{
        .root_source_file = b.path("shared/gpu.zig"),
        .target = target,
        .optimize = optimize,
    });
    gpu.addImport("platform", platform_dep.module("platform"));
    gpu.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    gpu.addImport("surface", surface);
    gpu.addImport("swapchain", swapchain);

    const frame = b.createModule(.{
        .root_source_file = b.path("shared/frame.zig"),
        .target = target,
        .optimize = optimize,
    });
    frame.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    frame.addImport("swapchain", swapchain);

    // The 3D path, beside the 2D one: pure camera math, a depth buffer, an indexed mesh.
    const camera = b.createModule(.{
        .root_source_file = b.path("shared/camera.zig"),
        .target = target,
        .optimize = optimize,
    });

    const depth = b.createModule(.{
        .root_source_file = b.path("shared/depth.zig"),
        .target = target,
        .optimize = optimize,
    });
    depth.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));

    const mesh = b.createModule(.{
        .root_source_file = b.path("shared/mesh.zig"),
        .target = target,
        .optimize = optimize,
    });
    mesh.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));

    const animation = b.createModule(.{
        .root_source_file = b.path("shared/animation.zig"),
        .target = target,
        .optimize = optimize,
    });
    animation.addImport("zclip", zclip_dep.module("zclip"));

    const zgame = b.addModule("zgame", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgame.addImport("platform", platform_dep.module("platform"));
    zgame.addImport("vulkan_stack", vulkan_dep.module("vulkan_stack"));
    zgame.addImport("surface", surface);
    zgame.addImport("swapchain", swapchain);
    zgame.addImport("gpu", gpu);
    zgame.addImport("frame", frame);
    zgame.addImport("camera", camera);
    zgame.addImport("depth", depth);
    zgame.addImport("mesh", mesh);
    zgame.addImport("zclip", zclip_dep.module("zclip"));
    // The math_stack module links its own static cglm library.
    zgame.addImport("math_stack", math_stack_dep.module("math_stack"));
    zgame.addImport("animation", animation);
    zgame.addImport("backend", backend_mod);
    zgame.linkLibrary(platform_dep.artifact("platform"));
    zgame.linkLibrary(vulkan_dep.artifact("vulkan_stack"));
    zgame.linkLibrary(zclip_dep.artifact("zclip"));

    const zgame_platform = b.addModule("zgame_platform", .{
        .root_source_file = b.path("src/root_platform.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgame_platform.addImport("platform", platform_dep.module("platform"));
    zgame_platform.linkLibrary(platform_dep.artifact("platform"));

    return .{
        .surface = surface,
        .swapchain = swapchain,
        .gpu = gpu,
        .frame = frame,
        .camera = camera,
        .depth = depth,
        .mesh = mesh,
        .animation = animation,
        .zgame = zgame,
        .zgame_platform = zgame_platform,
        .platform_dep = platform_dep,
        .vulkan_dep = vulkan_dep,
        .zclip_dep = zclip_dep,
        .math_stack_dep = math_stack_dep,
    };
}
