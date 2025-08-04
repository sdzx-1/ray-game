const save_path = "config.json";

pub const SaveData = struct {
    screen_width: f32 = 1000,
    screen_height: f32 = 800,
    hdw: f32 = 800.0 / 1000.0,
    menu: []const StateComponents(menu.Menu).Component = &.{},
    map: []const StateComponents(map.Map).Component = &.{},
    play: []const StateComponents(play.Play).Component = &.{},
    tbuild: []const tbuild.TbuildData.Building = &.{},
    maze_config: map.MazeConfig = .{},
    maze_texture: [4]textures.TextID = .{
        .{ .x = 2, .y = 31 },
        .{ .x = 6, .y = 67 },
        .{ .x = 5, .y = 31 },
        .{ .x = 7, .y = 31 },
    },

    pub fn save(self: *const @This()) void {
        const cwd = std.fs.cwd();
        const file = cwd.createFile(save_path, .{}) catch unreachable;
        const writer = file.writer();
        std.json.stringify(self.*, .{ .whitespace = .indent_2 }, writer) catch unreachable;
    }

    pub fn load(gpa: std.mem.Allocator) SaveData {
        var arena_instance = std.heap.ArenaAllocator.init(gpa);
        defer arena_instance.deinit();
        const arena = arena_instance.allocator();

        const cwd = std.fs.cwd();

        if (cwd.access(save_path, .{})) |_| {
            const file = cwd.openFile(save_path, .{}) catch unreachable;
            const content = file.readToEndAlloc(arena, 5 << 20) catch unreachable;
            const parsed = std.json.parseFromSlice(@This(), arena, content, .{ .ignore_unknown_fields = true }) catch unreachable;

            var val = parsed.value;
            val.menu = gpa.dupe(StateComponents(menu.Menu).Component, val.menu) catch unreachable;
            val.play = gpa.dupe(StateComponents(play.Play).Component, val.play) catch unreachable;
            val.map = gpa.dupe(StateComponents(map.Map).Component, val.map) catch unreachable;
            val.tbuild = gpa.dupe(tbuild.TbuildData.Building, val.tbuild) catch unreachable;
            return val;
        } else |_| {
            return .{};
        }
    }
};

pub fn saveData(ctx: *Context) void {
    const save_data: SaveData = .{
        // zig fmt: off
        .menu          = ctx.menu.rs.array_r.items,
        .map           = ctx.map.rs.array_r.items,
        .play          = ctx.play.rs.array_r.items,
        .tbuild        = ctx.tbuild.list.items,
        .maze_config   = ctx.map.maze_config,
        .screen_width  = ctx.screen_width,
        .screen_height = ctx.screen_height,
        .hdw           = ctx.hdw,
        // .tbuild_view   = ctx.tbuild.view,
        .maze_texture  = ctx.play.maze_texture,
        // zig fmt: on
    };
    save_data.save();
    ctx.log("save");
}

pub fn loadData(gpa: std.mem.Allocator, ctx: *Context) !void {
    const save_data = SaveData.load(gpa);
    try ctx.menu.rs.array_r.appendSlice(gpa, save_data.menu);
    try ctx.map.rs.array_r.appendSlice(gpa, save_data.map);
    try ctx.play.rs.array_r.appendSlice(gpa, save_data.play);
    try ctx.tbuild.list.appendSlice(gpa, save_data.tbuild);
    ctx.map.maze_config = save_data.maze_config;
    ctx.screen_width = save_data.screen_width;
    ctx.screen_height = save_data.screen_height;
    ctx.hdw = save_data.hdw;
    // ctx.tbuild.view = save_data.tbuild_view;
    ctx.play.maze_texture = save_data.maze_texture;
    ctx.log("load_data");
}

const std = @import("std");
const StateComponents = core.StateComponents;
const core = @import("core.zig");
const tbuild = @import("tbuild.zig");
const map = @import("map.zig");
const menu = @import("menu.zig");
const play = @import("play.zig");
const Context = core.Context;
const rl = @import("raylib");
const textures = @import("textures.zig");
