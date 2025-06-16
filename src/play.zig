pub const Play = struct {
    rs: RS = .empty,
    current_map: *CurrentMap,
    view: View = undefined,
    selected_cell_id: CellID = .{},
    selected_build: tbuild.Building = undefined,

    current_texture: i32 = 0,
    maze_texture: [4]textures.TextID = .{
        .{ .x = 2, .y = 31 },
        .{ .x = 6, .y = 67 },
        .{ .x = 5, .y = 31 },
        .{ .x = 7, .y = 31 },
    },

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
    building: ?tbuild.Building,
};

pub const CurrentMap = [200][200]Cell;

pub const placeST = union(enum) {
    ToPlay: Wit(Example.play),

    pub fn conthandler(gst: *GST) ContR {
        switch (genMsg(gst)) {
            .ToPlay => |wit| {
                const b = gst.play.selected_build;
                const cell_id = gst.play.selected_cell_id;
                const y: i32 = @intCast(cell_id.y);
                const x: i32 = @intCast(cell_id.x);
                const w: i32 = @intFromFloat(b.width);
                const h: i32 = @intFromFloat(b.height);
                var ty = y;
                while (ty < y + h) : (ty += 1) {
                    var tx = x;
                    while (tx < x + w) : (tx += 1) {
                        const cell = &gst.play.current_map[@intCast(ty)][@intCast(tx)];
                        cell.building = b;
                    }
                }
                return .{ .Curr = wit.conthandler() };
            },
        }
    }

    pub fn genMsg(gst: *GST) @This() {
        _ = gst;
        return .ToPlay;
    }

    pub fn select_render1(gst: *GST, sst: select.SelectState) bool {
        _ = sst;
        {
            gst.tbuild.view.mouse_wheel(gst.hdw);
            gst.tbuild.view.drag_view(gst.screen_width);
        }
        for (gst.tbuild.list.items) |*b| b.draw(gst);
        return false;
    }

    pub fn check_inside1(gst: *GST) select.CheckInsideResult {
        for (gst.tbuild.list.items) |*b| {
            if (b.inBuilding(gst, rl.getMousePosition())) {
                gst.play.selected_build = b.*;
                return .in_someone;
            }
        }
        return .not_in_any_rect;
    }

    pub fn check_still_inside1(gst: *GST) bool {
        const b = &gst.play.selected_build;
        return b.inBuilding(gst, rl.getMousePosition());
    }

    //select position

    pub fn select_render(gst: *GST, sst: select.SelectState) bool {
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);
        draw_cells(&gst.play.view, gst, -2);
        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            gst.play.selected_build.rotate();
            return true;
        }

        switch (sst) {
            .hover => {
                const b = &gst.play.selected_build;
                b.draw_with_win_pos_and_view(
                    gst,
                    rl.getMousePosition(),
                    &gst.play.view,
                    rl.Color.green,
                );
            },
            .inside => {
                const b = &gst.play.selected_build;
                b.draw_with_win_pos_and_view(
                    gst,
                    rl.getMousePosition(),
                    &gst.play.view,
                    rl.Color.green,
                );
            },
            else => {},
        }
        return false;
    }

    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        const b = &gst.play.selected_build;
        const vp = gst.play.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const x: i32 = @intFromFloat(@floor(vp.x - b.width / 2));
        const y: i32 = @intFromFloat(@floor(vp.y - b.height / 2));
        const w: i32 = @intFromFloat(b.width);
        const h: i32 = @intFromFloat(b.height);

        if (x < 0 or
            y < 0 or
            x + w > gst.map.maze_config.total_x or
            y + h > gst.map.maze_config.total_y) return .not_in_any_rect;

        var ty = y;
        while (ty < y + h) : (ty += 1) {
            var tx = x;
            while (tx < x + w) : (tx += 1) {
                const cell = gst.play.current_map[@intCast(ty)][@intCast(tx)];
                if (cell.tag != .room or cell.building != null) {
                    b.draw_with_win_pos_and_view(gst, rl.getMousePosition(), &gst.play.view, rl.Color.red);
                    return .not_in_any_rect;
                }
            }
        }

        b.draw_with_win_pos_and_view(gst, rl.getMousePosition(), &gst.play.view, rl.Color.green);
        gst.play.selected_cell_id = .{ .x = @intCast(x), .y = @intCast(y) };
        return .in_someone;
    }

    pub fn check_still_inside(gst: *GST) bool {
        const b = &gst.play.selected_build;
        const vp = gst.play.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const x: i32 = @intFromFloat(@floor(vp.x - b.width / 2));
        const y: i32 = @intFromFloat(@floor(vp.y - b.height / 2));
        return (x == gst.play.selected_cell_id.x and
            y == gst.play.selected_cell_id.y);
    }
};

pub const playST = union(enum) {
    // zig fmt: off
    ToEditor     : Wit(.{ Example.select, Example.play, .{ Example.edit, Example.play } }),
    ToMenu       : Wit(.{ Example.animation, Example.play, Example.menu }),
    ToBuild      : Wit(.{ Example.select, Example.play, Example.build }),
    ToPlace      : Wit(.{ Example.select, Example.play, .{ Example.select, Example.play, Example.place } }),
    SetMazeTextId: Wit(.{ Example.select, Example.play, .{ Example.sel_texture, Example.play } }),
    // zig fmt: on

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToMenu => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
                .ToBuild => |wit| return .{ .Next = wit.conthandler() },
                .ToPlace => |wit| return .{ .Next = wit.conthandler() },
                .SetMazeTextId => |wit| {
                    return .{ .Next = wit.conthandler() };
                },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);
        draw_cells(&gst.play.view, gst, 0);
        for (gst.play.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;

        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
        if (rl.isKeyPressed(rl.KeyboardKey.b)) return .ToBuild;
        if (rl.isKeyPressed(rl.KeyboardKey.f)) return .ToPlace;
        return null;
    }

    pub fn set_text_id(gst: *GST, tid: textures.TextID) void {
        gst.play.maze_texture[@intCast(gst.play.current_texture)] = tid;
    }

    pub fn sed_texture(gst: *const GST) textures.TextID {
        return gst.play.maze_texture[@intCast(gst.play.current_texture)];
    }

    //
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor", .val = .{ .Button = toEditor } },
        .{ .name = "Menu", .val = .{ .Button = toMenu } },
        .{ .name = "SetMazeTextId", .val = .{ .Button = setMazeTextId } },
        .{
            .name = "Select",
            .val = .{ .DropdownBox = .{ .fun = get_curr_text_ref, .text = "room;blank;path;connPoint" } },
        },
    };

    fn toEditor(_: *GST) ?@This() {
        return .ToEditor;
    }
    fn toMenu(_: *GST) ?@This() {
        return .ToMenu;
    }

    fn setMazeTextId(_: *GST) ?@This() {
        return .SetMazeTextId;
    }

    fn get_curr_text_ref(gst: *GST) *i32 {
        return &gst.play.current_texture;
    }
};

pub fn draw_cells(view: *const View, gst: *GST, inc: f32) void {
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
            const win_pos = view.view_to_win(gst.screen_width, .{ .x = @floatFromInt(tx), .y = @floatFromInt(ty) });
            const scale = 1 * gst.screen_width / view.width;

            if (val.building == null) {
                const texture = gst.textures.read(gst.play.maze_texture[@intFromEnum(val.tag)]).texture.tex2d;
                texture.drawPro(
                    .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                    .{ .x = win_pos.x, .y = win_pos.y, .width = scale + inc, .height = scale + inc },
                    .{ .x = 0, .y = 0 },
                    0,
                    rl.Color.white,
                );
            } else {
                const texture = gst.textures.read(val.building.?.text_id).texture.tex2d;
                texture.drawPro(
                    .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                    .{ .x = win_pos.x, .y = win_pos.y, .width = scale + inc, .height = scale + inc },
                    .{ .x = 0, .y = 0 },
                    0,
                    val.building.?.color,
                );
            }
        }
    }
}

const std = @import("std");
const polystate = @import("polystate");
const core = @import("core.zig");
const anim = @import("animation.zig");
const select = @import("select.zig");
const tbuild = @import("tbuild.zig");
const textures = @import("textures.zig");
const utils = @import("utils.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const maze = @import("maze");

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
const Maze = maze.Maze;
const View = utils.View;
