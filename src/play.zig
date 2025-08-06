pub const PlayData = struct {
    rs: StateComponents(Play) = .empty,
    current_map: *CurrentMap,
    vw: ViewWin = .{},
    build_vw: ViewWin = .{},
    selected_cell_id: CellID = .{},
    selected_color: rl.Color = undefined,
    selected_build: Building = undefined,
    current_texture: i32 = 0,
    maze_texture: [4]textures.TextID = .{
        .{ .x = 19, .y = 18 },
        .{ .x = 18, .y = 27 },
        .{ .x = 28, .y = 22 },
        .{ .x = 27, .y = 22 },
    },

    pub fn render_current_map(self: *const @This(), ctx: *Context, enable_grid: bool) void {
        if (self.vw.viewport_intersect_rect(.{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(ctx.map.maze_config.total_x)),
            .height = @as(f32, @floatFromInt(ctx.map.maze_config.total_y)),
        })) |rect| {
            const start_x: usize = @intFromFloat(@floor(rect.x));
            const start_y: usize = @intFromFloat(@floor(rect.y));
            const end_x: usize = @intFromFloat(@floor(rect.x + rect.width - 0.01));
            const end_y: usize = @intFromFloat(@floor(rect.y + rect.height - 0.01));

            self.vw.winport_beginScissorMode();
            defer rl.endScissorMode();

            for (start_y..end_y + 1) |y| {
                for (start_x..end_x + 1) |x| {
                    const val = self.current_map[y][x];
                    const win_pos = self.vw.viewpos_to_winpos(.{ .x = @floatFromInt(x), .y = @floatFromInt(y) });
                    const dw = self.vw.wv_ratio();

                    ctx.textures.render_texture(
                        ctx.play.maze_texture[@intFromEnum(val.tag)],
                        .{ .x = win_pos.x, .y = win_pos.y, .width = dw, .height = dw },
                        rl.Color.white,
                    );

                    if (val.building) |build| {
                        ctx.textures.render_texture(
                            build.text_id,
                            .{ .x = win_pos.x, .y = win_pos.y, .width = dw, .height = dw },
                            build.color,
                        );
                    }
                }
            }

            if (enable_grid) {
                for (start_x..end_x + 1) |x| {
                    const start_pos = self.vw.viewpos_to_winpos(.{ .x = @floatFromInt(x), .y = rect.y });
                    const end_pos = self.vw.viewpos_to_winpos(.{ .x = @floatFromInt(x), .y = rect.y + rect.height });
                    rl.drawLineEx(start_pos.toVector2(), end_pos.toVector2(), 2, rl.Color.black);
                }

                for (start_y..end_y + 1) |y| {
                    const start_pos = self.vw.viewpos_to_winpos(.{ .x = rect.x, .y = @floatFromInt(y) });
                    const end_pos = self.vw.viewpos_to_winpos(.{ .x = rect.x + rect.width, .y = @floatFromInt(y) });
                    rl.drawLineEx(start_pos.toVector2(), end_pos.toVector2(), 2, rl.Color.black);
                }
            }
        }
    }
};

pub const CellID = struct {
    x: usize = 0,
    y: usize = 0,
};

pub const Cell = struct {
    tag: Maze.Tag,
    building: ?tbuild.TbuildData.Building,
};

pub const CurrentMap = [200][200]Cell;

const TwoStageSelect = Select(Play, SelectBuildInstance(Place, Tmp(Place, Select(BackUpLevel, SelectCellInstance(Place, Place)))));

pub const BackUpLevel = union(enum) {
    back_up_level: Example(.current, TwoStageSelect),

    pub fn handler(_: *Context) @This() {
        return .back_up_level;
    }
};

pub const Play = union(enum) {
    // zig fmt: off
    to_exit         : Example(.next, ps.Exit),
    to_editor       : Example(.next, Select(Play, Editor(Play))),
    to_menu         : Example(.next, Menu),
    to_build        : Example(.next, Select(Play, TBuild)),
    to_place        : Example(.next, TwoStageSelect),
    set_maze_text_id: Example(.next, SetTexture(Play, Play)),
    to_delete       : Example(.next, Select(Play, SelectCellInstance(Delete, Delete))),
    no_trasition    : Example(.next, @This()),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        ctx.play.vw.mouse_drag_viewport();
        ctx.play.vw.mouse_wheel_zoom_viewport();

        if (ctx.play.rs.pull()) |msg| return msg;
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;
        if (rl.isKeyPressed(rl.KeyboardKey.b)) return .to_build;
        if (rl.isKeyPressed(rl.KeyboardKey.f)) return .to_place;
        if (rl.isKeyPressed(rl.KeyboardKey.d)) return .to_delete;
        return .no_trasition;
    }

    pub fn render(ctx: *Context) void {
        ctx.play.render_current_map(ctx, false);
        ctx.play.rs.render(ctx);
    }

    pub fn set_text_id(ctx: *Context, tid: textures.TextID) void {
        ctx.play.maze_texture[@intCast(ctx.play.current_texture)] = tid;
    }

    pub fn get_text_id(ctx: *const Context) textures.TextID {
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
        .{ .name = "Delete", .val = .{ .button = toDelete } },
    };

    fn toDelete(_: *Context) ?@This() {
        return .to_delete;
    }

    fn toExit(_: *Context) ?@This() {
        return .to_exit;
    }

    fn toEditor(_: *Context) ?@This() {
        return .to_editor;
    }
    fn toMenu(_: *Context) ?@This() {
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

    pub fn access_rs(ctx: *Context) *StateComponents(Play) {
        return &ctx.play.rs;
    }
};

pub const Place = union(enum) {
    to_play: Example(.current, TwoStageSelect),

    pub fn handler(ctx: *Context) @This() {
        const cell_id = ctx.play.selected_cell_id;
        const x = cell_id.x;
        const y = cell_id.y;

        const b = ctx.play.selected_build;
        for (y..y + b.height) |iy| {
            for (x..x + b.width) |ix| {
                ctx.play.current_map[iy][ix].building = b;
            }
        }
        return .to_play;
    }

    pub fn access_vw(ctx: *Context) *ViewWin {
        return &ctx.play.build_vw;
    }

    pub fn tmp_fun(ctx: *Context) bool {
        const vp = ctx.play.build_vw.viewpos_from_vector2(rl.getMousePosition());

        if (ctx.play.build_vw.inViewport(vp)) {
            return false;
        }
        return true;
    }

    pub fn tmp_render(ctx: *Context) void {
        ctx.play.render_current_map(ctx, true);
        ctx.tbuild.render(ctx, &ctx.play.build_vw);

        const vp = ctx.play.vw.viewpos_from_vector2(rl.getMousePosition());
        ctx.play.selected_build.x = vp.x;
        ctx.play.selected_build.y = vp.y;
        ctx.play.selected_build.render(ctx, &ctx.play.vw);
    }

    pub fn select_build_backend_render(ctx: *Context, _: select.SelectStage) void {
        ctx.play.render_current_map(ctx, true);
    }

    pub fn select_build_fun(ctx: *Context, _: select.SelectStage) bool {
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            ctx.play.build_vw.drag_winport(rl.getMouseDelta());
        }

        return false;
    }

    pub fn select_build_inside_fun(ctx: *Context) void {
        ctx.play.selected_build = ctx.tbuild.list.items[ctx.tbuild.selected_id];
    }
    pub fn select_cell_is_back(ctx: *Context) bool {
        const vp = ctx.play.build_vw.viewpos_from_vector2(rl.getMousePosition());

        if (ctx.play.build_vw.inViewport(vp)) {
            return true;
        } else {
            return false;
        }
    }

    pub fn select_cell_check_inside(ctx: *Context, cid: CellID) bool {
        const b = ctx.play.selected_build;

        const vp = ctx.play.build_vw.viewpos_from_vector2(rl.getMousePosition());

        if (ctx.play.build_vw.inViewport(vp)) {
            return false;
        }

        for (0..b.height) |dy| {
            for (0..b.width) |dx| {
                const cell = ctx.play.current_map[cid.y + dy][cid.x + dx];

                if (cell.tag != .room or cell.building != null) {
                    ctx.play.selected_color = rl.Color.red;
                    return false;
                }
            }
        }

        ctx.play.selected_color = rl.Color.green;
        return true;
    }

    pub fn select_cell_render(ctx: *Context, sst: select.SelectStage) void {
        _ = sst;

        ctx.tbuild.render(ctx, &ctx.play.build_vw);

        const vp = ctx.play.vw.viewpos_from_vector2(rl.getMousePosition());
        const b = ctx.play.selected_build;

        const wpos = ctx.play.vw.viewpos_to_winpos(.{ .x = @floor(vp.x), .y = @floor(vp.y) });
        const dwpos = ctx.play.vw.dviewpos_to_dwinpos(.{ .x = @floatFromInt(b.width), .y = @floatFromInt(b.height) });

        rl.drawRectangleLinesEx(.{
            .x = wpos.x,
            .y = wpos.y,
            .width = dwpos.x,
            .height = dwpos.y,
        }, 8, ctx.play.selected_color);
    }

    pub fn select_cell_fun(ctx: *Context, sst: select.SelectStage) bool {
        _ = sst;
        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            ctx.play.selected_build.rotate();
            return true;
        }
        return false;
    }
};

pub const Delete = union(enum) {
    to_delete: Example(.current, Select(Play, SelectCellInstance(Delete, Delete))),

    pub fn handler(ctx: *Context) @This() {
        const id = ctx.play.selected_cell_id;
        ctx.play.current_map[id.y][id.x].building = null;
        return .to_delete;
    }

    pub fn select_cell_check_inside(ctx: *Context, cid: CellID) bool {
        const cell = ctx.play.current_map[@intCast(cid.y)][@intCast(cid.x)];
        return (cell.building != null);
    }

    pub fn select_cell_render(ctx: *Context, sst: select.SelectStage) void {
        switch (sst) {
            .outside => {},
            else => {
                const cid = ctx.play.selected_cell_id;
                const x: f32 = @floatFromInt(cid.x);
                const y: f32 = @floatFromInt(cid.y);
                const wpos = ctx.play.vw.viewpos_to_winpos(.{ .x = x, .y = y });
                const dw = ctx.play.vw.wv_ratio();
                rl.drawRectangleLinesEx(.{
                    .x = wpos.x,
                    .y = wpos.y,
                    .width = dw,
                    .height = dw,
                }, 2, rl.Color.red);
            },
        }
    }
};

pub fn SelectCellInstance(Config: type, Next: type) type {
    return union(enum) {
        after_select_cell: Example(.current, Next),

        pub fn handler(_: *Context) @This() {
            return .after_select_cell;
        }

        pub fn select_is_back(ctx: *Context) bool {
            if (@hasDecl(Config, "select_cell_is_back")) {
                const fun: fn (*Context) bool = Config.select_cell_is_back;
                return (fun(ctx));
            }
            return false;
        }

        pub fn select_fun(ctx: *Context, sst: select.SelectStage) bool {
            ctx.play.vw.mouse_drag_viewport();
            ctx.play.vw.mouse_wheel_zoom_viewport();

            if (@hasDecl(Config, "select_cell_fun")) {
                const select_fun_: fn (*Context, select.SelectStage) bool = Config.select_cell_fun;
                return select_fun_(ctx, sst);
            }

            return false;
        }

        pub fn select_render(ctx: *Context, sst: select.SelectStage) void {
            ctx.play.render_current_map(ctx, true);

            if (@hasDecl(Config, "select_cell_render")) {
                const render_: fn (*Context, select.SelectStage) void = Config.select_cell_render;
                render_(ctx, sst);
            }
        }

        pub fn check_inside(ctx: *Context) select.CheckInsideResult {
            const vp = ctx.play.vw.viewpos_from_vector2(rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(vp.x));
            const y: i32 = @intFromFloat(@floor(vp.y));

            if (x < 0 or
                y < 0 or
                x >= ctx.map.maze_config.total_x or
                y >= ctx.map.maze_config.total_y) return .not_in_any_rect;

            const cell_id: CellID = .{ .x = @intCast(x), .y = @intCast(y) };
            if (Config.select_cell_check_inside(ctx, cell_id)) {
                ctx.play.selected_cell_id = cell_id;
                return .in_someone;
            }

            return .not_in_any_rect;
        }

        pub fn check_still_inside(ctx: *Context) bool {
            const vp = ctx.play.vw.viewpos_from_vector2(rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(vp.x));
            const y: i32 = @intFromFloat(@floor(vp.y));

            return (x == ctx.play.selected_cell_id.x and
                y == ctx.play.selected_cell_id.y);
        }
    };
}
const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const select = @import("select.zig");
const tbuild = @import("tbuild.zig");
const textures = @import("textures.zig");
const utils = @import("utils.zig");

const Example = core.Example;
const Menu = @import("menu.zig").Menu;
const Select = core.Select;
const Init = core.Init;
const Editor = @import("editor.zig").Editor;
const Map = @import("map.zig").Map;
const TBuild = @import("tbuild.zig").TBuild;
const Building = @import("tbuild.zig").TbuildData.Building;
const SetTexture = @import("textures.zig").SetTexture;

const rl = @import("raylib");
const rg = @import("raygui");
const maze = @import("maze");

const Context = core.Context;
const Action = core.Action;
const StateComponents = core.StateComponents;
const Maze = maze.Maze;
const ViewWin = @import("ViewWin.zig");
const SelectBuildInstance = tbuild.SelectBuildInstance;
const Tmp = core.Tmp;
