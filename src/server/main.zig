const std = @import("std");
const zeta = @import("zeta");
const Window = zeta.Window;
const HotLib = zeta.HotLib;
const System = @import("System.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var window: Window = undefined;
    try window.open(arena, init.minimal, .{
        .title = "Zeta Server",
        .app_id = "zeta-server",
        .size = .{ .width = 1280, .height = 720 },
    });
    defer window.close();

    var hot_lib: HotLib(System.ffi) = undefined;
    try hot_lib.init(io, "system_server");
    defer hot_lib.deinit();

    var system: System = undefined;
    if (!hot_lib.api.systemInit(&system, &.{ .io = io })) return error.SystemInit;
    defer hot_lib.api.systemDeinit(&system);

    while (!window.should_close) {
        try window.poll(.{});

        hot_lib.update(io);
        hot_lib.api.systemUpdate(&system, &window);
    }
}
