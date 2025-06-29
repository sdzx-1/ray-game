const std = @import("std");
const polystate = @import("polystate");
const rl = @import("raylib");
const GST = @import("core.zig").GST;

pub const CheckInsideResult = enum {
    not_in_any_rect,
    in_someone,
};

pub const SelectData = struct {
    no_move_duartion: i64 = 0,
};

pub const SelectStage = enum { outside, inside, hover };

pub fn Select(
    fsm: fn (type) type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back  : fsm(back),
        to_inside: fsm(Inside(fsm, back, selected)),
        // zig fmt: on

        pub fn conthandler(gst: *GST) polystate.NextState(@This()) {
            const render: fn (*GST, SelectStage) bool = selected.select_render;
            _ = render(gst, .outside);
            const res: CheckInsideResult = selected.check_inside(gst);
            switch (res) {
                .not_in_any_rect => {},
                .in_someone => {
                    gst.select.no_move_duartion = std.time.milliTimestamp();
                    return .{ .next = .to_inside };
                },
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .{ .next = .to_back };
            return .no_trasition;
        }

        pub const select_render = selected.select_render1;
        pub const select_render1 = selected.select_render2;
        pub const select_render2 = selected.select_render3;
        pub const select_render3 = selected.select_render4;
        pub const select_render4 = selected.select_render5;

        pub const check_inside = selected.check_inside1;
        pub const check_inside1 = selected.check_inside2;
        pub const check_inside2 = selected.check_inside3;
        pub const check_inside3 = selected.check_inside4;
        pub const check_inside4 = selected.check_inside5;

        pub const check_still_inside = selected.check_still_inside1;
        pub const check_still_inside1 = selected.check_still_inside2;
        pub const check_still_inside2 = selected.check_still_inside3;
        pub const check_still_inside3 = selected.check_still_inside4;
        pub const check_still_inside4 = selected.check_still_inside5;
    };
}

pub fn Inside(
    fsm: fn (type) type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back    : fsm(back),
        to_outside : fsm(Select(fsm, back, selected)),
        to_hover   : fsm(Hover(fsm, back, selected)),
        to_selected: fsm(selected),
        // zig fmt: on

        pub fn conthandler(gst: *GST) polystate.NextState(@This()) {
            const render: fn (*GST, SelectStage) bool = selected.select_render;
            if (render(gst, .inside)) return .{ .next = .to_outside };
            const res: bool = selected.check_still_inside(gst);
            if (!res) return .{ .next = .to_outside };
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) return .{ .next = .to_selected };
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .{ .next = .to_back };
            if (mouse_moved()) gst.select.no_move_duartion = std.time.milliTimestamp();
            const deta = std.time.milliTimestamp() - gst.select.no_move_duartion;
            if (deta > 400) return .{ .next = .to_hover };
            return .no_trasition;
        }
    };
}

pub fn Hover(
    fsm: fn (type) type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back    : fsm(back),
        to_outside : fsm(Select(fsm, back, selected)),
        to_inside  : fsm(Inside(fsm, back, selected)),
        to_selected: fsm(selected),
        // zig fmt: on

        pub fn conthandler(gst: *GST) polystate.NextState(@This()) {
            const render: fn (*GST, SelectStage) bool = selected.select_render;
            if (render(gst, .hover)) return .{ .next = .to_outside };
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) return .{ .next = .to_selected };
            if (mouse_moved()) {
                gst.select.no_move_duartion = std.time.milliTimestamp();
                return .{ .next = .to_inside };
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .{ .next = .to_back };
            return .no_trasition;
        }
    };
}

fn mouse_moved() bool {
    const deta = rl.getMouseDelta();
    return (@abs(deta.x) > 1 or @abs(deta.y) > 1);
}
