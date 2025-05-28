pub const MazeConfig = struct {
    x: f32 = 0,
    y: f32 = 100,
    width: f32 = 10,
    probability: f32 = 0.2,
};

pub const Play = struct {
    rs: RS = .empty,
    maze: ?Maze = null,
    maze_config: MazeConfig = .{},
    generating: bool = false,

    pub fn animation(self: *const @This(), duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(self.rs.items, duration, total, b);
    }
};

pub const playST = union(enum) {
    // zig fmt: off
        Exit:     Wit(Example.exit),
        ToEditor: Wit(.{ Example.idle, Example.play }),
        ToMenu:   Wit(.{ Example.animation, Example.play, Example.menu }),
        ToPlay:   Wit(.{ Example.animation, Example.play, Example.play }),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .Exit     => |wit| return .{ .Next = wit.conthandler() },
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToMenu   => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
                .ToPlay   => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
            }
        } else return .Wait;
    }
    // zig fmt: on
    fn genMsg(gst: *GST) ?@This() {
        for (gst.play.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;

        if (rl.isKeyPressed(rl.KeyboardKey.g)) {
            _ = gen_maze(gst);
        }

        if (gst.play.maze) |m| {
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
                    const ptr = &gst.play.maze_config;
                    const width: i32 = @intFromFloat(ptr.width);
                    const tx: i32 = @intFromFloat(ptr.x);
                    const ty: i32 = @intFromFloat(ptr.y);
                    const rx = tx + @as(i32, @intCast(x)) * width;
                    const ry = ty + @as(i32, @intCast(y)) * width;
                    rl.drawRectangle(rx, ry, width, width, color);
                }
            }
        }

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
        if (!gst.play.generating) {
            gst.play.generating = !gst.play.generating;
            _ = std.Thread.spawn(
                .{},
                generate_maze,
                .{ gst.gpa, &gst.play.maze, gst.random.int(u64), gst.play.maze_config.probability },
            ) catch unreachable;
            gst.play.generating = !gst.play.generating;
        }
        return null;
    }

    fn mconfig_x(gst: *GST) *f32 {
        return &gst.play.maze_config.x;
    }

    fn mconfig_y(gst: *GST) *f32 {
        return &gst.play.maze_config.y;
    }

    fn mconfig_width(gst: *GST) *f32 {
        return &gst.play.maze_config.width;
    }

    fn mconfig_prob(gst: *GST) *f32 {
        return &gst.play.maze_config.probability;
    }
    // zig fmt: off
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor",   .val = .{ .Fun = toEditor } },
        .{ .name = "Menu",     .val = .{ .Fun = toMenu } },
        .{ .name = "Exit",     .val = .{ .Fun = exit } },
        .{ .name = "Play",     .val = .{ .Fun = toPlay } },
        .{ .name = "Gen maze", .val = .{ .Fun = gen_maze } },
        .{ .name = "rmx", .val = .{ .Ptr_f32 = .{.fun = mconfig_x, .min = 0, .max = 1000}  } },
        .{ .name = "rmy", .val = .{ .Ptr_f32 = .{.fun = mconfig_y, .min = 0, .max = 1000}  } },
        .{ .name = "rmwidth", .val = .{ .Ptr_f32 = .{.fun = mconfig_width, .min = 10, .max = 100}  } },
        .{ .name = "probability", .val = .{ .Ptr_f32 = .{.fun = mconfig_prob, .min = 0.1, .max = 0.9}  } },
    };
    // zig fmt: on
};

fn generate_maze(
    gpa: std.mem.Allocator,
    m_maze: *?Maze,
    seed: u64,
    probability: f32,
) void {
    var m = Maze.init(gpa, 37, 37, 3, 7, probability, seed) catch unreachable;
    m.genMaze(gpa) catch unreachable;
    m_maze.* = m;
}

const std = @import("std");
const typedFsm = @import("typed_fsm");
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
const ContR = typedFsm.ContR(GST);
const Action = core.Action;
const RS = core.RS;
const maze = @import("maze");
const Maze = maze.Maze;
