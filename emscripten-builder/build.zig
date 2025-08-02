const std = @import("std");
const builtin = @import("builtin");

const emsdk_script_file = switch (builtin.os.tag) {
    .windows => "emsdk.bat",
    else => "emsdk",
};

fn emsdkDependencyInstalled(b: *std.Build, emsdk: *std.Build.Dependency) !bool {
    const dot_emsc_path = try std.fs.path.join(b.allocator, &.{ emsdk.path("").getPath(b), ".emscripten" });
    const dot_emsc_exists = !std.meta.isError(std.fs.accessAbsolute(dot_emsc_path, .{}));
    return dot_emsc_exists;
}

pub fn build(b: *std.Build) !void {
    const emsdk = b.dependency("emsdk", .{});

    if (try emsdkDependencyInstalled(b, emsdk)) {
        if (std.meta.isError(std.fs.accessAbsolute(b.install_path, .{}))) {
            try std.fs.makeDirAbsolute(b.install_path);
        }

        if (std.meta.isError(std.fs.accessAbsolute(b.getInstallPath(.{ .custom = "emsdk" }, ""), .{}))) {
            try std.fs.symLinkAbsolute(
                emsdk.path("").getPath(b),
                b.getInstallPath(.{ .custom = "emsdk" }, ""),
                .{ .is_directory = true },
            );
        }

        return;
    }

    const emsdk_install_dir = b.addInstallDirectory(.{
        .install_dir = .{ .custom = "emsdk" },
        .install_subdir = "",
        .source_dir = emsdk.path(""),
    });

    const emsdk_script_path = b.getInstallPath(.{ .custom = "emsdk" }, emsdk_script_file);

    const emsdk_run_install = b.addSystemCommand(&.{ emsdk_script_path, "install", "latest" });
    emsdk_run_install.step.dependOn(&emsdk_install_dir.step);

    const emsdk_run_activate = b.addSystemCommand(&.{ emsdk_script_path, "activate", "latest" });
    emsdk_run_activate.step.dependOn(&emsdk_install_dir.step);
    emsdk_run_activate.step.dependOn(&emsdk_run_install.step);

    b.default_step.dependOn(&emsdk_run_activate.step);
}
