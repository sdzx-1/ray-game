pub const PlayData = struct {
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

    pub fn render(self: *PlayData) ?Play {
        const gst = self.parentGst();

        draw_cells(&self.view, gst, 0);

        for (self.rs.items) |*r| {
            if (r.render(gst, Play, action_list)) |msg| {
                return msg;
            }
        }
        return null;
    }

    pub fn animation(self: *const PlayData, screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }

    fn parentGst(self: *PlayData) *GST {
        return @alignCast(@fieldParentPtr("play", self));
    }

    pub const action_list: []const (Action(Play)) = &.{
        .{ .name = "Editor", .val = .{ .button = Play.toEditor } },
        .{ .name = "Menu", .val = .{ .button = Play.toMenu } },
        .{ .name = "SetMazeTextId", .val = .{ .button = Play.setMazeTextId } },
        .{
            .name = "Select",
            .val = .{ .dropdown_box = .{ .fun = Play.get_curr_text_ref, .text = "room;blank;path;connPoint" } },
        },
        .{ .name = "Build", .val = .{ .button = Play.toBuild } },
        .{ .name = "Place", .val = .{ .button = Play.toPlace } },
        .{ .name = "Exit", .val = .{ .button = Play.toExit } },
    };
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

pub fn X(back: type, target: type) type {
    return union(enum) {
        XX: Example(.current, Select(back, Select(X(back, target), target))),

        pub fn handler(_: *GST) @This() {
            return .XX;
        }
    };
}

pub const Place = union(enum) {
    to_play: Example(.current, Select(Play, Select(X(Play, Place), Place))),

    pub fn handler(gst: *GST) @This() {
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
        return .to_play;
    }

    pub fn select_render1(gst: *GST, sst: select.SelectStage) bool {
        _ = sst;
        draw_cells(&gst.play.view, gst, -1);
        {
            gst.tbuild.view.mouse_wheel(gst.hdw);
            gst.tbuild.view.drag_view(gst.screen_width);
        }
        for (gst.tbuild.list.items) |*b| {
            const win_pos = gst.tbuild.view.view_to_win(
                gst.screen_width,
                .{ .x = b.x, .y = b.y },
            );
            b.draw(gst);
            rl.drawCircleV(win_pos, 9, rl.Color.green);
        }
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

    pub fn select_render(gst: *GST, sst: select.SelectStage) bool {
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);
        draw_cells(&gst.play.view, gst, -1);

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

pub const Play = union(enum) {
    // zig fmt: off
    to_exit         : Example(.next, ps.Exit),
    to_editor       : Example(.next, Select(Play, Editor(Play))),
    to_menu         : Example(.next, Animation(Play, Menu)),
    to_build        : Example(.next, Select(Play, TBuild)),
    to_place        : Example(.next, Select(Play, Select(X(Play, Place), Place))),
    set_maze_text_id: Example(.next, Select(Play, SetTexture(Play))),
    no_trasition    : Example(.next, @This()),
    // zig fmt: on

    pub const gst_field: std.meta.FieldEnum(GST) = .play;

    pub fn handler(gst: *GST) @This() {
        gst.play.view.mouse_wheel(gst.hdw);
        gst.play.view.drag_view(gst.screen_width);

        if (gst.play.render()) |transition| {
            return transition;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;
        if (rl.isKeyPressed(rl.KeyboardKey.b)) return .to_build;
        if (rl.isKeyPressed(rl.KeyboardKey.f)) return .to_place;
        return .no_trasition;
    }

    pub fn set_text_id(gst: *GST, tid: textures.TextID) void {
        gst.play.maze_texture[@intCast(gst.play.current_texture)] = tid;
    }

    pub fn sed_texture(gst: *const GST) textures.TextID {
        return gst.play.maze_texture[@intCast(gst.play.current_texture)];
    }

    fn toExit(_: *GST) ?@This() {
        return .to_exit;
    }

    fn toEditor(_: *GST) ?@This() {
        return .to_editor;
    }
    fn toMenu(gst: *GST) ?@This() {
        gst.animation.start_time = std.time.milliTimestamp();
        return .to_menu;
    }

    fn toBuild(_: *GST) ?@This() {
        return .to_build;
    }

    fn toPlace(_: *GST) ?@This() {
        return .to_place;
    }

    fn setMazeTextId(_: *GST) ?@This() {
        return .set_maze_text_id;
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
                switch (gst.textures.read(gst.play.maze_texture[@intFromEnum(val.tag)])) {
                    .texture => |texture| {
                        texture.tex2d.drawPro(
                            .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                            .{ .x = win_pos.x, .y = win_pos.y, .width = scale + inc, .height = scale + inc },
                            .{ .x = 0, .y = 0 },
                            0,
                            rl.Color.white,
                        );
                    },
                    else => {},
                }
            } else {
                switch (gst.textures.read(val.building.?.text_id)) {
                    .texture => |texture| {
                        texture.tex2d.drawPro(
                            .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                            .{ .x = win_pos.x, .y = win_pos.y, .width = scale + inc, .height = scale + inc },
                            .{ .x = 0, .y = 0 },
                            0,
                            val.building.?.color,
                        );
                    },
                    else => {},
                }
            }
        }
    }
}

const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const anim = @import("animation.zig");
const select = @import("select.zig");
const tbuild = @import("tbuild.zig");
const textures = @import("textures.zig");
const utils = @import("utils.zig");

const Example = core.Example;
const Menu = @import("menu.zig").Menu;
const Select = core.Select;
const Editor = @import("editor.zig").Editor;
const Animation = @import("animation.zig").Animation;
const Map = @import("map.zig").Map;
const TBuild = @import("tbuild.zig").TBuild;
const SetTexture = @import("textures.zig").SetTexture;

const rl = @import("raylib");
const rg = @import("raygui");
const maze = @import("maze");

const GST = core.GST;
const R = core.R;
const Action = core.Action;
const RS = core.RS;
const Maze = maze.Maze;
const View = utils.View;
