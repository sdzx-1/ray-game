const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
const utils = @import("utils.zig");
const select = @import("select.zig");
const anim = @import("animation.zig");

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const Wit = Example.Wit;
const WitRow = Example.WitRow;
const SDZX = Example.SDZX;
const GST = core.GST;
const R = core.R;
const getTarget = core.getTarget;
const ContR = typedFsm.ContR(GST);
const Action = core.Action;
const SaveData = utils.SaveData;
const RS = core.RS;

pub const Menu = struct {
    rs: RS = .empty,
    select_id: usize = 0,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }
};
pub const menuST = union(enum) {
    // zig fmt: off
    Exit:     Wit(Example.exit),
    ToEditor: Wit(.{ Example.idle, Example.menu }),
    ToPlay:   Wit(.{ Example.animation, Example.menu, Example.map }),
    ToSelect: Wit(.{Example.outside, Example.menu,  Example.menu}),
    // zig fmt: on

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .Exit => |wit| return .{ .Next = wit.conthandler() },
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToPlay => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
                .ToSelect => |wit| return .{ .Next = wit.conthandler() },
            }
        } else return .Wait;
    }
    fn genMsg(gst: *GST) ?@This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
        if (rl.isKeyPressed(rl.KeyboardKey.s)) return .ToSelect;
        for (gst.menu.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        return null;
    }
    //

    fn render_all(gst: *GST) void {
        for (gst.menu.rs.items) |*r| {
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
        for (gst.menu.rs.items, 0..) |*r, i| {
            if (r.inR(rl.getMousePosition())) {
                gst.menu.select_id = i;
                return .in_someone;
            }
        }
        return .not_in_any_rect;
    }

    pub fn check_still_inside(gst: *GST) bool {
        render_all(gst);
        const r = gst.menu.rs.items[gst.menu.select_id];
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
        _ = gst;
    }

    //

    fn saveData(gst: *GST) ?@This() {
        utils.saveData(gst);
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
