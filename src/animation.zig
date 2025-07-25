const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const Example = core.Example;

const rl = @import("raylib");
const rg = @import("raygui");

const Context = core.Context;
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

        pub fn handler(ctx: *Context) @This() {
            if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                ctx.log("skip animation");
                return .animation_end;
            }

            const duration: f32 = @floatFromInt(std.time.milliTimestamp() - ctx.animation.start_time);
            var buf: [20]u8 = undefined;
            ctx.log_duration(std.fmt.bufPrint(&buf, "duration: {d:.2}", .{duration}) catch "too long!", 10);
            from.animation(ctx, ctx.screen_width, ctx.screen_height, duration, ctx.animation.total_time, true);
            to.animation(ctx, ctx.screen_width, ctx.screen_height, duration, ctx.animation.total_time, false);

            if (duration > ctx.animation.total_time - 1000 / 60) {
                return .animation_end;
            }
            return .no_trasition;
        }
    };
}
