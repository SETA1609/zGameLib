const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;
const vk = zgame.vk;
const sc_mod = zgame.swapchain;

const max_frames = 2;

const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,
};

const vertices = [_]Vertex{
    .{ .pos = .{ 0.0, -0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
};

pub fn main() !void {
    try platform.init(.{});
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "hello-triangle", .size = .{ .w = 800, .h = 600 }, .renderer = .vulkan });
    defer win.destroy();

    var gpu = try zgame.Gpu.init(win, .{ .app_name = "hello-triangle" });
    defer gpu.deinit();

    var sc = try gpu.createSwapchain(extentOf(win));
    defer sc.deinit();

    var frames = try zgame.FrameRing(max_frames).init(gpu);
    defer frames.deinit();

    // Create a render pass for the swapchain format.
    const color_attach = vk.AttachmentDescription{
        .format = sc.format.format,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .present_src_khr,
    };
    const color_ref = vk.AttachmentReference{ .attachment = 0, .layout = .color_attachment_optimal };
    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_ref),
    };
    const render_pass = try gpu.vkd.createRenderPass(gpu.device, &.{
        .attachment_count = 1,
        .p_attachments = @ptrCast(&color_attach),
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
    defer gpu.vkd.destroyRenderPass(gpu.device, render_pass, null);

    // Framebuffers — one per swapchain image view.
    var framebuffers: [8]vk.Framebuffer = undefined;
    var fb_count: u32 = 0;
    for (sc.views[0..sc.count], 0..) |view, i| {
        framebuffers[i] = try gpu.vkd.createFramebuffer(gpu.device, &.{
            .render_pass = render_pass,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&view),
            .width = sc.extent.width,
            .height = sc.extent.height,
            .layers = 1,
        }, null);
        fb_count += 1;
    }
    defer for (framebuffers[0..fb_count]) |fb| gpu.vkd.destroyFramebuffer(gpu.device, fb, null);

    // Load embedded SPIR-V shaders.
    const vert_code = @as([]const u32, @ptrCast(@alignCast(@embedFile("shaders/triangle.vert.spv"))));
    const frag_code = @as([]const u32, @ptrCast(@alignCast(@embedFile("shaders/triangle.frag.spv"))));

    const vert_mod = try gpu.vkd.createShaderModule(gpu.device, &.{
        .code_size = vert_code.len * @sizeOf(u32),
        .p_code = vert_code.ptr,
    }, null);
    defer gpu.vkd.destroyShaderModule(gpu.device, vert_mod, null);

    const frag_mod = try gpu.vkd.createShaderModule(gpu.device, &.{
        .code_size = frag_code.len * @sizeOf(u32),
        .p_code = frag_code.ptr,
    }, null);
    defer gpu.vkd.destroyShaderModule(gpu.device, frag_mod, null);

    // Vertex buffer.
    const vb_size = @sizeOf(@TypeOf(vertices));
    const vb = try gpu.vkd.createBuffer(gpu.device, &.{
        .size = vb_size,
        .usage = .{ .vertex_buffer_bit = true },
        .sharing_mode = .exclusive,
    }, null);
    defer gpu.vkd.destroyBuffer(gpu.device, vb, null);

    const mem_req = gpu.vkd.getBufferMemoryRequirements(gpu.device, vb);
    const mem_type = try findMemoryType(gpu.vki, gpu.pdev, mem_req.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true });
    const vb_mem = try gpu.vkd.allocateMemory(gpu.device, &.{
        .allocation_size = mem_req.size,
        .memory_type_index = mem_type,
    }, null);
    defer gpu.vkd.freeMemory(gpu.device, vb_mem, null);
    try gpu.vkd.bindBufferMemory(gpu.device, vb, vb_mem, 0);

    const mapped = try gpu.vkd.mapMemory(gpu.device, vb_mem, 0, vb_size, .{});
    defer gpu.vkd.unmapMemory(gpu.device, vb_mem);
    @memcpy(@as(*[vb_size]u8, @ptrCast(mapped)), std.mem.asBytes(&vertices));

    // Vertex input state.
    const bind_desc = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .input_rate = .vertex,
    };
    const attr_desc = [_]vk.VertexInputAttributeDescription{
        .{ .location = 0, .binding = 0, .format = .r32g32_sfloat, .offset = @offsetOf(Vertex, "pos") },
        .{ .location = 1, .binding = 0, .format = .r32g32b32_sfloat, .offset = @offsetOf(Vertex, "color") },
    };

    const pipe_layout = try gpu.vkd.createPipelineLayout(gpu.device, &.{
        .set_layout_count = 0,
        .push_constant_range_count = 0,
    }, null);
    defer gpu.vkd.destroyPipelineLayout(gpu.device, pipe_layout, null);

    const pipe_ci = vk.GraphicsPipelineCreateInfo{
        .stage_count = 2,
        .p_stages = @ptrCast(&[_]vk.PipelineShaderStageCreateInfo{
            .{ .stage = .{ .vertex_bit = true }, .module = vert_mod, .p_name = "main" },
            .{ .stage = .{ .fragment_bit = true }, .module = frag_mod, .p_name = "main" },
        }),
        .p_vertex_input_state = &vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @ptrCast(&bind_desc),
            .vertex_attribute_description_count = attr_desc.len,
            .p_vertex_attribute_descriptions = @ptrCast(&attr_desc),
        },
        .p_input_assembly_state = &vk.PipelineInputAssemblyStateCreateInfo{
            .topology = .triangle_list,
            .primitive_restart_enable = .false,
        },
        .p_tessellation_state = null,
        .p_viewport_state = &vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .scissor_count = 1,
        },
        .p_rasterization_state = &vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .clockwise,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1.0,
        },
        .p_multisample_state = &vk.PipelineMultisampleStateCreateInfo{
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = .false,
            .min_sample_shading = 0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = .false,
            .alpha_to_one_enable = .false,
        },
        .p_depth_stencil_state = null,
        .p_color_blend_state = &vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&[_]vk.PipelineColorBlendAttachmentState{.{
                .blend_enable = .false,
                .src_color_blend_factor = .one,
                .dst_color_blend_factor = .zero,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .one,
                .dst_alpha_blend_factor = .zero,
                .alpha_blend_op = .add,
                .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            }}),
            .blend_constants = .{ 0, 0, 0, 0 },
        },
        .p_dynamic_state = null,
        .layout = pipe_layout,
        .render_pass = render_pass,
        .subpass = 0,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };
    var pipelines: [1]vk.Pipeline = .{undefined};
    _ = try gpu.vkd.createGraphicsPipelines(gpu.device, .null_handle, &.{pipe_ci}, null, &pipelines);
    const pipeline = pipelines[0];
    defer gpu.vkd.destroyPipeline(gpu.device, pipeline, null);

    while (!win.shouldClose()) {
        platform.pollAllEvents();
        const ev = platform.events();
        if (ev.close_requested) break;
        if (ev.resizes.len > 0) try sc.recreate(extentOf(win));

        const f = (try frames.begin(&sc, extentOf(win))) orelse continue;

        const extent = extentOf(win);
        const vp = vk.Viewport{ .x = 0, .y = 0, .width = @floatFromInt(extent.width), .height = @floatFromInt(extent.height), .min_depth = 0, .max_depth = 1 };
        const scissor = vk.Rect2D{ .offset = .{ .x = 0, .y = 0 }, .extent = extent };
        gpu.vkd.cmdSetViewport(f.cmd, 0, (&vp)[0..1]);
        gpu.vkd.cmdSetScissor(f.cmd, 0, (&scissor)[0..1]);

        const clear = vk.ClearValue{ .color = .{ .float_32 = .{ 0.1, 0.1, 0.1, 1.0 } } };
        gpu.vkd.cmdBeginRenderPass(f.cmd, &.{
            .render_pass = render_pass,
            .framebuffer = if (f.image_index < fb_count) framebuffers[f.image_index] else framebuffers[0],
            .render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = extent },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear),
        }, .@"inline");

        gpu.vkd.cmdBindPipeline(f.cmd, .graphics, pipeline);
        gpu.vkd.cmdBindVertexBuffers(f.cmd, 0, (&vb)[0..1], (&[_]vk.DeviceSize{0})[0..1]);
        gpu.vkd.cmdDraw(f.cmd, vertices.len, 1, 0, 0);

        gpu.vkd.cmdEndRenderPass(f.cmd);

        try frames.end(&sc, f, .{ .color_attachment_output_bit = true });
    }
    gpu.waitIdle();
}

fn extentOf(win: *platform.Window) vk.Extent2D {
    const s = win.size();
    return .{ .width = s.w, .height = s.h };
}

fn findMemoryType(vki: vk.InstanceWrapper, pdev: vk.PhysicalDevice, type_bits: u32, wanted: vk.MemoryPropertyFlags) !u32 {
    const mem_props = vki.getPhysicalDeviceMemoryProperties(pdev);
    var i: u32 = 0;
    while (i < mem_props.memory_type_count) : (i += 1) {
        if (type_bits & (@as(u32, 1) << @as(std.math.Log2Int(u32), @intCast(i))) != 0 and
            mem_props.memory_types[i].property_flags.contains(wanted))
        {
            return i;
        }
    }
    return error.NoSuitableMemoryType;
}
