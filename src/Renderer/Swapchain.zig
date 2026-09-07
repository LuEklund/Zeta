const Swapchain = @This();

const std = @import("std");
const vk = @import("vulkan");
const Instance = @import("Instance.zig");
const Device = @import("Device.zig");

const max_images = 4;
const max_surface_formats = 64;
const max_present_modes = 8;

handle: vk.SwapchainKHR,
format: vk.Format,
extent: vk.Extent2D,
images: [max_images]vk.Image,
views: [max_images]vk.ImageView,
render_finished: [max_images]vk.Semaphore,
image_count: u32,

pub fn init(
    self: *Swapchain,
    instance: *const Instance,
    device: *const Device,
    surface: vk.SurfaceKHR,
    wanted_extent: vk.Extent2D,
    old_handle: vk.SwapchainKHR,
) !void {
    const vki = instance.proxy;
    const vkd = device.proxy;

    const capabilities = try vki.getPhysicalDeviceSurfaceCapabilitiesKHR(device.physical, surface);
    const surface_format = try pickFormat(instance, device.physical, surface);
    const present_mode = try pickPresentMode(instance, device.physical, surface);
    const extent = pickExtent(capabilities, wanted_extent);

    var min_image_count = capabilities.min_image_count + 1;
    if (capabilities.max_image_count > 0 and min_image_count >
        capabilities.max_image_count)
    {
        min_image_count = capabilities.max_image_count;
    }

    const same_family = device.graphics_family ==
        device.present_family;
    const families: [2]u32 = .{ device.graphics_family, device.present_family };

    self.handle = try vkd.createSwapchainKHR(&.{
        .surface = surface,
        .min_image_count = min_image_count,
        .image_format = surface_format.format,
        .image_color_space = surface_format.color_space,
        .image_extent = extent,
        .image_array_layers = 1,
        .image_usage = .{ .color_attachment_bit = true },
        .image_sharing_mode = if (same_family) .exclusive else .concurrent,
        .queue_family_index_count = if (same_family) 0 else 2,
        .p_queue_family_indices = if (same_family) null else &families,
        .pre_transform = capabilities.current_transform,
        .composite_alpha = .{ .opaque_bit_khr = true },
        .present_mode = present_mode,
        .clipped = .true,
        .old_swapchain = old_handle,
    }, null);
    errdefer vkd.destroySwapchainKHR(self.handle, null);

    self.format = surface_format.format;
    self.extent = extent;

    var count: u32 = max_images;
    _ = try vkd.getSwapchainImagesKHR(self.handle, &count, &self.images);
    self.image_count = count;

    var created: u32 = 0;
    errdefer for (self.views[0..created]) |view|
        vkd.destroyImageView(view, null);
    while (created < count) : (created += 1) {
        self.render_finished[created] = try vkd.createSemaphore(&.{}, null);
        self.views[created] = try vkd.createImageView(&.{
            .image = self.images[created],
            .view_type = .@"2d",
            .format = self.format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
    }
}

pub fn deinit(self: *Swapchain, device: *const Device) void {
    const vkd = device.proxy;
    for (self.views[0..self.image_count]) |view| vkd.destroyImageView(view, null);
    for (self.render_finished[0..self.image_count]) |semaphore| vkd.destroySemaphore(semaphore, null);
    vkd.destroySwapchainKHR(self.handle, null);
}

pub fn recreate(
    self: *Swapchain,
    instance: *const Instance,
    device: *const Device,
    surface: vk.SurfaceKHR,
    wanted_extent: vk.Extent2D,
) !void {
    device.proxy.deviceWaitIdle() catch {};

    var old = self.*;
    try self.init(instance, device, surface, wanted_extent, old.handle);
    old.deinit(device);
}

fn pickExtent(caps: vk.SurfaceCapabilitiesKHR, wanted: vk.Extent2D) vk.Extent2D {
    if (caps.current_extent.width != std.math.maxInt(u32)) return caps.current_extent;
    return .{
        .width = std.math.clamp(wanted.width, caps.min_image_extent.width, caps.max_image_extent.width),
        .height = std.math.clamp(wanted.height, caps.min_image_extent.height, caps.max_image_extent.height),
    };
}

fn pickFormat(instance: *const Instance, physical: vk.PhysicalDevice, surface: vk.SurfaceKHR) !vk.SurfaceFormatKHR {
    const vki = instance.proxy;
    var formats: [max_surface_formats]vk.SurfaceFormatKHR = undefined;
    var count: u32 = formats.len;
    _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(physical, surface, &count, &formats);
    if (count == 0) return error.NoSurfaceFormats;

    for (formats[0..count]) |f| {
        if (f.format == .b8g8r8a8_srgb and f.color_space ==
            .srgb_nonlinear_khr) return f;
    }
    return formats[0];
}

fn pickPresentMode(instance: *const Instance, physical: vk.PhysicalDevice, surface: vk.SurfaceKHR) !vk.PresentModeKHR {
    const vki = instance.proxy;
    var modes: [max_present_modes]vk.PresentModeKHR = undefined;
    var count: u32 = modes.len;
    _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(physical, surface, &count, &modes);

    for (modes[0..count]) |m| if (m == .mailbox_khr) return m;
    return .fifo_khr;
}
