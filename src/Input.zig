const Input = @This();

const nz = @import("numz");
const Window = @import("Window.zig");

pub const world_up: nz.Vec3(f32) = .{ 0, 1, 0 };

keys: Keys = .{},
look: [2]f32 = .{ 0, 0 },

pub const Keys = packed struct(u8) {
    forward: bool = false,
    back: bool = false,
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    _pad: u2 = 0,
};

pub fn forward(self: Input) nz.Vec3(f32) {
    const cos_pitch = @cos(self.pitch);
    return .{ -cos_pitch * @sin(self.yaw), @sin(self.pitch), -cos_pitch * @cos(self.yaw) };
}

pub fn sample(window: *const Window) Input {
    return .{
        .keys = .{
            .forward = window.keyboard.isDown(.w),
            .back = window.keyboard.isDown(.s),
            .left = window.keyboard.isDown(.a),
            .right = window.keyboard.isDown(.d),
            .up = window.keyboard.isDown(.space),
            .down = window.keyboard.isDown(.left_shift),
        },
        .look = switch (window.pointer.movement) {
            .relative => |r| .{ @floatCast(r.dx), @floatCast(r.dy) },
            .position => .{ 0, 0 },
        },
    };
}
