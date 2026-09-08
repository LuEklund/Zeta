const FrameData = @This();

const vk = @import("vulkan");
const Device = @import("Device.zig");
const Buffer = @import("Buffer.zig");

const buffer_size = 1 * 1024 * 1024;

command_buffer: vk.CommandBuffer,
image_available: vk.Semaphore,
in_flight: vk.Fence,
buffer: Buffer,

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

    try self.buffer.init(device, buffer_size, .{
        .vertex_buffer_bit = true,
        .index_buffer_bit = true,
        .shader_device_address_bit = true,
    });
}

pub fn deinit(self: *FrameData, device: *const Device) void {
    const vkd = device.proxy;
    vkd.destroyFence(self.in_flight, null);
    vkd.destroySemaphore(self.image_available, null);
    self.buffer.deinit(device);
}
