pub const View = struct {
    x: f32,
    y: f32,
    width: f32,

    pub fn dwin_to_dview(self: *const View, screen_w: f32, deta_win_pos: rl.Vector2) rl.Vector2 {
        const r = self.width / screen_w;
        return .{ .x = deta_win_pos.x * r, .y = deta_win_pos.y * r };
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
};

pub const Cell = struct {
    tag: Maze.Tag,
    building_id: ?usize,
};

pub const CurrentMap = [200][200]Cell;

pub const Play = struct {
    rs: RS = .empty,
    current_map: *CurrentMap,
    view: View = undefined,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
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

        {
            const mouse_wheel_deta = rl.getMouseWheelMove();
            const deta = (mouse_wheel_deta * 0.65) * gst.play.view.width * 0.2;
            gst.play.view.x -= deta / 2;
            gst.play.view.y -= (deta * gst.hdw) / 2;
            gst.play.view.width += deta;
        }

        if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
            const deta = gst.play.view.dwin_to_dview(gst.screen_width, rl.getMouseDelta());
            gst.play.view.x -= deta.x;
            gst.play.view.y -= deta.y;
        }

        {
            const view = gst.play.view;
            const height = view.width * gst.hdw;

            const min_x: i32 = @intFromFloat(@floor(view.x));
            const max_x: i32 = @intFromFloat(@floor(view.x + view.width));

            const min_y: i32 = @intFromFloat(@floor(view.y));
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

                    const win_pos = gst.play.view.view_to_win(gst.screen_width, .{
                        .x = @floatFromInt(tx),
                        .y = @floatFromInt(ty),
                    });

                    const scale = 1 * gst.screen_width / gst.play.view.width;
                    rl.drawRectangle(
                        @intFromFloat(win_pos.x),
                        @intFromFloat(win_pos.y),
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
