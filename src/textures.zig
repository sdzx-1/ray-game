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
    vw: ViewWin = .{},

    pub fn read(self: *const @This(), id: TextID) Cell {
        return self.text_arr[id.y][id.x];
    }

    pub fn render_texture(
        self: *const @This(),
        text_id: TextID,
        rect: rl.Rectangle,
        color: rl.Color,
    ) void {
        switch (self.read(text_id)) {
            .texture => |texture| {
                texture.tex2d.drawPro(.{
                    .x = 0,
                    .y = 0,
                    .width = 256,
                    .height = 256,
                }, rect, .{ .x = 0, .y = 0 }, 0, color);
            },
            else => {
                rl.drawRectangleRec(rect, rl.Color.red);
            },
        }
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

    pub fn render(self: @This()) void {
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

            self.vw.winport_beginScissorMode();
            defer rl.endScissorMode();

            for (start_y..end_y + 1) |y| {
                for (start_x..end_x + 1) |x| {
                    const win_pos1 = self.vw.viewpos_to_winpos(.{
                        .x = @floatFromInt(x),
                        .y = @floatFromInt(y),
                    }).add(.{ .x = 1, .y = 1 });
                    const dw = self.vw.wv_ratio() - 1;
                    self.render_texture(
                        .{ .x = x, .y = y },
                        .{ .x = win_pos1.x, .y = win_pos1.y, .width = dw, .height = dw },
                        rl.Color.white,
                    );
                }
            }

            const wpos = self.vw.winport.pos;
            rl.drawRectangleLinesEx(.{
                .x = wpos.x,
                .y = wpos.y,
                .width = self.vw.winport.width,
                .height = self.vw.winport_get_height(),
            }, 4, rl.Color.black);
        }
    }
};

pub const SetTextureData = struct {
    text_id: TextID = .{ .x = 0, .y = 0 },
};

pub fn ViewTextures(Back: type) type {
    return union(enum) {
        view_loop: Example(.current, Select(Back, SelectTextureInstance(struct {}, @This()))),

        pub fn handler(_: *Context) @This() {
            return .view_loop;
        }
    };
}

pub fn SetTexture(Back: type, Next: type) type {
    const Tmp = SetTextureInner(Next);
    return Init(Tmp, Select(Back, SelectTextureInstance(Tmp, Tmp)));
}

pub fn SetTextureInner(Next: type) type {
    return union(enum) {
        after_set_texture: Example(.current, Next),

        pub fn handler(ctx: *Context) @This() {
            Next.set_text_id(ctx, ctx.sel_texture.text_id);
            return .after_set_texture;
        }

        pub fn init_fun(ctx: *Context) void {
            const selected = Next.get_text_id(ctx);
            ctx.textures.vw.viewport.pos.y = @as(f32, @floatFromInt(selected.y)) - 2;
        }

        pub fn select_texture_render(ctx: *Context, _: select.SelectStage) void {
            const selected = Next.get_text_id(ctx);

            const smp = ctx.textures.vw.viewpos_to_winpos(.{ .x = @floatFromInt(selected.x), .y = @floatFromInt(selected.y) });
            const wh: f32 = ctx.textures.vw.wv_ratio();
            rl.drawRectangleLinesEx(.{
                .x = smp.x,
                .y = smp.y,
                .width = wh,
                .height = wh,
            }, 10, rl.Color.green);
        }
    };
}

pub fn SelectTextureInstance(Config: type, Next: type) type {
    return union(enum) {
        after_select_texture: Example(.current, Next),

        pub fn handler(_: *Context) @This() {
            return .after_select_texture;
        }

        pub fn select_fun(ctx: *Context, sst: select.SelectStage) bool {
            _ = sst;
            const dr = rl.getMouseWheelMove() * 1.4;
            if (dr != 0) {
                ctx.textures.vw.viewport.pos.y -= dr;
                return true;
            }
            return false;
        }

        pub fn select_render(ctx: *Context, sst: select.SelectStage) void {
            ctx.textures.render();

            if (@hasDecl(Config, "select_texture_render")) {
                const render_: fn (*Context, select.SelectStage) void = Config.select_texture_render;
                render_(ctx, sst);
            }

            switch (sst) {
                .outside => {},
                else => {
                    const id = ctx.sel_texture.text_id;
                    const wpos = ctx.textures.vw.viewpos_to_winpos(.{ .x = @floatFromInt(id.x), .y = @floatFromInt(id.y) });
                    const dw = ctx.textures.vw.wv_ratio();
                    rl.drawRectangleLinesEx(.{ .x = wpos.x, .y = wpos.y, .width = dw + 1, .height = dw + 1 }, 2, rl.Color.red);
                },
            }
            switch (sst) {
                .hover => {
                    const val = ctx.textures.read(ctx.sel_texture.text_id);
                    const name = val.texture.name;
                    const mp = rl.getMousePosition();
                    const mwid = rl.measureText(name, 22);
                    rl.drawText(name, @as(i32, @intFromFloat(mp.x)) - @divTrunc(mwid, 2), @as(i32, @intFromFloat(mp.y)) - 40, 32, rl.Color.green);

                    const dw = 512;
                    ctx.textures.render_texture(
                        ctx.sel_texture.text_id,
                        .{ .x = if ((ctx.screen_width - mp.x) < dw) mp.x - dw else mp.x, .y = mp.y, .width = dw, .height = dw },
                        rl.Color.white,
                    );
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
    var text_data_arr: TextureDataArray = .empty;
    defer text_data_arr.deinit(ctx.gpa);

    const file_path_list = rl.loadDirectoryFilesEx("data/resouces", ".png", true);

    const file_paths = file_path_list.paths[0..file_path_list.count];

    for (file_paths) |file_path_null_terminated| {
        const file_path = std.mem.span(file_path_null_terminated);
        const loaded_texture = try rl.loadTexture(file_path);
        try text_data_arr.append(ctx.gpa, .{ .name = try ctx.gpa.dupeZ(u8, std.fs.path.basename(file_path)), .tex2d = loaded_texture });
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
const Init = core.Init;
