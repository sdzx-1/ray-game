const std = @import("std");
const builtin = @import("builtin");

const emsdk_script_file = switch (builtin.os.tag) {
    .windows => "emsdk.bat",
    else => "emsdk",
};

fn emsdkInstalled(b: *std.Build, path: []const u8) !bool {
    const dot_emsc_path = try std.fs.path.join(b.allocator, &.{ path, ".emscripten" });
    const dot_emsc_exists = !std.meta.isError(std.fs.accessAbsolute(dot_emsc_path, .{}));
    return dot_emsc_exists;
}

fn emsdkDependencyInstalled(b: *std.Build, emsdk: *std.Build.Dependency) !bool {
    return try emsdkInstalled(b, emsdk.path("").getPath(b));
}

fn addEmscriptenInstall(b: *std.Build) !std.Build.LazyPath {
    const emsdk = b.dependency("emsdk", .{});

    if (try emsdkDependencyInstalled(b, emsdk)) {
        return emsdk.path("");
    }

    if (try emsdkInstalled(b, b.getInstallPath(.{ .custom = "emsdk" }, ""))) {
        return .{
            .cwd_relative = b.getInstallPath(.{ .custom = "emsdk" }, ""),
        };
    }

    const emsdk_install_dir = b.addInstallDirectory(.{
        .install_dir = .{ .custom = "emsdk" },
        .install_subdir = "",
        .source_dir = emsdk.path(""),
    });

    const emsdk_script_path = b.getInstallPath(.{ .custom = "emsdk" }, emsdk_script_file);

    const emsdk_run_install = b.addSystemCommand(&.{ emsdk_script_path, "install", "latest" });
    emsdk_run_install.step.dependOn(&emsdk_install_dir.step);

    emsdk_run_install.addFileInput(.{ .cwd_relative = b.getInstallPath(.{ .custom = "emsdk" }, ".emscripten") });

    const emsdk_run_activate = b.addSystemCommand(&.{ emsdk_script_path, "activate", "latest" });
    emsdk_run_activate.step.dependOn(&emsdk_install_dir.step);
    emsdk_run_activate.step.dependOn(&emsdk_run_install.step);

    const gen_file = try b.allocator.create(std.Build.GeneratedFile);
    gen_file.* = .{ .path = b.getInstallPath(.{ .custom = "emsdk" }, ""), .step = &emsdk_run_activate.step };

    return .{ .generated = .{ .file = gen_file } };
}

pub fn build(b: *std.Build) !void {
    b.addNamedLazyPath("emscripten", try addEmscriptenInstall(b));
}
