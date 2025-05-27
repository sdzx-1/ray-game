const std = @import("std");
const typedFsm = @import("typed_fsm");
const editor = @import("editor.zig");

const rl = @import("raylib");
const rg = @import("raygui");

pub const Notify = struct {
    msg_que: std.ArrayListUnmanaged([:0]const u8) = .empty,
    last_time: i64 = 0,
    current_msg: ?[:0]const u8 = null,
};

pub const R = struct {
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 100, .height = 40 },
    str_buf: [60:0]u8 = blk: {
        var tmp: [60:0]u8 = @splat(0);
        @memcpy(tmp[0..5], "empty");
        break :blk tmp;
    },
    color: rl.Color = rl.Color.black,
    action_id: i32 = 0,
    action_select: bool = false,

    pub fn inR(self: *const R, pos: rl.Vector2) bool {
        const r = self.rect;
        if (pos.x > r.x and
            pos.x < r.x + r.width and
            pos.y > r.y and
            pos.y < r.y + r.height) return true;
        return false;
    }
};

fn animation_list_r(items: []const R, deta: f32, b: bool) void {
    for (items) |*r| {
        rg.setStyle(.button, .{ .control = .text_color_normal }, r.color.toInt());
        var rect = r.rect;
        if (b) {
            rect.x -= deta;
        } else {
            rect.x = rect.x + 1000 - deta;
        }
        _ = rg.button(rect, &r.str_buf);
        rg.setStyle(.button, .{ .control = .text_color_normal }, rl.Color.black.toInt());
    }
}

pub const Menu = struct {
    rs: std.ArrayListUnmanaged(R) = .empty,

    pub fn animation(self: *const @This(), deta: f32, b: bool) void {
        animation_list_r(self.rs.items, deta, b);
    }
};

pub const Play = struct {
    rs: std.ArrayListUnmanaged(R) = .empty,

    pub fn animation(self: *const @This(), deta: f32, b: bool) void {
        animation_list_r(self.rs.items, deta, b);
    }
};

pub const Animation = struct {
    total_time: f32 = 150,
    start_time: i64 = 0,
};

pub fn getTarget(comptime target: Example.SDZX) []const u8 {
    const nst = switch (target) {
        .Term => |v| @tagName(v),
        .Fun => |val| @tagName(val.fun),
    };
    return nst;
}

pub const GST = struct {
    gpa: std.mem.Allocator,
    editor: editor.Editor = .{},
    menu: Menu = .{},
    play: Play = .{},
    animation: Animation = .{},

    //
    notify: Notify = .{},
    im_log_buf: [60:0]u8 = @splat(0),

    pub fn log(self: *@This(), str: []const u8) void {
        self.notify.msg_que.append(
            self.gpa,
            std.fmt.allocPrintZ(self.gpa, "{s}", .{str}) catch unreachable,
        ) catch unreachable;
    }

    pub fn log_im(self: *@This(), str: []const u8) void {
        _ = std.fmt.bufPrintZ(&self.im_log_buf, "{s}", .{str}) catch unreachable;
    }

    pub fn render_log(self: *@This()) void {
        const currt = std.time.milliTimestamp();
        if (currt - self.notify.last_time > 600) {
            if (self.notify.current_msg) |cmsg| {
                self.gpa.free(cmsg);
                self.notify.current_msg = null;
            }

            if (self.notify.msg_que.pop()) |cmsg| {
                self.notify.current_msg = cmsg;
                self.notify.last_time = std.time.milliTimestamp();
            }
        }

        if (self.notify.current_msg) |cmsg| {
            rl.drawText(cmsg, 0, 0, 32, rl.Color.red);
        }

        rl.drawText(&self.im_log_buf, 0, 40, 32, rl.Color.red);
    }
};

pub fn Action(cst: type) type {
    return struct {
        name: []const u8,
        fun: *const fn (*GST) ?cst,
    };
}

pub const ContR = typedFsm.ContR(GST);

pub const Example = enum {
    exit,
    //
    menu,
    play,

    //
    animation,

    //editor
    idle,
    in_rect,
    selected,
    edit,

    pub fn animationST(from: SDZX, to: SDZX) type {
        return union(enum) {
            End: WitRow(to),

            const from_t = getTarget(from);
            const to_t = getTarget(to);

            pub fn conthandler(gst: *GST) ContR {
                if (genMsg(gst)) |msg| {
                    switch (msg) {
                        .End => |wit| {
                            return .{ .Next = wit.conthandler() };
                        },
                    }
                } else return .Wait;
            }

            fn genMsg(gst: *GST) ?@This() {
                if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                    gst.log("skip animation");
                    return .End;
                }

                const deta_time: f32 = @floatFromInt(std.time.milliTimestamp() - gst.animation.start_time);
                var buf: [20]u8 = undefined;
                gst.log_im(std.fmt.bufPrint(&buf, "duration: {d:.2}", .{deta_time}) catch "too long!");
                const deta: f32 = 1000 / gst.animation.total_time * deta_time;
                @field(gst, from_t).animation(deta, true);
                @field(gst, to_t).animation(deta, false);

                if (deta_time > gst.animation.total_time - 1000 / 60) {
                    return .End;
                }
                return null;
            }
        };
    }

    pub const playST = union(enum) {
        Exit: Wit(Example.exit),
        ToEditor: Wit(.{ Example.idle, Example.play }),
        ToMenu: Wit(.{ Example.animation, Example.play, Example.menu }),
        ToPlay: Wit(.{ Example.animation, Example.play, Example.play }),

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .Exit => |wit| return .{ .Next = wit.conthandler() },
                    .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                    .ToMenu => |wit| {
                        gst.animation.start_time = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                    .ToPlay => |wit| {
                        gst.animation.start_time = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                }
            } else return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            for (gst.play.rs.items) |*r| {
                rg.setStyle(.button, .{ .control = .text_color_normal }, r.color.toInt());
                if (rg.button(r.rect, &r.str_buf)) {
                    if (action_list[@intCast(r.action_id)].fun(gst)) |val| {
                        return val;
                    }
                }
                rg.setStyle(.button, .{ .control = .text_color_normal }, rl.Color.black.toInt());
            }

            var rect: rl.Rectangle = .{ .x = 0, .y = 100, .width = 100, .height = 40 };

            if (rg.button(rect, "Editor")) return .ToEditor;

            rect.y += 50;
            if (rg.button(rect, "Exit")) return .Exit;
            if (rl.isKeyPressed(rl.KeyboardKey.q)) return .Exit;

            rect.y += 50;
            if (rg.button(rect, "Menu")) return .ToMenu;

            rect.y += 50;
            if (rg.button(rect, "Play")) return .ToPlay;

            return null;
        }

        fn toEditor(_: *GST) ?@This() {
            return .ToEditor;
        }

        fn toMenu(_: *GST) ?@This() {
            return .ToMenu;
        }

        fn exit(_: *GST) ?@This() {
            return .Exit;
        }

        pub const action_list: []const (Action(@This())) = &.{
            .{ .name = "Editor", .fun = toEditor },
            .{ .name = "Exit", .fun = exit },
            .{ .name = "Menu", .fun = toMenu },
        };
    };

    pub const menuST = union(enum) {
        Exit: Wit(Example.exit),
        ToEditor: Wit(.{ Example.idle, Example.menu }),
        ToPlay: Wit(.{ Example.animation, Example.menu, Example.play }),

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .Exit => |wit| return .{ .Next = wit.conthandler() },
                    .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                    .ToPlay => |wit| {
                        gst.animation.start_time = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                }
            } else return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            for (gst.menu.rs.items) |*r| {
                rg.setStyle(.button, .{ .control = .text_color_normal }, r.color.toInt());
                if (rg.button(r.rect, &r.str_buf)) {
                    if (action_list[@intCast(r.action_id)].fun(gst)) |val| {
                        return val;
                    }
                }
                rg.setStyle(.button, .{ .control = .text_color_normal }, rl.Color.black.toInt());
            }

            var rect: rl.Rectangle = .{ .x = 0, .y = 100, .width = 100, .height = 40 };

            if (rg.button(rect, "Editor")) return .ToEditor;

            rect.y += 50;
            if (rg.button(rect, "Exit")) return .Exit;
            if (rl.isKeyPressed(rl.KeyboardKey.q)) return .Exit;

            rect.y += 50;
            if (rg.button(rect, "Play")) return .ToPlay;

            rect.y += 50;
            if (rg.button(rect, "Save")) {
                _ = saveData(gst);
            }

            rect.y += 50;

            _ = rg.slider(rect, "", "Animation duration", &gst.animation.total_time, 140, 3500);
            return null;
        }

        fn saveData(gst: *GST) ?@This() {
            const save_data: SaveData = .{
                .menu = gst.menu.rs.items,
                .play = gst.play.rs.items,
            };
            save_data.save();
            gst.log("save");
            return null;
        }

        fn toEditor(_: *GST) ?@This() {
            return .ToEditor;
        }

        fn toPlay(_: *GST) ?@This() {
            return .ToPlay;
        }

        fn exit(_: *GST) ?@This() {
            return .Exit;
        }

        fn log_hello(gst: *GST) ?@This() {
            gst.log("hello!!!!");
            return null;
        }

        pub const action_list: []const (Action(@This())) = &.{
            .{ .name = "Editor", .fun = toEditor },
            .{ .name = "Exit", .fun = exit },
            .{ .name = "Play", .fun = toPlay },
            .{ .name = "Log hello", .fun = log_hello },
            .{ .name = "Save data", .fun = saveData },
        };
    };

    pub fn editST(target: SDZX) type {
        return editor.editST(target);
    }

    pub fn selectedST(target: SDZX) type {
        return editor.selectedST(target);
    }

    pub fn in_rectST(target: SDZX) type {
        return editor.in_rectST(target);
    }

    pub fn idleST(target: SDZX) type {
        return editor.idleST(target);
    }

    pub const exitST = union(enum) {
        pub fn conthandler(gst: *GST) ContR {
            _ = gst;
            std.debug.print("exit\n", .{});
            return .Exit;
        }
    };

    fn enter_fn(cst: typedFsm.sdzx(@This()), gst: *GST) void {
        var buf: [30]u8 = @splat(0);
        gst.log_im(std.fmt.bufPrintZ(&buf, "{}", .{cst}) catch unreachable);
    }

    pub fn Wit(val: anytype) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(@This(), val), GST, enter_fn);
    }

    pub fn WitRow(val: SDZX) type {
        return typedFsm.Witness(@This(), val, GST, enter_fn);
    }

    pub const SDZX = typedFsm.sdzx(@This());
};

pub const SaveData = struct {
    menu: []const R = &.{},
    play: []const R = &.{},

    pub fn save(self: *const @This()) void {
        const cwd = std.fs.cwd();
        const file = cwd.createFile("config.txt", .{}) catch unreachable;
        const writer = file.writer();
        std.json.stringify(self.*, .{ .whitespace = .indent_2 }, writer) catch unreachable;
    }

    pub fn load(gpa: std.mem.Allocator) SaveData {
        var arena_instance = std.heap.ArenaAllocator.init(gpa);
        defer arena_instance.deinit();
        const arena = arena_instance.allocator();

        const cwd = std.fs.cwd();

        if (cwd.access("config.txt", .{})) |_| {
            const file = cwd.openFile("config.txt", .{}) catch unreachable;
            const content = file.readToEndAlloc(arena, 5 << 20) catch unreachable;
            const parsed = std.json.parseFromSlice(@This(), arena, content, .{ .ignore_unknown_fields = true }) catch unreachable;
            const val = parsed.value;

            return .{
                .menu = gpa.dupe(R, val.menu) catch unreachable,
                .play = gpa.dupe(R, val.play) catch unreachable,
            };
        } else |_| {
            return .{};
        }
    }
};
