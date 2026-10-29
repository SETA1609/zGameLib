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
        return .{ .x = left.x - right.x, .y = left.y - right.y, .z = left.z - right.z };
    }

    pub fn computeDotProduct(left: Vector3, right: Vector3) f32 {
        return left.x * right.x + left.y * right.y + left.z * right.z;
    }

    pub fn computeCrossProduct(left: Vector3, right: Vector3) Vector3 {
        return .{
            .x = left.y * right.z - left.z * right.y,
            .y = left.z * right.x - left.x * right.z,
            .z = left.x * right.y - left.y * right.x,
        };
    }

    /// The same direction with length 1. The zero vector stays zero.
    pub fn normalize(vector: Vector3) Vector3 {
        const length = @sqrt(vector.computeDotProduct(vector));
        if (length == 0) return vector;
        return .{ .x = vector.x / length, .y = vector.y / length, .z = vector.z / length };
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
        for (0..4) |column| {
            for (0..4) |row| {
                var sum: f32 = 0;
                for (0..4) |inner| sum += left.columns[inner][row] * right.columns[column][inner];
                product.columns[column][row] = sum;
            }
        }
        return product;
    }

    /// The point as homogeneous coordinates `(x, y, z, 1)`, transformed.
    pub fn transformPoint(matrix: Matrix4, point: Vector3) [4]f32 {
        const homogeneous_point = [4]f32{ point.x, point.y, point.z, 1 };
        var transformed_point: [4]f32 = undefined;
        for (0..4) |row| {
            var sum: f32 = 0;
            for (0..4) |column| sum += matrix.columns[column][row] * homogeneous_point[column];
            transformed_point[row] = sum;
        }
        return transformed_point;
    }

    pub fn computeTranslation(offset: Vector3) Matrix4 {
        var translation = identity;
        translation.columns[3] = .{ offset.x, offset.y, offset.z, 1 };
        return translation;
    }

    /// Counter-clockwise when looking down the Y axis from above: +X turns towards -Z.
    pub fn computeRotationAroundYAxis(angle_radians: f32) Matrix4 {
        const cosine = @cos(angle_radians);
        const sine = @sin(angle_radians);
        return .{ .columns = .{
            .{ cosine, 0, -sine, 0 },
            .{ 0, 1, 0, 0 },
            .{ sine, 0, cosine, 0 },
            .{ 0, 0, 0, 1 },
        } };
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
        const forward = camera.target.subtract(camera.position).normalize();
        const right = forward.computeCrossProduct(camera.up_direction).normalize();
        const up = right.computeCrossProduct(forward);
        return .{ .columns = .{
            .{ right.x, up.x, -forward.x, 0 },
            .{ right.y, up.y, -forward.y, 0 },
            .{ right.z, up.z, -forward.z, 0 },
            .{
                -right.computeDotProduct(camera.position),
                -up.computeDotProduct(camera.position),
                forward.computeDotProduct(camera.position),
                1,
            },
        } };
    }

    /// View space to Vulkan clip space. `aspect_ratio` is width / height.
    pub fn computeProjectionMatrix(camera: PerspectiveCamera, aspect_ratio: f32) Matrix4 {
        const focal_length = 1.0 / @tan(camera.vertical_field_of_view_radians / 2.0);
        const near = camera.near_plane_distance;
        const far = camera.far_plane_distance;
        return .{
            .columns = .{
                .{ focal_length / aspect_ratio, 0, 0, 0 },
                // Negative: Vulkan's clip-space Y points down.
                .{ 0, -focal_length, 0, 0 },
                .{ 0, 0, far / (near - far), -1 },
                .{ 0, 0, near * far / (near - far), 0 },
            },
        };
    }

    pub fn computeViewProjectionMatrix(camera: PerspectiveCamera, aspect_ratio: f32) Matrix4 {
        return camera.computeProjectionMatrix(aspect_ratio).multiply(camera.computeViewMatrix());
    }
};
