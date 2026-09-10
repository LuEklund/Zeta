const Image = @This();

const vk = @import("vulkan");
const Device = @import("Device.zig");

handle: vk.Image,
memory: vk.DeviceMemory,
view: vk.ImageView,

pub fn init(
    self: *Image,
    device: *const Device,
    format: vk.Format,
    extent: vk.Extent2D,
    usage: vk.ImageUsageFlags,
    aspect_mask: vk.ImageAspectFlags,
) !void {
    const vkd = device.proxy;

    var image_info: vk.ImageCreateInfo = .{
        .image_type = .@"2d",
        .format = format,
        .extent = .{ .height = extent.height, .width = extent.width, .depth = 1 },
        .mip_levels = 1,
        .array_layers = 1,
        .samples = .{ .@"1_bit" = true },
        .tiling = .optimal,
        .usage = usage,
        .sharing_mode = .exclusive,
        .initial_layout = .undefined,
    };
    self.handle = try vkd.createImage(&image_info, null);
    errdefer vkd.destroyImage(self.handle, null);

    const requirements = vkd.getImageMemoryRequirements(self.handle);
    var memory_info: vk.MemoryAllocateInfo = .{
        .allocation_size = requirements.size,
        .memory_type_index = Device.findMemoryTypeIndex(
            device.memory_properties,
            requirements.memory_type_bits,
            .{ .device_local_bit = true },
        ),
    };
    self.memory = try vkd.allocateMemory(&memory_info, null);
    errdefer vkd.freeMemory(self.memory, null);

    try vkd.bindImageMemory(self.handle, self.memory, 0);
    self.view = try vkd.createImageView(&.{
        .image = self.handle,
        .view_type = .@"2d",
        .format = format,
        .components = .{
            .r = .identity,
            .g = .identity,
            .b = .identity,
            .a = .identity,
        },
        .subresource_range = .{
            .aspect_mask = aspect_mask,
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
    }, null);
}

pub fn deinit(self: *Image, device: *const Device) void {
    const vkd = device.proxy;
    vkd.destroyImageView(self.view, null);
    vkd.destroyImage(self.handle, null);
    vkd.freeMemory(self.memory, null);
}
