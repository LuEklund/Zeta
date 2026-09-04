const std = @import("std");
const Window = @import("window");

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

    var buffer: [1200]u8 = undefined;
    while (!window.should_close) {
        try window.poll(.{});
        const message = try socket.receive(io, &buffer);
        std.log.debug("{f} sent {d} bytes: {s}", .{ message.from, message.data.len, message.data });
    }
}
