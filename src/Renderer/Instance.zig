const Instance = @This();

const std = @import("std");
const vk = @import("vulkan");

pub const default_debug_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
    .message_severity = .{ .warning_bit_ext = true, .error_bit_ext = true },
    .message_type = .{ .general_bit_ext = true, .validation_bit_ext = true, .performance_bit_ext = true },
    .pfn_user_callback = debugCallback,
};

pub const api_version = vk.makeApiVersion(0, 1, 3, 0);

handle: vk.Instance,
dispatch: vk.InstanceWrapper,
debug_messenger: vk.DebugUtilsMessengerEXT,

pub fn init(
    self: *Instance,
    vkb: vk.BaseWrapper,
    layers: []const [*:0]const u8,
    extensions: []const [*:0]const u8,
    debug: ?*const vk.DebugUtilsMessengerCreateInfoEXT,
) !void {
    const available_api_version: vk.Version = @bitCast(try vkb.enumerateInstanceVersion());
    if (available_api_version.major < api_version.major or available_api_version.minor < api_version.minor) {
        std.log.err("vulkan {d}.{d} required, found {d}.{d}", .{
            api_version.major, api_version.minor, available_api_version.major, available_api_version.minor,
        });
        return error.VulkanVersionTooOld;
    }

    self.handle = try vkb.createInstance(&.{
        .p_next = debug,
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
    self.dispatch = .load(self.handle, vkb.dispatch.vkGetInstanceProcAddr.?);

    self.debug_messenger = if (debug) |info| try self.dispatch.createDebugUtilsMessengerEXT(
        self.handle,
        info,
        null,
    ) else .null_handle;
}

pub fn deinit(self: *Instance) void {
    if (self.debug_messenger != .null_handle) self.dispatch.destroyDebugUtilsMessengerEXT(self.handle, self.debug_messenger, null);
    self.dispatch.destroyInstance(self.handle, null);
}

fn debugCallback(
    severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    types: vk.DebugUtilsMessageTypeFlagsEXT,
    p_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    _ = types;
    _ = p_user_data;
    const data = p_data orelse return .false;
    const msg = std.mem.span(data.p_message orelse return .false);

    if (severity.error_bit_ext) {
        std.log.err("{s}", .{msg});
    } else if (severity.warning_bit_ext) {
        std.log.warn("{s}", .{msg});
    } else {
        std.log.info("{s}", .{msg});
    }
    return .false;
}
