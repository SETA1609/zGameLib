//! Spec for the math_stack adapter. Known values only; no display or GPU.
//! Conventions under test: right-handed, +Y up, -Z forward, column vectors,
//! column-major storage, Vulkan clip space (depth 0..1, y down).

const std = @import("std");
const math_stack = @import("math_stack");
const Vector3 = math_stack.Vector3;
const Vector4 = math_stack.Vector4;
const Matrix4 = math_stack.Matrix4;

const tolerance = 1e-5;

fn expectVector3(expected: Vector3, actual: Vector3) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
    try std.testing.expectApproxEqAbs(expected.z, actual.z, tolerance);
}

fn expectVector4(expected: Vector4, actual: Vector4) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
    try std.testing.expectApproxEqAbs(expected.z, actual.z, tolerance);
    try std.testing.expectApproxEqAbs(expected.w, actual.w, tolerance);
}

fn expectMatrix4(expected: Matrix4, actual: Matrix4) !void {
    for (expected.columns, actual.columns) |expected_column, actual_column| {
        for (expected_column, actual_column) |expected_element, actual_element| {
            try std.testing.expectApproxEqAbs(expected_element, actual_element, tolerance);
        }
    }
}

/// After the perspective divide.
fn divideByW(clip_point: Vector4) Vector3 {
    return .{ .x = clip_point.x / clip_point.w, .y = clip_point.y / clip_point.w, .z = clip_point.z / clip_point.w };
}

const right_angle = std.math.pi / 2.0;
const unit_x = Vector3{ .x = 1, .y = 0, .z = 0 };
const unit_y = Vector3{ .x = 0, .y = 1, .z = 0 };

// --- Layout: the C boundary passes these types straight to cglm -------------

test "Vector3 is three packed floats and Matrix4 is 64 contiguous bytes" {
    try std.testing.expectEqual(12, @sizeOf(Vector3));
    try std.testing.expectEqual(16, @sizeOf(Vector4));
    try std.testing.expectEqual(64, @sizeOf(Matrix4));
    try std.testing.expectEqual(@alignOf(f32), @alignOf(Matrix4));
}

// --- Vector3 -----------------------------------------------------------------

test "adding, subtracting, and scaling work component by component" {
    const walk_east = Vector3{ .x = 3, .y = 0, .z = 0 };
    const walk_north = Vector3{ .x = 0, .y = 0, .z = -4 };
    try expectVector3(.{ .x = 3, .y = 0, .z = -4 }, walk_east.add(walk_north));
    try expectVector3(.{ .x = 3, .y = 0, .z = 4 }, walk_east.subtract(walk_north));
    try expectVector3(.{ .x = 6, .y = 0, .z = -8 }, walk_east.add(walk_north).scale(2));
}

test "the length of a 3-4 walk is 5" {
    try std.testing.expectApproxEqAbs(@as(f32, 5), (Vector3{ .x = 3, .y = 0, .z = -4 }).computeLength(), tolerance);
}

test "normalize keeps the direction and makes the length 1" {
    const direction = (Vector3{ .x = 3, .y = 0, .z = -4 }).normalize();
    try expectVector3(.{ .x = 0.6, .y = 0, .z = -0.8 }, direction);
    try std.testing.expectApproxEqAbs(@as(f32, 1), direction.computeLength(), tolerance);
}

test "normalizing the zero vector gives the zero vector" {
    try expectVector3(.{ .x = 0, .y = 0, .z = 0 }, (Vector3{ .x = 0, .y = 0, .z = 0 }).normalize());
}

test "the dot product is the sum of products and 0 for perpendicular vectors" {
    try std.testing.expectApproxEqAbs(@as(f32, 32), (Vector3{ .x = 1, .y = 2, .z = 3 }).computeDotProduct(.{ .x = 4, .y = 5, .z = 6 }), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), unit_x.computeDotProduct(unit_y), tolerance);
}

test "the cross product follows the right-hand rule: forward x up is right" {
    const forward = Vector3{ .x = 0, .y = 0, .z = -1 };
    try expectVector3(unit_x, forward.computeCrossProduct(unit_y));
    try expectVector3(.{ .x = 0, .y = 0, .z = 1 }, unit_x.computeCrossProduct(unit_y));
}

test "the cross product of parallel vectors is zero" {
    try expectVector3(.{ .x = 0, .y = 0, .z = 0 }, unit_y.computeCrossProduct(unit_y.scale(3)));
}

// --- Matrix4 -----------------------------------------------------------------

test "multiplying by the identity leaves a matrix unchanged" {
    const translation = Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 });
    try expectMatrix4(translation, Matrix4.identity.multiply(translation));
    try expectMatrix4(translation, translation.multiply(Matrix4.identity));
}

test "a translation moves a point but not a direction" {
    const translation = Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 });
    try expectVector4(.{ .x = 1, .y = 2, .z = 3, .w = 1 }, translation.transformPoint(.{ .x = 0, .y = 0, .z = 0 }));
    try expectVector4(.{ .x = 0, .y = 1, .z = 0, .w = 0 }, translation.transformVector4(.{ .x = 0, .y = 1, .z = 0, .w = 0 }));
}

test "the translation is stored in the fourth column" {
    const translation = Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 });
    try std.testing.expectEqual([4]f32{ 1, 2, 3, 1 }, translation.columns[3]);
}

test "rotating 90 degrees around Y turns +X into -Z, and around X turns +Y into +Z" {
    try expectVector4(.{ .x = 0, .y = 0, .z = -1, .w = 1 }, Matrix4.computeRotationAroundAxis(right_angle, unit_y).transformPoint(unit_x));
    try expectVector4(.{ .x = 0, .y = 0, .z = 1, .w = 1 }, Matrix4.computeRotationAroundAxis(right_angle, unit_x).transformPoint(unit_y));
}

test "the rotation axis need not be unit length" {
    try expectMatrix4(Matrix4.computeRotationAroundAxis(0.7, unit_y), Matrix4.computeRotationAroundAxis(0.7, unit_y.scale(5)));
}

test "multiplying applies the right-hand matrix first" {
    const move = Matrix4.computeTranslation(.{ .x = 5, .y = 0, .z = 0 });
    const rotate = Matrix4.computeRotationAroundAxis(right_angle, unit_y);
    try expectVector4(.{ .x = 5, .y = 0, .z = -1, .w = 1 }, move.multiply(rotate).transformPoint(unit_x));
    try expectVector4(.{ .x = 0, .y = 0, .z = -6, .w = 1 }, rotate.multiply(move).transformPoint(unit_x));
}

test "transposing swaps rows and columns, and a rotation's transpose is its inverse" {
    const matrix = Matrix4{ .columns = .{ .{ 1, 2, 3, 4 }, .{ 5, 6, 7, 8 }, .{ 9, 10, 11, 12 }, .{ 13, 14, 15, 16 } } };
    try std.testing.expectEqual([4]f32{ 1, 5, 9, 13 }, matrix.transpose().columns[0]);
    const rotation = Matrix4.computeRotationAroundAxis(0.7, unit_y);
    try expectMatrix4(Matrix4.identity, rotation.multiply(rotation.transpose()));
}

test "a matrix times its inverse is the identity" {
    const transform = Matrix4.computeTranslation(.{ .x = 1, .y = -2, .z = 3 }).multiply(Matrix4.computeRotationAroundAxis(0.7, .{ .x = 1, .y = 1, .z = 0 }));
    try expectMatrix4(Matrix4.identity, transform.multiply(transform.computeInverse()));
    try expectVector4(.{ .x = 0, .y = 0, .z = 0, .w = 1 }, Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 }).computeInverse().transformPoint(.{ .x = 1, .y = 2, .z = 3 }));
}

test "the look-at matrix puts the eye at the origin and the target on the negative Z axis" {
    const eye = Vector3{ .x = 3, .y = 2.5, .z = 4 };
    const target = Vector3{ .x = 0, .y = 0, .z = 0 };
    const view = Matrix4.computeLookAt(eye, target, unit_y);
    try expectVector4(.{ .x = 0, .y = 0, .z = 0, .w = 1 }, view.transformPoint(eye));
    try expectVector4(.{ .x = 0, .y = 0, .z = -eye.computeLength(), .w = 1 }, view.transformPoint(target));
}

const near_plane_distance = 1;
const far_plane_distance = 10;
/// A function, not a constant, so the projection is computed when a test runs.
fn squareVulkanPerspective() Matrix4 {
    return Matrix4.computeVulkanPerspective(right_angle, 1.0, near_plane_distance, far_plane_distance);
}

test "the Vulkan perspective maps the near plane to depth 0 and the far plane to depth 1" {
    try std.testing.expectApproxEqAbs(@as(f32, 0), divideByW(squareVulkanPerspective().transformPoint(.{ .x = 0, .y = 0, .z = -near_plane_distance })).z, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1), divideByW(squareVulkanPerspective().transformPoint(.{ .x = 0, .y = 0, .z = -far_plane_distance })).z, tolerance);
}

test "the Vulkan perspective puts a point above the centre at negative y" {
    try std.testing.expect(divideByW(squareVulkanPerspective().transformPoint(.{ .x = 0, .y = 1, .z = -2 })).y < 0);
}

test "the Vulkan perspective puts the distance in w" {
    try std.testing.expectApproxEqAbs(@as(f32, 2), squareVulkanPerspective().transformPoint(.{ .x = 0, .y = 0, .z = -2 }).w, tolerance);
}

test "the aspect ratio narrows the horizontal extent" {
    const square = divideByW(squareVulkanPerspective().transformPoint(.{ .x = 1, .y = 0, .z = -2 }));
    const wide = divideByW(Matrix4.computeVulkanPerspective(right_angle, 2.0, near_plane_distance, far_plane_distance).transformPoint(.{ .x = 1, .y = 0, .z = -2 }));
    try std.testing.expectApproxEqAbs(square.x / 2.0, wide.x, tolerance);
}
