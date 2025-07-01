const std = @import("std");
const polystate = @import("polystate");
const select = @import("select.zig");
const editor = @import("editor.zig");
const map = @import("map.zig");
const play = @import("play.zig");
const menu = @import("menu.zig");
const tbuild = @import("tbuild.zig");
const textures = @import("textures.zig");
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
    dropdown_box: bool = false,

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
                .button => |fun| if (rg.button(r.rect, &r.str_buf)) if (fun(gst)) |val| return val,
                .slider => |val| {
                    var buf: [30]u8 = undefined;
                    var buf1: [30]u8 = undefined;
                    const minVal = std.fmt.bufPrintZ(&buf, "{d:.1}", .{val.min}) catch unreachable;
                    const maxVal = std.fmt.bufPrintZ(&buf1, "{d:.1}", .{val.max}) catch unreachable;
                    const ref = val.fun(gst);
                    _ = rg.slider(r.rect, minVal, maxVal, ref, val.min, val.max);
                },
                .dropdown_box => |val| {
                    const ref = val.fun(gst);
                    if (rg.dropdownBox(r.rect, val.text, ref, r.dropdown_box) == 1) {
                        r.dropdown_box = !r.dropdown_box;
                    }
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

pub const GST = struct {
    gpa: std.mem.Allocator,
    screen_width: f32 = 1000,
    screen_height: f32 = 800,
    hdw: f32 = 800.0 / 1000.0,
    random: std.Random,
    select: select.SelectData = .{},
    editor: editor.EditorData = .{},
    menu: menu.MenuData = .{},
    map: map.MapData = .{},
    play: play.PlayData,
    tbuild: tbuild.TbuildData = .{},
    animation: animation.AnimationData = .{},
    textures: textures.TexturesData,
    sel_texture: textures.SetTextureData = .{},

    //
    notify: Notify = .{},
    im_log_buf: [60:0]u8 = @splat(0),
    tmp_buf: []u8,

    pub fn log(self: *@This(), str: []const u8) void {
        self.log_duration(str, 600);
    }

    pub fn printZ(self: *@This(), comptime fmt: []const u8, args: anytype) [:0]u8 {
        return std.fmt.bufPrintZ(self.tmp_buf, fmt, args) catch unreachable;
    }

    pub fn log_duration(self: *@This(), str: []const u8, dur: i64) void {
        const msg = std.fmt.allocPrintZ(self.gpa, "{s}", .{str}) catch unreachable;
        self.notify.msg_que.append(
            self.gpa,
            .{ .msg = msg, .dur = dur },
        ) catch unreachable;
    }

    pub fn log_im(self: *@This(), str: []const u8) void {
        _ = std.fmt.bufPrintZ(&self.im_log_buf, "{s}", .{str}) catch &self.im_log_buf;
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
        button: *const fn (*GST) ?cst,
        slider: struct { fun: *const fn (*GST) *f32, min: f32, max: f32 },
        dropdown_box: struct { fun: *const fn (*GST) *i32, text: [:0]const u8 },
    };
}

pub fn Action(cst: type) type {
    return struct {
        name: []const u8,
        val: ActionVal(cst),
    };
}

fn enter_fn(gst: *GST, state: type) void {
    gst.log_im(gst.printZ("{s}", .{@typeName(state)}));
}
pub fn Example(state: type) type {
    return polystate.FSM("Example", GST, enter_fn, state);
}
