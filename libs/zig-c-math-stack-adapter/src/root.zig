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

/// Errors the fallible wrappers return. cglm itself never reports failure: given
/// one of these inputs it returns a matrix of zeros, infinities, or NaN, which
/// draws nothing and trips no validation layer. The wrappers check the input (and,
/// for the inverse, the result) and return one of these instead.
pub const Error = error{
    /// `computeInverse`: the determinant is zero or not finite, or the inverse
    /// overflows. A scale of zero on any axis is the common cause.
    SingularMatrix,
    /// `computeRotationAroundAxis`: the axis has zero length, or the axis or the
    /// angle is not finite.
    InvalidRotation,
    /// `computeLookAt`: `eye` equals `target`, the view direction is parallel to
    /// `up_direction` (within `parallel_sine_tolerance`), `up_direction` is zero,
    /// or an input is not finite. No camera orientation is defined.
    DegenerateLookAt,
    /// `computeVulkanPerspective`: the field of view is not inside (0, pi), the
    /// aspect ratio is not positive, the near plane is not positive, or the far
    /// plane is not beyond the near plane; or an input is not finite.
    InvalidPerspective,
};

/// `computeLookAt` treats the view direction and `up_direction` as parallel when
/// the sine of the angle between them is at most this (about 0.00006 degrees).
pub const parallel_sine_tolerance: f32 = 1e-6;

pub const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn add(left: Vector3, right: Vector3) Vector3 {
        var sum: cglm.vec3 = undefined;
        cglm.glmc_vec3_add(&left.toArray(), &right.toArray(), &sum);
        return fromArray(sum);
    }

    pub fn subtract(left: Vector3, right: Vector3) Vector3 {
        var difference: cglm.vec3 = undefined;
        cglm.glmc_vec3_sub(&left.toArray(), &right.toArray(), &difference);
        return fromArray(difference);
    }

    pub fn scale(vector: Vector3, factor: f32) Vector3 {
        var scaled: cglm.vec3 = undefined;
        cglm.glmc_vec3_scale(&vector.toArray(), factor, &scaled);
        return fromArray(scaled);
    }

    pub fn computeDotProduct(left: Vector3, right: Vector3) f32 {
        return cglm.glmc_vec3_dot(&left.toArray(), &right.toArray());
    }

    /// Perpendicular to both, by the right-hand rule. Parallel inputs give zero.
    pub fn computeCrossProduct(left: Vector3, right: Vector3) Vector3 {
        var cross_product: cglm.vec3 = undefined;
        cglm.glmc_vec3_cross(&left.toArray(), &right.toArray(), &cross_product);
        return fromArray(cross_product);
    }

    pub fn computeLength(vector: Vector3) f32 {
        return cglm.glmc_vec3_norm(&vector.toArray());
    }

    fn toArray(vector: Vector3) cglm.vec3 {
        return .{ vector.x, vector.y, vector.z };
    }

    fn fromArray(array: cglm.vec3) Vector3 {
        return .{ .x = array[0], .y = array[1], .z = array[2] };
    }

    /// The same direction with length 1. The zero vector stays zero.
    pub fn normalize(vector: Vector3) Vector3 {
        var unit_vector: cglm.vec3 = undefined;
        cglm.glmc_vec3_normalize_to(&vector.toArray(), &unit_vector);
        return fromArray(unit_vector);
    }
};

/// Homogeneous coordinates: `w = 1` for a point, `w = 0` for a direction.
pub const Vector4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    fn toArray(vector: Vector4) cglm.vec4 {
        return .{ vector.x, vector.y, vector.z, vector.w };
    }

    fn fromArray(array: cglm.vec4) Vector4 {
        return .{ .x = array[0], .y = array[1], .z = array[2], .w = array[3] };
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
        var product: Matrix4 = undefined;
        cglm.glmc_mat4_mul(&left.columns, &right.columns, &product.columns);
        return product;
    }

    /// `matrix * vector`, with the vector as a column.
    pub fn transformVector4(matrix: Matrix4, vector: Vector4) Vector4 {
        var transformed: cglm.vec4 = undefined;
        cglm.glmc_mat4_mulv(&matrix.columns, &vector.toArray(), &transformed);
        return Vector4.fromArray(transformed);
    }

    /// The point as `(x, y, z, 1)`, transformed; `w` is kept for the perspective divide.
    pub fn transformPoint(matrix: Matrix4, point: Vector3) Vector4 {
        return matrix.transformVector4(.{ .x = point.x, .y = point.y, .z = point.z, .w = 1 });
    }

    pub fn transpose(matrix: Matrix4) Matrix4 {
        var transposed = matrix;
        cglm.glmc_mat4_transpose(&transposed.columns);
        return transposed;
    }

    /// The matrix that undoes this one. A singular matrix has no inverse:
    /// `error.SingularMatrix`.
    pub fn computeInverse(matrix: Matrix4) Error!Matrix4 {
        _ = matrix;
        @panic("not implemented");
    }

    pub fn computeTranslation(offset: Vector3) Matrix4 {
        var translation: Matrix4 = undefined;
        cglm.glmc_translate_make(&translation.columns, &offset.toArray());
        return translation;
    }

    /// Counter-clockwise around `axis` (right-hand rule) by `angle_radians`.
    /// `axis` need not be unit length but must not be zero: `error.InvalidRotation`.
    pub fn computeRotationAroundAxis(angle_radians: f32, axis: Vector3) Error!Matrix4 {
        _ = .{ angle_radians, axis };
        @panic("not implemented");
    }

    /// World space to view space for a camera at `eye` looking at `target`:
    /// the camera ends at the origin looking down -Z. `error.DegenerateLookAt`
    /// when no orientation is defined (see `Error`).
    pub fn computeLookAt(eye: Vector3, target: Vector3, up_direction: Vector3) Error!Matrix4 {
        _ = .{ eye, target, up_direction };
        @panic("not implemented");
    }

    /// View space to Vulkan clip space: depth 0 at the near plane and 1 at the
    /// far plane, y pointing down. `aspect_ratio` is width / height. Needs
    /// 0 < field of view < pi, aspect ratio > 0, and 0 < near < far:
    /// `error.InvalidPerspective` otherwise.
    pub fn computeVulkanPerspective(vertical_field_of_view_radians: f32, aspect_ratio: f32, near_plane_distance: f32, far_plane_distance: f32) Error!Matrix4 {
        _ = .{ vertical_field_of_view_radians, aspect_ratio, near_plane_distance, far_plane_distance };
        @panic("not implemented");
    }
};
