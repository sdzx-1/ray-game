const std = @import("std");
const polystate = @import("polystate");
const rl = @import("raylib");

pub const CheckInsideResult = enum {
    not_in_any_rect,
    in_someone,
};

pub const Select = struct {
    no_move_duartion: i64 = 0,
};

pub const SelectState = enum { outside, inside, hover };

pub fn selectST(
    FST: type,
    GST: type,
    enter_fn: ?fn (polystate.sdzx(FST), *GST) void,
    back: polystate.sdzx(FST),
    selected: polystate.sdzx(FST),
) type {
    const cst = polystate.sdzx_to_cst(FST, selected);
    const SDZX = polystate.sdzx(FST);

    return union(enum) {
        // zig fmt: off
        ToBack  : polystate.Witness(FST, back,                                     GST, enter_fn),
        ToInside: polystate.Witness(FST, SDZX.C(FST.inside, &.{ back, selected }), GST, enter_fn),
        // zig fmt: on

        pub fn conthandler(gst: *GST) polystate.ContR(GST) {
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
            const render: fn (*GST, SelectState) bool = cst.select_render;
            _ = render(gst, .outside);
            const res: CheckInsideResult = cst.check_inside(gst);
            switch (res) {
                .not_in_any_rect => {},
                .in_someone => return .ToInside,
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .ToBack;
            return null;
        }

        pub const select_render = cst.select_render1;
        pub const select_render1 = cst.select_render2;
        pub const select_render2 = cst.select_render3;
        pub const select_render3 = cst.select_render4;
        pub const select_render4 = cst.select_render5;

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
    };
}

pub fn insideST(
    FST: type,
    GST: type,
    enter_fn: ?fn (polystate.sdzx(FST), *GST) void,
    back: polystate.sdzx(FST),
    selected: polystate.sdzx(FST),
) type {
    const cst = polystate.sdzx_to_cst(FST, selected);
    const SDZX = polystate.sdzx(FST);

    return union(enum) {
        // zig fmt: off
        ToBack    : polystate.Witness(FST, back,                                      GST, enter_fn),
        ToOutside : polystate.Witness(FST, SDZX.C(FST.select, &.{ back, selected }),  GST, enter_fn),
        ToHover   : polystate.Witness(FST, SDZX.C(FST.hover, &.{ back, selected }),   GST, enter_fn),
        ToSelected: polystate.Witness(FST, selected,                                  GST, enter_fn),
        // zig fmt: on

        pub fn conthandler(gst: *GST) polystate.ContR(GST) {
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
            const render: fn (*GST, SelectState) bool = cst.select_render;
            if (render(gst, .inside)) return .ToOutside;
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

pub fn hoverST(
    FST: type,
    GST: type,
    enter_fn: ?fn (polystate.sdzx(FST), *GST) void,
    back: polystate.sdzx(FST),
    selected: polystate.sdzx(FST),
) type {
    const cst = polystate.sdzx_to_cst(FST, selected);
    const SDZX = polystate.sdzx(FST);

    return union(enum) {
        // zig fmt: off
        ToBack    : polystate.Witness(FST, back,                                     GST, enter_fn),
        ToOutside : polystate.Witness(FST, SDZX.C(FST.select, &.{ back, selected }), GST, enter_fn),
        ToInside  : polystate.Witness(FST, SDZX.C(FST.inside, &.{ back, selected }), GST, enter_fn),
        ToSelected: polystate.Witness(FST, selected,                                 GST, enter_fn),
        // zig fmt: on

        pub fn conthandler(gst: *GST) polystate.ContR(GST) {
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
            const render: fn (*GST, SelectState) bool = cst.select_render;
            if (render(gst, .hover)) return .ToOutside;
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
