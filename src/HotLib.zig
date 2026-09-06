const std = @import("std");
const builtin = @import("builtin");
const DynLib = std.DynLib;

const max_libs_count = 256;
pub fn HotLib(comptime ffi: type) type {
    return struct {
        const Self = @This();
        const Api = ApiOf(ffi);

        api: Api,

        mtime: std.Io.Timestamp = .zero,
        retired: [max_libs_count]DynLib,
        retired_count: usize,

        source_path_buf: [std.fs.max_path_bytes]u8,
        source_path: []const u8,
        copy_id: usize,

        pub fn init(self: *Self, io: std.Io, comptime library_name: []const u8) !void {
            const source_name = if (builtin.os.tag == .windows) library_name ++ ".dll" else "lib" ++ library_name ++ ".so";
            const search_paths: []const []const u8 = &.{ "zig-out/bin/", "zig-out/lib/", "./" };

            for (search_paths) |path| {
                const full =
                    std.fmt.bufPrint(&self.source_path_buf, "{s}{s}", .{ path, source_name }) catch continue;
                const stat = std.Io.Dir.cwd().statFile(io, full, .{}) catch continue;
                self.source_path = full;
                self.mtime = stat.mtime;
                break;
            } else return error.NoLibraryPathFound;

            self.copy_id = @intCast(std.Io.Timestamp.zero.durationTo(.now(io, .real)).nanoseconds);
            self.retired_count = 0;
            try self.open(io);
        }

        pub fn deinit(self: *Self) void {
            for (self.retired[0..self.retired_count]) |*dynlib| dynlib.close();
        }

        pub fn update(self: *Self, io: std.Io) void {
            const stat = std.Io.Dir.cwd().statFile(io, self.source_path, .{}) catch return;
            if (stat.mtime.nanoseconds <= self.mtime.nanoseconds) return;

            self.open(io) catch |err| {
                std.log.err("{s}: reload failed: {t}", .{ self.source_path, err });
                return;
            };

            self.mtime = stat.mtime;
        }

        fn open(self: *Self, io: std.Io) !void {
            std.debug.assert(self.retired_count < max_libs_count);
            self.copy_id += 1;
            var copy_buf: [std.fs.max_path_bytes]u8 = undefined;
            const copy_path = try std.fmt.bufPrint(&copy_buf, "{s}.{d}", .{
                self.source_path,
                self.copy_id,
            });
            const cwd = std.Io.Dir.cwd();
            try cwd.copyFile(self.source_path, cwd, copy_path, io, .{});
            var dynlib = try DynLib.open(copy_path);
            errdefer dynlib.close();
            cwd.deleteFile(io, copy_path) catch {};

            var api: Api = undefined;
            inline for (std.meta.fields(Api)) |field| {
                @field(api, field.name) = dynlib.lookup(field.type, field.name) orelse return error.DynLibLookUp;
            }

            self.api = api;
            self.retired[self.retired_count] = dynlib;
            self.retired_count += 1;
        }

        fn ApiOf(comptime Ffi: type) type {
            const decls = @typeInfo(Ffi).@"struct".decls;
            var names: [decls.len][]const u8 = undefined;
            var types: [decls.len]type = undefined;

            for (decls, &names, &types) |decl, *name, *T| {
                const Fn = @TypeOf(@field(Ffi, decl.name));
                if (@typeInfo(Fn) != .@"fn") @compileError("ffi." ++ decl.name ++ " is not a function! Only function allowed in the ffi struct!");
                name.* = decl.name;
                T.* = *const Fn;
            }

            const attributes: [decls.len]std.builtin.Type.StructField.Attributes = @splat(.{});
            return @Struct(.auto, null, &names, &types, &attributes);
        }
    };
}
