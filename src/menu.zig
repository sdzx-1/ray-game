const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const utils = @import("utils.zig");
const Select = core.Select;
const Editor = @import("editor.zig").Editor;
const Textures = @import("textures.zig").Textures;
const Map = @import("map.zig").Map;

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const Context = core.Context;
const R = core.R;
const Action = core.Action;
const SaveData = utils.SaveData;
const StateComponents = core.StateComponents;

pub const MenuData = struct {
    rs: StateComponents(Menu) = .empty,
};
pub const Menu = union(enum) {
    // zig fmt: off
    exit1       : Example(.next, ps.Exit),
    to_editor   : Example(.next, Select(Menu, Editor(Menu))),
    to_play     : Example(.next, Map),
    to_textures : Example(.next, Textures),
    no_trasition: Example(.next, @This()),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        if (ctx.menu.rs.pull()) |msg| return msg;

        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;

        ctx.menu.rs.render(ctx);

        return .no_trasition;
    }

    // zig fmt: off
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor",    .val = .{ .button = toEditor  } },
        .{ .name = "Exit",      .val = .{ .button = exit      } },
        .{ .name = "Play",      .val = .{ .button = toPlay    } },
        .{ .name = "Log hello", .val = .{ .button = log_hello } },
        .{ .name = "Save data", .val = .{ .button = saveData  } },
        .{ .name = "View textures",   .val = .{ .button = toTextures    } },
    };
    // zig fmt: on

    pub fn access_rs(ctx: *Context) *StateComponents(Menu) {
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

    fn toPlay(_: *Context) ?@This() {
        return .to_play;
    }

    fn exit(_: *Context) ?@This() {
        return .exit1;
    }

    fn log_hello(ctx: *Context) ?@This() {
        ctx.log("hello!!!!");
        return null;
    }
};
