pub const TbuildData = struct {
    list: std.ArrayListUnmanaged(Building) = .empty,
    selected_id: usize = 0,
    vw: ViewWin = .{
        .hw_ratio = 0.618,
        .winport = .{ .width = 1936, .pos = .{ .x = 0, .y = 0 } },
        .viewport = .{ .width = 30, .pos = .{ .x = 45, .y = 54 } },
        .wheel_zoom_ratio = 0.2,
    },
    msg: ?EditBuild = null,

    pub const Building = struct {
        name: [30:0]u8 = @splat(0),
        x: f32,
        y: f32,
        width: usize,
        height: usize,
        color: rl.Color = .white,
        text_id: textures.TextID = .{ .x = 0, .y = 0 },

        pub fn rotate(self: *@This()) void {
            const t = self.width;
            self.width = self.height;
            self.height = t;
        }

        pub fn inBuilding(self: *const Building, view_pos: ViewWin.Viewport.Pos) bool {
            if (view_pos.x > self.x and
                view_pos.x < self.x + @as(f32, @floatFromInt(self.width)) and
                view_pos.y > self.y and
                view_pos.y < self.y + @as(f32, @floatFromInt(self.height))) return true;
            return false;
        }
    };

    pub fn render(self: *const @This(), ctx: *const Context) void {
        const win_rect: rl.Rectangle = .{
            .x = self.vw.winport.pos.x,
            .y = self.vw.winport.pos.y,
            .width = self.vw.winport.width,
            .height = self.vw.winport_get_height(),
        };
        rl.drawRectangleRec(win_rect, rl.Color.white);

        for (self.list.items) |build| {
            const wpos = self.vw.viewpos_to_winpos(.{ .x = build.x, .y = build.y });

            self.vw.winport_beginScissorMode();
            defer rl.endScissorMode();

            const dw = self.vw.wv_ratio();
            for (0..build.height) |dy| {
                for (0..build.width) |dx| {
                    ctx.textures.render_texture(
                        build.text_id,
                        .{
                            .x = wpos.x + @as(f32, @floatFromInt(dx)) * dw,
                            .y = wpos.y + @as(f32, @floatFromInt(dy)) * dw,
                            .width = dw,
                            .height = dw,
                        },
                        build.color,
                    );
                }
            }

            const dpos = self.vw.dviewpos_to_dwinpos(.{
                .x = @floatFromInt(build.width),
                .y = @floatFromInt(build.height),
            });

            const build_rect: rl.Rectangle = .{ .x = wpos.x, .y = wpos.y, .width = dpos.x, .height = dpos.y };

            rl.drawRectangleLinesEx(build_rect, 4, rl.Color.black);
        }

        rl.drawRectangleLinesEx(win_rect, 4, rl.Color.black);
    }

    pub fn draw_gui(self: *@This(), build: *Building) ?EditBuild {
        const win_pos = self.vw.viewpos_to_winpos(.{ .x = build.x, .y = build.y });

        const r = self.vw.wv_ratio();
        var rect: rl.Rectangle = .{ .x = win_pos.x, .y = win_pos.y, .width = 180, .height = 30 };

        rect.y = win_pos.y + @as(f32, @floatFromInt(build.height)) * r + 3;
        if (rg.button(rect, "set texture")) return .set_text_Id;

        rect.y += 33;
        rect.width = 200;
        rect.height = 300;
        _ = rg.colorPicker(rect, "picker", &build.color);
        return null;
    }
};

pub const TBuild = SelectBuildInstance(EditBuild, EditBuild);

pub fn ViewBuilds(Next: type) type {
    return union(enum) {
        after_view_build: Example(.current, Select(Next, SelectBuildInstance(@This(), @This()))),

        pub fn handler(_: *Context) @This() {
            return .after_view_build;
        }
    };
}

pub const EditBuild = union(enum) {
    // zig fmt: off
    to_play     : Example(.next, Play),
    to_select   : Example(.next, Select(Play, TBuild)),
    set_text_Id : Example(.next, Init(SetEditBuildTexture, Select(EditBuild, SetEditBuildTexture))),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    const SetEditBuildTexture = SetTexture(true, EditBuild);

    pub fn handler(ctx: *Context) @This() {
        ctx.tbuild.vw.mouse_wheel_zoom_viewport();
        ctx.tbuild.vw.mouse_drag_viewport();

        if (ctx.tbuild.msg) |msg| {
            ctx.tbuild.msg = null;
            return msg;
        }

        const ptr = &ctx.tbuild.list.items[ctx.tbuild.selected_id];

        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            const deta = ctx.tbuild.vw.dwinpos_to_dviewpos(ViewWin.Winport.Pos.fromVector2(rl.getMouseDelta()));
            ptr.x += deta.x;
            ptr.y += deta.y;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.j)) {
            ptr.height = ptr.height + 1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.k)) {
            ptr.height = @max(ptr.height - 1, 1);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.h)) {
            ptr.width = @max(ptr.width - 1, 1);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.l)) {
            ptr.width = ptr.width + 1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            return .to_play;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.tab)) {
            return .to_select;
        }

        return .no_trasition;
    }

    pub fn render(ctx: *Context) void {
        ctx.tbuild.render(ctx);
        const ptr = &ctx.tbuild.list.items[ctx.tbuild.selected_id];
        if (ctx.tbuild.draw_gui(ptr)) |msg| {
            if (ctx.tbuild.msg == null) ctx.tbuild.msg = msg;
        }
    }

    pub fn set_text_id(ctx: *Context, tid: textures.TextID) void {
        ctx.tbuild.list.items[ctx.tbuild.selected_id].text_id = tid;
    }

    pub fn get_text_id(ctx: *const Context) textures.TextID {
        return ctx.tbuild.list.items[ctx.tbuild.selected_id].text_id;
    }

    //select

    pub fn select_build_fun(ctx: *Context, sst: select.SelectStage) bool {
        switch (sst) {
            .outside => {
                const mp = ctx.tbuild.vw.viewpos_from_vector2(rl.getMousePosition());
                if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                    ctx.tbuild.list.append(
                        ctx.gpa,
                        .{ .x = mp.x, .y = mp.y, .width = 1, .height = 1, .color = rl.Color.white },
                    ) catch unreachable;
                }
            },
            else => {
                if (rl.isKeyPressed(rl.KeyboardKey.d)) {
                    _ = ctx.tbuild.list.swapRemove(ctx.tbuild.selected_id);
                    return true;
                }
            },
        }
        return false;
    }
};

pub fn SelectBuildInstance(Config: type, Next: type) type {
    return union(enum) {
        after_select_build: Example(.current, Next),

        pub fn handler(ctx: *Context) @This() {
            _ = ctx;
            return .after_select_build;
        }

        pub fn select_fun(ctx: *Context, sst: select.SelectStage) bool {
            ctx.tbuild.vw.mouse_wheel_zoom_viewport();
            ctx.tbuild.vw.mouse_drag_viewport();
            ctx.tbuild.vw.mouse_drag_winport();

            if (@hasDecl(Config, "select_build_fun")) {
                const select_fun_: fn (*Context, select.SelectStage) bool = Config.select_build_fun;
                return select_fun_(ctx, sst);
            } else {
                return false;
            }
        }

        pub fn select_render(ctx: *Context, sst: select.SelectStage) void {
            if (@hasDecl(Config, "select_build_backend_render")) {
                const render_: fn (*Context, select.SelectStage) void = Config.select_build_backend_render;
                render_(ctx, sst);
            }

            ctx.tbuild.render(ctx);

            switch (sst) {
                .hover => {
                    const b = ctx.tbuild.list.items[ctx.tbuild.selected_id];
                    const wp = ViewWin.Winport.Pos.fromVector2(rl.getMousePosition());
                    const str = ctx.printZ(
                        \\width: {d}, height: {d}
                        \\text_id
                        \\  x: {d}, y: {d}
                    , .{ b.width, b.height, b.text_id.x, b.text_id.y });
                    rl.drawRectangleRec(.{ .x = wp.x, .y = wp.y, .width = 290, .height = 100 }, rl.Color.white);
                    rl.drawText(str, @intFromFloat(wp.x), @intFromFloat(wp.y), 30, rl.Color.black);
                },
                else => {},
            }

            if (@hasDecl(Config, "select_build_render")) {
                const render_: fn (*Context, select.SelectStage) void = Config.select_build_render;
                render_(ctx, sst);
            }
        }

        pub fn check_inside(ctx: *Context) select.CheckInsideResult {
            const wp = ViewWin.Winport.Pos.fromVector2(rl.getMousePosition());
            const vp = ctx.tbuild.vw.winpos_to_viewpos(wp);
            if (ctx.tbuild.vw.inViewport(vp)) {
                for (ctx.tbuild.list.items, 0..) |*b, i| {
                    if (b.inBuilding(vp)) {
                        ctx.tbuild.selected_id = i;
                        if (@hasDecl(Config, "select_build_inside_fun")) Config.select_build_inside_fun(ctx);
                        return .in_someone;
                    }
                }
            }
            return .not_in_any_rect;
        }

        pub fn check_still_inside(ctx: *Context) bool {
            const b = ctx.tbuild.list.items[ctx.tbuild.selected_id];
            const wp = ViewWin.Winport.Pos.fromVector2(rl.getMousePosition());
            const vp = ctx.tbuild.vw.winpos_to_viewpos(wp);
            if (ctx.tbuild.vw.inViewport(vp)) {
                return b.inBuilding(ctx.tbuild.vw.winpos_to_viewpos(wp));
            }
            return false;
        }
    };
}

const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const select = @import("select.zig");
const textures = @import("textures.zig");
const utils = @import("utils.zig");

const Example = core.Example;
const Menu = @import("menu.zig").Menu;
const Select = core.Select;
const Init = core.Init;
const Editor = @import("editor.zig").Editor;
const Map = @import("map.zig").Map;
const SetTexture = @import("textures.zig").SetTexture;
const Play = @import("play.zig").Play;

const rl = @import("raylib");
const rg = @import("raygui");

const Context = core.Context;
const View = utils.View;
const ViewWin = @import("ViewWin.zig");
