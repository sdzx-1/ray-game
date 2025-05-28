pub const Play = struct {
    rs: RS = .empty,
    maze: Maze = undefined,

    pub fn animation(self: *const @This(), duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(self.rs.items, duration, total, b);
    }
};

pub const playST = union(enum) {
    ToEditor: Wit(.{ Example.idle, Example.play }),
    ToMenu: Wit(Example.menu),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToMenu => |wit| return .{ .Next = wit.conthandler() },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        for (gst.play.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
        if (rl.isKeyPressed(rl.KeyboardKey.m)) return .ToMenu;
        return null;
    }

    fn toEditor(_: *GST) ?@This() {
        return .ToEditor;
    }
    fn toMenu(_: *GST) ?@This() {
        return .ToMenu;
    }

    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor", .val = .{ .Fun = toEditor } },
        .{ .name = "Menu", .val = .{ .Fun = toMenu } },
    };
};

const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
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
const RS = core.RS;
const maze = @import("maze");
const Maze = maze.Maze;
