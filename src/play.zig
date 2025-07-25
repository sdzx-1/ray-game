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

pub fn X(back: type, target: type) type {
    return union(enum) {
        XX: Example(.current, Select(back, Select(X(back, target), target))),

        pub fn handler(_: *Context) @This() {
            return .XX;
        }
    };
}

pub const Place = union(enum) {
    to_play: Example(.current, Select(Play, Select(X(Play, Place), Place))),

    pub fn handler(ctx: *Context) @This() {
        const b = ctx.play.selected_build;
        const cell_id = ctx.play.selected_cell_id;
        const y: i32 = @intCast(cell_id.y);
        const x: i32 = @intCast(cell_id.x);
        const w: i32 = @intFromFloat(b.width);
        const h: i32 = @intFromFloat(b.height);
        var ty = y;
        while (ty < y + h) : (ty += 1) {
            var tx = x;
            while (tx < x + w) : (tx += 1) {
                const cell = &ctx.play.current_map[@intCast(ty)][@intCast(tx)];
                cell.building = b;
            }
        }
        return .to_play;
    }

    pub fn select_render1(ctx: *Context, sst: select.SelectStage) bool {
        _ = sst;
        draw_cells(&ctx.play.view, ctx, -1);
        {
            ctx.tbuild.view.mouse_wheel(ctx.hdw);
            ctx.tbuild.view.drag_view(ctx.screen_width);
        }
        for (ctx.tbuild.list.items) |*b| {
            const win_pos = ctx.tbuild.view.view_to_win(
                ctx.screen_width,
                .{ .x = b.x, .y = b.y },
            );
            b.draw(ctx);
            rl.drawCircleV(win_pos, 9, rl.Color.green);
        }
        return false;
    }

    pub fn check_inside1(ctx: *Context) select.CheckInsideResult {
        for (ctx.tbuild.list.items) |*b| {
            if (b.inBuilding(ctx, rl.getMousePosition())) {
                ctx.play.selected_build = b.*;
                return .in_someone;
            }
        }
        return .not_in_any_rect;
    }

    pub fn check_still_inside1(ctx: *Context) bool {
        const b = &ctx.play.selected_build;
        return b.inBuilding(ctx, rl.getMousePosition());
    }

    //select position

    pub fn select_render(ctx: *Context, sst: select.SelectStage) bool {
        ctx.play.view.mouse_wheel(ctx.hdw);
        ctx.play.view.drag_view(ctx.screen_width);
        draw_cells(&ctx.play.view, ctx, -1);

        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            ctx.play.selected_build.rotate();
            return true;
        }

        switch (sst) {
            .hover => {
                const b = &ctx.play.selected_build;
                b.draw_with_win_pos_and_view(
                    ctx,
                    rl.getMousePosition(),
                    &ctx.play.view,
                    rl.Color.green,
                );
            },
            .inside => {
                const b = &ctx.play.selected_build;
                b.draw_with_win_pos_and_view(
                    ctx,
                    rl.getMousePosition(),
                    &ctx.play.view,
                    rl.Color.green,
                );
            },
            else => {},
        }

        return false;
    }

    pub fn check_inside(ctx: *Context) select.CheckInsideResult {
        const b = &ctx.play.selected_build;
        const vp = ctx.play.view.win_to_view(ctx.screen_width, rl.getMousePosition());
        const x: i32 = @intFromFloat(@floor(vp.x - b.width / 2));
        const y: i32 = @intFromFloat(@floor(vp.y - b.height / 2));
        const w: i32 = @intFromFloat(b.width);
        const h: i32 = @intFromFloat(b.height);

        if (x < 0 or
            y < 0 or
            x + w > ctx.map.maze_config.total_x or
            y + h > ctx.map.maze_config.total_y) return .not_in_any_rect;

        var ty = y;
        while (ty < y + h) : (ty += 1) {
            var tx = x;
            while (tx < x + w) : (tx += 1) {
                const cell = ctx.play.current_map[@intCast(ty)][@intCast(tx)];
                if (cell.tag != .room or cell.building != null) {
                    b.draw_with_win_pos_and_view(ctx, rl.getMousePosition(), &ctx.play.view, rl.Color.red);
                    return .not_in_any_rect;
                }
            }
        }

        b.draw_with_win_pos_and_view(ctx, rl.getMousePosition(), &ctx.play.view, rl.Color.green);
        ctx.play.selected_cell_id = .{ .x = @intCast(x), .y = @intCast(y) };
        return .in_someone;
    }

    pub fn check_still_inside(ctx: *Context) bool {
        const b = &ctx.play.selected_build;
        const vp = ctx.play.view.win_to_view(ctx.screen_width, rl.getMousePosition());
        const x: i32 = @intFromFloat(@floor(vp.x - b.width / 2));
        const y: i32 = @intFromFloat(@floor(vp.y - b.height / 2));
        return (x == ctx.play.selected_cell_id.x and
            y == ctx.play.selected_cell_id.y);
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

    pub fn handler(ctx: *Context) @This() {
        ctx.play.view.mouse_wheel(ctx.hdw);
        ctx.play.view.drag_view(ctx.screen_width);
        draw_cells(&ctx.play.view, ctx, 0);
        for (ctx.play.rs.items) |*r| if (r.render(ctx, @This(), action_list)) |msg| return msg;

        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;
        if (rl.isKeyPressed(rl.KeyboardKey.b)) return .to_build;
        if (rl.isKeyPressed(rl.KeyboardKey.f)) return .to_place;
        return .no_trasition;
    }

    pub fn set_text_id(ctx: *Context, tid: textures.TextID) void {
        ctx.play.maze_texture[@intCast(ctx.play.current_texture)] = tid;
    }

    pub fn sed_texture(ctx: *const Context) textures.TextID {
        return ctx.play.maze_texture[@intCast(ctx.play.current_texture)];
    }

    //
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor", .val = .{ .button = toEditor } },
        .{ .name = "Menu", .val = .{ .button = toMenu } },
        .{ .name = "SetMazeTextId", .val = .{ .button = setMazeTextId } },
        .{
            .name = "Select",
            .val = .{ .dropdown_box = .{ .fun = get_curr_text_ref, .text = "room;blank;path;connPoint" } },
        },
        .{ .name = "Build", .val = .{ .button = toBuild } },
        .{ .name = "Place", .val = .{ .button = toPlace } },
        .{ .name = "Exit", .val = .{ .button = toExit } },
    };

    fn toExit(_: *Context) ?@This() {
        return .to_exit;
    }

    fn toEditor(_: *Context) ?@This() {
        return .to_editor;
    }
    fn toMenu(ctx: *Context) ?@This() {
        ctx.animation.start_time = std.time.milliTimestamp();
        return .to_menu;
    }

    fn toBuild(_: *Context) ?@This() {
        return .to_build;
    }

    fn toPlace(_: *Context) ?@This() {
        return .to_place;
    }

    fn setMazeTextId(_: *Context) ?@This() {
        return .set_maze_text_id;
    }

    fn get_curr_text_ref(ctx: *Context) *i32 {
        return &ctx.play.current_texture;
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
            ctx.play.rs.items,
            duration,
            total,
            b,
        );
    }

    pub fn access_rs(ctx: *Context) *RS {
        return &ctx.play.rs;
    }
};

pub fn draw_cells(view: *const View, ctx: *Context, inc: f32) void {
    const height = view.width * ctx.hdw;

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
                tx > (ctx.map.maze_config.total_x - 1) or
                ty > (ctx.map.maze_config.total_y - 1)) continue;

            const val = ctx.play.current_map[@intCast(ty)][@intCast(tx)];
            const win_pos = view.view_to_win(ctx.screen_width, .{ .x = @floatFromInt(tx), .y = @floatFromInt(ty) });
            const scale = 1 * ctx.screen_width / view.width;

            if (val.building == null) {
                switch (ctx.textures.read(ctx.play.maze_texture[@intFromEnum(val.tag)])) {
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
                switch (ctx.textures.read(val.building.?.text_id)) {
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

const Context = core.Context;
const R = core.R;
const Action = core.Action;
const RS = core.RS;
const Maze = maze.Maze;
const View = utils.View;
