//! The C boundary: hand-written declarations of the cglm "Linked" API
//! (`glmc_*`, `include/cglm/call/*.h`) functions this adapter wraps. Only these
//! cross into Zig; everything else in cglm is left out on purpose.
//!
//! cglm types as seen from Zig, with cglm built as `CGLM_ALL_UNALIGNED`:
//!   - `vec3` = `float[3]`, `vec4` = `float[4]`, `mat4` = `vec4[4]` (column-major:
//!     `mat4[column][row]`). C array parameters are pointers to their first
//!     element, so they are declared as pointers to Zig arrays here.
//!
//! Raw access: these are public, so a caller can call cglm directly with the
//! same pointers the wrappers in root.zig pass.

pub const vec3 = [3]f32;
pub const vec4 = [4]f32;
pub const mat4 = [4][4]f32;

pub extern fn glmc_vec3_add(a: *const vec3, b: *const vec3, dest: *vec3) void;
pub extern fn glmc_vec3_sub(a: *const vec3, b: *const vec3, dest: *vec3) void;
pub extern fn glmc_vec3_scale(v: *const vec3, s: f32, dest: *vec3) void;
pub extern fn glmc_vec3_dot(a: *const vec3, b: *const vec3) f32;
pub extern fn glmc_vec3_cross(a: *const vec3, b: *const vec3, dest: *vec3) void;
pub extern fn glmc_vec3_norm(v: *const vec3) f32;
pub extern fn glmc_vec3_normalize_to(v: *const vec3, dest: *vec3) void;

pub extern fn glmc_mat4_mul(m1: *const mat4, m2: *const mat4, dest: *mat4) void;
pub extern fn glmc_mat4_mulv(m: *const mat4, v: *const vec4, dest: *vec4) void;
pub extern fn glmc_mat4_transpose(m: *mat4) void;
pub extern fn glmc_mat4_det(mat: *const mat4) f32;
pub extern fn glmc_mat4_inv(mat: *const mat4, dest: *mat4) void;
pub extern fn glmc_translate_make(m: *mat4, v: *const vec3) void;
pub extern fn glmc_rotate_make(m: *mat4, angle: f32, axis: *const vec3) void;

pub extern fn glmc_lookat_rh_zo(eye: *const vec3, center: *const vec3, up: *const vec3, dest: *mat4) void;
pub extern fn glmc_perspective_rh_zo(fovy: f32, aspect: f32, near_val: f32, far_val: f32, dest: *mat4) void;
