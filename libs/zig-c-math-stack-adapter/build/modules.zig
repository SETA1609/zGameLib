//! Builds cglm (C, MIT) as a static library from its pinned source and wraps
//! it in the `math_stack` Zig module (`src/root.zig`).
//!
//! cglm is compiled with:
//!   - `CGLM_STATIC`: no dllimport/dllexport decoration, for a static link.
//!   - `CGLM_ALL_UNALIGNED`: `vec4`/`mat4` need only `f32` alignment, so the
//!     adapter's `extern struct` types are passed to cglm as they are.

const std = @import("std");

pub const Modules = struct {
    math_stack_module: *std.Build.Module,
    cglm_library: *std.Build.Step.Compile,
};

/// cglm's compiled sources: the "Linked" (`glmc_*`) API. `src/swift` is
/// Swift-package glue and is not built.
const cglm_source_files = [_][]const u8{
    "src/aabb2d.c",                "src/affine.c",                "src/affine2d.c",              "src/bezier.c",
    "src/box.c",                   "src/cam.c",                   "src/curve.c",                 "src/ease.c",
    "src/euler.c",                 "src/frustum.c",               "src/io.c",                    "src/ivec2.c",
    "src/ivec3.c",                 "src/ivec4.c",                 "src/mat2.c",                  "src/mat2x3.c",
    "src/mat2x4.c",                "src/mat3.c",                  "src/mat3x2.c",                "src/mat3x4.c",
    "src/mat4.c",                  "src/mat4x2.c",                "src/mat4x3.c",                "src/noise.c",
    "src/plane.c",                 "src/project.c",               "src/quat.c",                  "src/ray.c",
    "src/sphere.c",                "src/vec2.c",                  "src/vec3.c",                  "src/vec4.c",
    "src/clipspace/ortho_lh_no.c", "src/clipspace/ortho_lh_zo.c", "src/clipspace/ortho_rh_no.c", "src/clipspace/ortho_rh_zo.c",
    "src/clipspace/persp_lh_no.c", "src/clipspace/persp_lh_zo.c", "src/clipspace/persp_rh_no.c", "src/clipspace/persp_rh_zo.c",
    "src/clipspace/project_no.c",  "src/clipspace/project_zo.c",  "src/clipspace/view_lh_no.c",  "src/clipspace/view_lh_zo.c",
    "src/clipspace/view_rh_no.c",  "src/clipspace/view_rh_zo.c",
};

pub const cglm_compile_flags = [_][]const u8{ "-std=c99", "-DCGLM_STATIC", "-DCGLM_ALL_UNALIGNED" };

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Modules {
    const cglm = b.dependency("cglm", .{});

    const cglm_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    cglm_module.addIncludePath(cglm.path("include"));
    cglm_module.addCSourceFiles(.{
        .root = cglm.path("."),
        .files = &cglm_source_files,
        .flags = &cglm_compile_flags,
    });
    const cglm_library = b.addLibrary(.{
        .name = "cglm",
        .linkage = .static,
        .root_module = cglm_module,
    });
    b.installArtifact(cglm_library);

    const math_stack_module = b.addModule("math_stack", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    math_stack_module.linkLibrary(cglm_library);

    return .{ .math_stack_module = math_stack_module, .cglm_library = cglm_library };
}
