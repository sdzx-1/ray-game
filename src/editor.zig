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

pub const Editor = struct {
    copyed_rect: ?R = null,
};

fn gui(comptime target: SDZX, cst: type, gst: *GST) ?cst {
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

    if (@hasDecl(cst, "genMsg")) return cst.genMsg(gst);

    return null;
}

const ContR = typedFsm.ContR(GST);

pub fn selected_button(target: SDZX) type {
    return union(enum) {
        ToEdit: WitRow(SDZX.C(Example.edit, &.{target})),

        pub fn conthandler(gst: *GST) ContR {
            switch (genMsg(gst)) {
                .ToEdit => |wit| return .{ .Next = wit.conthandler() },
            }
        }

        pub fn genMsg(gst: *GST) @This() {
            _ = gst;
            return .ToEdit;
        }

        const nst = getTarget(target);

        fn render_all(gst: *GST) void {
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
        }

        pub fn check_inside(gst: *GST) select.CheckInsideResult {
            render_all(gst);

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
                    gst.selected_id = i;
                    return .in_someone;
                }
            }
            return .not_in_any_rect;
        }

        pub fn check_still_inside(gst: *GST) bool {
            render_all(gst);

            const r = @field(gst, nst).rs.items[gst.selected_id];

            if (rl.isKeyDown(rl.KeyboardKey.c)) {
                gst.log("Copy!");
                gst.editor.copyed_rect = r;
            }

            if (rl.isKeyDown(rl.KeyboardKey.d)) {
                gst.log("Delete!");
                _ = @field(gst, nst).rs.swapRemove(gst.selected_id);
                return false;
            }

            rl.drawRectangleLines(
                @intFromFloat(r.rect.x - 1),
                @intFromFloat(r.rect.y - 1),
                @intFromFloat(r.rect.width + 2),
                @intFromFloat(r.rect.height + 2),
                rl.Color.blue,
            );

            return r.inR(rl.getMousePosition());
        }

        pub fn hover(gst: *GST) void {
            const ptr: *R = &@field(gst, nst).rs.items[gst.selected_id];
            if (@hasDecl(@field(Example, nst ++ "ST"), "action_list") and
                ptr.enable_action)
            {
                const action_list = @field(@field(Example, nst ++ "ST"), "action_list");
                const str = action_list[@as(usize, @intCast(ptr.action_id))].name;

                var tmpBuf: [100]u8 = undefined;
                const str1 = std.fmt.bufPrintZ(&tmpBuf, "{s}", .{str}) catch unreachable;
                const tsize = rl.measureText(str1, 32);

                const mp = rl.getMousePosition();
                const x = @as(i32, @intFromFloat(mp.x)) - @divTrunc(tsize, 2);
                const y = @as(i32, @intFromFloat(mp.y)) - 50;

                rl.drawText(str1, x, y, 52, rl.Color.black);
            }
        }
    };
}

pub fn editST(target: SDZX) type {
    return union(enum) {
        Finish: WitRow(target),
        ToOutside: WitRow(SDZX.C(Example.select, &.{ target, SDZX.C(Example.selected_button, &.{target}) })),

        pub fn conthandler(gst: *GST) ContR {
            if (gui(target, @This(), gst)) |msg| {
                switch (msg) {
                    .Finish => |wit| return .{ .Next = wit.conthandler() },
                    .ToOutside => |wit| return .{ .Next = wit.conthandler() },
                }
            } else return .Wait;
        }

        const nst = getTarget(target);

        fn genMsg(gst: *GST) ?@This() {
            const ptr: *R = &@field(gst, nst).rs.items[gst.selected_id];
            var rect = ptr.rect;

            rect.y += 40;

            rg.setStyle(.default, .{ .default = .text_size }, 20);
            _ = rg.textBox(rect, &ptr.str_buf, 20, true);
            rg.setStyle(.default, .{ .default = .text_size }, 30);

            rect.y += 40;
            rect.width = 40;
            _ = rg.checkBox(rect, "enbale", &ptr.enable_action);

            if (@hasDecl(@field(Example, nst ++ "ST"), "action_list") and
                ptr.enable_action)
            {
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
                    &ptr.color,
                );
            }
            const size = rl.measureText(&ptr.str_buf, 32);
            ptr.rect.width = @max(32, @as(f32, @floatFromInt(size)));

            if (rl.isKeyPressed(rl.KeyboardKey.escape)) return .Finish;
            if (rl.isKeyPressed(rl.KeyboardKey.enter) or
                rl.isKeyPressed(rl.KeyboardKey.caps_lock)) return .ToOutside;

            if (rl.isMouseButtonDown(rl.MouseButton.left)) {
                const v = rl.getMouseDelta();
                ptr.rect.x += v.x;
                ptr.rect.y += v.y;
            }

            return null;
        }
    };
}

// const deta: f32 = 1.4;
//             if (rl.isKeyDown(rl.KeyboardKey.h)) {
//                 const v = .{ .x = -deta, .y = 0 };
//                 r.rect.width += v.x;
//                 r.rect.height += v.y;
//             }

//             if (rl.isKeyDown(rl.KeyboardKey.l)) {
//                 const v = .{ .x = deta, .y = 0 };
//                 r.rect.width += v.x;
//                 r.rect.height += v.y;
//             }

//             if (rl.isKeyDown(rl.KeyboardKey.j)) {
//                 const v = .{ .x = 0, .y = deta };
//                 r.rect.width += v.x;
//                 r.rect.height += v.y;
//             }

//             if (rl.isKeyDown(rl.KeyboardKey.k)) {
//                 const v = .{ .x = 0, .y = -deta };
//                 r.rect.width += v.x;
//                 r.rect.height += v.y;
//             }
