const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const utils = @import("utils.zig");
const anim = @import("animation.zig");
const Select = @import("select.zig").Select;
const Editor = @import("editor.zig").Editor;
const Animation = @import("animation.zig").Animation;
const Textures = @import("textures.zig").Textures;
const Map = @import("map.zig").Map;

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const GST = core.GST;
const R = core.R;
const Action = core.Action;
const SaveData = utils.SaveData;
const RS = core.RS;

pub const MenuData = struct {
    rs: RS = .empty,
};
pub const Menu = union(enum) {
    // zig fmt: off
    exit1       : Example(.next, ps.Exit),
    to_editor   : Example(.next, Select(Example, Menu, Editor(Example, Menu))),
    to_play     : Example(.next, Animation(Example, Menu, Map)),
    to_textures : Example(.next, Textures),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    pub fn handler(gst: *GST) @This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;
        if (rl.isKeyPressed(rl.KeyboardKey.t)) return .to_textures;
        for (gst.menu.rs.items) |*r| if (r.render(gst, @This(), action_list)) |msg| return msg;
        return .no_trasition;
    }

    // zig fmt: off
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor",    .val = .{ .button = toEditor  } },
        .{ .name = "Exit",      .val = .{ .button = exit      } },
        .{ .name = "Play",      .val = .{ .button = toPlay    } },
        .{ .name = "Log hello", .val = .{ .button = log_hello } },
        .{ .name = "Save data", .val = .{ .button = saveData  } },
        .{ .name = "animation", .val = .{ .slider = .{.fun =  animation_duration_ref, .min = 50, .max = 5000}  } },
    };
    // zig fmt: on

    pub fn animation(
        gst: *GST,
        screen_width: f32,
        screen_height: f32,
        duration: f32,
        total: f32,
        b: bool,
    ) void {
        anim.animation_list_r(
            screen_width,
            screen_height,
            gst.menu.rs.items,
            duration,
            total,
            b,
        );
    }

    pub fn access_rs(gst: *GST) *RS {
        return &gst.menu.rs;
    }

    fn saveData(gst: *GST) ?@This() {
        utils.saveData(gst);
        return null;
    }

    fn toEditor(_: *GST) ?@This() {
        return .to_editor;
    }

    fn toPlay(gst: *GST) ?@This() {
        gst.animation.start_time = std.time.milliTimestamp();
        return .to_play;
    }

    fn exit(_: *GST) ?@This() {
        return .exit1;
    }

    fn log_hello(gst: *GST) ?@This() {
        gst.log("hello!!!!");
        return null;
    }

    fn animation_duration_ref(gst: *GST) *f32 {
        return &gst.animation.total_time;
    }
};
