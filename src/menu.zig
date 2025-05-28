const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
const utils = @import("utils.zig");
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

    pub fn animation(self: *const @This(), duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(self.rs.items, duration, total, b);
    }
};
pub const menuST = union(enum) {
    // zig fmt: off
        Exit:     Wit(Example.exit),
        ToEditor: Wit(.{ Example.idle, Example.menu }),
        ToPlay:   Wit(.{ Example.animation, Example.menu, Example.map }),

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
