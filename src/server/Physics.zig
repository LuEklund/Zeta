const Physics = @This();

const std = @import("std");
const zeta = @import("zeta");
const b3 = @import("box3d");
const nz = zeta.numz;

pub const tick_hz = 60;
pub const tick_dt: f32 = 1.0 / @as(f32, tick_hz);

world: b3.b3WorldId,
ball: b3.b3BodyId,
accumulator: f32,

pub fn init(self: *Physics) void {
    var world_def = b3.b3DefaultWorldDef();
    world_def.gravity = .{ .x = 0, .y = -9.81, .z = 0 };
    self.world = b3.b3CreateWorld(&world_def);

    var ground_def = b3.b3DefaultBodyDef();
    ground_def.type = b3.b3_staticBody;
    ground_def.position = .{ .x = 0, .y = -2, .z = 0 };
    const ground = b3.b3CreateBody(self.world, &ground_def);
    var ground_shape = b3.b3DefaultShapeDef();
    var ground_hull = b3.b3MakeBoxHull(20, 0.5, 20);
    _ = b3.b3CreateHullShape(ground, &ground_shape, &ground_hull.base);

    var ball_def = b3.b3DefaultBodyDef();
    ball_def.type = b3.b3_dynamicBody;
    ball_def.position = .{ .x = 0, .y = 50, .z = 0 };
    self.ball = b3.b3CreateBody(self.world, &ball_def);
    var ball_shape = b3.b3DefaultShapeDef();
    ball_shape.density = 1;
    const sphere: b3.b3Sphere = .{ .center = .{ .x = 0, .y = 0, .z = 0 }, .radius = 1 };
    _ = b3.b3CreateSphereShape(self.ball, &ball_shape, &sphere);

    self.accumulator = 0;
}

pub fn deinit(self: *Physics) void {
    // b3.b3DestroyBody(self.ball);
    b3.b3DestroyWorld(self.world);
}

pub fn update(self: *Physics, dt: f32) void {
    self.accumulator += dt;
    while (self.accumulator >= tick_dt) : (self.accumulator -= tick_dt) {
        b3.b3World_Step(self.world, tick_dt, 4);
    }
}

pub fn ballTransform(self: *const Physics) nz.Mat4x4(f32) {
    const p = b3.b3Body_GetPosition(self.ball);
    const q = b3.b3Body_GetRotation(self.ball);
    const rotation: nz.quat.Hamiltonian(f32) = .new(q.v.x, q.v.y, q.v.z, q.s);
    return nz.Mat4x4(f32).translate(.{ p.x, p.y, p.z })
        .mul(rotation.toMat4x4())
        .mul(.scale(@splat(1)));
}
