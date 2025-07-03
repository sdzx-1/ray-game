const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const Example = core.Example;

const rl = @import("raylib");
const rg = @import("raygui");

const GST = core.GST;
const R = core.R;

pub const AnimationData = struct {
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

pub fn Animation(
    from: type,
    to: type,
) type {
    return union(enum) {
        animation_end: Example(.next, to),
        no_trasition: Example(.next, @This()),

        pub fn handler(gst: *GST) @This() {
            if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                gst.log("skip animation");
                return .animation_end;
            }

            const duration: f32 = @floatFromInt(std.time.milliTimestamp() - gst.animation.start_time);
            var buf: [20]u8 = undefined;
            gst.log_duration(std.fmt.bufPrint(&buf, "duration: {d:.2}", .{duration}) catch "too long!", 10);
            from.animation(gst, gst.screen_width, gst.screen_height, duration, gst.animation.total_time, true);
            to.animation(gst, gst.screen_width, gst.screen_height, duration, gst.animation.total_time, false);

            if (duration > gst.animation.total_time - 1000 / 60) {
                return .animation_end;
            }
            return .no_trasition;
        }
    };
}
