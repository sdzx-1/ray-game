const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const select = @import("select.zig");
const utils = @import("utils.zig");

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const Menu = @import("menu.zig").Menu;

const Context = core.Context;
const R = core.R;
const getTarget = core.getTarget;
const View = utils.View;

pub const TextureData = struct {
    name: [:0]const u8,
    tex2d: rl.Texture2D,
};

pub const Cell = union(enum) {
    texture: TextureData,
    blank: void,
    text_dir_name: [:0]const u8,
};

pub const Width = 20;
pub const Height = 90;

pub const TextArr = [Height][Width]Cell;

pub const TextID = struct {
    x: usize,
    y: usize,
};

pub fn arr_set_blank(ta: *TextArr) void {
    for (0..Height) |y| {
        for (0..Width) |x| {
            ta[y][x] = .blank;
        }
    }
}

pub const TexturesData = struct {
    text_arr: *TextArr,
    view: View = .{ .x = 0, .y = 0, .width = 25 },

    pub fn read(self: *const @This(), id: TextID) Cell {
        return self.text_arr[id.y][id.x];
    }

    pub fn deinit(self: *const @This()) void {
        for (0..Height) |y| {
            for (0..Width) |x| {
                const val = self.text_arr[y][x];
                switch (val) {
                    .texture => |text| {
                        text.tex2d.unload();
                    },
                    else => {},
                }
            }
        }
    }

    pub fn render(_: @This(), ctx: *Context) void {
        for (0..Height) |y| {
            for (0..Width) |x| {
                const val = ctx.textures.text_arr[y][x];
                const win_pos = ctx.textures.view.view_to_win(
                    ctx.screen_width,
                    .{ .x = @floatFromInt(x), .y = @floatFromInt(y) },
                );
                const worh = ctx.screen_width / ctx.textures.view.width;

                const view = ctx.textures.view;
                const r1: rl.Rectangle = .{ .x = view.x, .y = view.y, .width = view.width, .height = view.width * ctx.hdw };
                const r2: rl.Rectangle = .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = 1, .height = 1 };
                if (r1.checkCollision(r2)) {
                    switch (val) {
                        .blank => {},
                        .texture => |text| {
                            text.tex2d.drawPro(
                                .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                                .{ .x = win_pos.x, .y = win_pos.y, .width = worh, .height = worh },
                                .{ .x = 0, .y = 0 },
                                0,
                                rl.Color.white,
                            );
                        },
                        .text_dir_name => |name| {
                            rl.drawText(name, @intFromFloat(win_pos.x), @intFromFloat(win_pos.y), 20, rl.Color.green);
                        },
                    }
                }
            }
        }
    }
};

pub const Textures = union(enum) {
    to_menu: Example(.next, Menu),
    no_trasition: Example(.next, @This()),

    pub fn handler(ctx: *Context) @This() {
        {
            ctx.textures.view.mouse_wheel(ctx.hdw);
            ctx.textures.view.drag_view(ctx.screen_width);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            return .to_menu;
        }
        return .no_trasition;
    }

    pub fn render(ctx: *Context) void {
        ctx.textures.render(ctx);
    }
};

pub const SetTextureData = struct {
    text_id: TextID = .{ .x = 0, .y = 0 },
};

pub fn SetTexture(target: type) type {
    return union(enum) {
        to_target: Example(.current, target),

        pub fn handler(ctx: *Context) @This() {
            target.set_text_id(ctx, ctx.sel_texture.text_id);
            return .to_target;
        }

        pub fn select_render(ctx: *Context, sst: select.SelectStage) void {
            {
                ctx.textures.view.mouse_wheel(ctx.hdw);
                ctx.textures.view.drag_view(ctx.screen_width);
            }
            ctx.textures.render(ctx);
            const selected = target.sed_texture(ctx);
            const smp = ctx.textures.view.view_to_win(ctx.screen_width, .{ .x = @floatFromInt(selected.x), .y = @floatFromInt(selected.y) });
            const wh: f32 = ctx.screen_width / ctx.textures.view.width;
            rl.drawRectangleLinesEx(.{
                .x = smp.x,
                .y = smp.y,
                .width = wh,
                .height = wh,
            }, 10, rl.Color.green);
            switch (sst) {
                .hover => {
                    const val = ctx.textures.read(ctx.sel_texture.text_id);
                    const name = val.texture.name;
                    const mp = rl.getMousePosition();
                    const mwid = rl.measureText(name, 22);
                    rl.drawText(
                        name,
                        @as(i32, @intFromFloat(mp.x)) - @divTrunc(mwid, 2),
                        @as(i32, @intFromFloat(mp.y)) - 40,
                        22,
                        rl.Color.green,
                    );
                },
                else => {},
            }
        }

        pub fn check_inside(ctx: *Context) select.CheckInsideResult {
            const view_pos = ctx.textures.view.win_to_view(ctx.screen_width, rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(view_pos.x));
            const y: i32 = @intFromFloat(@floor(view_pos.y));

            if (x < 0 or y < 0 or x >= Width or y >= Height) return .not_in_any_rect;
            const xi: usize = @intCast(x);
            const yi: usize = @intCast(y);

            switch (ctx.textures.text_arr[yi][xi]) {
                .blank => return .not_in_any_rect,
                .text_dir_name => return .not_in_any_rect,
                .texture => {
                    ctx.sel_texture.text_id = .{ .x = xi, .y = yi };
                    return .in_someone;
                },
            }
        }

        pub fn check_still_inside(ctx: *Context) bool {
            const view_pos = ctx.textures.view.win_to_view(ctx.screen_width, rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(view_pos.x));
            const y: i32 = @intFromFloat(@floor(view_pos.y));

            return (x == @as(i32, @intCast(ctx.sel_texture.text_id.x)) and
                y == @as(i32, @intCast(ctx.sel_texture.text_id.y)));
        }
    };
}

pub fn load(ctx: *Context) !void {
    const cwd = std.fs.cwd();
    const res_dir = try cwd.openDir("data/resouces", .{ .iterate = true });
    var walker = try res_dir.walk(ctx.gpa);

    var x: usize = 0;
    var y: usize = 0;
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const ext = std.fs.path.extension(entry.basename);
                if (std.mem.eql(u8, ext, ".png")) {
                    const path = try std.fs.path.joinZ(ctx.gpa, &.{ "data/resouces", entry.path });
                    const loaded_texture = try rl.loadTexture(path);
                    ctx.textures.text_arr[y][x] = .{ .texture = .{
                        .name = try ctx.gpa.dupeZ(u8, entry.basename),
                        .tex2d = loaded_texture,
                    } };
                    x += 1;
                    if (x >= Width) {
                        y += 1;
                        x = 0;
                    }
                }
            },
            else => {
                x = 1;
                y += 1;
                const str = try ctx.gpa.dupeZ(u8, entry.basename);
                ctx.textures.text_arr[y][0] = .{ .text_dir_name = str };
            },
        }
    }
    std.debug.print("y: {d}, x: {d}\n", .{ y, x });
}
