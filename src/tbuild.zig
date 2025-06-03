pub const buildST = union(enum) {
    ToPlay: Wit(Example.play),
    ToSelect: WitRow(SDZX.C(
        Example.select,
        &.{ SDZX.V(Example.play), SDZX.V(Example.build) },
    )),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToPlay => |wit| return .{ .Next = wit.conthandler() },
                .ToSelect => |wit| return .{ .Next = wit.conthandler() },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        for (gst.tbuild.list.items) |*b| b.draw(gst);
        const ptr = &gst.tbuild.list.items[gst.tbuild.selected_id];
        ptr.draw_color_picker(gst);

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
    pub fn select_render(gst: *GST, sst: select.SelectState) void {
        _ = sst;
        {
            gst.tbuild.view.mouse_wheel(gst.hdw);
            gst.tbuild.view.drag_view(gst.screen_width);
        }

        for (gst.tbuild.list.items) |*b| b.draw(gst);
    }

    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        const mp = gst.tbuild.view.win_to_view(gst.screen_width, rl.getMousePosition());
        for (gst.tbuild.list.items, 0..) |*b, i| {
            if (b.inBuilding(mp)) {
                gst.tbuild.selected_id = i;
                return .in_someone;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            gst.tbuild.list.append(
                gst.gpa,
                .{
                    .x = mp.x,
                    .y = mp.y,
                    .width = 1,
                    .height = 1,
                    .color = rl.Color.orange,
                },
            ) catch unreachable;
        }
        return .not_in_any_rect;
    }

    pub fn check_still_inside(gst: *GST) bool {
        const mp = gst.tbuild.view.win_to_view(gst.screen_width, rl.getMousePosition());
        const b = gst.tbuild.list.items[gst.tbuild.selected_id];
        return b.inBuilding(mp);
    }
};

pub const Tbuild = struct {
    list: std.ArrayListUnmanaged(Building) = .empty,
    selected_id: usize = 0,
    view: View = .{ .x = 0, .y = 0, .width = 25 },
};

pub const Building = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: rl.Color = .orange,

    pub fn inBuilding(self: *const Building, view_pos: rl.Vector2) bool {
        if (view_pos.x > self.x and
            view_pos.x < self.x + self.width and
            view_pos.y > self.y and
            view_pos.y < self.y + self.height) return true;
        return false;
    }

    pub fn draw(self: *Building, gst: *GST) void {
        self.draw_with_pos(gst, .{ .x = self.x, .y = self.y }, null);
    }

    pub fn draw_with_pos(
        self: *Building,
        gst: *GST,
        view_pos: rl.Vector2,
        color: ?rl.Color,
    ) void {
        self.draw_with_pos_and_view(gst, view_pos, &gst.tbuild.view, color);
    }

    pub fn draw_with_pos_and_view(
        self: *Building,
        gst: *GST,
        view_pos: rl.Vector2,
        view: *const View,
        color: ?rl.Color,
    ) void {
        const win_pos = view.view_to_win(gst.screen_width, view_pos);
        const r = gst.screen_width / view.width;
        const x: i32 = @intFromFloat(win_pos.x);
        const y: i32 = @intFromFloat(win_pos.y);
        const w: i32 = @intFromFloat(r * self.width);
        const h: i32 = @intFromFloat(r * self.height);
        if (color) |col| rl.drawRectangle(x, y, w, h, col) else rl.drawRectangle(x, y, w, h, self.color);
        const str = gst.printZ("{d}, {d}", .{ self.width, self.height });
        rl.drawText(str, x, y, 32, rl.Color.black);
    }

    pub fn draw_color_picker(self: *Building, gst: *GST) void {
        const win_pos = gst.tbuild.view.view_to_win(gst.screen_width, .{ .x = self.x, .y = self.y });
        const r = gst.screen_width / gst.tbuild.view.width;
        _ = rg.colorPicker(
            .{
                .x = win_pos.x,
                .y = win_pos.y + self.height * r + 3,
                .width = 200,
                .height = 300,
            },
            "picker",
            &self.color,
        );
    }
};

const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
const select = @import("select.zig");
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
