const std = @import("std");
const ps = @import("polystate");
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
    fsm: fn (ps.Method, type) type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back     : fsm(.next, back),
        to_inside   : fsm(.next, Inside(fsm, back, selected)),
        no_trasition: fsm(.next, @This()),
        // zig fmt: on

        pub fn handler(gst: *GST) @This() {
            const render: fn (*GST, SelectStage) bool = selected.select_render;
            _ = render(gst, .outside);
            const res: CheckInsideResult = selected.check_inside(gst);
            switch (res) {
                .not_in_any_rect => {},
                .in_someone => {
                    gst.select.no_move_duartion = std.time.milliTimestamp();
                    return .to_inside;
                },
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .to_back;
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
    fsm: fn (ps.Method, type) type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back     : fsm(.next, back),
        to_outside  : fsm(.next, Select(fsm, back, selected)),
        to_hover    : fsm(.next, Hover(fsm, back, selected)),
        to_selected : fsm(.next, selected),
        no_trasition: fsm(.next, @This()),
        // zig fmt: on

        pub fn handler(gst: *GST) @This() {
            const render: fn (*GST, SelectStage) bool = selected.select_render;
            if (render(gst, .inside)) return .to_outside;
            const res: bool = selected.check_still_inside(gst);
            if (!res) return .to_outside;
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) return .to_selected;
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .to_back;
            if (mouse_moved()) gst.select.no_move_duartion = std.time.milliTimestamp();
            const deta = std.time.milliTimestamp() - gst.select.no_move_duartion;
            if (deta > 400) return .to_hover;
            return .no_trasition;
        }
    };
}

pub fn Hover(
    fsm: fn (ps.Method, type) type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back     : fsm(.next, back),
        to_outside  : fsm(.next, Select(fsm, back, selected)),
        to_inside   : fsm(.next, Inside(fsm, back, selected)),
        to_selected : fsm(.next, selected),
        no_trasition: fsm(.next, @This()),
        // zig fmt: on

        pub fn handler(gst: *GST) @This() {
            const render: fn (*GST, SelectStage) bool = selected.select_render;
            if (render(gst, .hover)) return .to_outside;
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) return .to_selected;
            if (mouse_moved()) {
                gst.select.no_move_duartion = std.time.milliTimestamp();
                return .to_inside;
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .to_back;
            return .no_trasition;
        }
    };
}

fn mouse_moved() bool {
    const deta = rl.getMouseDelta();
    return (@abs(deta.x) > 1 or @abs(deta.y) > 1);
}
