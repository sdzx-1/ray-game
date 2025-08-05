const std = @import("std");
const builtin = @import("builtin");
const addInstallGraphFile = @import("polystate").addInstallGraphFile;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const emcc_dir: std.Build.LazyPath =
        if (target.query.os_tag == .emscripten) blk: {
            if (b.sysroot) |sysroot| {
                const emcc_path = try std.fs.path.join(b.allocator, &.{ sysroot, "emcc" });

                std.fs.accessAbsolute(emcc_path, .{}) catch {
                    b.default_step.dependOn(&b.addFail("if sysroot is provided, it must point to the emscripten directory containing `emcc`").step);
                };

                break :blk .{ .cwd_relative = sysroot };
            }

            // 'sysroot' isn't actually used in a meaningful way, but some dependencies require it when compiling their build scripts.
            b.sysroot = "/";

            const emscripten_builder_dep = b.lazyDependency("emscripten_builder", .{}) orelse return;

            break :blk try emscripten_builder_dep.namedLazyPath("emscripten").join(b.allocator, "upstream/emscripten");
        } else undefined;

    const optimize = b.standardOptimizeOption(.{});
    const no_bin = b.option(bool, "no_bin", "no bin") orelse false;

    // zig fmt: off
    const polystate  = b.dependency("polystate",  .{.target = target, .optimize = optimize}).module("root");
    const raylib_dep = b.dependency("raylib_zig", .{.target = target, .optimize = optimize});
    const maze_dep =   b.dependency("maze",       .{.target = target, .optimize = optimize});

    // zig fmt: on

    const raylib_artifact = raylib_dep.artifact("raylib");

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

    exe_mod.linkLibrary(raylib_artifact);

    if (target.query.os_tag == .emscripten) {
        const exe_lib = b.addLibrary(.{
            .linkage = .static,
            .name = "ray_game",
            .root_module = exe_mod,
        });

        const link = try linkWithEmscripten(b, emcc_dir, optimize, &.{ exe_lib, raylib_artifact });

        link.command.addArg("--emrun");
        link.command.addArg("-sALLOW_MEMORY_GROWTH");
        link.command.addArg("-sFORCE_FILESYSTEM");
        link.command.addArg("-lidbfs.js");

        link.command.addArg("--pre-js");
        link.command.addFileArg(b.path("emscripten/setup.js"));

        link.command.addArg("--js-library");
        link.command.addFileArg(b.path("emscripten/file_sync.js"));

        link.command.addArg("--preload-file");
        try addEmscriptenVirtualDirectoryArg(b, link.command, "data");

        link.command.addArg("--preload-file");
        try addEmscriptenVirtualFileArg(b, link.command, "config.json");

        b.installDirectory(.{
            .source_dir = link.output_dir,
            .install_dir = .{ .custom = "htmlout" },
            .install_subdir = "",
        });

        const run_cmd = try emscriptenRunStep(b, emcc_dir, try link.output_dir.join(b.allocator, "index.html"));
        const run_option = b.step("run", "Run the app");

        run_option.dependOn(&run_cmd.step);
    } else {
        //generate state graph
        const install_dot_file = addInstallGraphFile(b, "ray-game", exe_mod, .graphviz, polystate, target, .{ .custom = "graphs" });
        const install_mmd_file = addInstallGraphFile(b, "ray-game", exe_mod, .mermaid, polystate, target, .{ .custom = "graphs" });
        const install_json_file = addInstallGraphFile(b, "ray-game", exe_mod, .json, polystate, target, .{ .custom = "../" });

        const exe = b.addExecutable(.{
            .name = "ray_game",
            .root_module = exe_mod,
        });

        if (no_bin) {
            b.getInstallStep().dependOn(&exe.step);
        } else {
            b.getInstallStep().dependOn(&install_dot_file.step);
            b.getInstallStep().dependOn(&install_mmd_file.step);
            b.getInstallStep().dependOn(&install_json_file.step);

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

fn addEmscriptenVirtualFileArg(
    b: *std.Build,
    run: *std.Build.Step.Run,
    rel_path: []const u8,
) !void {
    try addEmscriptenVirtualPathArg(b, run, rel_path);
    try run.step.addWatchInput(b.path(rel_path));
}

fn addEmscriptenVirtualDirectoryArg(
    b: *std.Build,
    run: *std.Build.Step.Run,
    rel_path: []const u8,
) !void {
    try addEmscriptenVirtualPathArg(b, run, rel_path);
    _ = try run.step.addDirectoryWatchInput(b.path(rel_path));
}

fn addEmscriptenVirtualPathArg(
    b: *std.Build,
    run: *std.Build.Step.Run,
    rel_path: []const u8,
) !void {
    run.addArg(
        try std.fmt.allocPrint(b.allocator, "{s}@{s}", .{
            try b.build_root.join(b.allocator, &.{rel_path}),
            rel_path,
        }),
    );
}

const EmccRun = struct {
    command: *std.Build.Step.Run,
    output_dir: std.Build.LazyPath,
};

fn linkWithEmscripten(
    b: *std.Build,
    emscripten_dir: std.Build.LazyPath,
    optimize: std.builtin.OptimizeMode,
    itemsToLink: []const *std.Build.Step.Compile,
) !EmccRun {
    const emccExe = switch (builtin.os.tag) {
        .windows => "emcc",
        else => "emcc",
    };

    const emcc_command = addSystemCommand(b, &.{});
    emcc_command.addFileArg(try emscripten_dir.join(b.allocator, emccExe));

    for (itemsToLink) |item| {
        emcc_command.addFileArg(item.getEmittedBin());
    }

    emcc_command.addArg("-o");

    const output_file = emcc_command.addOutputFileArg("index.html");
    var output_dir = output_file;
    output_dir.generated.up = 1;

    emcc_command.addArg(switch (optimize) {
        .Debug => "-O0",
        .ReleaseSafe => "-O3",
        .ReleaseFast => "-O3",
        .ReleaseSmall => "-Oz",
    });

    emcc_command.addArgs(&[_][]const u8{
        "-sUSE_OFFSET_CONVERTER",
        "-sFULL-ES3=1",
        "-sUSE_GLFW=3",
        "-sASYNCIFY",
        "-fsanitize=undefined",
        "--emrun",
    });

    return .{
        .command = emcc_command,
        .output_dir = output_dir,
    };
}

fn emscriptenRunStep(
    b: *std.Build,
    emscripten_dir: std.Build.LazyPath,
    run_file: std.Build.LazyPath,
) !*std.Build.Step.Run {
    const emrunExe = switch (builtin.os.tag) {
        .windows => "emrun.bat",
        else => "emrun",
    };

    const run_cmd = addSystemCommand(b, &.{});
    run_cmd.addFileArg(try emscripten_dir.join(b.allocator, emrunExe));
    run_cmd.addFileArg(run_file);

    return run_cmd;
}

// This is a hack to allow LazyPath for the first arg (normal addSystemCommand requires at least one arg).
fn addSystemCommand(b: *std.Build, argv: []const []const u8) *std.Build.Step.Run {
    const run_step = std.Build.Step.Run.create(b, b.fmt("run command", .{}));
    run_step.addArgs(argv);
    return run_step;
}
