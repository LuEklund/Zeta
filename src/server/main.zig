const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const bind_address: std.Io.net.IpAddress = .{ .ip4 = .unspecified(9000) };
    const socket: std.Io.net.Socket = try bind_address.bind(io, .{ .mode = .dgram });

    var buffer: [1200]u8 = undefined;
    while (true) {
        const message = try socket.receive(io, &buffer);
        std.log.debug("{f} sent {d} bytes: {s}\n", .{ message.from, message.data.len, message.data });
    }

    defer socket.close(io);
}
