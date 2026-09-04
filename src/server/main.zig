const std = @import("std");
const zeta = @import("zeta");
const Window = zeta.Window;
const HotLib = zeta.HotLib;
const System = @import("System.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const bind_address: std.Io.net.IpAddress = .{ .ip4 = .unspecified(9000) };
    const socket: std.Io.net.Socket = try bind_address.bind(io, .{ .mode = .dgram });
    defer socket.close(io);

    var window: Window = undefined;
    try window.open(arena, init.minimal, .{
        .title = "Zeta Server",
        .app_id = "zeta-server",
        .size = .{ .width = 1280, .height = 720 },
    });
    defer window.close();

    var system: System = undefined;
    var hot_lib: HotLib(System.ffi) = undefined;
    try hot_lib.init(io, "system_server");
    defer hot_lib.deinit();

    if (!hot_lib.api.systemInit(&system, &.{ .io = io })) return error.SystemInit;
    defer hot_lib.api.systemDeinit(&system);

    var buffer: [1200]u8 = undefined;
    while (!window.should_close) {
        try window.poll(.{});
        const message = try socket.receive(io, &buffer);
        std.log.debug("{f} sent {d} bytes: {s}", .{ message.from, message.data.len, message.data });
        hot_lib.update(io);
        hot_lib.api.systemUpdate(&system, &window);
    }
}
