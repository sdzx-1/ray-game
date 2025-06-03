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
        ptr.draw_color_picker();
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            const deta = rl.getMouseDelta();
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
        for (gst.tbuild.list.items) |*b| b.draw(gst);
    }

    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        for (gst.tbuild.list.items, 0..) |*b, i| {
            if (b.inBuilding(rl.getMousePosition())) {
                gst.tbuild.selected_id = i;
                return .in_someone;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            const mp = rl.getMousePosition();
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
        const b = gst.tbuild.list.items[gst.tbuild.selected_id];
        return b.inBuilding(rl.getMousePosition());
    }
};

pub const Tbuild = struct {
    list: std.ArrayListUnmanaged(Building) = .empty,
    selected_id: usize = 0,
};

pub const Building = struct {
    x: f32,
    y: f32,
    width: i32,
    height: i32,
    color: rl.Color = .orange,

    pub fn inBuilding(self: *const Building, pos: rl.Vector2) bool {
        const w: f32 = 50 * @as(f32, @floatFromInt(self.width));
        const h: f32 = 50 * @as(f32, @floatFromInt(self.height));
        if (pos.x > self.x and
            pos.x < self.x + w and
            pos.y > self.y and
            pos.y < self.y + h) return true;
        return false;
    }

    pub fn draw(self: *Building, gst: *GST) void {
        self.draw_with_pos(gst, .{ .x = self.x, .y = self.y }, null, false);
    }

    pub fn draw_with_pos(
        self: *Building,
        gst: *GST,
        pos: rl.Vector2,
        color: ?rl.Color,
        scale: bool,
    ) void {
        const x: i32 = @intFromFloat(pos.x);
        const y: i32 = @intFromFloat(pos.y);
        var w: i32 = undefined;
        var h: i32 = undefined;

        if (scale) {
            const r = gst.screen_width / gst.play.view.width;
            w = @intFromFloat(r * @as(f32, @floatFromInt(self.width)));
            h = @intFromFloat(r * @as(f32, @floatFromInt(self.height)));
        } else {
            w = 50 * self.width;
            h = 50 * self.height;
        }

        if (color) |col| rl.drawRectangle(x, y, w, h, col) else rl.drawRectangle(x, y, w, h, self.color);
        const str = gst.printZ("{d}, {d}", .{ self.width, self.height });
        rl.drawText(str, x, y, 32, rl.Color.black);
    }

    pub fn draw_color_picker(self: *Building) void {
        _ = rg.colorPicker(
            .{ .x = self.x, .y = self.y + @as(f32, @floatFromInt(self.height)) * 50 + 3, .width = 300, .height = 400 },
            "picker",
            &self.color,
        );
    }
};

const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
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
