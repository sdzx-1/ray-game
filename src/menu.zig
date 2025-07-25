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
const Context = core.Context;
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
    to_editor   : Example(.next, Select(Menu, Editor(Menu))),
    to_play     : Example(.next, Animation(Menu, Map)),
    to_textures : Example(.next, Textures),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;
        for (ctx.menu.rs.items) |*r| if (r.render(ctx, @This(), action_list)) |msg| return msg;
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

    pub fn animation(
        ctx: *Context,
        screen_width: f32,
        screen_height: f32,
        duration: f32,
        total: f32,
        b: bool,
    ) void {
        anim.animation_list_r(
            screen_width,
            screen_height,
            ctx.menu.rs.items,
            duration,
            total,
            b,
        );
    }

    pub fn access_rs(ctx: *Context) *RS {
        return &ctx.menu.rs;
    }

    fn saveData(ctx: *Context) ?@This() {
        utils.saveData(ctx);
        return null;
    }

    fn toTextures(_: *Context) ?@This() {
        return .to_textures;
    }

    fn toEditor(_: *Context) ?@This() {
        return .to_editor;
    }

    fn toPlay(ctx: *Context) ?@This() {
        ctx.animation.start_time = std.time.milliTimestamp();
        return .to_play;
    }

    fn exit(_: *Context) ?@This() {
        return .exit1;
    }

    fn log_hello(ctx: *Context) ?@This() {
        ctx.log("hello!!!!");
        return null;
    }

    fn animation_duration_ref(ctx: *Context) *f32 {
        return &ctx.animation.total_time;
    }
};
