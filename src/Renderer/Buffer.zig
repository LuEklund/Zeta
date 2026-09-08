const Buffer = @This();

const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");

handle: vk.Buffer,
memory: vk.DeviceMemory,
mapped: [*]u8,
base: vk.DeviceAddress,
size: vk.DeviceSize,
used: vk.DeviceSize,

pub fn init(
    self: *Buffer,
    device: *const Device,
    size: vk.DeviceSize,
    usage: vk.BufferUsageFlags,
) !void {
    const vkd = device.proxy;

    self.size = size;
    self.used = 0;

    var info: vk.BufferCreateInfo = .{
        .size = size,
        .usage = usage,
        .sharing_mode = .exclusive,
    };
    self.handle = try vkd.createBuffer(&info, null);

    var allocate_flags_info: vk.MemoryAllocateFlagsInfo = .{
        .flags = .{ .device_address_bit = true },
        .device_mask = 0,
    };
    const requirements = vkd.getBufferMemoryRequirements(self.handle);
    self.memory = try vkd.allocateMemory(&.{
        .p_next = &allocate_flags_info,
        .allocation_size = requirements.size,
        .memory_type_index = Device.findMemoryTypeIndex(
            device.memory_properties,
            requirements.memory_type_bits,
            .{ .host_visible_bit = true, .host_coherent_bit = true },
        ),
    }, null);
    try vkd.bindBufferMemory(self.handle, self.memory, 0);

    self.mapped = @ptrCast(try vkd.mapMemory(self.memory, 0, size, .{}) orelse return error.MapMemory);
    self.base = vkd.getBufferDeviceAddress(&.{ .buffer = self.handle });
}

pub fn deinit(self: *Buffer, device: *const Device) void {
    const vkd = device.proxy;

    vkd.unmapMemory(self.memory);
    vkd.destroyBuffer(self.handle, null);
    vkd.freeMemory(self.memory, null);
}

pub const Allocation = struct {
    offset: vk.DeviceSize,
    address: vk.DeviceAddress,
};
pub fn alloc(self: *Buffer, comptime T: type, data: []const T, alignment: vk.DeviceSize) Allocation {
    const offset = std.mem.alignForward(vk.DeviceSize, self.used, alignment);
    const bytes = data.len * @sizeOf(T);
    std.debug.assert(offset + bytes <= self.size);

    const dst: [*]T = @ptrCast(@alignCast(self.mapped + offset));
    @memcpy(dst[0..data.len], data);

    self.used = offset + bytes;
    return .{ .offset = offset, .address = self.base + offset };
}
