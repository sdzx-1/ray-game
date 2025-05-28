const std = @import("std");
const typedFsm = @import("typed_fsm");
const editor = @import("editor.zig");

const rl = @import("raylib");
const rg = @import("raygui");

pub const Notify = struct {
    msg_que: std.ArrayListUnmanaged(struct { msg: [:0]const u8, dur: i64 }) = .empty,
    duration: i64 = 600,
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
    enable_action: bool = true,
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

    pub fn render(r: *@This(), gst: *GST, cst: type, action_list: []const Action(cst)) ?cst {
        if (r.enable_action) {
            rg.setStyle(.button, .{ .control = .text_color_normal }, r.color.toInt());
            const action_ptr = &action_list[@intCast(r.action_id)];
            switch (action_ptr.val) {
                .Fun => |fun| if (rg.button(r.rect, &r.str_buf)) if (fun(gst)) |val| return val,
                .Ptr_f32 => |val| {
                    var buf: [30]u8 = undefined;
                    var buf1: [30]u8 = undefined;
                    const minVal = std.fmt.bufPrintZ(&buf, "{d}", .{val.min}) catch unreachable;
                    const maxVal = std.fmt.bufPrintZ(&buf1, "{d}", .{val.max}) catch unreachable;
                    const ref = val.fun(gst);
                    _ = rg.slider(r.rect, minVal, maxVal, ref, val.min, val.max);
                },
            }
            rg.setStyle(.button, .{ .control = .text_color_normal }, rl.Color.black.toInt());
        } else {
            _ = rl.drawText(&r.str_buf, @intFromFloat(r.rect.x), @intFromFloat(r.rect.y), 32, r.color);
        }

        return null;
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

const RS = std.ArrayListUnmanaged(R);

pub const Menu = struct {
    rs: RS = .empty,

    pub fn animation(self: *const @This(), deta: f32, b: bool) void {
        animation_list_r(self.rs.items, deta, b);
    }
};

pub const Play = struct {
    rs: RS = .empty,

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
        self.log_duration(str, 600);
    }

    pub fn log_duration(self: *@This(), str: []const u8, dur: i64) void {
        const msg = std.fmt.allocPrintZ(self.gpa, "{s}", .{str}) catch unreachable;
        self.notify.msg_que.append(
            self.gpa,
            .{ .msg = msg, .dur = dur },
        ) catch unreachable;
    }

    pub fn log_im(self: *@This(), str: []const u8) void {
        _ = std.fmt.bufPrintZ(&self.im_log_buf, "{s}", .{str}) catch unreachable;
    }

    pub fn render_log(self: *@This()) void {
        const currt = std.time.milliTimestamp();
        if (currt - self.notify.last_time > self.notify.duration) {
            if (self.notify.current_msg) |cmsg| {
                self.gpa.free(cmsg);
                self.notify.current_msg = null;
            }

            if (self.notify.msg_que.pop()) |val| {
                self.notify.current_msg = val.msg;
                self.notify.duration = val.dur;
                self.notify.last_time = std.time.milliTimestamp();
            }
        }

        if (self.notify.current_msg) |cmsg| {
            rl.drawText(cmsg, 0, 0, 32, rl.Color.red);
        }

        rl.drawText(&self.im_log_buf, 0, 40, 32, rl.Color.red);
    }
};

pub fn ActionVal(cst: type) type {
    return union(enum) {
        Fun: *const fn (*GST) ?cst,
        Ptr_f32: struct {
            fun: *const fn (*GST) *f32,
            min: f32,
            max: f32,
        },
    };
}

pub fn Action(cst: type) type {
    return struct {
        name: []const u8,
        val: ActionVal(cst),
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
                        .End => |wit| return .{ .Next = wit.conthandler() },
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
                gst.log_duration(std.fmt.bufPrint(&buf, "duration: {d:.2}", .{deta_time}) catch "too long!", 10);
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
        // zig fmt: off
        Exit:     Wit(Example.exit),
        ToEditor: Wit(.{ Example.idle, Example.play }),
        ToMenu:   Wit(.{ Example.animation, Example.play, Example.menu }),
        ToPlay:   Wit(.{ Example.animation, Example.play, Example.play }),

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .Exit     => |wit| return .{ .Next = wit.conthandler() },
                    .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                    .ToMenu   => |wit| {
                        gst.animation.start_time = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                    .ToPlay   => |wit| {
                        gst.animation.start_time = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                }
            } else return .Wait;
        }
        // zig fmt: on
        fn genMsg(gst: *GST) ?@This() {
            for (gst.play.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
            if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
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

        // zig fmt: off
        pub const action_list: []const (Action(@This())) = &.{
            .{ .name = "Editor",  .val = .{ .Fun = toEditor } },
            .{ .name = "Menu",    .val = .{ .Fun = toMenu } },
            .{ .name = "Exit",    .val = .{ .Fun = exit } },
        };
        // zig fmt: on
    };

    pub const menuST = union(enum) {
        // zig fmt: off
        Exit:     Wit(Example.exit),
        ToEditor: Wit(.{ Example.idle, Example.menu }),
        ToPlay:   Wit(.{ Example.animation, Example.menu, Example.play }),

        pub fn conthandler(gst: *GST) ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .Exit     => |wit| return .{ .Next = wit.conthandler() },
                    .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                    .ToPlay   => |wit| {
                        gst.animation.start_time = std.time.milliTimestamp();
                        return .{ .Next = wit.conthandler() };
                    },
                }
            } else return .Wait;
        }
        // zig fmt: on
        fn genMsg(gst: *GST) ?@This() {
            for (gst.menu.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
            if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
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

        fn animation_duration_ref(gst: *GST) *f32 {
            return &gst.animation.total_time;
        }

        // zig fmt: off
        pub const action_list: []const (Action(@This())) = &.{
            .{ .name = "Editor",    .val = .{ .Fun = toEditor  } },
            .{ .name = "Exit",      .val = .{ .Fun = exit      } },
            .{ .name = "Play",      .val = .{ .Fun = toPlay    } },
            .{ .name = "Log hello", .val = .{ .Fun = log_hello } },
            .{ .name = "Save data", .val = .{ .Fun = saveData  } },
            .{ .name = "animation", .val = .{ .Ptr_f32 = .{.fun =  animation_duration_ref, .min = 50, .max = 5000}  } },
        };
        // zig fmt: on
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
