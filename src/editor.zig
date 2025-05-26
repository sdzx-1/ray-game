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

pub const Editor = struct {
    in_rect: usize = 0,
    selected: usize = 0,
    copyed_rect: ?R = null,
};

fn gui(comptime target: typedFsm.sdzx(Example), cst: type, gst: *GST) cst {
    while (true) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);
        rl.drawCircle(rl.getMouseX(), rl.getMouseY(), 4, rl.Color.red);
        gst.render_log();

        const nst = comptime getTarget(target);
        for (@field(gst, nst).rs.items) |*r| {
            rl.drawRectangleLines(
                @intFromFloat(r.rect.x),
                @intFromFloat(r.rect.y),
                @intFromFloat(r.rect.width),
                @intFromFloat(r.rect.height),
                r.color,
            );

            rl.drawText(
                &r.str_buf,
                @intFromFloat(r.rect.x),
                @intFromFloat(r.rect.y),
                32,
                r.color,
            );
        }

        if (@hasDecl(cst, "genMsg")) {
            if (cst.genMsg(gst)) |msg| return msg;
        }
    }
}

pub fn idleST(target: typedFsm.sdzx(Example)) type {
    return union(enum) {
        Exit: WitRow(target),
        InRect: struct { wit: WitRow(SDZX.C(Example.in_rect, &.{target})) = .{}, id: usize },

        pub fn handler(gst: *GST) void {
            switch (gui(target, @This(), gst)) {
                .InRect => |v| {
                    gst.editor.in_rect = v.id;
                    v.wit.handler(gst);
                },
                .Exit => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *GST) ?@This() {
            const nst = comptime getTarget(target);
            if (rl.isKeyPressed(rl.KeyboardKey.q)) return .Exit;

            if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                const mp = rl.getMousePosition();

                var r: R = .{};
                if (gst.editor.copyed_rect) |cr| r = cr;

                r.rect.x = mp.x;
                r.rect.y = mp.y;
                const size = rl.measureText(&r.str_buf, 32);

                r.rect.width = @floatFromInt(size);

                @field(gst, nst).rs.append(gst.gpa, r) catch unreachable;

                gst.log("Add button");
            }

            for (@field(gst, nst).rs.items, 0..) |*r, i| {
                if (r.inR(rl.getMousePosition())) {
                    return .{ .InRect = .{ .id = i } };
                }
            }

            return null;
        }
    };
}

pub fn in_rectST(target: typedFsm.sdzx(Example)) type {
    return union(enum) {
        Exit: WitRow(target),
        ToIdle: WitRow(SDZX.C(Example.idle, &.{target})),
        ToEdit: WitRow(SDZX.C(Example.edit, &.{target})),
        ToSelected: WitRow(SDZX.C(Example.selected, &.{target})),

        pub fn handler(gst: *GST) void {
            switch (gui(target, @This(), gst)) {
                .Exit => |wit| wit.handler(gst),
                .ToIdle => |wit| wit.handler(gst),
                .ToSelected => |wit| {
                    gst.editor.selected = gst.editor.in_rect;
                    wit.handler(gst);
                },
                .ToEdit => |wit| {
                    gst.editor.selected = gst.editor.in_rect;
                    wit.handler(gst);
                },
            }
        }

        fn genMsg(gst: *GST) ?@This() {
            const nst = comptime getTarget(target);
            const r = @field(gst, nst).rs.items[gst.editor.in_rect];

            rl.drawRectangleLines(
                @intFromFloat(r.rect.x - 1),
                @intFromFloat(r.rect.y - 1),
                @intFromFloat(r.rect.width + 2),
                @intFromFloat(r.rect.height + 2),
                rl.Color.blue,
            );

            if (rl.isKeyPressed(rl.KeyboardKey.q)) return .Exit;

            if (!r.inR(rl.getMousePosition())) {
                return .ToIdle;
            }

            if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
                return .ToSelected;
            }

            if (rl.isMouseButtonPressed(rl.MouseButton.right)) {
                return .ToEdit;
            }
            return null;
        }
    };
}

pub fn selectedST(target: typedFsm.sdzx(Example)) type {
    return union(enum) {
        Exit: WitRow(target),
        ToIdle: WitRow(SDZX.C(Example.idle, &.{target})),
        Edit: WitRow(SDZX.C(Example.edit, &.{target})),

        pub fn handler(gst: *GST) void {
            switch (gui(target, @This(), gst)) {
                .Exit => |wit| wit.handler(gst),
                .ToIdle => |wit| wit.handler(gst),
                .Edit => |wit| {
                    wit.handler(gst);
                },
            }
        }

        fn genMsg(gst: *GST) ?@This() {
            const nst = comptime getTarget(target);
            const r = @field(gst, nst).rs.items[gst.editor.selected];
            rl.drawRectangleLines(
                @intFromFloat(r.rect.x - 1),
                @intFromFloat(r.rect.y - 1),
                @intFromFloat(r.rect.width + 2),
                @intFromFloat(r.rect.height + 2),
                rl.Color.red,
            );

            if (rl.isKeyPressed(rl.KeyboardKey.q)) return .Exit;

            const deta: f32 = 1.4;

            if (!r.inR(rl.getMousePosition()) and
                rl.isMouseButtonPressed(rl.MouseButton.left))
            {
                return .ToIdle;
            }

            if (rl.isMouseButtonDown(rl.MouseButton.left)) {
                const v = rl.getMouseDelta();
                @field(gst, nst).rs.items[gst.editor.selected].rect.x += v.x;
                @field(gst, nst).rs.items[gst.editor.selected].rect.y += v.y;
            }

            if (rl.isKeyDown(rl.KeyboardKey.h)) {
                const v = .{ .x = -deta, .y = 0 };
                @field(gst, nst).rs.items[gst.editor.selected].rect.width += v.x;
                @field(gst, nst).rs.items[gst.editor.selected].rect.height += v.y;
            }

            if (rl.isKeyDown(rl.KeyboardKey.l)) {
                const v = .{ .x = deta, .y = 0 };
                @field(gst, nst).rs.items[gst.editor.selected].rect.width += v.x;
                @field(gst, nst).rs.items[gst.editor.selected].rect.height += v.y;
            }

            if (rl.isKeyDown(rl.KeyboardKey.j)) {
                const v = .{ .x = 0, .y = deta };
                @field(gst, nst).rs.items[gst.editor.selected].rect.width += v.x;
                @field(gst, nst).rs.items[gst.editor.selected].rect.height += v.y;
            }

            if (rl.isKeyDown(rl.KeyboardKey.k)) {
                const v = .{ .x = 0, .y = -deta };
                @field(gst, nst).rs.items[gst.editor.selected].rect.width += v.x;
                @field(gst, nst).rs.items[gst.editor.selected].rect.height += v.y;
            }

            if (rl.isKeyDown(rl.KeyboardKey.c)) {
                gst.log("Copy!");
                gst.editor.copyed_rect = @field(gst, nst).rs.items[gst.editor.selected];
            }

            if (rl.isKeyDown(rl.KeyboardKey.d)) {
                gst.log("Delete!");
                _ = @field(gst, nst).rs.swapRemove(gst.editor.selected);
                return .ToIdle;
            }

            if (rl.isMouseButtonPressed(rl.MouseButton.right) or
                rl.isKeyPressed(rl.KeyboardKey.enter))
            {
                return .Edit;
            }

            return null;
        }
    };
}

pub fn editST(target: typedFsm.sdzx(Example)) type {
    return union(enum) {
        ToSelected: WitRow(SDZX.C(Example.selected, &.{target})),

        pub fn handler(gst: *GST) void {
            switch (gui(target, @This(), gst)) {
                .ToSelected => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *GST) ?@This() {
            const nst = comptime getTarget(target);
            const ptr = &@field(gst, nst).rs.items[gst.editor.selected];
            var rect = ptr.rect;

            rect.y += 40;

            _ = rg.textBox(
                rect,
                &@field(gst, nst).rs.items[gst.editor.selected].str_buf,
                20,
                true,
            );

            if (@hasDecl(@field(Example, nst ++ "ST"), "action_list")) {
                rect.y += 40;
                rect.width = 150;
                rect.height = 40;

                const drop_str = comptime blk: {
                    var buf: [500:0]u8 = @splat(0);
                    var offset: usize = 0;
                    const action_list = @field(@field(Example, nst ++ "ST"), "action_list");
                    for (action_list, 0..) |val, i| {
                        const name = val.name;
                        @memcpy(buf[offset .. offset + name.len], name);
                        offset = offset + name.len;
                        if (i != action_list.len - 1) {
                            buf[offset] = ';';
                            offset += 1;
                        }
                    }
                    break :blk buf;
                };
                if (rg.dropdownBox(rect, &drop_str, &ptr.action_id, ptr.action_select) == 1) {
                    ptr.action_select = !ptr.action_select;
                }
            }
            if (!ptr.action_select) {
                rect.y += 40;
                rect.width = 150;
                rect.height = 300;

                _ = rg.colorPicker(
                    rect,
                    "color",
                    &@field(gst, nst).rs.items[gst.editor.selected].color,
                );
            }
            const size = rl.measureText(&@field(gst, nst).rs.items[gst.editor.selected].str_buf, 32);
            @field(gst, nst).rs.items[gst.editor.selected].rect.width = @max(32, @as(f32, @floatFromInt(size)));

            if (rl.isKeyPressed(rl.KeyboardKey.enter) or
                rl.isKeyPressed(rl.KeyboardKey.caps_lock) or
                rl.isKeyPressed(rl.KeyboardKey.escape))
            {
                return .ToSelected;
            }
            return null;
        }
    };
}
