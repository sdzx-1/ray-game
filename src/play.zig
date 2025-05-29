pub const View = struct {
    hdw: f32 = @as(f32, 800) / @as(f32, 1000),
    x: f32 = 18,
    y: f32 = 18,
    width: f32 = 5,
};

pub const Play = struct {
    rs: RS = .empty,
    maze: Maze = undefined,
    view: View = .{},

    pub fn animation(self: *const @This(), duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(self.rs.items, duration, total, b);
    }
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

        const mouse_wheel_deta = rl.getMouseWheelMove();

        gst.play.view.width += mouse_wheel_deta * 0.65;

        const scale: f32 = @as(f32, 1000) / (gst.play.view.width * 2);

        if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
            const mouse_deta = rl.getMouseDelta();
            gst.play.view.x -= (gst.play.view.width * (mouse_deta.x / 500));
            const height = gst.play.view.width * gst.play.view.hdw;
            gst.play.view.y -= (height * (mouse_deta.y / 400));
        }

        {
            const view = gst.play.view;
            const height = view.width * view.hdw;
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
                    if (tx < 0 or ty < 0 or tx > 36 or ty > 36) continue;
                    const idx = Maze.Index.from_uszie_xy(@intCast(tx), @intCast(ty));
                    const val = gst.play.maze.readBoard(idx);
                    const color = switch (val) {
                        .room => rl.Color.sky_blue,
                        .path => rl.Color.gray,
                        .connPoint => rl.Color.orange,
                        else => rl.Color.white,
                    };

                    const tx1: f32 = scale * (@as(f32, @floatFromInt(tx)) - origin_x);
                    const ty1: f32 = scale * (@as(f32, @floatFromInt(ty)) - origin_y);

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
