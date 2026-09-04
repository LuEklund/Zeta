const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .gnu } });
    const optimize = b.standardOptimizeOption(.{});

    const zeta_mod = zetaModule(b, target, optimize);

    const server_system_mod = b.createModule(.{
        .root_source_file = b.path("src/server/System.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zeta", .module = zeta_mod }},
    });
    const server_system = b.addLibrary(.{
        .name = "system_server",
        .root_module = server_system_mod,
        .linkage = .dynamic,
    });
    b.installArtifact(server_system);

    const server_mod = b.createModule(.{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zeta", .module = zeta_mod }},
    });

    const client_mod = b.createModule(.{
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zeta", .module = zeta_mod }},
    });

    const server = b.addExecutable(.{ .name = "ZetaServer", .root_module = server_mod });
    const client = b.addExecutable(.{ .name = "ZetaClient", .root_module = client_mod });
    b.installArtifact(server);
    b.installArtifact(client);

    const run_server = b.addRunArtifact(server);
    const run_client = b.addRunArtifact(client);
    run_server.step.dependOn(b.getInstallStep());
    run_client.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_server.addArgs(args);
        run_client.addArgs(args);
    }
    b.step("s", "Run the server").dependOn(&run_server.step);
    b.step("c", "Run the client").dependOn(&run_client.step);

    const check = b.step("check", "Semantic analysis for ZLS");
    check.dependOn(&b.addExecutable(.{ .name = "check-server", .root_module = server_mod }).step);
    check.dependOn(&b.addExecutable(.{ .name = "check-client", .root_module = client_mod }).step);
}

fn zetaModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = b.dependency("win32", .{}).module("win32") },
        },
        .link_libc = switch (target.result.os.tag) {
            .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => true,
            else => false,
        },
    });

    switch (target.result.os.tag) {
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => {
            const scanner = @import("wayland").Scanner.create(b, .{});
            const protocols = b.dependency("wayland_protocols", .{});
            scanner.addCustomProtocol(protocols.path("stable/xdg-shell/xdg-shell.xml"));
            scanner.addCustomProtocol(protocols.path("unstable/xdg-decoration/xdg-decoration-unstable-v1.xml"));
            scanner.addCustomProtocol(protocols.path("staging/cursor-shape/cursor-shape-v1.xml"));
            scanner.addCustomProtocol(protocols.path("unstable/tablet/tablet-unstable-v2.xml"));
            scanner.addCustomProtocol(protocols.path("unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"));
            scanner.addCustomProtocol(protocols.path("unstable/relative-pointer/relative-pointer-unstable-v1.xml"));
            scanner.addCustomProtocol(protocols.path("staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml"));

            scanner.generate("wl_compositor", 1);
            scanner.generate("wl_output", 4);
            scanner.generate("wl_shm", 1);
            scanner.generate("wl_seat", 4);
            scanner.generate("wl_data_device_manager", 3);
            scanner.generate("xdg_wm_base", 3);
            scanner.generate("wp_cursor_shape_manager_v1", 2);
            scanner.generate("zxdg_decoration_manager_v1", 1);
            scanner.generate("zwp_tablet_manager_v2", 1);
            scanner.generate("zwp_pointer_constraints_v1", 1);
            scanner.generate("zwp_relative_pointer_manager_v1", 1);
            scanner.generate("xdg_toplevel_icon_manager_v1", 1);

            mod.addImport("wayland", b.createModule(.{
                .root_source_file = scanner.result,
                .target = target,
                .optimize = optimize,
            }));

            const xkbcommon = b.dependency("xkbcommon", .{}).module("xkbcommon");
            xkbcommon.linkLibrary(b.dependency("libxkbcommon", .{
                .target = target,
                .optimize = optimize,
                .@"xkb-config-root" = "/usr/share/X11/xkb",
                .@"x-locale-root" = "/usr/share/X11/locale",
            }).artifact("xkbcommon"));
            mod.addImport("xkbcommon", xkbcommon);
        },
        .macos => {
            mod.addCSourceFile(.{
                .file = b.path("src/Window/Cocoa.m"),
                .flags = &.{"-fobjc-arc"},
                .language = .objective_c,
            });
            mod.linkFramework("Cocoa", .{});
            mod.linkFramework("QuartzCore", .{});
        },
        else => {},
    }

    return mod;
}
