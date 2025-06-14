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

pub const Map = struct {
    rs: RS = .empty,
    maze: ?Maze = null,
    maze_config: MazeConfig = .{},
    generating: bool = false,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }
};

pub const mapST = union(enum) {
    // zig fmt: off
    Exit    : Wit(Example.exit),
    ToEditor: Wit(.{ Example.select, Example.map ,.{Example.edit, Example.map} }),
    ToMenu  : Wit(.{ Example.animation, Example.map, Example.menu }),
    ToPlay  : Wit(Example.play ),
    // zig fmt: on

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .Exit => |wit| return .{ .Next = wit.conthandler() },
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToMenu => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
                .ToPlay => |wit| {
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
                    return .{ .Next = wit.conthandler() };
                },
            }
        } else return .Wait;
    }
    fn genMsg(gst: *GST) ?@This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;

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

        for (gst.map.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        return null;
    }

    fn toEditor(_: *GST) ?@This() {
        return .ToEditor;
    }

    fn toMenu(_: *GST) ?@This() {
        return .ToMenu;
    }

    fn toPlay(_: *GST) ?@This() {
        return .ToPlay;
    }

    fn exit(_: *GST) ?@This() {
        return .Exit;
    }

    fn gen_maze(gst: *GST) ?@This() {
        if (!gst.map.generating) {
            gst.map.generating = !gst.map.generating;
            if (gst.map.maze) |*m| {
                gst.map.maze = null;
                m.deinit(gst.gpa);
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
        .{ .name = "Editor",   .val = .{ .Button = toEditor } },
        .{ .name = "Menu",     .val = .{ .Button = toMenu } },
        .{ .name = "Exit",     .val = .{ .Button = exit } },
        .{ .name = "Gen maze", .val = .{ .Button = gen_maze } },
        .{ .name = "rmx",      .val = .{ .Slider = .{.fun = mconfig_x, .min = 0, .max = 1000}  } },
        .{ .name = "rmy",      .val = .{ .Slider = .{.fun = mconfig_y, .min = 0, .max = 1000}  } },
        .{ .name = "rmwidth",     .val = .{ .Slider = .{.fun = mconfig_width, .min = 2, .max = 100}  } },
        .{ .name = "probability", .val = .{ .Slider = .{.fun = mconfig_prob, .min = 0, .max = 0.4}  } },
        .{ .name = "Play", .val = .{ .Button = toPlay } },
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
const polystate = @import("polystate");
const core = @import("core.zig");
const anim = @import("animation.zig");

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const Wit = Example.Wit;
const WitRow = Example.WitRow;
const SDZX = Example.SDZX;
const GST = core.GST;
const R = core.R;
const getTarget = core.getTarget;
const ContR = polystate.ContR(GST);
const Action = core.Action;
const RS = core.RS;
const maze = @import("maze");
const Maze = maze.Maze;
