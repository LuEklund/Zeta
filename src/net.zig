const std = @import("std");
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const Keys = @import("Input.zig").Keys;

pub const endian: std.builtin.Endian = .little;
pub const max_packet_len = 1200;

pub const ClientPacket = union(enum) {
    hello: void,
    input: Command,
};

pub const ServerPacket = union(enum) {
    welcome: void,
    state: State,
};

pub const Command = struct {
    keys: Keys,
    yaw: f32,
    pitch: f32,
};

pub const State = struct {
    position: @Vector(3, f32),
    rotation: @Vector(4, f32),
    velocity: @Vector(3, f32),
};

pub const protocol_version: u32 = version: {
    @setEvalBranchQuota(100_000);
    break :version std.hash.Fnv1a_32.hash(description(ClientPacket) ++
        description(ServerPacket));
};

pub fn encode(packet: anytype, buffer: *[max_packet_len]u8) []u8 {
    var writer: std.Io.Writer = .fixed(buffer);
    writer.writeInt(u32, protocol_version, endian);
    marshal(packet, &writer) catch unreachable;
    return writer.buffered();
}

pub fn decode(comptime Packet: type, bytes: []const u8) !Packet {
    var reader: Reader = .fixed(bytes);
    if (try reader.takeInt(u32, endian) != protocol_version) return error.ProtocolVersionMismatch;
    return unmarshal(Packet, &reader);
}

pub fn marshal(value: anytype, writer: *Writer) Writer.Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .void => {},
        .bool => try writer.writeInt(u8, @intFromBool(value), endian),
        .int => try writer.writeInt(T, value, endian),
        .float => |float| try writer.writeInt(@Int(.unsigned, float.bits), @bitCast(value), endian),
        .@"enum" => |e| try writer.writeInt(e.tag_type, @intFromEnum(value), endian),
        .array => for (value) |element| try marshal(element, writer),
        .@"struct" => |s| switch (s.layout) {
            .auto, .@"extern" => inline for (s.fields) |field| try marshal(@field(value, field.name), writer),
            .@"packed" => try writer.writeStruct(value, endian),
        },
        .@"union" => switch (value) {
            inline else => |payload, tag| {
                try writer.writeInt(u8, @intFromEnum(tag), endian);
                try marshal(payload, writer);
            },
        },
        else => @compileError("NO wire format for " ++ @typeName(T)),
    }
}

fn unmarshal(comptime T: type, reader: *Reader) !T {
    return switch (@typeInfo(T)) {
        .void => {},
        .bool => try reader.takeInt(u8, endian) != 0,
        .int => try reader.takeInt(T, endian),
        // .float => |float| @bitCast(try reader.takeInt(@Int(.unsigned, float.bits), endian)),
    };
}

fn description(comptime T: type) []const u8 {
    return switch (@typeInfo(T)) {
        .array => |array| std.fmt.comptimePrint("[{d}]", .{array.len}) ++
            description(array.child),
        .@"enum" => |@"enum"| text: {
            var text: []const u8 = "e" ++ @typeName(@"enum".tag_type) ++ "{";
            for (@"enum".fields) |field| text = text ++ field.name ++ ",";
            break :text text ++ "}";
        },
        .@"struct" => |@"struct"| text: {
            var text: []const u8 = "s{";
            for (@"struct".fields) |field| text = text ++ field.name ++ ":" ++
                description(field.type) ++ ",";
            break :text text ++ "}";
        },
        .@"union" => |@"union"| text: {
            var text: []const u8 = "u{";
            for (@"union".fields) |field| text = text ++ field.name ++ ":" ++
                description(field.type) ++ ",";
            break :text text ++ "}";
        },
        else => @typeName(T),
    };
}
