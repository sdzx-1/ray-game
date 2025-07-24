const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const utils = @import("utils.zig");
const anim = @import("animation.zig");
const Select = core.Select;
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

    pub fn animation(self: *const MenuData, screen_width: f32, screen_height: f32, duration: f32, total: f32, b: bool) void {
        anim.animation_list_r(screen_width, screen_height, self.rs.items, duration, total, b);
    }

    pub fn render(self: *MenuData) ?Menu {
        const gst = self.parentGst();
        for (self.rs.items) |*r| {
            if (r.render(gst, Menu, action_list)) |msg| {
                return msg;
            }
        }
        return null;
    }

    fn parentGst(self: *MenuData) *GST {
        return @alignCast(@fieldParentPtr("menu", self));
    }

    pub const action_list: []const (Action(Menu)) = &.{
        .{ .name = "Editor", .val = .{ .button = Menu.toEditor } },
        .{ .name = "Exit", .val = .{ .button = Menu.exit } },
        .{ .name = "Play", .val = .{ .button = Menu.toPlay } },
        .{ .name = "Log hello", .val = .{ .button = Menu.log_hello } },
        .{ .name = "Save data", .val = .{ .button = Menu.saveData } },
        .{ .name = "animation", .val = .{ .slider = .{ .fun = Menu.animation_duration_ref, .min = 50, .max = 5000 } } },
        .{ .name = "View textures", .val = .{ .button = Menu.toTextures } },
    };
};
pub const Menu = union(enum) {
    // zig fmt: off
    exit1       : Example(.next, ps.Exit),
    to_editor   : Example(.next, Select(Menu, Editor(Menu))),
    to_play     : Example(.next, Animation(Menu, Map)),
    to_textures : Example(.next, Textures),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    pub const gst_field: std.meta.FieldEnum(GST) = .menu;

    pub fn handler(gst: *GST) @This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;

        if (gst.menu.render()) |transition| {
            return transition;
        }

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
        .{ .name = "View textures",   .val = .{ .button = toTextures    } },
    };
    // zig fmt: on

    fn saveData(gst: *GST) ?@This() {
        utils.saveData(gst);
        return null;
    }

    fn toTextures(_: *GST) ?@This() {
        return .to_textures;
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
