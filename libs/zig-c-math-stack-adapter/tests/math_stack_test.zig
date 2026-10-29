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

const zero_vector = Vector3{ .x = 0, .y = 0, .z = 0 };
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
    try expectVector4(.{ .x = 0, .y = 0, .z = -1, .w = 1 }, (try Matrix4.computeRotationAroundAxis(right_angle, unit_y)).transformPoint(unit_x));
    try expectVector4(.{ .x = 0, .y = 0, .z = 1, .w = 1 }, (try Matrix4.computeRotationAroundAxis(right_angle, unit_x)).transformPoint(unit_y));
}

test "the rotation axis need not be unit length" {
    try expectMatrix4(try Matrix4.computeRotationAroundAxis(0.7, unit_y), try Matrix4.computeRotationAroundAxis(0.7, unit_y.scale(5)));
}

test "multiplying applies the right-hand matrix first" {
    const move = Matrix4.computeTranslation(.{ .x = 5, .y = 0, .z = 0 });
    const rotate = try Matrix4.computeRotationAroundAxis(right_angle, unit_y);
    try expectVector4(.{ .x = 5, .y = 0, .z = -1, .w = 1 }, move.multiply(rotate).transformPoint(unit_x));
    try expectVector4(.{ .x = 0, .y = 0, .z = -6, .w = 1 }, rotate.multiply(move).transformPoint(unit_x));
}

test "transposing swaps rows and columns, and a rotation's transpose is its inverse" {
    const matrix = Matrix4{ .columns = .{ .{ 1, 2, 3, 4 }, .{ 5, 6, 7, 8 }, .{ 9, 10, 11, 12 }, .{ 13, 14, 15, 16 } } };
    try std.testing.expectEqual([4]f32{ 1, 5, 9, 13 }, matrix.transpose().columns[0]);
    const rotation = try Matrix4.computeRotationAroundAxis(0.7, unit_y);
    try expectMatrix4(Matrix4.identity, rotation.multiply(rotation.transpose()));
}

test "a matrix times its inverse is the identity" {
    const transform = Matrix4.computeTranslation(.{ .x = 1, .y = -2, .z = 3 }).multiply(try Matrix4.computeRotationAroundAxis(0.7, .{ .x = 1, .y = 1, .z = 0 }));
    try expectMatrix4(Matrix4.identity, transform.multiply(try transform.computeInverse()));
    try expectVector4(.{ .x = 0, .y = 0, .z = 0, .w = 1 }, (try Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 }).computeInverse()).transformPoint(.{ .x = 1, .y = 2, .z = 3 }));
}

test "the look-at matrix puts the eye at the origin and the target on the negative Z axis" {
    const eye = Vector3{ .x = 3, .y = 2.5, .z = 4 };
    const target = Vector3{ .x = 0, .y = 0, .z = 0 };
    const view = try Matrix4.computeLookAt(eye, target, unit_y);
    try expectVector4(.{ .x = 0, .y = 0, .z = 0, .w = 1 }, view.transformPoint(eye));
    try expectVector4(.{ .x = 0, .y = 0, .z = -eye.computeLength(), .w = 1 }, view.transformPoint(target));
}

const near_plane_distance = 1;
const far_plane_distance = 10;
/// A function, not a constant, so the projection is computed when a test runs.
fn squareVulkanPerspective() !Matrix4 {
    return try Matrix4.computeVulkanPerspective(right_angle, 1.0, near_plane_distance, far_plane_distance);
}

test "the Vulkan perspective maps the near plane to depth 0 and the far plane to depth 1" {
    try std.testing.expectApproxEqAbs(@as(f32, 0), divideByW((try squareVulkanPerspective()).transformPoint(.{ .x = 0, .y = 0, .z = -near_plane_distance })).z, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1), divideByW((try squareVulkanPerspective()).transformPoint(.{ .x = 0, .y = 0, .z = -far_plane_distance })).z, tolerance);
}

test "the Vulkan perspective puts a point above the centre at negative y" {
    try std.testing.expect(divideByW((try squareVulkanPerspective()).transformPoint(.{ .x = 0, .y = 1, .z = -2 })).y < 0);
}

test "the Vulkan perspective puts the distance in w" {
    try std.testing.expectApproxEqAbs(@as(f32, 2), (try squareVulkanPerspective()).transformPoint(.{ .x = 0, .y = 0, .z = -2 }).w, tolerance);
}

test "the aspect ratio narrows the horizontal extent" {
    const square = divideByW((try squareVulkanPerspective()).transformPoint(.{ .x = 1, .y = 0, .z = -2 }));
    const wide = divideByW((try Matrix4.computeVulkanPerspective(right_angle, 2.0, near_plane_distance, far_plane_distance)).transformPoint(.{ .x = 1, .y = 0, .z = -2 }));
    try std.testing.expectApproxEqAbs(square.x / 2.0, wide.x, tolerance);
}

// --- Errors: inputs cglm would turn into zeros, infinities, or NaN ----------

test "inverting a singular matrix is an error, not a matrix of infinities" {
    const flatten_y = Matrix4{ .columns = .{ .{ 1, 0, 0, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 1 } } };
    try std.testing.expectError(error.SingularMatrix, flatten_y.computeInverse());
    const zero_matrix = Matrix4{ .columns = .{ .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } } };
    try std.testing.expectError(error.SingularMatrix, zero_matrix.computeInverse());
}

test "inverting a matrix with a NaN element is an error" {
    var poisoned = Matrix4.identity;
    poisoned.columns[2][1] = std.math.nan(f32);
    try std.testing.expectError(error.SingularMatrix, poisoned.computeInverse());
}

test "a small but regular scale still inverts" {
    const shrink = Matrix4{ .columns = .{ .{ 0.01, 0, 0, 0 }, .{ 0, 0.01, 0, 0 }, .{ 0, 0, 0.01, 0 }, .{ 0, 0, 0, 1 } } };
    try expectMatrix4(Matrix4.identity, shrink.multiply(try shrink.computeInverse()));
}

test "rotating around a zero-length or non-finite axis, or by a non-finite angle, is an error" {
    try std.testing.expectError(error.InvalidRotation, Matrix4.computeRotationAroundAxis(right_angle, zero_vector));
    try std.testing.expectError(error.InvalidRotation, Matrix4.computeRotationAroundAxis(right_angle, .{ .x = std.math.inf(f32), .y = 0, .z = 0 }));
    try std.testing.expectError(error.InvalidRotation, Matrix4.computeRotationAroundAxis(std.math.nan(f32), unit_y));
}

test "a look-at with the eye on the target is an error" {
    const eye = Vector3{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expectError(error.DegenerateLookAt, Matrix4.computeLookAt(eye, eye, unit_y));
}

test "a look-at straight along the up direction is an error" {
    const eye = Vector3{ .x = 0, .y = 5, .z = 0 };
    try std.testing.expectError(error.DegenerateLookAt, Matrix4.computeLookAt(eye, zero_vector, unit_y));
    try std.testing.expectError(error.DegenerateLookAt, Matrix4.computeLookAt(zero_vector, eye, unit_y));
}

test "a look-at with a zero or non-finite input is an error" {
    const eye = Vector3{ .x = 0, .y = 0, .z = 5 };
    try std.testing.expectError(error.DegenerateLookAt, Matrix4.computeLookAt(eye, zero_vector, zero_vector));
    try std.testing.expectError(error.DegenerateLookAt, Matrix4.computeLookAt(.{ .x = std.math.nan(f32), .y = 0, .z = 5 }, zero_vector, unit_y));
}

test "a look-at slightly off the up direction is still defined" {
    const eye = Vector3{ .x = 0.01, .y = 5, .z = 0 };
    const view = try Matrix4.computeLookAt(eye, zero_vector, unit_y);
    try expectVector4(.{ .x = 0, .y = 0, .z = -eye.computeLength(), .w = 1 }, view.transformPoint(zero_vector));
}

test "a perspective with the field of view outside (0, pi) is an error" {
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(0, 1.0, near_plane_distance, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(std.math.pi, 1.0, near_plane_distance, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(-right_angle, 1.0, near_plane_distance, far_plane_distance));
}

test "a perspective with a zero or negative aspect ratio is an error" {
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, 0, near_plane_distance, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, -1.0, near_plane_distance, far_plane_distance));
}

test "a perspective needs 0 < near < far" {
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, 1.0, 0, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, 1.0, -1, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, 1.0, far_plane_distance, near_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, 1.0, near_plane_distance, near_plane_distance));
}

test "a perspective with a non-finite input is an error" {
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(std.math.nan(f32), 1.0, near_plane_distance, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, std.math.inf(f32), near_plane_distance, far_plane_distance));
    try std.testing.expectError(error.InvalidPerspective, Matrix4.computeVulkanPerspective(right_angle, 1.0, near_plane_distance, std.math.inf(f32)));
}
