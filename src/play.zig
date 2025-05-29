pub const View = struct {
    x: f32,
    y: f32,
    width: f32,
};

//        CurrentMap   View     Window
//
// pos       usize     f32        f32

pub const Cell = struct {
    tag: Maze.Tag,
    building_id: ?usize,
};

pub const CurrentMap = [200][200]Cell;

pub const Play = struct {
    rs: RS = .empty,
    current_map: *CurrentMap,
    view: View = undefined,
    building_list: std.ArrayListUnmanaged(Building) = .empty,
    building: bool = false,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }
};

pub const Building = struct {
    width: i32 = 4,
    height: i32 = 3,
};

pub const playST = union(enum) {
    ToEditor: Wit(.{ Example.idle, Example.play }),
    ToMenu: Wit(.{ Example.animation, Example.play, Example.menu }),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToMenu => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
        if (rl.isKeyPressed(rl.KeyboardKey.b)) {
            gst.play.building = !gst.play.building;
        }

        const mouse_wheel_deta = rl.getMouseWheelMove();

        gst.play.view.width += (mouse_wheel_deta * 0.65) * gst.play.view.width * 0.2;

        const scale: f32 = gst.screen_width / (gst.play.view.width * 2);

        if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
            const mouse_deta = rl.getMouseDelta();
            gst.play.view.x -= (gst.play.view.width * (mouse_deta.x / (gst.screen_width / 2)));
            const height = gst.play.view.width * gst.hdw;
            gst.play.view.y -= (height * (mouse_deta.y / (gst.screen_height / 2)));
        }

        {
            const view = gst.play.view;
            const height = view.width * gst.hdw;
            const origin_x: f32 = view.x - view.width;
            const origin_y: f32 = view.y - height;

            const min_x: i32 = @intFromFloat(@floor(view.x - view.width));
            const max_x: i32 = @intFromFloat(@floor(view.x + view.width));

            const min_y: i32 = @intFromFloat(@floor(view.y - height));
            const max_y: i32 = @intFromFloat(@floor(view.y + height));

            var ty = min_y;
            while (ty < max_y + 1) : (ty += 1) {
                var tx = min_x;
                while (tx < max_x + 1) : (tx += 1) {
                    if (tx < 0 or
                        ty < 0 or
                        tx > (gst.map.maze_config.total_x - 1) or
                        ty > (gst.map.maze_config.total_y - 1)) continue;

                    const val = gst.play.current_map[@intCast(ty)][@intCast(tx)];

                    const color = switch (val.tag) {
                        .room => rl.Color.sky_blue,
                        .path => rl.Color.gray,
                        .connPoint => rl.Color.orange,
                        else => rl.Color.white,
                    };

                    const tx1: f32 = scale * (@as(f32, @floatFromInt(tx)) - origin_x);
                    const ty1: f32 = scale * (@as(f32, @floatFromInt(ty)) - origin_y);

                    if (gst.play.building) {
                        rl.drawRectangle(
                            @intFromFloat(tx1),
                            @intFromFloat(ty1),
                            @intFromFloat(scale - 2),
                            @intFromFloat(scale - 2),
                            color,
                        );
                    } else {
                        rl.drawRectangle(
                            @intFromFloat(tx1),
                            @intFromFloat(ty1),
                            @intFromFloat(scale + 1),
                            @intFromFloat(scale + 1),
                            color,
                        );
                    }
                }
            }
        }

        if (gst.play.building) {
            const mp = rl.getMousePosition();
            const b: Building = .{};

            const w: f32 = (@as(f32, @floatFromInt(b.width)) - 0.5) * scale;
            const h: f32 = (@as(f32, @floatFromInt(b.height)) - 0.5) * scale;

            rl.drawRectangle(
                @intFromFloat(mp.x - w / 2),
                @intFromFloat(mp.y - h / 2),
                @intFromFloat(w - 3),
                @intFromFloat(h - 3),
                rl.Color.blue,
            );
        }

        for (gst.play.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        return null;
    }

    fn toEditor(_: *GST) ?@This() {
        return .ToEditor;
    }
    fn toMenu(_: *GST) ?@This() {
        return .ToMenu;
    }

    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor", .val = .{ .Fun = toEditor } },
        .{ .name = "Menu", .val = .{ .Fun = toMenu } },
    };
};

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
