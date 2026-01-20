pub const MenuData = struct {
    rs: StateComponents(Menu) = .empty,
};

pub const Menu = union(enum) {
    // zig fmt: off
    exit1        : Data(.next, void, ps.Exit),
    to_editor    : Data(.next, void, Select(Menu, Editor(Menu))),
    to_play      : Data(.next, void, Map),
    to_build     : Data(.next, void, ViewBuilds(Menu)),
    view_textures: Data(.current, void, ViewTextures(Menu)),
    no_trasition : Data(.next, void, @This()),
    // zig fmt: on

    pub const info = core.example_info("Menu");

    pub fn handler(ctx: *Context) @This() {
        if (ctx.menu.rs.pull()) |msg| return msg;
        if (rl.isKeyPressed(rl.KeyboardKey.space)) return .to_editor;
        return .no_trasition;
    }

    pub fn render(ctx: *Context) void {
        ctx.menu.rs.render(ctx);
    }

    // zig fmt: off
    pub const action_list: []const (Action(@This())) = &.{
        .{ .name = "Editor",        .val = .{ .button = toEditor  } },
        .{ .name = "Exit",          .val = .{ .button = exit      } },
        .{ .name = "Play",          .val = .{ .button = toPlay    } },
        .{ .name = "Log hello",     .val = .{ .button = log_hello } },
        .{ .name = "Save data",     .val = .{ .button = saveData  } },
        .{ .name = "View textures", .val = .{ .button = toTextures} },
        .{ .name = "View build",    .val = .{ .button = toBuild   } },
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
        return .view_textures;
    }

    fn toBuild(_: *Context) ?@This() {
        return .to_build;
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

const std = @import("std");
const ps = @import("polystate");
const Data = ps.Data;
const core = @import("core.zig");
const utils = @import("utils.zig");
const Select = core.Select;
const Editor = @import("editor.zig").Editor;
const Map = @import("map.zig").Map;
const ViewTextures = @import("textures.zig").ViewTextures;
const ViewBuilds = @import("tbuild.zig").ViewBuilds;

const rl = @import("raylib");
const rg = @import("raygui");

const Context = core.Context;
const Action = core.Action;
const SaveData = utils.SaveData;
const StateComponents = core.StateComponents;
