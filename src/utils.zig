const initial_save_path = "config.json";

const save_path = switch (@import("builtin").os.tag) {
    .emscripten => "save-data/" ++ initial_save_path,
    else => initial_save_path,
};

extern "env" fn js_syncfs() void;

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

    pub fn save(self: *const @This(), allocator: std.mem.Allocator) void {
        const json_string = std.json.stringifyAlloc(allocator, self.*, .{ .whitespace = .indent_2 }) catch return;
        defer allocator.free(json_string);

        const json_string_z = allocator.dupeZ(u8, json_string) catch return;
        defer allocator.free(json_string_z);

        _ = rl.saveFileText(save_path, json_string_z);

        switch (@import("builtin").os.tag) {
            .emscripten => js_syncfs(),
            else => {},
        }
    }

    pub fn load(gpa: std.mem.Allocator) SaveData {
        const load_path = if (rl.fileExists(save_path)) save_path else if (rl.fileExists(initial_save_path)) initial_save_path else return .{};

        const content = rl.loadFileText(load_path);
        defer rl.unloadFileText(content);

        const parsed = std.json.parseFromSlice(@This(), gpa, content, .{ .ignore_unknown_fields = true, .allocate = .alloc_always }) catch return .{};

        return parsed.value;
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
    save_data.save(ctx.gpa);
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
