const std = @import("std");
const polystate = @import("polystate");
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
const ContR = polystate.ContR(GST);
const Action = core.Action;
const SaveData = utils.SaveData;
const RS = core.RS;

pub const Menu = struct {
    rs: RS = .empty,

    pub fn animation(self: *const @This(), screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }
};
pub const menuST = union(enum) {
    // zig fmt: off
    Exit:     Wit(Example.exit),
    ToEditor: Wit(.{Example.select, Example.menu,  .{Example.edit, Example.menu}}),
    ToPlay:   Wit(.{ Example.animation, Example.menu, Example.map }),
    ToTextures: Wit(Example.textures),
    // zig fmt: on

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .Exit => |wit| return .{ .Next = wit.conthandler() },
                .ToEditor => |wit| return .{ .Next = wit.conthandler() },
                .ToTextures => |wit| return .{ .Next = wit.conthandler() },
                .ToPlay => |wit| {
                    gst.animation.start_time = std.time.milliTimestamp();
                    return .{ .Next = wit.conthandler() };
                },
            }
        } else return .Wait;
    }
    fn genMsg(gst: *GST) ?@This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .ToEditor;
        if (rl.isKeyPressed(rl.KeyboardKey.t)) return .ToTextures;
        for (gst.menu.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        return null;
    }

    // zig fmt: off
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor",    .val = .{ .Button = toEditor  } },
        .{ .name = "Exit",      .val = .{ .Button = exit      } },
        .{ .name = "Play",      .val = .{ .Button = toPlay    } },
        .{ .name = "Log hello", .val = .{ .Button = log_hello } },
        .{ .name = "Save data", .val = .{ .Button = saveData  } },
        .{ .name = "animation", .val = .{ .Slider = .{.fun =  animation_duration_ref, .min = 50, .max = 5000}  } },
    };
    // zig fmt: on

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
};
