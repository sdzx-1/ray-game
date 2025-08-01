pub const TextureData = struct {
    name: [:0]const u8,
    tex2d: rl.Texture2D,

    pub fn lessThanFn(_: void, lhs: @This(), rhs: @This()) bool {
        return switch (std.mem.order(u8, lhs.name, rhs.name)) {
            .lt => true,
            else => false,
        };
    }
};

pub const Cell = union(enum) {
    texture: TextureData,
    blank: void,
};

pub const Width = 30;
pub const Height = 33;

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
    vw: ViewWin = .{
        .hw_ratio = 1,
        .winport = .{},
        .viewport = .{ .pos = .{ .x = 0, .y = 0 }, .width = @floatFromInt(Width) },
    },

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

    pub fn render(self: @This(), ctx: *Context) void {
        if (self.vw.viewport_intersect_rect(.{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(Width)),
            .height = @as(f32, @floatFromInt(Height)),
        })) |rect| {
            const start_x: usize = @intFromFloat(@floor(rect.x));
            const start_y: usize = @intFromFloat(@floor(rect.y));
            const end_x: usize = @intFromFloat(@floor(rect.x + rect.width - 0.01));
            const end_y: usize = @intFromFloat(@floor(rect.y + rect.height - 0.01));

            ctx.textures.vw.winport_beginScissorMode();
            defer rl.endScissorMode();

            for (start_y..end_y + 1) |y| {
                for (start_x..end_x + 1) |x| {
                    const val = ctx.textures.text_arr[y][x];
                    switch (val) {
                        .blank => {},
                        .texture => |text| {
                            const win_pos1 = self.vw.viewpos_to_winpos(.{ .x = @floatFromInt(x), .y = @floatFromInt(y) });
                            const dw = self.vw.wv_ratio();
                            text.tex2d.drawPro(
                                .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                                .{ .x = win_pos1.x, .y = win_pos1.y, .width = dw, .height = dw },
                                .{ .x = 0, .y = 0 },
                                0,
                                rl.Color.white,
                            );
                        },
                    }
                }
            }
        }
    }
};

pub const SetTextureData = struct {
    text_id: TextID = .{ .x = 0, .y = 0 },
};

pub fn ViewTextures(Back: type) type {
    return union(enum) {
        to_view: Example(.current, Select(Back, SetTexture(false, @This()))),

        pub fn handler(_: *Context) @This() {
            return .to_view;
        }
    };
}

pub fn SetTexture(comptime is_set: bool, target: type) type {
    return union(enum) {
        setTexture_to_target: Example(.current, target),

        pub fn handler(ctx: *Context) @This() {
            if (is_set) target.set_text_id(ctx, ctx.sel_texture.text_id);
            return .setTexture_to_target;
        }

        pub fn select_fun(ctx: *Context, sst: select.SelectStage) bool {
            _ = sst;

            ctx.textures.vw.hw_ratio = ctx.hdw;
            ctx.textures.vw.winport = .{ .width = ctx.screen_width, .pos = .{ .x = 0, .y = 0 } };
            const dr = rl.getMouseWheelMove() * 1.4;
            if (dr != 0) {
                ctx.textures.vw.viewport.pos.y -= dr;
                return true;
            }
            return false;
        }

        pub fn select_render(ctx: *Context, sst: select.SelectStage) void {
            ctx.textures.render(ctx);

            if (is_set) {
                const selected = target.get_text_id(ctx);

                const smp = ctx.textures.vw.viewpos_to_winpos(.{ .x = @floatFromInt(selected.x), .y = @floatFromInt(selected.y) });
                const wh: f32 = ctx.textures.vw.wv_ratio();
                rl.drawRectangleLinesEx(.{
                    .x = smp.x,
                    .y = smp.y,
                    .width = wh,
                    .height = wh,
                }, 10, rl.Color.green);
            }
            switch (sst) {
                .hover => {
                    const val = ctx.textures.read(ctx.sel_texture.text_id);
                    const name = val.texture.name;
                    const mp = rl.getMousePosition();
                    const mwid = rl.measureText(name, 22);
                    rl.drawText(name, @as(i32, @intFromFloat(mp.x)) - @divTrunc(mwid, 2), @as(i32, @intFromFloat(mp.y)) - 40, 32, rl.Color.green);

                    switch (val) {
                        .blank => {},
                        .texture => |text| {
                            text.tex2d.drawPro(
                                .{ .x = 0, .y = 0, .width = 256, .height = 256 },
                                .{ .x = if ((ctx.screen_width - mp.x) < 512) mp.x - 512 else mp.x, .y = mp.y, .width = 512, .height = 512 },
                                .{ .x = 0, .y = 0 },
                                0,
                                rl.Color.white,
                            );
                        },
                    }
                },
                else => {},
            }
        }

        pub fn check_inside(ctx: *Context) select.CheckInsideResult {
            const view_pos = ctx.textures.vw.viewpos_from_vector2(rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(view_pos.x));
            const y: i32 = @intFromFloat(@floor(view_pos.y));

            if (x < 0 or y < 0 or x >= Width or y >= Height) return .not_in_any_rect;
            const xi: usize = @intCast(x);
            const yi: usize = @intCast(y);

            switch (ctx.textures.text_arr[yi][xi]) {
                .blank => return .not_in_any_rect,
                .texture => {
                    ctx.sel_texture.text_id = .{ .x = xi, .y = yi };
                    return .in_someone;
                },
            }
        }

        pub fn check_still_inside(ctx: *Context) bool {
            const view_pos = ctx.textures.vw.viewpos_from_vector2(rl.getMousePosition());
            const x: i32 = @intFromFloat(@floor(view_pos.x));
            const y: i32 = @intFromFloat(@floor(view_pos.y));

            return (x == @as(i32, @intCast(ctx.sel_texture.text_id.x)) and
                y == @as(i32, @intCast(ctx.sel_texture.text_id.y)));
        }
    };
}

const TextureDataArray = std.ArrayListUnmanaged(TextureData);

pub fn load(ctx: *Context) !void {
    const cwd = std.fs.cwd();
    const res_dir = try cwd.openDir("data/resouces", .{ .iterate = true });
    var walker = try res_dir.walk(ctx.gpa);

    var text_data_arr: TextureDataArray = .empty;
    defer text_data_arr.deinit(ctx.gpa);
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const ext = std.fs.path.extension(entry.basename);
                if (std.mem.eql(u8, ext, ".png")) {
                    const path = try std.fs.path.joinZ(ctx.gpa, &.{ "data/resouces", entry.path });
                    const loaded_texture = try rl.loadTexture(path);
                    try text_data_arr.append(ctx.gpa, .{ .name = try ctx.gpa.dupeZ(u8, entry.basename), .tex2d = loaded_texture });
                }
            },
            else => {},
        }
    }
    std.sort.insertion(TextureData, text_data_arr.items, {}, TextureData.lessThanFn);

    for (text_data_arr.items, 0..) |data, i| {
        const y: usize = @intCast(i / Width);
        const x: usize = @intCast(@mod(i, Width));
        ctx.textures.text_arr[y][x] = .{ .texture = data };
    }
}

const std = @import("std");
const ps = @import("polystate");
const core = @import("core.zig");
const Select = core.Select;
const select = @import("select.zig");
const utils = @import("utils.zig");

const rl = @import("raylib");
const rg = @import("raygui");

const Example = core.Example;
const Menu = @import("menu.zig").Menu;

const Context = core.Context;
const getTarget = core.getTarget;
const View = utils.View;
const ViewWin = @import("ViewWin.zig");
