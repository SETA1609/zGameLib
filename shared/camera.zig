//! Perspective camera math for the 3D path.
//!
//! Column-major 4x4 matrices in Vulkan's conventions: right-handed view space
//! looking down -Z, clip-space Y pointing down, and a 0..1 depth range. The
//! memory layout (`columns[column][row]`) is what GLSL's `mat4` expects, so a
//! `Matrix4` can be pushed as a push constant or copied into a uniform buffer
//! as is. Pure math with no GPU or windowing imports; the 2D path never uses it.

const std = @import("std");

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn subtract(left: Vector3, right: Vector3) Vector3 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    pub fn computeDotProduct(left: Vector3, right: Vector3) f32 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    pub fn computeCrossProduct(left: Vector3, right: Vector3) Vector3 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    /// The same direction with length 1. The zero vector stays zero.
    pub fn normalize(vector: Vector3) Vector3 {
        _ = vector;
        @panic("not implemented");
    }
};

pub const Matrix4 = extern struct {
    /// Column-major: `columns[column][row]`.
    columns: [4][4]f32,

    pub const identity = Matrix4{ .columns = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    } };

    /// `left * right`: applying the result applies `right` first, then `left`.
    pub fn multiply(left: Matrix4, right: Matrix4) Matrix4 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    /// The point as homogeneous coordinates `(x, y, z, 1)`, transformed.
    pub fn transformPoint(matrix: Matrix4, point: Vector3) [4]f32 {
        _ = .{ matrix, point };
        @panic("not implemented");
    }

    pub fn computeTranslation(offset: Vector3) Matrix4 {
        _ = offset;
        @panic("not implemented");
    }

    /// Counter-clockwise when looking down the Y axis from above: +X turns towards -Z.
    pub fn computeRotationAroundYAxis(angle_radians: f32) Matrix4 {
        _ = angle_radians;
        @panic("not implemented");
    }
};

pub const PerspectiveCamera = struct {
    position: Vector3,
    target: Vector3,
    up_direction: Vector3 = .{ .x = 0, .y = 1, .z = 0 },
    vertical_field_of_view_radians: f32,
    near_plane_distance: f32,
    far_plane_distance: f32,

    /// World space to view space: the camera at the origin, looking down -Z.
    pub fn computeViewMatrix(camera: PerspectiveCamera) Matrix4 {
        _ = camera;
        @panic("not implemented");
    }

    /// View space to Vulkan clip space. `aspect_ratio` is width / height.
    pub fn computeProjectionMatrix(camera: PerspectiveCamera, aspect_ratio: f32) Matrix4 {
        _ = .{ camera, aspect_ratio };
        @panic("not implemented");
    }

    pub fn computeViewProjectionMatrix(camera: PerspectiveCamera, aspect_ratio: f32) Matrix4 {
        _ = .{ camera, aspect_ratio };
        @panic("not implemented");
    }
};
