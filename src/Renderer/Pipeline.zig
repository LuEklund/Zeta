const Pipeline = @This();

const vk = @import("vulkan");
const Device = @import("Device.zig");

const triangle_spv align(@alignOf(u32)) = @embedFile("triangle_spv").*;

pub const Config = struct {
    color_format: vk.Format,

    topology: vk.PrimitiveTopology = .triangle_list,
    polygon_mode: vk.PolygonMode = .fill,
    cull_mode: vk.CullModeFlags = .{},
    front_face: vk.FrontFace = .counter_clockwise,
    line_width: f32 = 1,
    blend_enable: bool = false,
    depth_format: vk.Format = .undefined,
    push_constant_size: u32 = 0,
};

handle: vk.Pipeline,
layout: vk.PipelineLayout,

pub fn init(self: *Pipeline, device: *const Device, config: Config) !void {
    const vkd = device.proxy;

    const module = try vkd.createShaderModule(&.{
        .code_size = triangle_spv.len,
        .p_code = @ptrCast(&triangle_spv),
    }, null);
    defer vkd.destroyShaderModule(module, null);

    const push_range: vk.PushConstantRange = .{
        .offset = 0,
        .stage_flags = .{ .vertex_bit = true },
        .size = config.push_constant_size,
    };

    self.layout = try vkd.createPipelineLayout(&.{
        .push_constant_range_count = if (config.push_constant_size > 0) 1 else 0,
        .p_push_constant_ranges = @ptrCast(&push_range),
    }, null);
    errdefer vkd.destroyPipelineLayout(self.layout, null);

    const stages: [2]vk.PipelineShaderStageCreateInfo = .{
        .{ .stage = .{ .vertex_bit = true }, .module = module, .p_name = "vertexMain" },
        .{ .stage = .{ .fragment_bit = true }, .module = module, .p_name = "fragmentMain" },
    };

    const dynamic_states: [2]vk.DynamicState = .{ .viewport, .scissor };

    const rendering: vk.PipelineRenderingCreateInfo = .{
        .view_mask = 0,
        .color_attachment_count = 1,
        .p_color_attachment_formats = @ptrCast(&config.color_format),
        .depth_attachment_format = config.depth_format,
        .stencil_attachment_format = .undefined,
    };

    const blend_attachment: vk.PipelineColorBlendAttachmentState = .{
        .blend_enable = if (config.blend_enable) .true else .false,
        .src_color_blend_factor = .src_alpha,
        .dst_color_blend_factor = .one_minus_src_alpha,
        .color_blend_op = .add,
        .src_alpha_blend_factor = .one,
        .dst_alpha_blend_factor = .zero,
        .alpha_blend_op = .add,
        .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
    };

    const depth_enable: vk.Bool32 = if (config.depth_format !=
        .undefined) .true else .false;
    const stencil_off: vk.StencilOpState = .{
        .fail_op = .keep,
        .pass_op = .keep,
        .depth_fail_op = .keep,
        .compare_op = .never,
        .compare_mask = 0,
        .write_mask = 0,
        .reference = 0,
    };

    _ = try vkd.createGraphicsPipelines(.null_handle, &.{.{
        .p_next = &rendering,
        .stage_count = stages.len,
        .p_stages = &stages,
        .p_vertex_input_state = &.{},
        .p_input_assembly_state = &.{
            .topology = config.topology,
            .primitive_restart_enable = .false,
        },
        .p_viewport_state = &.{ .viewport_count = 1, .scissor_count = 1 },
        .p_rasterization_state = &.{
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = config.polygon_mode,
            .cull_mode = config.cull_mode,
            .front_face = config.front_face,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = config.line_width,
        },
        .p_multisample_state = &.{
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = .false,
            .min_sample_shading = 0,
            .alpha_to_coverage_enable = .false,
            .alpha_to_one_enable = .false,
        },
        .p_depth_stencil_state = &.{
            .depth_test_enable = depth_enable,
            .depth_write_enable = depth_enable,
            .depth_compare_op = .less,
            .depth_bounds_test_enable = .false,
            .stencil_test_enable = .false,
            .front = stencil_off,
            .back = stencil_off,
            .min_depth_bounds = 0,
            .max_depth_bounds = 1,
        },
        .p_color_blend_state = &.{
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&blend_attachment),
            .blend_constants = .{ 0, 0, 0, 0 },
        },
        .p_dynamic_state = &.{
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        },
        .layout = self.layout,
        .render_pass = .null_handle,
        .subpass = 0,
        .base_pipeline_index = -1,
    }}, null, @ptrCast(&self.handle));
}

pub fn deinit(self: *Pipeline, device: *const Device) void {
    const vkd = device.proxy;
    vkd.destroyPipeline(self.handle, null);
    vkd.destroyPipelineLayout(self.layout, null);
}
