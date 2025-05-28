const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const typedFsm = @import("typed_fsm");

const core = @import("core.zig");
const utils = @import("utils.zig");

const Example = core.Example;
const SaveData = utils.SaveData;

pub fn main() anyerror!void {
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    var graph = typedFsm.Graph.init;
    defer graph.deinit(gpa) catch unreachable;
    try typedFsm.generate_graph(gpa, Example, &graph);
    std.debug.print("{}\n", .{graph});

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1000;
    const screenHeight = 800;

    rl.initWindow(screenWidth, screenHeight, "Example");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rg.setStyle(.default, .{ .default = .text_size }, 20);

    //--------------------------------------------------------------------------------------
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var gst = core.GST{
        .gpa = gpa,
        .random = rand,
    };

    const save_data = SaveData.load(gpa);
    gst.log("load_data");
    try gst.menu.rs.appendSlice(gpa, save_data.menu);
    try gst.play.rs.appendSlice(gpa, save_data.play);
    gst.play.maze_config = save_data.maze_config;

    const wit = Example.Wit(Example.menu){};

    var next = wit.conthandler();
    var exit: bool = false;

    while (!exit) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);
        rl.drawCircle(rl.getMouseX(), rl.getMouseY(), 4, rl.Color.red);
        gst.render_log();

        switch (next(&gst)) {
            .Exit => exit = true,
            .Wait => {},
            .Next => |fun| next = fun,
        }
    }
}
