const std = @import("std");
const typedFsm = @import("typed_fsm");
const editor = @import("editor.zig");
const map = @import("map.zig");
const play = @import("play.zig");
const menu = @import("menu.zig");
const animation = @import("animation.zig");
const utils = @import("utils.zig");

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
    enable_action: bool = false,
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
                    const minVal = std.fmt.bufPrintZ(&buf, "{d:.1}", .{val.min}) catch unreachable;
                    const maxVal = std.fmt.bufPrintZ(&buf1, "{d:.1}", .{val.max}) catch unreachable;
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

pub const RS = std.ArrayListUnmanaged(R);

pub fn getTarget(comptime target: Example.SDZX) []const u8 {
    const nst = switch (target) {
        .Term => |v| @tagName(v),
        .Fun => |val| @tagName(val.fun),
    };
    return nst;
}

pub const GST = struct {
    gpa: std.mem.Allocator,
    screen_width: f32 = 1000,
    screen_height: f32 = 800,
    hdw: f32 = 800.0 / 1000.0,
    random: std.Random,
    editor: editor.Editor = .{},
    menu: menu.Menu = .{},
    map: map.Map = .{},
    play: play.Play,
    animation: animation.Animation = .{},

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
    map,
    play,

    //
    animation,

    //editor
    idle,
    in_rect,
    selected,
    edit,

    pub const playST = play.playST;

    pub fn animationST(from: SDZX, to: SDZX) type {
        return animation.animationST(from, to);
    }

    pub const mapST = map.mapST;

    pub const menuST = menu.menuST;

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
            utils.saveData(gst);
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
