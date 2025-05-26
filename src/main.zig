const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const typedFsm = @import("typed_fsm");

const core = @import("core.zig");

const Example = core.Example;
const SaveData = core.SaveData;

pub fn main() anyerror!void {
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    var graph = typedFsm.Graph.init;
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

    var gst = core.GST{
        .gpa = gpa,
    };

    const save_data = SaveData.load(gpa);
    gst.log("load_data");
    try gst.menu.rs.appendSlice(gpa, save_data.menu);
    try gst.play.rs.appendSlice(gpa, save_data.play);

    const wit = Example.Wit(Example.menu){};
    wit.handler_normal(&gst);
}
