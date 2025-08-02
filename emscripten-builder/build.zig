const std = @import("std");
const builtin = @import("builtin");

const emsdk_script_file = switch (builtin.os.tag) {
    .windows => "emsdk.bat",
    else => "emsdk",
};

pub fn build(b: *std.Build) !void {
    const emsdk = b.dependency("emsdk", .{});

    const emsdk_install_dir = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "",
        .source_dir = emsdk.path(""),
    });

    const emsdk_script_path = b.getInstallPath(.prefix, emsdk_script_file);

    const emsdk_run_install = b.addSystemCommand(&.{ emsdk_script_path, "install", "latest" });
    emsdk_run_install.step.dependOn(&emsdk_install_dir.step);

    const emsdk_run_activate = b.addSystemCommand(&.{ emsdk_script_path, "activate", "latest" });
    emsdk_run_activate.step.dependOn(&emsdk_install_dir.step);
    emsdk_run_activate.step.dependOn(&emsdk_run_install.step);

    b.default_step.dependOn(&emsdk_run_activate.step);
}
