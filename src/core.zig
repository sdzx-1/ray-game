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
    select: select.Select = .{},
    editor: editor.Editor = .{},
    menu: menu.Menu = .{},
    map: map.Map = .{},
    play: play.Play,
    tbuild: tbuild.Tbuild = .{},
    animation: animation.Animation = .{},
    textures: textures.Textures,
    sel_texture: textures.SelTexture = .{},

    //
    notify: Notify = .{},
    im_log_buf: [260:0]u8 = @splat(0),
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

pub const ContR = polystate.ContR(GST);

pub const Example = enum {
    exit,
    //
    menu,
    map,
    play,
    build,
    textures,
    sel_texture,
    place,
    x,

    //
    animation,

    //
    edit,

    //
    select,
    inside,
    hover,

    pub const sel_textureST = textures.sel_textureST;
    pub const texturesST = textures.texturesST;
    pub const buildST = tbuild.buildST;
    pub const menuST = menu.menuST;
    pub const mapST = map.mapST;
    pub const playST = play.playST;
    pub const placeST = play.placeST;
    pub const animationST = animation.animationST;
    pub const editST = editor.editST;

    pub const xST = play.xST;

    pub fn selectST(back: SDZX, selected: SDZX) type {
        return select.selectST(@This(), GST, enter_fn, back, selected);
    }
    pub fn insideST(back: SDZX, selected: SDZX) type {
        return select.insideST(@This(), GST, enter_fn, back, selected);
    }
    pub fn hoverST(back: SDZX, selected: SDZX) type {
        return select.hoverST(@This(), GST, enter_fn, back, selected);
    }
    pub const exitST = union(enum) {
        pub fn conthandler(gst: *GST) ContR {
            utils.saveData(gst);
            std.debug.print("exit\n", .{});
            return .Exit;
        }
    };

    fn enter_fn(cst: polystate.sdzx(@This()), gst: *GST) void {
        gst.log_im(gst.printZ("{}", .{cst}));
    }

    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), GST, enter_fn, polystate.val_to_sdzx(@This(), val));
    }

    pub fn WitRow(val: SDZX) type {
        return polystate.Witness(@This(), GST, enter_fn, val);
    }

    pub const SDZX = polystate.sdzx(@This());
};
