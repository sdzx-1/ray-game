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

pub fn main() anyerror!void {
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    const StartState = Example(.next, Menu);

    var graph = try ps.Graph.initWithFsm(gpa, StartState, 100);
    defer graph.deinit();

    const cwd = std.fs.cwd();
    const t_dot_path = try cwd.createFile("t.dot", .{});
    try graph.generateDot(t_dot_path.writer());

    const t_mermaid_path = try cwd.createFile("t.mmd", .{});
    try graph.generateMermaid(t_mermaid_path.writer());

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

    var gst = core.GST{
        .gpa = gpa,
        .random = rand,
        .play = .{ .current_map = current_map },
        .tmp_buf = tmp_buf,
        .textures = .{ .text_arr = text_arr },
    };

    try utils.loadData(gpa, &gst);

    rl.initWindow(@as(i32, @intFromFloat(gst.screen_width)), @as(i32, @intFromFloat(gst.screen_height)), "ray-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setWindowState(.{ .window_resizable = true });
    rl.hideCursor();
    rl.setTraceLogLevel(.none);

    { //load textures
        rl.beginDrawing();
        rl.clearBackground(.white);
        rl.drawText("Loading textures...", 100, 100, 50, rl.Color.black);
        rl.endDrawing();
        try textures.load(&gst);
    }

    defer gst.textures.deinit();
    errdefer gst.textures.deinit();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rg.setStyle(.default, .{ .default = .text_size }, 30);

    const Runner = ps.Runner(120, true, StartState);
    var curr_id: ?Runner.StateId = Runner.idFromState(Menu);

    while (curr_id) |id| {
        rl.beginDrawing();
        defer rl.endDrawing();
        if (rl.isWindowResized()) {
            gst.screen_width = @floatFromInt(rl.getScreenWidth());
            gst.screen_height = @floatFromInt(rl.getScreenHeight());
            gst.hdw = gst.screen_height / gst.screen_width;
        }

        rl.clearBackground(.white);

        curr_id = Runner.runHandler(id, &gst);

        rl.drawCircle(rl.getMouseX(), rl.getMouseY(), 6, rl.Color.red);
        gst.render_log();
    }

    utils.saveData(&gst);
}
