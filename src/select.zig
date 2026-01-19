const std = @import("std");
const ps = @import("polystate");
const Data = ps.Data;
const rl = @import("raylib");

pub const CheckInsideResult = enum {
    not_in_any_rect,
    in_someone,
};

pub const SelectData = struct {
    no_move_duartion: i64 = 0,
};

pub const SelectStage = enum { outside, inside, hover };

pub fn select_info(name: []const u8, Context: type) ps.StateInfo("Example", Context) {
    return .{ .name = name };
}

pub fn Select(
    Context: type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back     : Data(.next, void, back),
        to_inside   : Data(.next, void, Inside(Context, back, selected)),
        no_trasition: Data(.next, void, @This()),
        // zig fmt: on

        pub const info = select_info("Select", Context);

        pub fn handler(ctx: *Context) @This() {
            if (@hasDecl(selected, "select_fun")) {
                const fun: fn (*Context, SelectStage) bool = selected.select_fun;
                _ = fun(ctx, .outside);
            }

            const res: CheckInsideResult = selected.check_inside(ctx);
            switch (res) {
                .not_in_any_rect => {},
                .in_someone => {
                    ctx.select.no_move_duartion = std.time.milliTimestamp();
                    return .to_inside;
                },
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .to_back;
            return .no_trasition;
        }

        pub fn render(ctx: *Context) void {
            const render_: fn (*Context, SelectStage) void = selected.select_render;
            render_(ctx, .outside);
        }
    };
}

pub fn Inside(
    Context: type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back     : Data(.next, void, back),
        to_outside  : Data(.next, void, Select(Context, back, selected)),
        to_hover    : Data(.next, void, Hover(Context, back, selected)),
        to_selected : Data(.next, void, selected),
        no_trasition: Data(.next, void, @This()),
        // zig fmt: on

        pub const info = select_info("Inside", Context);

        pub fn handler(ctx: *Context) @This() {
            if (@hasDecl(selected, "select_fun")) {
                const select_fun: fn (*Context, SelectStage) bool = selected.select_fun;
                if (select_fun(ctx, .inside)) return .to_outside;
            }

            const res: bool = selected.check_still_inside(ctx);
            if (!res) return .to_outside;
            if (rl.isMouseButtonReleased(rl.MouseButton.left)) return .to_selected;
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .to_back;
            if (mouse_moved()) ctx.select.no_move_duartion = std.time.milliTimestamp();
            const deta = std.time.milliTimestamp() - ctx.select.no_move_duartion;
            if (deta > 400) return .to_hover;
            return .no_trasition;
        }

        pub fn render(ctx: *Context) void {
            const render_: fn (*Context, SelectStage) void = selected.select_render;
            render_(ctx, .inside);
        }
    };
}

pub fn Hover(
    Context: type,
    back: type,
    selected: type,
) type {
    return union(enum) {
        // zig fmt: off
        to_back     : Data(.next, void, back),
        to_outside  : Data(.next, void, Select(Context, back, selected)),
        to_inside   : Data(.next, void, Inside(Context, back, selected)),
        to_selected : Data(.next, void, selected),
        no_trasition: Data(.next, void, @This()),
        // zig fmt: on

        pub const info = select_info("Hover", Context);

        pub fn handler(ctx: *Context) @This() {
            if (@hasDecl(selected, "select_fun")) {
                const select_fun: fn (*Context, SelectStage) bool = selected.select_fun;
                if (select_fun(ctx, .hover)) return .to_outside;
            }

            if (rl.isMouseButtonReleased(rl.MouseButton.left)) return .to_selected;
            if (mouse_moved()) {
                ctx.select.no_move_duartion = std.time.milliTimestamp();
                return .to_inside;
            }
            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .to_back;
            return .no_trasition;
        }

        pub fn render(ctx: *Context) void {
            const render_: fn (*Context, SelectStage) void = selected.select_render;
            render_(ctx, .hover);
        }
    };
}

fn mouse_moved() bool {
    const deta = rl.getMouseDelta();
    return (@abs(deta.x) > 1 or @abs(deta.y) > 1);
}
