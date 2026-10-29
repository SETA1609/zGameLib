//! depth-cube — the first rung of the 3D path: a rotating, depth-tested cube.
//!
//! Uses the 3D building blocks beside the 2D ones: `Gpu` with
//! `enable_dynamic_rendering`, a `DepthBuffer`, an `IndexedMesh`, and a
//! `PerspectiveCamera`. Draws with dynamic rendering (`cmdBeginRendering`), no
//! render pass or framebuffers. The cube turns a fixed angle per frame, so a run
//! is the same every time.
//!
//! `zig build run-depth-cube` runs until the window closes;
//! `zig build run-depth-cube -- --frames 3` exits after three presented frames
//! (used for a headless smoke run under Xvfb).

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;
const vk = zgame.vk;

const max_frames_in_flight = 2;
const rotation_per_frame_radians: f32 = 0.01;

const CubeVertex = extern struct {
    position: [3]f32,
    color: [3]f32,
};

const cube_vertices = [_]CubeVertex{
    .{ .position = .{ -1, -1, -1 }, .color = .{ 0, 0, 0 } },
    .{ .position = .{ 1, -1, -1 }, .color = .{ 1, 0, 0 } },
    .{ .position = .{ 1, 1, -1 }, .color = .{ 1, 1, 0 } },
    .{ .position = .{ -1, 1, -1 }, .color = .{ 0, 1, 0 } },
    .{ .position = .{ -1, -1, 1 }, .color = .{ 0, 0, 1 } },
    .{ .position = .{ 1, -1, 1 }, .color = .{ 1, 0, 1 } },
    .{ .position = .{ 1, 1, 1 }, .color = .{ 1, 1, 1 } },
    .{ .position = .{ -1, 1, 1 }, .color = .{ 0, 1, 1 } },
};

/// Two triangles per face, six faces.
const cube_indices = [_]u16{
    0, 1, 2, 2, 3, 0, // back (-Z)
    4, 6, 5, 6, 4, 7, // front (+Z)
    0, 3, 7, 7, 4, 0, // left (-X)
    1, 5, 6, 6, 2, 1, // right (+X)
    3, 2, 6, 6, 7, 3, // top (+Y)
    0, 4, 5, 5, 1, 0, // bottom (-Y)
};

const vertex_shader_bytes align(@alignOf(u32)) = @embedFile("shaders/cube.vert.spv").*;
const fragment_shader_bytes align(@alignOf(u32)) = @embedFile("shaders/cube.frag.spv").*;

pub fn main(init: std.process.Init) !void {
    const exit_after_frame_count = try parseExitAfterFrameCount(init);

    try platform.init(.{});
    defer platform.deinit();
    const window = try platform.Window.create(.{ .title = "depth-cube", .size = .{ .w = 800, .h = 600 }, .renderer = .vulkan });
    defer window.destroy();

    var gpu = try zgame.Gpu.init(window, .{ .app_name = "depth-cube", .enable_dynamic_rendering = true });
    defer gpu.deinit();
    var swapchain = try gpu.createSwapchain(extentOfWindow(window));
    defer swapchain.deinit();
    var frame_ring = try zgame.FrameRing(max_frames_in_flight).init(gpu);
    defer frame_ring.deinit();
    var depth_buffer = try zgame.DepthBuffer.create(&gpu, swapchain.extent);
    defer depth_buffer.destroy();
    var cube_mesh = try zgame.IndexedMesh.create(&gpu, std.mem.sliceAsBytes(&cube_vertices), &cube_indices);
    defer cube_mesh.destroy();

    const pipeline_layout = try gpu.vkd.createPipelineLayout(gpu.device, &.{
        .push_constant_range_count = 1,
        .p_push_constant_ranges = &[_]vk.PushConstantRange{.{
            .stage_flags = .{ .vertex = true },
            .offset = 0,
            .size = @sizeOf(zgame.Matrix4),
        }},
    }, null);
    defer gpu.vkd.destroyPipelineLayout(gpu.device, pipeline_layout, null);
    const pipeline = try createCubePipeline(&gpu, pipeline_layout, swapchain.format.format, depth_buffer.format);
    defer gpu.vkd.destroyPipeline(gpu.device, pipeline, null);

    const camera = zgame.PerspectiveCamera{
        .position = .{ .x = 3, .y = 2.5, .z = 4 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .vertical_field_of_view_radians = std.math.degreesToRadians(60.0),
        .near_plane_distance = 0.1,
        .far_plane_distance = 100,
    };

    var presented_frame_count: u64 = 0;
    while (!window.shouldClose()) {
        if (exit_after_frame_count) |frame_limit| if (presented_frame_count >= frame_limit) break;
        platform.pollAllEvents();
        const events = platform.events();
        if (events.close_requested) break;
        if (events.resizes.len > 0) try swapchain.recreate(extentOfWindow(window));

        const frame = (try frame_ring.begin(&swapchain, extentOfWindow(window))) orelse continue;
        if (depth_buffer.extent.width != swapchain.extent.width or depth_buffer.extent.height != swapchain.extent.height) {
            gpu.waitIdle();
            try depth_buffer.recreate(&gpu, swapchain.extent);
        }

        const rotation_angle_radians = rotation_per_frame_radians * @as(f32, @floatFromInt(presented_frame_count));
        const aspect_ratio = @as(f32, @floatFromInt(swapchain.extent.width)) / @as(f32, @floatFromInt(swapchain.extent.height));
        const model_view_projection = camera.computeViewProjectionMatrix(aspect_ratio)
            .multiply(zgame.Matrix4.computeRotationAroundYAxis(rotation_angle_radians));

        recordCubeFrame(&gpu, frame, &swapchain, &depth_buffer, &cube_mesh, pipeline, pipeline_layout, &model_view_projection);
        try frame_ring.end(&swapchain, frame, .{ .color_attachment_output = true, .early_fragment_tests = true });
        presented_frame_count += 1;
    }
    gpu.waitIdle();
}

/// `--frames N` → exit after N presented frames; no flag → run until the window closes.
fn parseExitAfterFrameCount(init: std.process.Init) !?u64 {
    var arguments = init.minimal.args.iterate();
    _ = arguments.next(); // program name
    while (arguments.next()) |argument| {
        if (std.mem.eql(u8, argument, "--frames")) {
            const frame_count_text = arguments.next() orelse return error.MissingFrameCount;
            return try std.fmt.parseInt(u64, frame_count_text, 10);
        }
    }
    return null;
}

fn recordCubeFrame(
    gpu: *zgame.Gpu,
    frame: zgame.FrameRing(max_frames_in_flight).Frame,
    swapchain: *zgame.swapchain.Swapchain,
    depth_buffer: *const zgame.DepthBuffer,
    cube_mesh: *const zgame.IndexedMesh,
    pipeline: vk.Pipeline,
    pipeline_layout: vk.PipelineLayout,
    model_view_projection: *const zgame.Matrix4,
) void {
    const vkd = gpu.vkd;
    const command_buffer = frame.cmd;
    // Source stage = the stage FrameRing.end waits on the image-acquire semaphore, so the
    // transition runs after the presentation engine is done reading the image.
    zgame.transitionImage(vkd, command_buffer, frame.image, .undefined, .color_attachment_optimal, .{}, .{ .color_attachment_write = true }, .{ .color_attachment_output = true }, .{ .color_attachment_output = true });
    depth_buffer.recordTransitionToAttachment(command_buffer);

    const color_attachment = vk.RenderingAttachmentInfo{
        .image_view = swapchain.views[frame.image_index],
        .image_layout = .color_attachment_optimal,
        .resolve_mode = .{},
        .resolve_image_layout = .undefined,
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{ .color = .{ .float_32 = .{ 0.05, 0.05, 0.08, 1.0 } } },
    };
    const depth_attachment = vk.RenderingAttachmentInfo{
        .image_view = depth_buffer.view,
        .image_layout = .depth_attachment_optimal,
        .resolve_mode = .{},
        .resolve_image_layout = .undefined,
        .load_op = .clear,
        .store_op = .dont_care,
        .clear_value = .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0 } },
    };
    const render_area = vk.Rect2D{ .offset = .{ .x = 0, .y = 0 }, .extent = swapchain.extent };
    vkd.cmdBeginRendering(command_buffer, &.{
        .render_area = render_area,
        .layer_count = 1,
        .view_mask = 0,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment),
        .p_depth_attachment = &depth_attachment,
    });
    const viewport = vk.Viewport{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(swapchain.extent.width),
        .height = @floatFromInt(swapchain.extent.height),
        .min_depth = 0,
        .max_depth = 1,
    };
    vkd.cmdSetViewport(command_buffer, 0, &.{viewport});
    vkd.cmdSetScissor(command_buffer, 0, &.{render_area});
    vkd.cmdBindPipeline(command_buffer, .graphics, pipeline);
    vkd.cmdPushConstants(command_buffer, pipeline_layout, .{ .vertex = true }, 0, @sizeOf(zgame.Matrix4), model_view_projection);
    cube_mesh.recordDraw(command_buffer);
    vkd.cmdEndRendering(command_buffer);
    zgame.transitionImage(vkd, command_buffer, frame.image, .color_attachment_optimal, .present_src_khr, .{ .color_attachment_write = true }, .{}, .{ .color_attachment_output = true }, .{ .bottom_of_pipe = true });
}

fn createCubePipeline(gpu: *zgame.Gpu, pipeline_layout: vk.PipelineLayout, color_format: vk.Format, depth_format: vk.Format) !vk.Pipeline {
    const vertex_shader_words: []const u32 = @ptrCast(&vertex_shader_bytes);
    const fragment_shader_words: []const u32 = @ptrCast(&fragment_shader_bytes);
    const vertex_shader = try gpu.vkd.createShaderModule(gpu.device, &.{ .code_size = vertex_shader_words.len * @sizeOf(u32), .p_code = vertex_shader_words.ptr }, null);
    defer gpu.vkd.destroyShaderModule(gpu.device, vertex_shader, null);
    const fragment_shader = try gpu.vkd.createShaderModule(gpu.device, &.{ .code_size = fragment_shader_words.len * @sizeOf(u32), .p_code = fragment_shader_words.ptr }, null);
    defer gpu.vkd.destroyShaderModule(gpu.device, fragment_shader, null);

    const vertex_binding = vk.VertexInputBindingDescription{ .binding = 0, .stride = @sizeOf(CubeVertex), .input_rate = .vertex };
    const vertex_attributes = [_]vk.VertexInputAttributeDescription{
        .{ .location = 0, .binding = 0, .format = .r32g32b32_sfloat, .offset = @offsetOf(CubeVertex, "position") },
        .{ .location = 1, .binding = 0, .format = .r32g32b32_sfloat, .offset = @offsetOf(CubeVertex, "color") },
    };
    const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };
    const color_attachment_formats = [_]vk.Format{color_format};
    // Dynamic rendering: the attachment formats replace a render pass.
    const rendering_create_info = vk.PipelineRenderingCreateInfo{
        .view_mask = 0,
        .color_attachment_count = color_attachment_formats.len,
        .p_color_attachment_formats = &color_attachment_formats,
        .depth_attachment_format = depth_format,
        .stencil_attachment_format = .undefined,
    };
    const pipeline_create_info = vk.GraphicsPipelineCreateInfo{
        .p_next = &rendering_create_info,
        .stage_count = 2,
        .p_stages = &[_]vk.PipelineShaderStageCreateInfo{
            .{ .stage = .{ .vertex = true }, .module = vertex_shader, .p_name = "main" },
            .{ .stage = .{ .fragment = true }, .module = fragment_shader, .p_name = "main" },
        },
        .p_vertex_input_state = &vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @ptrCast(&vertex_binding),
            .vertex_attribute_description_count = vertex_attributes.len,
            .p_vertex_attribute_descriptions = &vertex_attributes,
        },
        .p_input_assembly_state = &vk.PipelineInputAssemblyStateCreateInfo{ .topology = .triangle_list, .primitive_restart_enable = .false },
        .p_viewport_state = &vk.PipelineViewportStateCreateInfo{ .viewport_count = 1, .scissor_count = 1 },
        .p_rasterization_state = &vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = .fill,
            // No culling: the depth test alone decides which faces show.
            .cull_mode = .{},
            .front_face = .counter_clockwise,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1.0,
        },
        .p_multisample_state = &vk.PipelineMultisampleStateCreateInfo{
            .rasterization_samples = .{ .@"1" = true },
            .sample_shading_enable = .false,
            .min_sample_shading = 0,
            .alpha_to_coverage_enable = .false,
            .alpha_to_one_enable = .false,
        },
        .p_depth_stencil_state = &vk.PipelineDepthStencilStateCreateInfo{
            .depth_test_enable = .true,
            .depth_write_enable = .true,
            .depth_compare_op = .less,
            .depth_bounds_test_enable = .false,
            .stencil_test_enable = .false,
            .front = std.mem.zeroes(vk.StencilOpState),
            .back = std.mem.zeroes(vk.StencilOpState),
            .min_depth_bounds = 0,
            .max_depth_bounds = 1,
        },
        .p_color_blend_state = &vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = &[_]vk.PipelineColorBlendAttachmentState{.{
                .blend_enable = .false,
                .src_color_blend_factor = .one,
                .dst_color_blend_factor = .zero,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .one,
                .dst_alpha_blend_factor = .zero,
                .alpha_blend_op = .add,
                .color_write_mask = .{ .r = true, .g = true, .b = true, .a = true },
            }},
            .blend_constants = .{ 0, 0, 0, 0 },
        },
        .p_dynamic_state = &vk.PipelineDynamicStateCreateInfo{ .dynamic_state_count = dynamic_states.len, .p_dynamic_states = &dynamic_states },
        .layout = pipeline_layout,
        .render_pass = .null,
        .subpass = 0,
        .base_pipeline_handle = .null,
        .base_pipeline_index = -1,
    };
    var pipelines: [1]vk.Pipeline = undefined;
    _ = try gpu.vkd.createGraphicsPipelines(gpu.device, .null, &.{pipeline_create_info}, null, &pipelines);
    return pipelines[0];
}

fn extentOfWindow(window: *platform.Window) vk.Extent2D {
    const window_size = window.size();
    return .{ .width = window_size.w, .height = window_size.h };
}
