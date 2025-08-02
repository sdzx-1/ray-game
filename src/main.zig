const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const ps = @import("polystate");

const core = @import("core.zig");
const utils = @import("utils.zig");
const play = @import("play.zig");
const textures = @import("textures.zig");
const Menu = @import("menu.zig").Menu;

const Example = core.Example;
const SaveData = utils.SaveData;

pub const EnterFsmState = Example(.next, Menu);
const Runner = ps.Runner(true, EnterFsmState);

pub fn main() anyerror!void {
    const gpa = std.heap.c_allocator;

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const current_map = try gpa.create(play.CurrentMap);
    const tmp_buf = try gpa.alloc(u8, 10 << 10);

    const text_arr = try gpa.create(textures.TextArr);
    textures.arr_set_blank(text_arr);

    var ctx = core.Context{
        .gpa = gpa,
        .random = rand,
        .play = .{ .current_map = current_map },
        .tmp_buf = tmp_buf,
        .textures = .{ .text_arr = text_arr },
    };

    try utils.loadData(gpa, &ctx);

    rl.initWindow(@as(i32, @intFromFloat(ctx.screen_width)), @as(i32, @intFromFloat(ctx.screen_height)), "ray-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setExitKey(.null); // Prevent window from closing when escape key is pressed
    rl.setWindowState(.{ .window_resizable = true });

    // hideCursor is buggy when building for emscripten: https://github.com/raysan5/raylib/issues/4940
    if (@import("builtin").os.tag != .emscripten) {
        rl.hideCursor();
    }

    rl.setTraceLogLevel(.none);

    { //load textures
        rl.beginDrawing();
        rl.clearBackground(.white);
        rl.drawText("Loading textures...", 100, 100, 50, rl.Color.black);
        rl.endDrawing();
        try textures.load(&ctx);
    }

    defer ctx.textures.deinit();
    errdefer ctx.textures.deinit();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rg.setStyle(.default, .{ .default = .text_size }, 30);

    var curr_id: Runner.StateId = Runner.idFromState(Menu);

    while (logic(curr_id, &ctx)) |id| {
        curr_id = id;
        defer rl.endDrawing();
        switch (id) {
            inline else => |tid| {
                const ty = Runner.StateFromId(tid);
                if (ty != ps.Exit and @hasDecl(ty, "render")) {
                    rl.clearBackground(.white);
                    ty.render(&ctx);
                    ctx.render_log();
                    rl.drawCircle(rl.getMouseX(), rl.getMouseY(), 6, rl.Color.red);
                }
            },
        }
    }

    utils.saveData(&ctx);
}

fn logic(id: Runner.StateId, ctx: *core.Context) ?Runner.StateId {
    if (rl.windowShouldClose()) return null;

    rl.beginDrawing();
    if (rl.isWindowResized()) {
        ctx.screen_width = @floatFromInt(rl.getScreenWidth());
        ctx.screen_height = @floatFromInt(rl.getScreenHeight());
        ctx.hdw = ctx.screen_height / ctx.screen_width;
    }
    return Runner.runHandler(id, ctx);
}
