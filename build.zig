const std = @import("std");
const addInstallGraphFile = @import("polystate").addInstallGraphFile;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // zig fmt: off
    const polystate  = b.dependency("polystate",  .{.target = target, .optimize = optimize});
    const raylib_dep = b.dependency("raylib_zig", .{.target = target, .optimize = optimize});
    const maze_dep =   b.dependency("maze",       .{.target = target, .optimize = optimize});

    // zig fmt: on

    const install_content_step = b.addInstallFile(
        b.path("data/FiraMono-Regular.ttf"),
        b.pathJoin(&.{ "bin", "data/FiraMono-Regular.ttf" }),
    );
    b.default_step.dependOn(&install_content_step.step);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "polystate", .module = polystate.module("root") },
            .{ .name = "raylib", .module = raylib_dep.module("raylib") },
            .{ .name = "raygui", .module = raylib_dep.module("raygui") },
            .{ .name = "maze", .module = maze_dep.module("maze") },
        },
    });

    //generate state graph
    const install_dot_file = addInstallGraphFile(b, "ray-game", exe_mod, 100, .graphviz, polystate, target, .{ .custom = "graphs" });
    const install_mmd_file = addInstallGraphFile(b, "ray-game", exe_mod, 100, .mermaid, polystate, target, .{ .custom = "graphs" });

    b.getInstallStep().dependOn(&install_dot_file.step);
    b.getInstallStep().dependOn(&install_mmd_file.step);

    const exe = b.addExecutable(.{
        .name = "ray_game",
        .root_module = exe_mod,
    });

    exe.linkLibrary(raylib_dep.artifact("raylib"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
