pub const MazeConfig = struct {
    x: f32 = 0,
    y: f32 = 100,
    width: f32 = 2,
    probability: f32 = 0.2,
    total_x: u32 = 137,
    total_y: u32 = 137,
    room_min_width: i32 = 3,
    room_max_width: i32 = 17,
};

pub const MapData = struct {
    rs: RS = .empty,
    maze: ?Maze = null,
    maze_config: MazeConfig = .{},
    generating: bool = false,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }
};

pub const Map = union(enum) {
    // zig fmt: off
    exit1       : Example(.next, ps.Exit),
    to_editor   : Example(.next, Select(Map, Editor( Map))),
    to_menu     : Example(.next, Animation(Map, Menu)),
    to_play     : Example(.next, Play),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;

        if (rl.isKeyPressed(rl.KeyboardKey.g)) {
            _ = gen_maze(ctx);
        }

        if (ctx.map.maze) |m| {
            for (0..m.totalYSize) |y| {
                for (0..m.totalXSize) |x| {
                    const idx = Maze.Index.from_uszie_xy(x, y);
                    const val = m.readBoard(idx);
                    const color = switch (val) {
                        .room => rl.Color.sky_blue,
                        .path => rl.Color.gray,
                        .connPoint => rl.Color.orange,
                        else => rl.Color.white,
                    };
                    const ptr = &ctx.map.maze_config;
                    const width: i32 = @intFromFloat(ptr.width);
                    const tx: i32 = @intFromFloat(ptr.x);
                    const ty: i32 = @intFromFloat(ptr.y);
                    const rx = tx + @as(i32, @intCast(x)) * width;
                    const ry = ty + @as(i32, @intCast(y)) * width;
                    rl.drawRectangle(rx, ry, width, width, color);
                }
            }
        }

        for (ctx.map.rs.items) |*r| {
            if (r.render(ctx, @This(), action_list)) |msg| {
                return msg;
            }
        }
        return .no_trasition;
    }

    fn toEditor(_: *Context) ?@This() {
        return .to_editor;
    }

    fn toMenu(ctx: *Context) ?@This() {
        ctx.animation.start_time = std.time.milliTimestamp();
        return .to_menu;
    }

    fn toPlay(ctx: *Context) ?@This() {
        ctx.animation.start_time = std.time.milliTimestamp();
        if (ctx.map.maze == null) {
            generate_maze(
                ctx.gpa,
                &ctx.map.maze,
                ctx.map.maze_config.total_x,
                ctx.map.maze_config.total_y,
                ctx.map.maze_config.room_min_width,
                ctx.map.maze_config.room_max_width,
                ctx.random.int(u64),
                ctx.map.maze_config.probability,
            );
        }
        const m = ctx.map.maze.?;

        for (0..m.totalYSize) |y| {
            for (0..m.totalXSize) |x| {
                const idx = Maze.Index.from_uszie_xy(x, y);
                const val = m.readBoard(idx);
                ctx.play.current_map[y][x] = .{ .tag = val, .building = null };
            }
        }

        const sx = @as(f32, @floatFromInt(ctx.map.maze_config.total_x));
        const sy = @as(f32, @floatFromInt(ctx.map.maze_config.total_y));
        ctx.play.view.width = 50;
        ctx.play.view.center(ctx.hdw, sx / 2, sy / 2);
        return .to_play;
    }

    fn exit(_: *Context) ?@This() {
        return .exit1;
    }

    fn gen_maze(ctx: *Context) ?@This() {
        if (!ctx.map.generating) {
            ctx.map.generating = !ctx.map.generating;
            if (ctx.map.maze) |*m| {
                m.deinit(ctx.gpa);
                ctx.map.maze = null;
            }
            _ = std.Thread.spawn(
                .{},
                generate_maze,
                .{
                    ctx.gpa,
                    &ctx.map.maze,
                    ctx.map.maze_config.total_x,
                    ctx.map.maze_config.total_y,
                    ctx.map.maze_config.room_min_width,
                    ctx.map.maze_config.room_max_width,
                    ctx.random.int(u64),
                    ctx.map.maze_config.probability,
                },
            ) catch unreachable;
            ctx.map.generating = !ctx.map.generating;
        }
        return null;
    }

    // zig fmt: off
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor",   .val = .{ .button = toEditor } },
        .{ .name = "Menu",     .val = .{ .button = toMenu } },
        .{ .name = "Exit",     .val = .{ .button = exit } },
        .{ .name = "Gen maze", .val = .{ .button = gen_maze } },
        .{ .name = "rmx",      .val = .{ .slider = .{.fun = mconfig_x, .min = 0, .max = 1000}  } },
        .{ .name = "rmy",      .val = .{ .slider = .{.fun = mconfig_y, .min = 0, .max = 1000}  } },
        .{ .name = "rmwidth",     .val = .{ .slider = .{.fun = mconfig_width, .min = 2, .max = 100}  } },
        .{ .name = "probability", .val = .{ .slider = .{.fun = mconfig_prob, .min = 0, .max = 0.4}  } },
        .{ .name = "Play", .val = .{ .button = toPlay } },
    };
    // zig fmt: on

    fn mconfig_x(ctx: *Context) *f32 {
        return &ctx.map.maze_config.x;
    }

    fn mconfig_y(ctx: *Context) *f32 {
        return &ctx.map.maze_config.y;
    }

    fn mconfig_width(ctx: *Context) *f32 {
        return &ctx.map.maze_config.width;
    }

    fn mconfig_prob(ctx: *Context) *f32 {
        return &ctx.map.maze_config.probability;
    }

    pub fn animation(
        ctx: *Context,
        screen_width: f32,
        screen_height: f32,
        duration: f32,
        total: f32,
        b: bool,
    ) void {
        anim.animation_list_r(
            screen_width,
            screen_height,
            ctx.map.rs.items,
            duration,
            total,
            b,
        );
    }

    pub fn access_rs(ctx: *Context) *RS {
        return &ctx.map.rs;
    }
};

fn generate_maze(
    gpa: std.mem.Allocator,
    m_maze: *?Maze,
    total_x: u32,
    total_y: u32,
    room_min_width: i32,
    room_max_width: i32,
    seed: u64,
    probability: f32,
) void {
    var m = Maze.init(
        gpa,
        total_x,
        total_y,
        room_min_width,
        room_max_width,
        probability,
        seed,
    ) catch unreachable;
    m.genMaze(gpa) catch unreachable;
    m_maze.* = m;
}

const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const anim = @import("animation.zig");
const Select = core.Select;
const Editor = @import("editor.zig").Editor;
const Animation = @import("animation.zig").Animation;
const Menu = @import("menu.zig").Menu;
const Play = @import("play.zig").Play;

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const Context = core.Context;
const R = core.R;
const Action = core.Action;
const RS = core.RS;
const maze = @import("maze");
const Maze = maze.Maze;
