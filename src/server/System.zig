const System = @This();

const std = @import("std");
const Window = @import("zeta").Window;

fn init(self: *System, init_info: InitInfo) !void {
    _ = self;
    _ = init_info;
    std.log.debug("Server Init", .{});
}
fn update(self: *System, window: *Window) !void {
    _ = self;
    _ = window;
    std.log.debug("Server update", .{});
}
fn deinit(self: *System) !void {
    std.log.debug("Server Deinit", .{});
    _ = self;
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
