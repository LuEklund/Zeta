const System = @This();

const std = @import("std");
const Window = @import("zeta").Window;

io: std.Io,
socket: std.Io.net.Socket,

fn init(self: *System, data: InitInfo) !void {
    const bind_address: std.Io.net.IpAddress = .{ .ip4 = .unspecified(9000) };
    self.socket = try bind_address.bind(data.io, .{ .mode = .dgram });
    self.io = data.io;

    std.log.debug("Server Init", .{});
}
fn update(self: *System, window: *Window) !void {
    _ = window;
    var messages: [16]std.Io.net.IncomingMessage = @splat(.init);
    var buffer: [1200]u8 = undefined;
    const maybe_err, const count = self.socket.receiveManyTimeout(
        self.io,
        &messages,
        &buffer,
        .{},
        .{ .duration = .{ .raw = .zero, .clock = .real } },
    );
    if (maybe_err) |err| if (err != error.Timeout) return err;
    for (messages[0..count]) |message| {
        std.log.debug("{f} sent {d} bytes: {s}", .{ message.from, message.data.len, message.data });
    }

    std.log.debug("Server update", .{});
}
fn deinit(self: *System) !void {
    std.log.debug("Server Deinit", .{});
    self.socket.close(self.io);
}

//Hot reload stuff
comptime {
    _ = ffi;
}

pub const InitInfo = struct {
    io: std.Io,
};

pub const ffi = struct {
    pub export fn systemInit(system: *System, init_info: *const InitInfo) callconv(.c) bool {
        system.init(init_info.*) catch |err| {
            logError("init", err, @errorReturnTrace());
            return false;
        };
        return true;
    }
    pub export fn systemUpdate(system: *System, window: *Window) callconv(.c) void {
        system.update(window) catch |err| logError("update", err, @errorReturnTrace());
    }
    pub export fn systemDeinit(system: *System) callconv(.c) void {
        system.deinit() catch |err| logError("deinit", err, @errorReturnTrace());
    }
};

fn logError(msg: []const u8, err: anyerror, trace: ?*std.builtin.StackTrace) void {
    if (trace) |t| std.debug.dumpErrorReturnTrace(t);
    std.log.err("server system {s} : {t}", .{ msg, err });
}
