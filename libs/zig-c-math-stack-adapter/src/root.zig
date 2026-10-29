//! **math_stack**: vector and matrix math for 3D graphics, as Zig types backed by
//! cglm (C, MIT), built statically from source.
//!
//! Conventions, the same throughout:
//!   - right-handed, +Y up, a camera looks down -Z;
//!   - column vectors: `p' = M * p`, so `left.multiply(right)` applies `right` first;
//!   - column-major storage, `columns[column][row]`, 64 contiguous bytes per
//!     `Matrix4`, the layout GLSL's `mat4` expects;
//!   - Vulkan clip space for projections: depth 0..1 and y pointing down.
//!
//! Raw-first: `cglm` exposes the C declarations the wrappers use.

pub const cglm = @import("cglm.zig");

pub const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn add(left: Vector3, right: Vector3) Vector3 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    pub fn subtract(left: Vector3, right: Vector3) Vector3 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    pub fn scale(vector: Vector3, factor: f32) Vector3 {
        _ = .{ vector, factor };
        @panic("not implemented");
    }

    pub fn computeDotProduct(left: Vector3, right: Vector3) f32 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    /// Perpendicular to both, by the right-hand rule. Parallel inputs give zero.
    pub fn computeCrossProduct(left: Vector3, right: Vector3) Vector3 {
        _ = .{ left, right };
        @panic("not implemented");
    }

    pub fn computeLength(vector: Vector3) f32 {
        _ = vector;
        @panic("not implemented");
    }

    /// The same direction with length 1. The zero vector stays zero.
    pub fn normalize(vector: Vector3) Vector3 {
        _ = vector;
        @panic("not implemented");
    }
};

/// Homogeneous coordinates: `w = 1` for a point, `w = 0` for a direction.
pub const Vector4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
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

    /// `matrix * vector`, with the vector as a column.
    pub fn transformVector4(matrix: Matrix4, vector: Vector4) Vector4 {
        _ = .{ matrix, vector };
        @panic("not implemented");
    }

    /// The point as `(x, y, z, 1)`, transformed; `w` is kept for the perspective divide.
    pub fn transformPoint(matrix: Matrix4, point: Vector3) Vector4 {
        _ = .{ matrix, point };
        @panic("not implemented");
    }

    pub fn transpose(matrix: Matrix4) Matrix4 {
        _ = matrix;
        @panic("not implemented");
    }

    /// The matrix that undoes this one. A singular matrix has no inverse; the
    /// result is then not meaningful (cglm does not report it).
    pub fn computeInverse(matrix: Matrix4) Matrix4 {
        _ = matrix;
        @panic("not implemented");
    }

    pub fn computeTranslation(offset: Vector3) Matrix4 {
        _ = offset;
        @panic("not implemented");
    }

    /// Counter-clockwise around `axis` (right-hand rule) by `angle_radians`.
    /// `axis` need not be unit length.
    pub fn computeRotationAroundAxis(angle_radians: f32, axis: Vector3) Matrix4 {
        _ = .{ angle_radians, axis };
        @panic("not implemented");
    }

    /// World space to view space for a camera at `eye` looking at `target`:
    /// the camera ends at the origin looking down -Z.
    pub fn computeLookAt(eye: Vector3, target: Vector3, up_direction: Vector3) Matrix4 {
        _ = .{ eye, target, up_direction };
        @panic("not implemented");
    }

    /// View space to Vulkan clip space: depth 0 at the near plane and 1 at the
    /// far plane, y pointing down. `aspect_ratio` is width / height.
    pub fn computeVulkanPerspective(vertical_field_of_view_radians: f32, aspect_ratio: f32, near_plane_distance: f32, far_plane_distance: f32) Matrix4 {
        _ = .{ vertical_field_of_view_radians, aspect_ratio, near_plane_distance, far_plane_distance };
        @panic("not implemented");
    }
};
