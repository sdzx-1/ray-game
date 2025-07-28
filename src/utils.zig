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

const save_path = "config.json";

pub const SaveData = struct {
    screen_width: f32 = 1000,
    screen_height: f32 = 800,
    hdw: f32 = 800.0 / 1000.0,
    menu: []const StateComponents(menu.Menu).Component = &.{},
    map: []const StateComponents(map.Map).Component = &.{},
    play: []const StateComponents(play.Play).Component = &.{},
    tbuild: []const tbuild.Building = &.{},
    tbuild_view: View = .{},
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
            val.tbuild = gpa.dupe(tbuild.Building, val.tbuild) catch unreachable;
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
        .tbuild_view   = ctx.tbuild.view,
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
    ctx.tbuild.view = save_data.tbuild_view;
    ctx.play.maze_texture = save_data.maze_texture;
    ctx.log("load_data");
}

pub const View = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 50,

    pub fn dwin_to_dview(self: *const View, screen_w: f32, deta_win_pos: rl.Vector2) rl.Vector2 {
        const r = self.width / screen_w;
        return .{ .x = deta_win_pos.x * r, .y = deta_win_pos.y * r };
    }

    pub fn dview_to_dwin(self: *const View, screen_w: f32, deta_view_pos: rl.Vector2) rl.Vector2 {
        const r = screen_w / self.width;
        return .{ .x = deta_view_pos.x * r, .y = deta_view_pos.y * r };
    }

    pub fn win_to_view(self: *const View, screen_w: f32, win_pos: rl.Vector2) rl.Vector2 {
        const r = self.width / screen_w;
        return .{ .x = self.x + win_pos.x * r, .y = self.y + win_pos.y * r };
    }

    pub fn view_to_win(self: *const View, screen_w: f32, view_pos: rl.Vector2) rl.Vector2 {
        const r = screen_w / self.width;
        return .{ .x = (view_pos.x - self.x) * r, .y = (view_pos.y - self.y) * r };
    }

    pub fn center(self: *@This(), hdw: f32, x: f32, y: f32) void {
        self.x = x - self.width / 2;
        self.y = y - (self.width * hdw) / 2;
    }

    pub fn mouse_wheel(self: *View, hdw: f32) void {
        const mouse_wheel_deta = rl.getMouseWheelMove();
        const deta = (mouse_wheel_deta * 0.65) * self.width * 0.2;
        self.x -= deta / 2;
        self.y -= (deta * hdw) / 2;
        self.width += deta;
    }

    pub fn drag_view(self: *View, screen_width: f32) void {
        if (rl.isMouseButtonDown(rl.MouseButton.middle) or
            (rl.isKeyDown(rl.KeyboardKey.left_alt)))
        {
            const deta = self.dwin_to_dview(screen_width, rl.getMouseDelta());
            self.x -= deta.x;
            self.y -= deta.y;
        }
    }
};
