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
};

pub const texturesST = union(enum) {
    ToMenu: Wit(Example.menu),
    ToExit: Wit(Example.exit),

    pub fn conthandler(gst: *GST) ContR {
        if (genMsg(gst)) |msg| {
            switch (msg) {
                .ToExit => |wit| return .{ .Next = wit.conthandler() },
                .ToMenu => |wit| return .{ .Next = wit.conthandler() },
            }
        } else return .Wait;
    }

    fn genMsg(gst: *GST) ?@This() {
        {
            gst.textures.view.mouse_wheel(gst.hdw);
            gst.textures.view.drag_view(gst.screen_width);
        }

        for (0..Height) |y| {
            for (0..Width) |x| {
                const val = gst.textures.text_arr[y][x];
                switch (val) {
                    .blank => {},
                    .texture => |text| {
                        const win_pos = gst.textures.view.view_to_win(
                            gst.screen_width,
                            .{ .x = @floatFromInt(x), .y = @floatFromInt(y) },
                        );
                        const worh = gst.screen_width / gst.textures.view.width;
                        text.tex2d.drawPro(
                            .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                            .{ .x = win_pos.x, .y = win_pos.y, .width = worh, .height = worh },
                            .{ .x = 0, .y = 0 },
                            0,
                            rl.Color.white,
                        );
                    },
                    .text_dir_name => |name| {
                        const win_pos = gst.textures.view.view_to_win(
                            gst.screen_width,
                            .{ .x = @floatFromInt(x), .y = @floatFromInt(y) },
                        );
                        rl.drawText(name, @intFromFloat(win_pos.x), @intFromFloat(win_pos.y), 20, rl.Color.green);
                    },
                }
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.q)) {
            return .ToExit;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.m)) {
            return .ToMenu;
        }
        return null;
    }
};
