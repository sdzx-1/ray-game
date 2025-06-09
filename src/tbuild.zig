pub const buildST = union(enum) {
    ToPlay: Wit(Example.play),
    ToSelect: WitRow(SDZX.C(Example.select, &.{ SDZX.V(Example.play), SDZX.V(Example.build) })),
    SetTextId: Wit(.{ Example.select, Example.build, .{ Example.sel_texture, Example.build } }),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToPlay => |wit| return .{ .Next = wit.conthandler() },
                .ToSelect => |wit| return .{ .Next = wit.conthandler() },
                .SetTextId => |wit| {
                    const ptr = &gst.tbuild.list.items[gst.tbuild.selected_id];
                    gst.sel_texture.address = &ptr.text_id;
                    return .{ .Next = wit.conthandler() };
                },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        for (gst.tbuild.list.items) |*b| b.draw(gst);
        const ptr = &gst.tbuild.list.items[gst.tbuild.selected_id];
        if (ptr.draw_gui(gst)) |msg| return msg;

        {
            gst.tbuild.view.mouse_wheel(gst.hdw);
            gst.tbuild.view.drag_view(gst.screen_width);
        }

        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            const deta = gst.tbuild.view.dwin_to_dview(gst.screen_width, rl.getMouseDelta());
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
            return .ToPlay;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.caps_lock)) {
            return .ToSelect;
        }
        return null;
    }

    //select
    pub fn select_render(gst: *GST, sst: select.SelectState) bool {
        {
            gst.tbuild.view.mouse_wheel(gst.hdw);
            gst.tbuild.view.drag_view(gst.screen_width);
        }
        for (gst.tbuild.list.items) |*b| b.draw(gst);

        switch (sst) {
            .outside => {},
            else => {
                if (rl.isKeyPressed(rl.KeyboardKey.d)) {
                    _ = gst.tbuild.list.swapRemove(gst.tbuild.selected_id);
                    return true;
                }
            },
        }

        return false;
    }

    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        for (gst.tbuild.list.items, 0..) |*b, i| {
            if (b.inBuilding(gst, rl.getMousePosition())) {
                gst.tbuild.selected_id = i;
                return .in_someone;
            }
        }

        const mp = gst.tbuild.view.win_to_view(gst.screen_width, rl.getMousePosition());
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            gst.tbuild.list.append(
                gst.gpa,
                .{ .x = mp.x, .y = mp.y, .width = 1, .height = 1, .color = rl.Color.white },
            ) catch unreachable;
        }

        return .not_in_any_rect;
    }

    pub fn check_still_inside(gst: *GST) bool {
        const b = gst.tbuild.list.items[gst.tbuild.selected_id];
        return b.inBuilding(gst, rl.getMousePosition());
    }
};

pub const Tbuild = struct {
    list: std.ArrayListUnmanaged(Building) = .empty,
    selected_id: usize = 0,
    view: View = .{ .x = 0, .y = 0, .width = 25 },
};

pub const Building = struct {
    name: [30:0]u8 = @splat(0),
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: rl.Color = .white,
    text_id: textures.TextID = .{ .x = 8, .y = 8 },

    pub fn rotate(self: *@This()) void {
        const t = self.width;
        self.width = self.height;
        self.height = t;
    }

    pub fn inBuilding(self: *const Building, gst: *const GST, win_pos: rl.Vector2) bool {
        const view_pos = gst.tbuild.view.win_to_view(gst.screen_width, win_pos);
        if (view_pos.x > self.x and
            view_pos.x < self.x + self.width and
            view_pos.y > self.y and
            view_pos.y < self.y + self.height) return true;
        return false;
    }

    pub fn draw(self: *Building, gst: *GST) void {
        const win_pos = gst.tbuild.view.view_to_win(
            gst.screen_width,
            .{ .x = self.x, .y = self.y },
        );
        self.draw_with_pos(gst, win_pos, null);
    }

    pub fn draw_with_pos(
        self: *Building,
        gst: *GST,
        win_pos: rl.Vector2,
        color: ?rl.Color,
    ) void {
        self.draw_with_win_pos_and_view(
            gst,
            win_pos,
            &gst.tbuild.view,
            color,
        );
    }

    pub fn draw_with_win_pos_and_view(
        self: *Building,
        gst: *GST,
        win_pos: rl.Vector2,
        view: *const View,
        color: ?rl.Color,
    ) void {
        const r = gst.screen_width / view.width;
        const x: i32 = @intFromFloat(win_pos.x - r * self.width / 2);
        const y: i32 = @intFromFloat(win_pos.y - r * self.height / 2);
        const w: i32 = @intFromFloat(r * self.width);
        const h: i32 = @intFromFloat(r * self.height);
        if (color) |col| rl.drawRectangle(x, y, w, h, col) else {
            for (0..@intFromFloat(self.height)) |dy| {
                for (0..@intFromFloat(self.width)) |dx| {
                    const texture = gst.textures.read(self.text_id).texture.tex2d;
                    texture.drawPro(
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
                }
            }
        }
    }

    pub fn draw_gui(self: *Building, gst: *GST) ?buildST {
        const win_pos = gst.tbuild.view.view_to_win(gst.screen_width, .{ .x = self.x, .y = self.y });
        const r = gst.screen_width / gst.tbuild.view.width;
        var rect: rl.Rectangle = .{ .x = win_pos.x, .y = win_pos.y, .width = 250, .height = 30 };
        _ = rg.textBox(rect, &self.name, 30, false);
        rect.y -= 33;
        rect.width = 240;
        if (rg.button(rect, "select texture")) return .SetTextId;
        rect.y = win_pos.y + self.height * r + 3;
        rect.width = 200;
        rect.height = 300;
        _ = rg.colorPicker(rect, "picker", &self.color);
        return null;
    }
};

const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
const select = @import("select.zig");
const textures = @import("textures.zig");
const utils = @import("utils.zig");

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
const View = utils.View;
