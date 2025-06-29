const std = @import("std");
const polystate = @import("polystate");
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

pub const Animation = struct {
    total_time: f32 = 150,
    start_time: i64 = 0,
};

pub fn animation_list_r(
    screen_width: f32,
    screen_height: f32,
    items: []const R,
    duration: f32,
    total_time: f32,
    b: bool,
) void {
    _ = screen_height;
    const deta: f32 = screen_width / total_time * duration;
    for (items) |*r| {
        var rect = r.rect;
        if (b) {
            rect.x -= deta;
        } else {
            rect.x = rect.x + screen_width - deta;
        }
        _ = rl.drawText(&r.str_buf, @intFromFloat(rect.x), @intFromFloat(rect.y), 32, r.color);
    }
}

pub fn animationST(from: SDZX, to: SDZX) type {
    return union(enum) {
        animation_end: WitRow(to),

        const from_t = getTarget(from);
        const to_t = getTarget(to);

        pub fn conthandler(gst: *GST) core.ContR {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .animation_end => |wit| return .{ .Next = wit.conthandler() },
                }
            } else return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                gst.log("skip animation");
                return .animation_end;
            }

            const duration: f32 = @floatFromInt(std.time.milliTimestamp() - gst.animation.start_time);
            var buf: [20]u8 = undefined;
            gst.log_duration(std.fmt.bufPrint(&buf, "duration: {d:.2}", .{duration}) catch "too long!", 10);
            @field(gst, from_t).animation(gst.screen_width, gst.screen_height, duration, gst.animation.total_time, true);
            @field(gst, to_t).animation(gst.screen_width, gst.screen_height, duration, gst.animation.total_time, false);

            if (duration > gst.animation.total_time - 1000 / 60) {
                return .animation_end;
            }
            return null;
        }
    };
}
