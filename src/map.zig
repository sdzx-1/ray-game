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

    pub fn handler(gst: *GST) @This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;

        if (rl.isKeyPressed(rl.KeyboardKey.g)) {
            _ = gen_maze(gst);
        }

        if (gst.map.maze) |m| {
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
                    const ptr = &gst.map.maze_config;
                    const width: i32 = @intFromFloat(ptr.width);
                    const tx: i32 = @intFromFloat(ptr.x);
                    const ty: i32 = @intFromFloat(ptr.y);
                    const rx = tx + @as(i32, @intCast(x)) * width;
                    const ry = ty + @as(i32, @intCast(y)) * width;
                    rl.drawRectangle(rx, ry, width, width, color);
                }
            }
        }

        for (gst.map.rs.items) |*r| {
            if (r.render(gst, @This(), action_list)) |msg| {
                return msg;
            }
        }
        return .no_trasition;
    }

    fn toEditor(_: *GST) ?@This() {
        return .to_editor;
    }

    fn toMenu(gst: *GST) ?@This() {
        gst.animation.start_time = std.time.milliTimestamp();
        return .to_menu;
    }

    fn toPlay(gst: *GST) ?@This() {
        gst.animation.start_time = std.time.milliTimestamp();
        if (gst.map.maze == null) {
            generate_maze(
                gst.gpa,
                &gst.map.maze,
                gst.map.maze_config.total_x,
                gst.map.maze_config.total_y,
                gst.map.maze_config.room_min_width,
                gst.map.maze_config.room_max_width,
                gst.random.int(u64),
                gst.map.maze_config.probability,
            );
        }
        const m = gst.map.maze.?;

        for (0..m.totalYSize) |y| {
            for (0..m.totalXSize) |x| {
                const idx = Maze.Index.from_uszie_xy(x, y);
                const val = m.readBoard(idx);
                gst.play.current_map[y][x] = .{ .tag = val, .building = null };
            }
        }

        const sx = @as(f32, @floatFromInt(gst.map.maze_config.total_x));
        const sy = @as(f32, @floatFromInt(gst.map.maze_config.total_y));
        gst.play.view.width = 50;
        gst.play.view.center(gst.hdw, sx / 2, sy / 2);
        return .to_play;
    }

    fn exit(_: *GST) ?@This() {
        return .exit1;
    }

    fn gen_maze(gst: *GST) ?@This() {
        if (!gst.map.generating) {
            gst.map.generating = !gst.map.generating;
            if (gst.map.maze) |*m| {
                m.deinit(gst.gpa);
                gst.map.maze = null;
            }
            _ = std.Thread.spawn(
                .{},
                generate_maze,
                .{
                    gst.gpa,
                    &gst.map.maze,
                    gst.map.maze_config.total_x,
                    gst.map.maze_config.total_y,
                    gst.map.maze_config.room_min_width,
                    gst.map.maze_config.room_max_width,
                    gst.random.int(u64),
                    gst.map.maze_config.probability,
                },
            ) catch unreachable;
            gst.map.generating = !gst.map.generating;
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

    fn mconfig_x(gst: *GST) *f32 {
        return &gst.map.maze_config.x;
    }

    fn mconfig_y(gst: *GST) *f32 {
        return &gst.map.maze_config.y;
    }

    fn mconfig_width(gst: *GST) *f32 {
        return &gst.map.maze_config.width;
    }

    fn mconfig_prob(gst: *GST) *f32 {
        return &gst.map.maze_config.probability;
    }

    pub fn animation(
        gst: *GST,
        screen_width: f32,
        screen_height: f32,
        duration: f32,
        total: f32,
        b: bool,
    ) void {
        anim.animation_list_r(
            screen_width,
            screen_height,
            gst.map.rs.items,
            duration,
            total,
            b,
        );
    }

    pub fn access_rs(gst: *GST) *RS {
        return &gst.map.rs;
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
const GST = core.GST;
const R = core.R;
const Action = core.Action;
const RS = core.RS;
const maze = @import("maze");
const Maze = maze.Maze;
