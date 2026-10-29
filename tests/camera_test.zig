//! Spec for the 3D path's camera math (`shared/camera.zig`). Pure math, no
//! display or GPU, so it runs under `zig build test`.
//!
//! Conventions under test (Vulkan): right-handed view space looking down -Z,
//! clip-space Y pointing down, depth range 0..1, column-major matrices.

const std = @import("std");
const camera = @import("camera");
const Matrix4 = camera.Matrix4;
const Vector3 = camera.Vector3;
const PerspectiveCamera = camera.PerspectiveCamera;

const tolerance = 1e-5;

fn expectHomogeneousPoint(expected: [4]f32, actual: [4]f32) !void {
    for (expected, actual) |expected_component, actual_component| {
        try std.testing.expectApproxEqAbs(expected_component, actual_component, tolerance);
    }
}

/// Clip-space point after the perspective divide.
fn divideByW(clip_point: [4]f32) [3]f32 {
    return .{ clip_point[0] / clip_point[3], clip_point[1] / clip_point[3], clip_point[2] / clip_point[3] };
}

const test_camera = PerspectiveCamera{
    .position = .{ .x = 0, .y = 0, .z = 5 },
    .target = .{ .x = 0, .y = 0, .z = 0 },
    .vertical_field_of_view_radians = std.math.pi / 2.0,
    .near_plane_distance = 1,
    .far_plane_distance = 10,
};

test "multiplying by the identity matrix leaves a matrix unchanged" {
    const translation = Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 });
    try std.testing.expectEqual(translation, Matrix4.identity.multiply(translation));
    try std.testing.expectEqual(translation, translation.multiply(Matrix4.identity));
}

test "multiplying applies the right-hand matrix first" {
    const move = Matrix4.computeTranslation(.{ .x = 5, .y = 0, .z = 0 });
    const rotate = Matrix4.computeRotationAroundYAxis(std.math.pi / 2.0);
    // Rotate (1, 0, 0) to (0, 0, -1) first, then move it 5 along X.
    try expectHomogeneousPoint(.{ 5, 0, -1, 1 }, move.multiply(rotate).transformPoint(.{ .x = 1, .y = 0, .z = 0 }));
    // The other order moves first, then rotates (6, 0, 0) to (0, 0, -6).
    try expectHomogeneousPoint(.{ 0, 0, -6, 1 }, rotate.multiply(move).transformPoint(.{ .x = 1, .y = 0, .z = 0 }));
}

test "a translation moves a point by its offset" {
    const translation = Matrix4.computeTranslation(.{ .x = 1, .y = 2, .z = 3 });
    try expectHomogeneousPoint(.{ 1, 2, 3, 1 }, translation.transformPoint(.{ .x = 0, .y = 0, .z = 0 }));
}

test "rotating 90 degrees around the Y axis turns +X into -Z" {
    const rotation = Matrix4.computeRotationAroundYAxis(std.math.pi / 2.0);
    try expectHomogeneousPoint(.{ 0, 0, -1, 1 }, rotation.transformPoint(.{ .x = 1, .y = 0, .z = 0 }));
}

test "the view matrix puts the camera at the origin and the target on the negative Z axis" {
    const view = test_camera.computeViewMatrix();
    try expectHomogeneousPoint(.{ 0, 0, 0, 1 }, view.transformPoint(test_camera.position));
    try expectHomogeneousPoint(.{ 0, 0, -5, 1 }, view.transformPoint(test_camera.target));
}

test "the projection maps the near plane to depth 0 and the far plane to depth 1" {
    const projection = test_camera.computeProjectionMatrix(1.0);
    const on_near_plane = divideByW(projection.transformPoint(.{ .x = 0, .y = 0, .z = -1 }));
    const on_far_plane = divideByW(projection.transformPoint(.{ .x = 0, .y = 0, .z = -10 }));
    try std.testing.expectApproxEqAbs(@as(f32, 0), on_near_plane[2], tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1), on_far_plane[2], tolerance);
}

test "a point above the view centre lands at negative clip-space Y (Vulkan Y points down)" {
    const projection = test_camera.computeProjectionMatrix(1.0);
    const above_centre = divideByW(projection.transformPoint(.{ .x = 0, .y = 1, .z = -2 }));
    try std.testing.expect(above_centre[1] < 0);
}

test "the aspect ratio narrows the horizontal extent of the view" {
    const square = divideByW(test_camera.computeProjectionMatrix(1.0).transformPoint(.{ .x = 1, .y = 0, .z = -2 }));
    const wide = divideByW(test_camera.computeProjectionMatrix(2.0).transformPoint(.{ .x = 1, .y = 0, .z = -2 }));
    try std.testing.expectApproxEqAbs(square[0] / 2.0, wide[0], tolerance);
}

test "the view-projection matrix is the projection times the view" {
    const expected = test_camera.computeProjectionMatrix(1.5).multiply(test_camera.computeViewMatrix());
    try std.testing.expectEqual(expected, test_camera.computeViewProjectionMatrix(1.5));
}

test "a point nearer the camera gets a smaller depth than a point farther away" {
    const view_projection = test_camera.computeViewProjectionMatrix(1.0);
    const near_point = divideByW(view_projection.transformPoint(.{ .x = 0, .y = 0, .z = 2 }));
    const far_point = divideByW(view_projection.transformPoint(.{ .x = 0, .y = 0, .z = -2 }));
    try std.testing.expect(near_point[2] < far_point[2]);
}
