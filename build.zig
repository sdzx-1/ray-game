const std = @import("std");
const addInstallGraphFile = @import("polystate").addInstallGraphFile;
const emcc = @import("raylib_zig").emcc;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    if (target.query.os_tag == .emscripten) {
        const sysroot =
            if (b.sysroot) |sysroot| sysroot else try b.build_root.join(b.allocator, &.{
                "emscripten-builder",
                "zig-out",
                "emsdk",
                "upstream",
                "emscripten",
            });

        const emcc_path = try std.fs.path.join(b.allocator, &.{ sysroot, "emcc" });

        std.fs.accessAbsolute(emcc_path, .{}) catch {
            b.default_step.dependOn(&b.addFail(
                \\sysroot must point to the emscripten directory containing `emcc`
                \\
                \\You must either:
                \\1. Use --sysroot <path-to-emscripten>
                \\2. Run `zig build` in emscripten-builder 
                \\
            ).step);
        };

        b.sysroot = sysroot;
    }

    const optimize = b.standardOptimizeOption(.{});
    const no_bin = b.option(bool, "no_bin", "no bin") orelse false;

    // zig fmt: off
    const polystate  = b.dependency("polystate",  .{.target = target, .optimize = optimize}).module("root");
    const raylib_dep = b.dependency("raylib_zig", .{.target = target, .optimize = optimize});
    const maze_dep =   b.dependency("maze",       .{.target = target, .optimize = optimize});

    // zig fmt: on

    const raylib_artifact = raylib_dep.artifact("raylib");

    if (target.query.os_tag == .emscripten) {
        const exe_lib = try emcc.compileForEmscripten(b, "ray_game", "src/main.zig", target, optimize);
        exe_lib.root_module.addImport("polystate", polystate);
        exe_lib.root_module.addImport("raylib", raylib_dep.module("raylib"));
        exe_lib.root_module.addImport("raygui", raylib_dep.module("raygui"));
        exe_lib.root_module.addImport("maze", maze_dep.module("maze"));

        exe_lib.linkLibrary(raylib_artifact);
        const link_step = try emcc.linkWithEmscripten(b, &.{ exe_lib, raylib_artifact });
        link_step.addArg("--emrun");
        link_step.addArg("-sALLOW_MEMORY_GROWTH");
        link_step.addArg("-sFORCE_FILESYSTEM");
        link_step.addArg("-lidbfs.js");

        link_step.addArg("--pre-js");
        link_step.addArg("emscripten/setup.js");

        link_step.addArg("--js-library");
        link_step.addArg("emscripten/file_sync.js");

        link_step.addArg("--preload-file");
        link_step.addArg("data/");
        link_step.addArg("--preload-file");
        link_step.addArg("config.json");

        b.getInstallStep().dependOn(&link_step.step);

        const run_step = try emcc.emscriptenRunStep(b);
        run_step.step.dependOn(b.getInstallStep());
        const run_option = b.step("run", "Run the app");

        run_option.dependOn(&run_step.step);
    } else {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "polystate", .module = polystate },
                .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                .{ .name = "maze", .module = maze_dep.module("maze") },
            },
        });

        //generate state graph
        const install_dot_file = addInstallGraphFile(b, "ray-game", exe_mod, .graphviz, polystate, target, .{ .custom = "graphs" });
        const install_mmd_file = addInstallGraphFile(b, "ray-game", exe_mod, .mermaid, polystate, target, .{ .custom = "graphs" });
        const install_json_file = addInstallGraphFile(b, "ray-game", exe_mod, .json, polystate, target, .{ .custom = "../" });

        const exe = b.addExecutable(.{
            .name = "ray_game",
            .root_module = exe_mod,
        });

        if (no_bin) {
            exe.linkLibrary(raylib_artifact);
            b.getInstallStep().dependOn(&exe.step);
        } else {
            b.getInstallStep().dependOn(&install_dot_file.step);
            b.getInstallStep().dependOn(&install_mmd_file.step);
            b.getInstallStep().dependOn(&install_json_file.step);

            exe.linkLibrary(raylib_artifact);
            b.installArtifact(exe);

            const run_cmd = b.addRunArtifact(exe);

            run_cmd.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);
        }

        const install_content_step = b.addInstallFile(
            b.path("data/FiraMono-Regular.ttf"),
            b.pathJoin(&.{ "bin", "data/FiraMono-Regular.ttf" }),
        );
        b.default_step.dependOn(&install_content_step.step);
    }
}
