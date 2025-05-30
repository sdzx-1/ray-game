pub const Play = struct {
    rs: RS = .empty,
    current_map: *CurrentMap,
    view: View = undefined,
    selected_cell_id: CellID = .{},
    selected_build_id: usize = 0,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }
};

pub const CellID = struct {
    x: usize = 0,
    y: usize = 0,
};

pub const Cell = struct {
    tag: Maze.Tag,
    building_id: ?usize,
};

pub const CurrentMap = [200][200]Cell;

pub const Building = struct {
    width: i32,
    height: i32,
};

pub const AllBuilding = [_]Building{
    .{ .width = 2, .height = 3 },
    .{ .width = 2, .height = 2 },
    .{ .width = 3, .height = 3 },
    .{ .width = 4, .height = 3 },
};

pub const selected_buildST = union(enum) {
    ToSelected_cell: Wit(.{
        Example.outside,
        Example.selected_build,
    }),

    pub fn conthandler(gst: *GST) ContR {
        switch (genMsg(gst)) {
            .ToSelected_cell => |wit| return .{ .Next = wit.conthandler() },
        }
    }

    pub fn genMsg(gst: *GST) @This() {
        _ = gst;
        return .ToSelected_cell;
    }

    pub fn render_all(gst: *GST) void {
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);
        gst.play.view.draw_cells(gst);
    }

    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        render_all(gst);
        const vp = gst.play.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const rx: f32 = @floor(vp.x);
        const ry: f32 = @floor(vp.y);
        const x: i32 = @intFromFloat(rx);
        const y: i32 = @intFromFloat(ry);

        if (x < 0 or
            y < 0 or
            x > (gst.map.maze_config.total_x - 1) or
            y > (gst.map.maze_config.total_y - 1)) return .not_in_any_rect;

        gst.play.selected_cell_id = .{ .x = @intCast(x), .y = @intCast(y) };
        return .in_someone;
    }

    pub fn check_still_inside(gst: *GST) bool {
        render_all(gst);
        const vp = gst.play.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const rx: f32 = @floor(vp.x);
        const ry: f32 = @floor(vp.y);
        const x: i32 = @intFromFloat(rx);
        const y: i32 = @intFromFloat(ry);

        return (x == gst.play.selected_cell_id.x and
            y == gst.play.selected_cell_id.y);
    }

    pub fn hover(gst: *GST) void {
        render_all(gst);

        const val = gst.play.current_map[gst.play.selected_cell_id.y][gst.play.selected_cell_id.x];
        var tmpBuf: [100]u8 = undefined;
        const str1 = std.fmt.bufPrintZ(&tmpBuf, "{any}", .{val}) catch unreachable;
        const tsize = rl.measureText(str1, 32);

        const mp = rl.getMousePosition();
        const x = @as(i32, @intFromFloat(mp.x)) - @divTrunc(tsize, 2);
        const y = @as(i32, @intFromFloat(mp.y)) - 50;

        rl.drawText(str1, x, y, 32, rl.Color.black);
    }
};

pub const selected_cellST = union(enum) {
    ToPlay: Wit(Example.play),

    pub fn conthandler(gst: *GST) ContR {
        switch (genMsg(gst)) {
            .ToPlay => |wit| return .{ .Next = wit.conthandler() },
        }
    }

    pub fn genMsg(gst: *GST) @This() {
        _ = gst;
        return .ToPlay;
    }

    pub fn render_all(gst: *GST) void {
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);
        gst.play.view.draw_cells(gst);
    }

    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        render_all(gst);
        const vp = gst.play.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const rx: f32 = @floor(vp.x);
        const ry: f32 = @floor(vp.y);
        const x: i32 = @intFromFloat(rx);
        const y: i32 = @intFromFloat(ry);

        if (x < 0 or
            y < 0 or
            x > (gst.map.maze_config.total_x - 1) or
            y > (gst.map.maze_config.total_y - 1)) return .not_in_any_rect;

        gst.play.selected_cell_id = .{ .x = @intCast(x), .y = @intCast(y) };
        return .in_someone;
    }

    pub fn check_still_inside(gst: *GST) bool {
        render_all(gst);
        const vp = gst.play.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const rx: f32 = @floor(vp.x);
        const ry: f32 = @floor(vp.y);
        const x: i32 = @intFromFloat(rx);
        const y: i32 = @intFromFloat(ry);

        return (x == gst.play.selected_cell_id.x and
            y == gst.play.selected_cell_id.y);
    }

    pub fn hover(gst: *GST) void {
        render_all(gst);

        const val = gst.play.current_map[gst.play.selected_cell_id.y][gst.play.selected_cell_id.x];
        var tmpBuf: [100]u8 = undefined;
        const str1 = std.fmt.bufPrintZ(&tmpBuf, "{any}", .{val}) catch unreachable;
        const tsize = rl.measureText(str1, 32);

        const mp = rl.getMousePosition();
        const x = @as(i32, @intFromFloat(mp.x)) - @divTrunc(tsize, 2);
        const y = @as(i32, @intFromFloat(mp.y)) - 50;

        rl.drawText(str1, x, y, 32, rl.Color.black);
    }
};

pub const playST = union(enum) {
    ToEditor: Wit(.{ Example.select, Example.play, .{ Example.selected_button, Example.play } }),
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
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);
        gst.play.view.draw_cells(gst);
        for (gst.play.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        return null;
    }

    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor", .val = .{ .Fun = toEditor } },
        .{ .name = "Menu", .val = .{ .Fun = toMenu } },
    };

    fn toEditor(_: *GST) ?@This() {
        return .ToEditor;
    }
    fn toMenu(_: *GST) ?@This() {
        return .ToMenu;
    }
};

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

    pub fn mouse_wheel(self: *View, hdw: f32) void {
        const mouse_wheel_deta = rl.getMouseWheelMove();
        const deta = (mouse_wheel_deta * 0.65) * self.width * 0.2;
        self.x -= deta / 2;
        self.y -= (deta * hdw) / 2;
        self.width += deta;
    }

    pub fn drag_view(self: *View, screen_width: f32) void {
        if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
            const deta = self.dwin_to_dview(screen_width, rl.getMouseDelta());
            self.x -= deta.x;
            self.y -= deta.y;
        }
    }

    pub fn draw_cells(view: *const View, gst: *GST) void {
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

                const win_pos = view.view_to_win(gst.screen_width, .{
                    .x = @floatFromInt(tx),
                    .y = @floatFromInt(ty),
                });

                const scale = 1 * gst.screen_width / view.width;
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
};

const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
const anim = @import("animation.zig");
const select = @import("select.zig");

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
