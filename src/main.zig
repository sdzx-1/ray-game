const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const polystate = @import("polystate");

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

    const StartState = Example(Menu);

    var graph = polystate.Graph.init;
    defer graph.deinit(gpa) catch unreachable;
    try graph.generate(gpa, StartState);
    const cwd = std.fs.cwd();
    const t_dot_path = try cwd.createFile("t.dot", .{});
    try t_dot_path.writeAll(try std.fmt.allocPrint(gpa, "{}", .{graph}));

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

    const res_dir = try cwd.openDir("data/resouces", .{ .iterate = true });
    var walker = try res_dir.walk(gpa);

    var x: usize = 0;
    var y: usize = 0;
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const ext = std.fs.path.extension(entry.basename);
                if (std.mem.eql(u8, ext, ".png")) {
                    const path = try std.fs.path.joinZ(gpa, &.{ "data/resouces", entry.path });
                    const loaded_texture = try rl.loadTexture(path);
                    gst.textures.text_arr[y][x] = .{ .texture = .{
                        .name = try gpa.dupeZ(u8, entry.basename),
                        .tex2d = loaded_texture,
                    } };
                    x += 1;
                    if (x >= textures.Width) {
                        y += 1;
                        x = 0;
                    }
                }
            },
            else => {
                x = 1;
                y += 1;
                const str = try gpa.dupeZ(u8, entry.basename);
                gst.textures.text_arr[y][0] = .{ .text_dir_name = str };
            },
        }
    }
    std.debug.print("y: {d}, x: {d}\n", .{ y, x });
    defer gst.textures.deinit();
    errdefer gst.textures.deinit();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rg.setStyle(.default, .{ .default = .text_size }, 30);

    var next = &StartState.conthandler;
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

        sw: switch (next(&gst)) {
            .exit => exit = true,
            .no_trasition => {},
            .next => |fun| next = fun,
            .current => |fun| {
                next = fun;
                continue :sw fun(&gst);
            },
        }

        rl.drawCircle(rl.getMouseX(), rl.getMouseY(), 6, rl.Color.red);
        gst.render_log();
    }
}
