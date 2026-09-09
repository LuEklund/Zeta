const Input = @This();

const Window = @import("Window.zig");

keys: Keys = .{},
yaw: f32 = 0,
pitch: f32 = 0,

pub const Keys = packed struct(u8) {
    forward: bool = false,
    back: bool = false,
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    _pad: u2 = 0,
};

pub fn sample(window: *const Window, previous: Input) Input {
    const look = switch (window.pointer.movement) {
        .relative => |r| r,
        .position => .{ .dx = 0, .dy = 0 },
    };
    const sensitivity = 0.002;
    return .{
        .keys = .{
            .forward = window.keyboard.isDown(.w),
            .back = window.keyboard.isDown(.s),
            .left = window.keyboard.isDown(.a),
            .right = window.keyboard.isDown(.d),
            .up = window.keyboard.isDown(.space),
            .down = window.keyboard.isDown(.left_shift),
        },
        .yaw = previous.yaw - @as(f32, @floatCast(look.dx)) *
            sensitivity,
        .pitch = @min(1.4, @max(-1.4, previous.pitch - @as(f32, @floatCast(look.dy)) * sensitivity)),
    };
}
