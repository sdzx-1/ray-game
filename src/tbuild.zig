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
        const deta = rl.getMouseDelta();
        ptr.x += deta.x;
        ptr.y += deta.y;
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
    pub fn check_inside(gst: *GST) select.CheckInsideResult {
        for (gst.tbuild.list.items) |*b| b.draw(gst);
        for (gst.tbuild.list.items, 0..) |*b, i| {
            if (b.inBuilding(gst, rl.getMousePosition())) {
                gst.tbuild.selected_id = i;
                return .in_someone;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            const mp = rl.getMousePosition();
            gst.tbuild.list.append(
                gst.gpa,
                .{ .x = mp.x, .y = mp.y, .width = 2, .height = 2 },
            ) catch unreachable;
        }
        return .not_in_any_rect;
    }

    pub fn check_still_inside(gst: *GST) bool {
        for (gst.tbuild.list.items) |*b| b.draw(gst);
        const b = gst.tbuild.list.items[gst.tbuild.selected_id];
        return b.inBuilding(gst, rl.getMousePosition());
    }

    pub fn hover(gst: *GST) void {
        for (gst.tbuild.list.items) |*b| b.draw(gst);
    }
};

pub const Tbuild = struct {
    list: std.ArrayListUnmanaged(Building) = .empty,
    selected_id: usize = 0,
};

pub const Building = struct {
    x: f32,
    y: f32,
    width: u32,
    height: u32,

    pub fn inBuilding(self: *const Building, gst: *const GST, pos: rl.Vector2) bool {
        const r = gst.screen_width / gst.play.view.width;
        const w: f32 = r * @as(f32, @floatFromInt(self.width));
        const h: f32 = r * @as(f32, @floatFromInt(self.height));
        if (pos.x > self.x and
            pos.x < self.x + w and
            pos.y > self.y and
            pos.y < self.y + h) return true;
        return false;
    }

    pub fn draw(self: *const Building, gst: *const GST) void {
        const x: i32 = @intFromFloat(self.x);
        const y: i32 = @intFromFloat(self.y);
        const r = gst.screen_width / gst.play.view.width;
        const w: i32 = @intFromFloat(r * @as(f32, @floatFromInt(self.width)));
        const h: i32 = @intFromFloat(r * @as(f32, @floatFromInt(self.height)));
        rl.drawRectangle(x, y, w, h, rl.Color.orange);
        var tmpBuf: [20]u8 = undefined;
        const str = std.fmt.bufPrintZ(
            &tmpBuf,
            "{d}, {d}",
            .{ self.width, self.height },
        ) catch unreachable;
        rl.drawText(str, x, y, 32, rl.Color.red);
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
