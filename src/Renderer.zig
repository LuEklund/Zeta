const Renderer = @This();

const build_options = @import("build_options");
const builtin = @import("builtin");
const std = @import("std");
const vk = @import("vulkan");
const Window = @import("Window.zig");

const Instance = @import("Renderer/Instance.zig");

const libvulkan = switch (builtin.os.tag) {
    .windows => "vulkan-1.dll",
    .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => "libvulkan.so.1",
    .macos => "libvulkan.1.dylib",
    else => @compileError("unsupported platform"),
};

const layers: []const [*:0]const u8 = if (build_options.validation)
    &.{"VK_LAYER_KHRONOS_validation"}
else
    &.{};

const debug_extensions: []const [*:0]const u8 = if (build_options.validation)
    &.{"VK_EXT_debug_utils"}
else
    &.{};

dynlib: std.DynLib,
vkb: vk.BaseWrapper,

instance: Instance,
surface: vk.SurfaceKHR,

pub fn init(self: *Renderer, gpa: std.mem.Allocator, window: *Window) !void {
    self.dynlib = try .open(libvulkan);
    errdefer self.dynlib.close();

    const getInstanceProcAddr = self.dynlib.lookup(
        vk.PfnGetInstanceProcAddr,
        "vkGetInstanceProcAddr",
    ) orelse return error.DynLibLookup;
    self.vkb = .load(getInstanceProcAddr);

    const platform_extensions: []const [*:0]const u8 = switch (builtin.os.tag) {
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => switch (window.inner) {
            .wayland => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_wayland_surface.name },
            .x11 => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_xlib_surface.name },
        },
        .windows => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_win_32_surface.name },
        .macos => &.{ vk.extensions.khr_surface.name, vk.extensions.ext_metal_surface.name },
        else => &.{},
    };
    const extensions = try std.mem.concat(gpa, [*:0]const u8, &.{ debug_extensions, platform_extensions });
    defer gpa.free(extensions);
    try self.instance.init(
        self.vkb,
        layers,
        extensions,
        if (build_options.validation) &Instance.default_debug_info else null,
    );

    self.surface = try createSurface(&self.instance, window);
}

pub fn deinit(self: *Renderer) void {
    self.instance.dispatch.destroySurfaceKHR(self.instance.handle, self.surface, null);
    self.instance.deinit();
    self.dynlib.close();
}

fn createSurface(instance: *const Instance, window: *Window) !vk.SurfaceKHR {
    return switch (builtin.os.tag) {
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => switch (window.inner) {
            .wayland => |*w| instance.dispatch.createWaylandSurfaceKHR(instance.handle, &.{
                .display = @ptrCast(w.display),
                .surface = @ptrCast(w.surface),
            }, null),
            .x11 => |*w| instance.dispatch.createXlibSurfaceKHR(instance.handle, &.{
                .dpy = @ptrCast(w.display),
                .window = @bitCast(w.xid),
            }, null),
        },
        else => @compileError("unsupported platform"),
    };
}
