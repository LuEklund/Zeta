const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const local_address: std.Io.net.IpAddress = .{ .ip4 = .unspecified(0) };
    const socket = try local_address.bind(io, .{ .mode = .dgram });
    defer socket.close(io);
    const server_address: std.Io.net.IpAddress = .{ .ip4 = .unspecified(9000) };
    try socket.send(io, &server_address, "hello");
}
