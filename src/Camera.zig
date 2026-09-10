const Camera = @This();

const std = @import("std");
const nz = @import("numz");
const Input = @import("Input.zig");

pub const world_up: nz.Vec3(f32) = .{ 0, 1, 0 };

const sensitivity = 0.002;

position: nz.Vec3(f32) = .{ 0, 1, 6 },
yaw: f32 = 0,
pitch: f32 = 0,

pub fn turn(self: Camera, look: [2]f32) Camera {
    return .{
        .position = self.position,
        .yaw = self.yaw - look[0] * sensitivity,
        .pitch = std.math.clamp(self.pitch - look[1] * sensitivity, -1.4, 1.4),
    };
}

pub fn fly(self: Camera, keys: Input.Keys, distance: f32) Camera {
    const f = self.forward();
    const r = nz.vec.normalize(nz.vec.cross(f, world_up));
    var d: nz.Vec3(f32) = @splat(0);
    if (keys.forward) d += f;
    if (keys.back) d -= f;
    if (keys.right) d += r;
    if (keys.left) d -= r;
    if (keys.up) d += world_up;
    if (keys.down) d -= world_up;
    const len = nz.vec.length(d);
    if (len == 0) return self;
    return .{
        .position = self.position + nz.vec.scale(d, distance / len),
        .yaw = self.yaw,
        .pitch = self.pitch,
    };
}

pub fn forward(self: Camera) nz.Vec3(f32) {
    const pitch_cos = @cos(self.pitch);
    return .{ -pitch_cos * @sin(self.yaw), @sin(self.pitch), -pitch_cos * @cos(self.yaw) };
}

pub fn viewMatrix(self: Camera) nz.Mat4x4(f32) {
    return .lookAt(self.position, self.position + self.forward(), world_up);
}
