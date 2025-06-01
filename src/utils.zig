const std = @import("std");
const R = core.R;
const core = @import("core.zig");
const tbuild = @import("tbuild.zig");
const map = @import("map.zig");
const GST = core.GST;

pub const SaveData = struct {
    screen_width: f32 = 1000,
    screen_height: f32 = 800,
    hdw: f32 = 800.0 / 1000.0,
    menu: []const R = &.{},
    map: []const R = &.{},
    play: []const R = &.{},
    tbuild: []const tbuild.Building = &.{},
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

            var val = parsed.value;
            val.menu = gpa.dupe(R, val.menu) catch unreachable;
            val.play = gpa.dupe(R, val.play) catch unreachable;
            val.map = gpa.dupe(R, val.map) catch unreachable;
            val.tbuild = gpa.dupe(tbuild.Building, val.tbuild) catch unreachable;
            return val;
        } else |_| {
            return .{};
        }
    }
};

pub fn saveData(gst: *GST) void {
    const save_data: SaveData = .{
        .menu = gst.menu.rs.items,
        .map = gst.map.rs.items,
        .play = gst.play.rs.items,
        .tbuild = gst.tbuild.list.items,
        .maze_config = gst.map.maze_config,
        .screen_width = gst.screen_width,
        .screen_height = gst.screen_height,
        .hdw = gst.hdw,
    };
    save_data.save();
    gst.log("save");
}

pub fn loadData(gpa: std.mem.Allocator, gst: *GST) !void {
    const save_data = SaveData.load(gpa);
    try gst.menu.rs.appendSlice(gpa, save_data.menu);
    try gst.map.rs.appendSlice(gpa, save_data.map);
    try gst.play.rs.appendSlice(gpa, save_data.play);
    try gst.tbuild.list.appendSlice(gpa, save_data.tbuild);
    gst.map.maze_config = save_data.maze_config;
    gst.screen_width = save_data.screen_width;
    gst.screen_height = save_data.screen_height;
    gst.hdw = save_data.hdw;

    gst.log("load_data");
}
