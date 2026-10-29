#version 450
// One model-view-projection matrix per draw, as a push constant (column-major mat4).
layout(push_constant) uniform PushConstants {
    mat4 model_view_projection;
} push_constants;

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 vertex_color;

layout(location = 0) out vec3 fragment_color;

void main() {
    gl_Position = push_constants.model_view_projection * vec4(vertex_position, 1.0);
    fragment_color = vertex_color;
}
