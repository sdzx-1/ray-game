const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");

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

//outside inside hover

pub const CheckInsideResult = enum {
    not_in_any_rect,
    in_someone,
};

pub const Select = struct {
    no_move_duartion: i64 = 0,
};

pub fn selectST(back: SDZX, selected: SDZX) type {
    const cst = typedFsm.sdzx_to_cst(Example, selected);
    return union(enum) {
        ToBack: WitRow(back),
        ToInside: WitRow(SDZX.C(Example.inside, &.{ back, selected })),

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .ToBack => |wit| return .{ .Next = wit.conthandler() },
                    .ToInside => |wit| {
                        gst.select.no_move_duartion = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                }
            } else return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            const res: CheckInsideResult = cst.check_inside(gst);
            switch (res) {
                .not_in_any_rect => {},
                .in_someone => return .ToInside,
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .ToBack;
            return null;
        }

        pub const check_inside = cst.check_inside1;
        pub const check_inside1 = cst.check_inside2;
        pub const check_inside2 = cst.check_inside3;
        pub const check_inside3 = cst.check_inside4;
        pub const check_inside4 = cst.check_inside5;

        pub const check_still_inside = cst.check_still_inside1;
        pub const check_still_inside1 = cst.check_still_inside2;
        pub const check_still_inside2 = cst.check_still_inside3;
        pub const check_still_inside3 = cst.check_still_inside4;
        pub const check_still_inside4 = cst.check_still_inside5;

        pub const hover = cst.hover1;
        pub const hover1 = cst.hover2;
        pub const hover2 = cst.hover3;
        pub const hover3 = cst.hover4;
        pub const hover4 = cst.hover5;
    };
}

pub fn insideST(back: SDZX, selected: SDZX) type {
    const cst = typedFsm.sdzx_to_cst(Example, selected);
    return union(enum) {
        // zig fmt: off
        ToBack    : WitRow(back),
        ToOutside : WitRow(SDZX.C(Example.select, &.{ back, selected })),
        ToHover   : WitRow(SDZX.C(Example.hover,   &.{ back, selected })),
        ToSelected: WitRow(selected),
        // zig fmt: on

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .ToBack => |wit| return .{ .Next = wit.conthandler() },
                    .ToOutside => |wit| return .{ .Next = wit.conthandler() },
                    .ToHover => |wit| return .{ .Next = wit.conthandler() },
                    .ToSelected => |wit| return .{ .Next = wit.conthandler() },
                }
            } else return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            const res: bool = cst.check_still_inside(gst);
            if (!res) return .ToOutside;
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) return .ToSelected;
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .ToBack;
            if (mouse_moved()) gst.select.no_move_duartion = std.time.milliTimestamp();
            const deta = std.time.milliTimestamp() - gst.select.no_move_duartion;
            if (deta > 400) return .ToHover;
            return null;
        }
    };
}

pub fn hoverST(back: SDZX, selected: SDZX) type {
    const cst = typedFsm.sdzx_to_cst(Example, selected);
    return union(enum) {
        // zig fmt: off
        ToBack    : WitRow(back),
        ToOutside : WitRow(SDZX.C(Example.select, &.{ back, selected })),
        ToInside  : WitRow(SDZX.C(Example.inside, &.{ back, selected })),
        ToSelected: WitRow(selected),
        // zig fmt: on

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .ToBack => |wit| return .{ .Next = wit.conthandler() },
                    .ToOutside => |wit| return .{ .Next = wit.conthandler() },
                    .ToInside => |wit| {
                        gst.select.no_move_duartion = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                    .ToSelected => |wit| return .{ .Next = wit.conthandler() },
                }
            } else return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            cst.hover(gst);
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) return .ToSelected;
            if (mouse_moved()) return .ToInside;
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .ToBack;
            return null;
        }
    };
}

fn mouse_moved() bool {
    const deta = rl.getMouseDelta();
    return (@abs(deta.x) > 1 or @abs(deta.y) > 1);
}
