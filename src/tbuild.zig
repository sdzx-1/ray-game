pub const TBuild = union(enum) {
    // zig fmt: off
    to_play     : Example(.next, Play),
    to_select   : Example(.next, Select(Play, TBuild)),
    set_text_Id : Example(.next, Init(Select(TBuild, SetTexture(true, TBuild)))),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        {
            ctx.tbuild.view.mouse_wheel(ctx.hdw);
            ctx.tbuild.view.drag_view(ctx.screen_width);
        }
        if (ctx.tbuild.msg) |msg| {
            ctx.tbuild.msg = null;
            return msg;
        }

        const ptr = &ctx.tbuild.list.items[ctx.tbuild.selected_id];
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            const deta = ctx.tbuild.view.dwin_to_dview(ctx.screen_width, rl.getMouseDelta());
            ptr.x += deta.x;
            ptr.y += deta.y;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.j)) {
            ptr.height = ptr.height + 1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.k)) {
            ptr.height = ptr.height - 1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.h)) {
            ptr.width = ptr.width - 1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.l)) {
            ptr.width = ptr.width + 1;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            return .to_play;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.caps_lock)) {
            return .to_select;
        }
        return .no_trasition;
    }

    pub fn render(ctx: *Context) void {
        for (ctx.tbuild.list.items) |*b| b.draw(ctx);
        const ptr = &ctx.tbuild.list.items[ctx.tbuild.selected_id];
        if (ptr.draw_gui(ctx)) |msg| {
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

    pub fn select_fun(ctx: *Context, sst: select.SelectStage) bool {
        switch (sst) {
            .outside => {
                const mp = ctx.tbuild.view.win_to_view(ctx.screen_width, rl.getMousePosition());
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

    pub fn select_render(ctx: *Context, _: select.SelectStage) void {
        {
            ctx.tbuild.view.mouse_wheel(ctx.hdw);
            ctx.tbuild.view.drag_view(ctx.screen_width);
        }
        for (ctx.tbuild.list.items) |*b| b.draw(ctx);
    }

    pub fn check_inside(ctx: *Context) select.CheckInsideResult {
        for (ctx.tbuild.list.items, 0..) |*b, i| {
            if (b.inBuilding(ctx, rl.getMousePosition())) {
                ctx.tbuild.selected_id = i;
                return .in_someone;
            }
        }

        return .not_in_any_rect;
    }

    pub fn check_still_inside(ctx: *Context) bool {
        const b = ctx.tbuild.list.items[ctx.tbuild.selected_id];
        return b.inBuilding(ctx, rl.getMousePosition());
    }
};

pub const TbuildData = struct {
    list: std.ArrayListUnmanaged(Building) = .empty,
    selected_id: usize = 0,
    view: View = .{ .x = 0, .y = 0, .width = 25 },
    msg: ?TBuild = null,
};

pub const Building = struct {
    name: [30:0]u8 = @splat(0),
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: rl.Color = .white,
    text_id: textures.TextID = .{ .x = 0, .y = 0 },

    pub fn rotate(self: *@This()) void {
        const t = self.width;
        self.width = self.height;
        self.height = t;
    }

    pub fn inBuilding(self: *const Building, ctx: *const Context, win_pos: rl.Vector2) bool {
        const view_pos = ctx.tbuild.view.win_to_view(ctx.screen_width, win_pos);
        if (view_pos.x > self.x and
            view_pos.x < self.x + self.width and
            view_pos.y > self.y and
            view_pos.y < self.y + self.height) return true;
        return false;
    }

    pub fn draw(self: *Building, ctx: *Context) void {
        const win_pos = ctx.tbuild.view.view_to_win(
            ctx.screen_width,
            .{ .x = self.x, .y = self.y },
        );
        self.draw_with_pos(ctx, win_pos, null);
    }

    pub fn draw_with_pos(
        self: *Building,
        ctx: *Context,
        win_pos: rl.Vector2,
        color: ?rl.Color,
    ) void {
        self.draw_with_win_pos_and_view(
            ctx,
            win_pos,
            &ctx.tbuild.view,
            color,
        );
    }

    pub fn draw_with_win_pos_and_view(
        self: *Building,
        ctx: *Context,
        win_pos: rl.Vector2,
        view: *const View,
        color: ?rl.Color,
    ) void {
        const r = ctx.screen_width / view.width;
        const x: i32 = @intFromFloat(win_pos.x - r * self.width / 2);
        const y: i32 = @intFromFloat(win_pos.y - r * self.height / 2);
        const w: i32 = @intFromFloat(r * self.width);
        const h: i32 = @intFromFloat(r * self.height);
        if (color) |col| rl.drawRectangle(x, y, w, h, col) else {
            for (0..@intFromFloat(self.height)) |dy| {
                for (0..@intFromFloat(self.width)) |dx| {
                    switch (ctx.textures.read(self.text_id)) {
                        .texture => |texture| {
                            texture.tex2d.drawPro(
                                .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                                .{
                                    .x = win_pos.x + @as(f32, @floatFromInt(dx)) * r,
                                    .y = win_pos.y + @as(f32, @floatFromInt(dy)) * r,
                                    .width = r,
                                    .height = r,
                                },
                                .{ .x = 0, .y = 0 },
                                0,
                                self.color,
                            );
                        },
                        else => {},
                    }
                }
            }
        }
    }

    pub fn draw_gui(self: *Building, ctx: *Context) ?TBuild {
        const win_pos = ctx.tbuild.view.view_to_win(ctx.screen_width, .{ .x = self.x, .y = self.y });
        const r = ctx.screen_width / ctx.tbuild.view.width;
        var rect: rl.Rectangle = .{ .x = win_pos.x, .y = win_pos.y, .width = 250, .height = 30 };
        _ = rg.textBox(rect, &self.name, 30, false);
        rect.y -= 33;
        rect.width = 240;
        if (rg.button(rect, "select texture")) return .set_text_Id;
        rect.y = win_pos.y + self.height * r + 3;
        rect.width = 200;
        rect.height = 300;
        _ = rg.colorPicker(rect, "picker", &self.color);
        return null;
    }
};

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
