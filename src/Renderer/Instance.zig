const Instance = @This();

const std = @import("std");
const vk = @import("vulkan");

pub const api_version = vk.makeApiVersion(0, 1, 3, 0);

proxy: vk.InstanceProxy,

pub fn init(
    self: *Instance,
    gpa: std.mem.Allocator,
    vkb: vk.BaseWrapper,
    layers: []const [*:0]const u8,
    extensions: []const [*:0]const u8,
) !void {
    const available_api_version: vk.Version = @bitCast(try vkb.enumerateInstanceVersion());
    if (available_api_version.major < api_version.major or available_api_version.minor < api_version.minor) {
        std.log.err("vulkan {d}.{d} required, found {d}.{d}", .{
            api_version.major, api_version.minor, available_api_version.major, available_api_version.minor,
        });
        return error.VulkanVersionTooOld;
    }

    const handle = try vkb.createInstance(&.{
        .p_application_info = &.{
            .p_engine_name = "zeta",
            .engine_version = vk.makeApiVersion(0, 1, 0, 0).toU32(),
            .application_version = vk.makeApiVersion(0, 1, 0, 0).toU32(),
            .api_version = api_version.toU32(),
        },
        .enabled_layer_count = @intCast(layers.len),
        .pp_enabled_layer_names = layers.ptr,
        .enabled_extension_count = @intCast(extensions.len),
        .pp_enabled_extension_names = extensions.ptr,
    }, null);
    const wrapper = try gpa.create(vk.InstanceWrapper);
    wrapper.* = .load(handle, vkb.dispatch.vkGetInstanceProcAddr.?);

    self.proxy = .init(handle, wrapper);
}

pub fn deinit(self: *Instance) !void {
    self.proxy.destroyInstance(null);
}
