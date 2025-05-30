const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const typedFsm = @import("typed_fsm");

const core = @import("core.zig");
const utils = @import("utils.zig");
const play = @import("play.zig");

const Example = core.Example;
const SaveData = utils.SaveData;

pub fn main() anyerror!void {
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    var graph = typedFsm.Graph.init;
    defer graph.deinit(gpa) catch unreachable;
    try typedFsm.generate_graph(gpa, Example, &graph);
    std.debug.print("{}\n", .{graph});

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const current_map = try gpa.create(play.CurrentMap);

    var gst = core.GST{
        .gpa = gpa,
        .random = rand,
        .play = .{ .current_map = current_map },
    };

    try utils.loadData(gpa, &gst);

    rl.initWindow(@as(i32, @intFromFloat(gst.screen_width)), @as(i32, @intFromFloat(gst.screen_height)), "ray-game");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setWindowState(.{ .window_resizable = true });
    rl.hideCursor();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rg.setStyle(.default, .{ .default = .text_size }, 30);

    const wit = Example.Wit(Example.menu){};

    var next = wit.conthandler();
    var exit: bool = false;

    while (!exit) {
        rl.beginDrawing();
        defer rl.endDrawing();
        if (rl.isWindowResized()) {
            gst.screen_width = @floatFromInt(rl.getScreenWidth());
            gst.screen_height = @floatFromInt(rl.getScreenHeight());
            gst.hdw = gst.screen_height / gst.screen_width;
        }

        rl.clearBackground(.white);

        switch (next(&gst)) {
            .Exit => exit = true,
            .Wait => {},
            .Next => |fun| next = fun,
        }

        rl.drawCircle(rl.getMouseX(), rl.getMouseY(), 6, rl.Color.red);
        gst.render_log();
    }
}
