const std = @import("std");
const R = core.R;
const core = @import("core.zig");
const map = @import("map.zig");

pub const SaveData = struct {
    menu: []const R = &.{},
    play: []const R = &.{},
    maze_config: map.MazeConfig = .{},

    pub fn save(self: *const @This()) void {
        const cwd = std.fs.cwd();
        const file = cwd.createFile("config.txt", .{}) catch unreachable;
        const writer = file.writer();
        std.json.stringify(self.*, .{ .whitespace = .indent_2 }, writer) catch unreachable;
    }

    pub fn load(gpa: std.mem.Allocator) SaveData {
        var arena_instance = std.heap.ArenaAllocator.init(gpa);
        defer arena_instance.deinit();
        const arena = arena_instance.allocator();

        const cwd = std.fs.cwd();

        if (cwd.access("config.txt", .{})) |_| {
            const file = cwd.openFile("config.txt", .{}) catch unreachable;
            const content = file.readToEndAlloc(arena, 5 << 20) catch unreachable;
            const parsed = std.json.parseFromSlice(@This(), arena, content, .{ .ignore_unknown_fields = true }) catch unreachable;
            const val = parsed.value;

            return .{
                .menu = gpa.dupe(R, val.menu) catch unreachable,
                .play = gpa.dupe(R, val.play) catch unreachable,
                .maze_config = val.maze_config,
            };
        } else |_| {
            return .{};
        }
    }
};
