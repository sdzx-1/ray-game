const std = @import("std");
const typedFsm = @import("typed_fsm");
const core = @import("core.zig");
const select = @import("select.zig");
const utils = @import("utils.zig");

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
const View = utils.View;

pub const Texture = struct {
    name: [:0]const u8,
    tex2d: rl.Texture2D,
};

pub const Cell = union(enum) {
    texture: Texture,
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

pub const Textures = struct {
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

    pub fn render(_: @This(), gst: *GST) void {
        for (0..Height) |y| {
            for (0..Width) |x| {
                const val = gst.textures.text_arr[y][x];
                const win_pos = gst.textures.view.view_to_win(
                    gst.screen_width,
                    .{ .x = @floatFromInt(x), .y = @floatFromInt(y) },
                );
                const worh = gst.screen_width / gst.textures.view.width;

                const view = gst.textures.view;
                const r1: rl.Rectangle = .{ .x = view.x, .y = view.y, .width = view.width, .height = view.width * gst.hdw };
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

pub const texturesST = union(enum) {
    ToMenu: Wit(Example.menu),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToMenu => |wit| return .{ .Next = wit.conthandler() },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        {
            gst.textures.view.mouse_wheel(gst.hdw);
            gst.textures.view.drag_view(gst.screen_width);
        }

        gst.textures.render(gst);

        if (rl.isKeyPressed(rl.KeyboardKey.m)) {
            return .ToMenu;
        }
        return null;
    }
};

pub const SelTexture = struct {
    text_id: TextID = .{ .x = 0, .y = 0 },
    address: *TextID = undefined,
};

pub fn sel_textureST(target: SDZX) type {
    return union(enum) {
        ToTarget: WitRow(target),

        pub fn conthandler(gst: *GST) ContR {
            switch (genMsg(gst)) {
                .ToTarget => |wit| {
                    gst.sel_texture.address.* = gst.sel_texture.text_id;
                    return wit.conthandler()(gst);
                },
            }
        }

        fn genMsg(gst: *GST) @This() {
            _ = gst;
            return .ToTarget;
        }

        pub fn select_render(gst: *GST, sst: select.SelectState) bool {
            {
                gst.textures.view.mouse_wheel(gst.hdw);
                gst.textures.view.drag_view(gst.screen_width);
            }
            gst.textures.render(gst);
            const selected = gst.sel_texture.address.*;
            const smp = gst.textures.view.view_to_win(gst.screen_width, .{ .x = @floatFromInt(selected.x), .y = @floatFromInt(selected.y) });
            const wh: f32 = gst.screen_width / gst.textures.view.width;
            rl.drawRectangleLinesEx(.{
                .x = smp.x,
                .y = smp.y,
                .width = wh,
                .height = wh,
            }, 10, rl.Color.green);
            switch (sst) {
                .hover => {
                    const val = gst.textures.read(gst.sel_texture.text_id);
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
            return false;
        }

        pub fn check_inside(gst: *GST) select.CheckInsideResult {
            const view_pos = gst.textures.view.win_to_view(gst.screen_width, rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(view_pos.x));
            const y: i32 = @intFromFloat(@floor(view_pos.y));

            if (x < 0 or y < 0 or x >= Width or y >= Height) return .not_in_any_rect;
            const xi: usize = @intCast(x);
            const yi: usize = @intCast(y);

            switch (gst.textures.text_arr[yi][xi]) {
                .blank => return .not_in_any_rect,
                .text_dir_name => return .not_in_any_rect,
                .texture => {
                    gst.sel_texture.text_id = .{ .x = xi, .y = yi };
                    return .in_someone;
                },
            }
        }

        pub fn check_still_inside(gst: *GST) bool {
            const view_pos = gst.textures.view.win_to_view(gst.screen_width, rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(view_pos.x));
            const y: i32 = @intFromFloat(@floor(view_pos.y));

            return (x == @as(i32, @intCast(gst.sel_texture.text_id.x)) and
                y == @as(i32, @intCast(gst.sel_texture.text_id.y)));
        }
    };
}
