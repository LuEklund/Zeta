const FrameData = @This();

const vk = @import("vulkan");
const Device = @import("Device.zig");

command_buffer: vk.CommandBuffer,
image_available: vk.Semaphore,
in_flight: vk.Fence,

pub fn init(self: *FrameData, device: *const Device, pool: vk.CommandPool) !void {
    const vkd = device.proxy;

    try vkd.allocateCommandBuffers(&.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&self.command_buffer));

    self.image_available = try vkd.createSemaphore(&.{}, null);
    errdefer vkd.destroySemaphore(self.image_available, null);

    self.in_flight = try vkd.createFence(&.{ .flags = .{ .signaled_bit = true } }, null);
}

pub fn deinit(self: *FrameData, device: *const Device) void {
    const vkd = device.proxy;
    vkd.destroyFence(self.in_flight, null);
    vkd.destroySemaphore(self.image_available, null);
}
