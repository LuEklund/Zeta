const Renderer = @This();

const build_options = @import("build_options");
const builtin = @import("builtin");
const std = @import("std");
const vk = @import("vulkan");
const Window = @import("Window.zig");

const Instance = @import("Renderer/Instance.zig");
const Device = @import("Renderer/Device.zig");
const Swapchain = @import("Renderer/Swapchain.zig");
const FrameData = @import("Renderer/FrameData.zig");
const Barrier = @import("Renderer/Barrier.zig");

const libvulkan = switch (builtin.os.tag) {
    .windows => "vulkan-1.dll",
    .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => "libvulkan.so.1",
    .macos => "libvulkan.1.dylib",
    else => @compileError("unsupported platform"),
};

const instance_layers: []const [*:0]const u8 = if (build_options.validation)
    &.{"VK_LAYER_KHRONOS_validation"}
else
    &.{};

const instance_extensions_debug: []const [*:0]const u8 = if (build_options.validation)
    &.{vk.extensions.ext_debug_utils.name}
else
    &.{};

const device_extensions: []const [*:0]const u8 = &.{
    vk.extensions.khr_swapchain.name,
};

const frame_data_count = 2;

dynlib: std.DynLib,
vkb: vk.BaseWrapper,

instance: Instance,
device: Device,
swapchain: Swapchain,
surface: vk.SurfaceKHR,
command_pool: vk.CommandPool,
frame_data: [frame_data_count]FrameData,
frame_data_index: u32,
swapchain_dirty: bool,

pub fn init(self: *Renderer, gpa: std.mem.Allocator, window: *Window) !void {
    self.dynlib = try .open(libvulkan);
    errdefer self.dynlib.close();

    const getInstanceProcAddr = self.dynlib.lookup(
        vk.PfnGetInstanceProcAddr,
        "vkGetInstanceProcAddr",
    ) orelse return error.DynLibLookup;
    self.vkb = .load(getInstanceProcAddr);

    const instance_extensions_surface: []const [*:0]const u8 = switch (builtin.os.tag) {
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => switch (window.inner) {
            .wayland => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_wayland_surface.name },
            .x11 => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_xlib_surface.name },
        },
        .windows => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_win_32_surface.name },
        .macos => &.{ vk.extensions.khr_surface.name, vk.extensions.ext_metal_surface.name },
        else => &.{},
    };
    const instance_extensions = try std.mem.concat(gpa, [*:0]const u8, &.{
        instance_extensions_debug,
        instance_extensions_surface,
    });
    defer gpa.free(instance_extensions);
    try self.instance.init(
        self.vkb,
        instance_layers,
        instance_extensions,
        if (build_options.validation) &Instance.default_debug_info else null,
    );

    self.surface = try createSurface(&self.instance, window);
    try self.device.init(&self.instance, self.surface, device_extensions);
    try self.swapchain.init(&self.instance, &self.device, self.surface, .{
        .width = window.size.width,
        .height = window.size.height,
    }, .null_handle);
    std.debug.assert(frame_data_count <= self.swapchain.image_count);

    self.command_pool = try self.device.proxy.createCommandPool(&.{
        .flags = .{ .reset_command_buffer_bit = true },
        .queue_family_index = self.device.graphics_family,
    }, null);
    for (&self.frame_data) |*frame| try frame.init(&self.device, self.command_pool);
    self.frame_data_index = 0;
    self.swapchain_dirty = false;
}

pub fn deinit(self: *Renderer) void {
    for (&self.frame_data) |*frame| frame.deinit(&self.device);
    self.device.proxy.destroyCommandPool(self.command_pool, null);
    self.device.deinit();
    self.instance.proxy.destroySurfaceKHR(self.surface, null);
    self.instance.deinit();
    self.dynlib.close();
}

pub fn draw(self: *Renderer, window: *Window) !void {
    const vkd = self.device.proxy;

    if (self.swapchain_dirty or window.size.width != self.swapchain.extent.width or
        window.size.height != self.swapchain.extent.height)
    {
        try self.swapchain.recreate(&self.instance, &self.device, self.surface, .{
            .width = window.size.width,
            .height = window.size.height,
        });
        self.swapchain_dirty = false;
    }
    if (self.swapchain.extent.width == 0 or self.swapchain.extent.height == 0) return;

    const frame = &self.frame_data[self.frame_data_index];

    _ = try vkd.waitForFences(@ptrCast(&frame.in_flight), .true, std.math.maxInt(u64));

    const acquired = vkd.acquireNextImageKHR(
        self.swapchain.handle,
        std.math.maxInt(u64),
        frame.image_available,
        .null_handle,
    ) catch |err| switch (err) {
        error.OutOfDateKHR => {
            self.swapchain_dirty = true;
            return;
        },
        else => return err,
    };
    if (acquired.result == .suboptimal_khr) self.swapchain_dirty = true;
    const image_index = acquired.image_index;

    try vkd.resetFences(@ptrCast(&frame.in_flight));
    try vkd.resetCommandBuffer(frame.command_buffer, .{});

    try self.record(frame.command_buffer, image_index);

    const wait_stage: [1]vk.PipelineStageFlags = .{.{ .color_attachment_output_bit = true }};
    try vkd.queueSubmit(self.device.graphics_queue, &.{.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast(&frame.image_available),
        .p_wait_dst_stage_mask = &wait_stage,
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&frame.command_buffer),
        .signal_semaphore_count = 1,
        .p_signal_semaphores = @ptrCast(&self.swapchain.render_finished[image_index]),
    }}, frame.in_flight);
    if (vkd.queuePresentKHR(self.device.present_queue, &.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast(&self.swapchain.render_finished[image_index]),
        .swapchain_count = 1,
        .p_swapchains = @ptrCast(&self.swapchain.handle),
        .p_image_indices = @ptrCast(&image_index),
    })) |result| {
        if (result == .suboptimal_khr) self.swapchain_dirty = true;
    } else |err| switch (err) {
        error.OutOfDateKHR => self.swapchain_dirty = true,
        else => return err,
    }

    self.frame_data_index = (self.frame_data_index + 1) % frame_data_count;
}

fn record(self: *Renderer, cmd: vk.CommandBuffer, image_index: u32) !void {
    const vkd = self.device.proxy;

    try vkd.beginCommandBuffer(cmd, &.{ .flags = .{ .one_time_submit_bit = true } });

    var barrier: Barrier = .{
        .vkd = vkd,
        .cmd = cmd,
        .image = self.swapchain.images[image_index],
        .aspect_mask = .{ .color_bit = true },
    };

    barrier.transition(
        .color_attachment_optimal,
        .{ .color_attachment_output_bit = true },
        .{ .color_attachment_write_bit = true },
    );

    const color: vk.RenderingAttachmentInfo = .{
        .image_view = self.swapchain.views[image_index],
        .image_layout = .color_attachment_optimal,
        .resolve_mode = .{},
        .resolve_image_layout = .undefined,
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{ .color = .{ .float_32 = .{ 0.05, 0.05, 0.08, 1.0 } } },
    };
    vkd.cmdBeginRendering(cmd, &.{
        .render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = self.swapchain.extent },
        .layer_count = 1,
        .view_mask = 0,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color),
    });

    // we do the draw here

    vkd.cmdEndRendering(cmd);

    barrier.transition(.present_src_khr, .{}, .{});

    try vkd.endCommandBuffer(cmd);
}

fn createSurface(instance: *const Instance, window: *Window) !vk.SurfaceKHR {
    return switch (builtin.os.tag) {
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => switch (window.inner) {
            .wayland => |*w| instance.proxy.createWaylandSurfaceKHR(&.{
                .display = @ptrCast(w.display),
                .surface = @ptrCast(w.surface),
            }, null),
            .x11 => |*w| instance.proxy.createXlibSurfaceKHR(&.{
                .dpy = @ptrCast(w.display),
                .window = @bitCast(w.xid),
            }, null),
        },
        else => @compileError("unsupported platform"),
    };
}
