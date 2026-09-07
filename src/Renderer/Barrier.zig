const Barrier = @This();

const vk = @import("vulkan");

vkd: vk.DeviceProxy,
cmd: vk.CommandBuffer,
image: vk.Image,
aspect_mask: vk.ImageAspectFlags,

layout: vk.ImageLayout = .undefined,
stage: vk.PipelineStageFlags2 = .{},
access: vk.AccessFlags2 = .{},

base_mip_level: u32 = 0,
level_count: u32 = 1,
base_array_layer: u32 = 0,
layer_count: u32 = 1,

pub fn transition(
    self: *Barrier,
    layout: vk.ImageLayout,
    stage: vk.PipelineStageFlags2,
    access: vk.AccessFlags2,
) void {
    self.vkd.cmdPipelineBarrier2(self.cmd, &.{
        .image_memory_barrier_count = 1,
        .p_image_memory_barriers = &.{.{
            .src_stage_mask = self.stage,
            .src_access_mask = self.access,
            .dst_stage_mask = stage,
            .dst_access_mask = access,
            .old_layout = self.layout,
            .new_layout = layout,
            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .image = self.image,
            .subresource_range = .{
                .aspect_mask = self.aspect_mask,
                .base_mip_level = self.base_mip_level,
                .level_count = self.level_count,
                .base_array_layer = self.base_array_layer,
                .layer_count = self.layer_count,
            },
        }},
    });

    self.layout = layout;
    self.stage = stage;
    self.access = access;
}
