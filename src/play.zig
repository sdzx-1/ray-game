const std = @import("std");
const typedFsm = @import("typed_fsm");
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
const ContR = typedFsm.ContR(GST);
const Action = core.Action;

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
