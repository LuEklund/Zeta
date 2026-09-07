const Device = @This();

const std = @import("std");
const vk = @import("vulkan");

const Instance = @import("Instance.zig");

const max_physical_devices = 8;
const max_queue_families = 16;

physical: vk.PhysicalDevice,
dispatch: vk.DeviceWrapper,
proxy: vk.DeviceProxy,
graphics_queue: vk.Queue,
present_queue: vk.Queue,
graphics_family: u32,
present_family: u32,

pub fn init(
    self: *Device,
    instance: *const Instance,
    surface: vk.SurfaceKHR,
    device_extensions: []const [*:0]const u8,
) !void {
    const vki = instance.proxy;

    const selection = try select(instance, surface, device_extensions);
    const priorities: [1]f32 = .{1.0};
    var queue_infos: [2]vk.DeviceQueueCreateInfo = undefined;
    var queue_info_count: u32 = 1;
    queue_infos[0] = .{
        .queue_family_index = selection.graphics_family,
        .queue_count = 1,
        .p_queue_priorities = &priorities,
    };
    if (selection.present_family != selection.graphics_family) {
        queue_infos[1] = .{
            .queue_family_index = selection.present_family,
            .queue_count = 1,
            .p_queue_priorities = &priorities,
        };
        queue_info_count = 2;
    }

    var features13: vk.PhysicalDeviceVulkan13Features = .{
        .dynamic_rendering = .true,
        .synchronization_2 = .true,
    };

    const handle = try vki.createDevice(selection.physical, &.{
        .p_next = &features13,
        .queue_create_info_count = queue_info_count,
        .p_queue_create_infos = &queue_infos,
        .enabled_extension_count = @intCast(device_extensions.len),
        .pp_enabled_extension_names = device_extensions.ptr,
    }, null);

    self.dispatch = .load(handle, instance.dispatch.dispatch.vkGetDeviceProcAddr.?);
    self.proxy = .init(handle, &self.dispatch);
    const vkd = self.proxy;
    errdefer vkd.destroyDevice(null);

    self.physical = selection.physical;
    self.graphics_family = selection.graphics_family;
    self.present_family = selection.present_family;
    self.graphics_queue = vkd.getDeviceQueue(selection.graphics_family, 0);
    self.present_queue = vkd.getDeviceQueue(selection.present_family, 0);
}

pub fn deinit(self: *Device) void {
    const vkd = self.proxy;
    vkd.deviceWaitIdle() catch {};
    vkd.destroyDevice(null);
}

const Selection = struct {
    physical: vk.PhysicalDevice,
    graphics_family: u32,
    present_family: u32,
};
fn select(
    instance: *const Instance,
    surface: vk.SurfaceKHR,
    device_extensions: []const [*:0]const u8,
) !Selection {
    const vki = instance.proxy;

    var physical_devices: [max_physical_devices]vk.PhysicalDevice = undefined;
    var device_count: u32 = physical_devices.len;
    _ = try vki.enumeratePhysicalDevices(&device_count, &physical_devices);

    var best: ?Selection = null;
    var best_score: u32 = 0;

    for (physical_devices[0..device_count]) |physical| {
        if (!try supportedExtensions(instance, physical, device_extensions)) continue;
        const families = try findFamilies(instance, physical, surface) orelse continue;
        const score: u32 = switch (vki.getPhysicalDeviceProperties(physical).device_type) {
            .discrete_gpu => 3,
            .integrated_gpu => 2,
            .virtual_gpu => 1,
            else => 0,
        };
        if (best == null or score > best_score) {
            best = .{
                .physical = physical,
                .graphics_family = families.graphics,
                .present_family = families.present,
            };
            best_score = score;
        }
    }

    const selection = best orelse return error.NoSuitbaleDevice;
    const properties = vki.getPhysicalDeviceProperties(selection.physical);
    std.log.info("GPU: ({t}) {s}", .{
        properties.device_type,
        std.mem.sliceTo(&properties.device_name, 0),
    });
    return selection;
}

fn supportedExtensions(
    instance: *const Instance,
    physical: vk.PhysicalDevice,
    device_extensions: []const [*:0]const u8,
) !bool {
    const vki = instance.proxy;

    var props: [256]vk.ExtensionProperties = undefined;
    var count: u32 = props.len;
    _ = try vki.enumerateDeviceExtensionProperties(physical, null, &count, &props);

    for (device_extensions) |required| {
        const want = std.mem.span(required);
        for (props[0..count]) |prop| {
            if (std.mem.eql(u8, want, std.mem.sliceTo(&prop.extension_name, 0))) break;
        } else return false;
    }
    return true;
}

const Families = struct {
    graphics: u32,
    present: u32,
};
fn findFamilies(instance: *const Instance, physical: vk.PhysicalDevice, surface: vk.SurfaceKHR) !?Families {
    const vki = instance.proxy;

    var props: [max_queue_families]vk.QueueFamilyProperties = undefined;
    var count: u32 = props.len;
    vki.getPhysicalDeviceQueueFamilyProperties(physical, &count, &props);

    var graphics: ?u32 = null;
    var present: ?u32 = null;

    for (props[0..count], 0..) |prop, i| {
        const family: u32 = @intCast(i);
        if (graphics == null and prop.queue_flags.graphics_bit) graphics = family;
        if (present == null and (try vki.getPhysicalDeviceSurfaceSupportKHR(physical, family, surface)) == .true) present = family;
    }
    return .{
        .graphics = graphics orelse return null,
        .present = present orelse return null,
    };
}
