const Mesh = @This();

const std = @import("std");

pub const sphere: Mesh = blk: {
    const s = makeSphere(16, 32);
    break :blk .{ .vertices = &s.vertices, .indices = &s.indices };
};

pub const Vertex = extern struct {
    pos: [4]f32,
    color: [4]f32,
};
vertices: []const Vertex,
indices: []const u32,

fn Sphere(comptime rings: u32, comptime sectors: u32) type {
    return struct {
        vertices: [(rings + 1) * (sectors + 1)]Vertex,
        indices: [rings * sectors * 6]u32,
    };
}

fn makeSphere(comptime rings: u32, comptime sectors: u32) Sphere(rings, sectors) {
    @setEvalBranchQuota(100_000);
    var new_sphere: Sphere(rings, sectors) = undefined;
    var vertex_index: usize = 0;
    for (0..rings + 1) |segment| {
        const phi = std.math.pi * @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(rings));
        const y = @cos(phi);
        const ring_radius = @sin(phi);
        for (0..sectors + 1) |c| {
            const theta = 2 * std.math.pi * @as(f32, @floatFromInt(c)) / @as(f32, @floatFromInt(sectors));
            const x = ring_radius * @cos(theta);
            const z = ring_radius * @sin(theta);
            new_sphere.vertices[vertex_index] = .{
                .pos = .{ x, y, z, 1 },
                .color = .{ x * 0.5 + 0.5, y * 0.5 + 0.5, z *
                    0.5 + 0.5, 1 },
            };
            vertex_index += 1;
        }
    }
    var i: usize = 0;
    for (0..rings) |r| {
        for (0..sectors) |c| {
            const a: u16 = @intCast(r * (sectors + 1) + c);
            const b: u16 = a + sectors + 1;
            new_sphere.indices[i..][0..6].* = .{ a, b, a + 1, a + 1, b, b + 1 };
            i += 6;
        }
    }
    return .{ .indices = new_sphere.indices, .vertices = new_sphere.vertices };
}
