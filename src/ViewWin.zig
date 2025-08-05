hw_ratio: f32 = 800.0 / 1000.0, //height / width
viewport: Viewport = .{},
winport: Winport = .{},
view_drag_ratio: f32 = 1,
wheel_zoom_ratio: f32 = 0.65,

const Self = @This();

pub const Viewport = Port("View");
pub const Winport = Port("Win");

pub fn inWinport(self: *const Self, pos: Winport.Pos) bool {
    return self.winport.in_port(pos, self.hw_ratio);
}

pub fn inViewport(self: *const Self, pos: Viewport.Pos) bool {
    return self.viewport.in_port(pos, self.hw_ratio);
}

pub fn dwinpos_to_dviewpos(self: *const Self, dwpos: Winport.Pos) Viewport.Pos {
    const r = self.viewport.width / self.winport.width;
    return .{ .x = dwpos.x * r, .y = dwpos.y * r };
}

pub fn dviewpos_to_dwinpos(self: *const Self, dvpos: Viewport.Pos) Winport.Pos {
    const r = self.winport.width / self.viewport.width;
    return .{ .x = dvpos.x * r, .y = dvpos.y * r };
}

pub fn winpos_to_viewpos(self: *const Self, pos: Winport.Pos) Viewport.Pos {
    const dwpos = pos.subtract(self.winport.pos);
    const dvpos = self.dwinpos_to_dviewpos(dwpos);
    return self.viewport.pos.add(dvpos);
}

pub fn viewpos_to_winpos(self: *const Self, pos: Viewport.Pos) Winport.Pos {
    const dvpos = pos.subtract(self.viewport.pos);
    const dwpos = self.dviewpos_to_dwinpos(dvpos);
    return self.winport.pos.add(dwpos);
}

pub fn viewpos_from_vector2(self: *const Self, vec2: rl.Vector2) Viewport.Pos {
    return self.winpos_to_viewpos(Winport.Pos.fromVector2(vec2));
}

pub fn winport_intersect_rect(self: *const @This(), rect: rl.Rectangle) ?rl.Rectangle {
    return self.winport.intersect_rect(self.hw_ratio, rect);
}

pub fn viewport_intersect_rect(self: *const @This(), rect: rl.Rectangle) ?rl.Rectangle {
    return self.viewport.intersect_rect(self.hw_ratio, rect);
}

pub fn mouse_drag_winport(self: *Self) void {
    if ((rl.isKeyDown(rl.KeyboardKey.left_control))) {
        const deta = rl.getMouseDelta();
        self.winport.move_port(Winport.Pos.fromVector2(deta));
    }
}

pub fn mouse_drag_viewport(self: *Self) void {
    if (rl.isMouseButtonDown(rl.MouseButton.middle) or
        (rl.isKeyDown(rl.KeyboardKey.left_alt)))
    {
        const deta = rl.getMouseDelta().scale(-self.view_drag_ratio);
        const dvpos = self.dwinpos_to_dviewpos(Winport.Pos.fromVector2(deta));
        self.viewport.move_port(dvpos);
    }
}

pub fn mouse_wheel_zoom_winport(self: *Self) void {
    const dr = rl.getMouseWheelMove() * self.wheel_zoom_ratio;
    self.winport.zoom_port_with_center_unchage(self.hw_ratio, dr);
}

pub fn mouse_wheel_zoom_viewport(self: *Self) void {
    const dr = rl.getMouseWheelMove() * -self.wheel_zoom_ratio;
    self.viewport.zoom_port_with_center_unchage(self.hw_ratio, dr);
}

pub fn winport_beginScissorMode(self: *const Self) void {
    rl.beginScissorMode(
        @intFromFloat(self.winport.pos.x),
        @intFromFloat(self.winport.pos.y),
        @intFromFloat(self.winport.width),
        @intFromFloat(self.winport.width * self.hw_ratio),
    );
}

pub fn winport_get_height(self: *const Self) f32 {
    return self.winport.get_height(self.hw_ratio);
}

pub fn viewport_get_height(self: *const Self) f32 {
    return self.viewport.get_height(self.hw_ratio);
}

pub fn wv_ratio(self: *const Self) f32 {
    return self.winport.width / self.viewport.width;
}

pub fn Port(name: []const u8) type {
    return struct {
        pos: Pos = .{ .x = 0, .y = 0 },
        width: f32 = 10,

        pub const Pos = struct {
            x: f32,
            y: f32,

            pub const Name = name;

            pub fn fromVector2(v2: rl.Vector2) @This() {
                return .{ .x = v2.x, .y = v2.y };
            }
            pub fn toVector2(self: @This()) rl.Vector2 {
                return .{ .x = self.x, .y = self.y };
            }

            pub fn add(self: @This(), v: @This()) @This() {
                return .{ .x = self.x + v.x, .y = self.y + v.y };
            }

            pub fn subtract(self: @This(), v: @This()) @This() {
                return .{ .x = self.x - v.x, .y = self.y - v.y };
            }
        };

        pub const Name = name;

        pub fn get_height(self: *const @This(), hw_ratio: f32) f32 {
            return self.width * hw_ratio;
        }

        pub fn in_port(self: *const @This(), pos: Pos, hw_ratio: f32) bool {
            if (pos.x > self.pos.x and
                pos.x < self.pos.x + self.width and
                pos.y > self.pos.y and
                pos.y < self.pos.y + self.width * hw_ratio) return true;
            return false;
        }

        pub fn move_port(self: *@This(), deta: Pos) void {
            self.pos.x += deta.x;
            self.pos.y += deta.y;
        }

        pub fn zoom_port(self: *@This(), dr: f32) void {
            self.width += self.width * dr;
        }

        pub fn zoom_port_with_center_unchage(self: *@This(), hw_ratio: f32, dr: f32) void {
            const dw = self.width * dr;
            self.pos.x -= dw / 2;
            self.pos.y -= (dw * hw_ratio) / 2;
            self.width += dw;
        }

        pub fn in_x_area(self: *const @This(), x: f32) bool {
            return (x >= self.pos.x and x <= self.pos.x + self.width);
        }

        pub fn in_y_area(self: *const @This(), hw_ratio: f32, y: f32) bool {
            return (y >= self.pos.y and y <= self.pos.y + self.width * hw_ratio);
        }

        pub fn intersect_rect(self: *const @This(), hw_ratio: f32, rect: rl.Rectangle) ?rl.Rectangle {
            const left_top_x = @max(self.pos.x, rect.x);
            const left_top_y = @max(self.pos.y, rect.y);

            const right_bottom_x = @min(self.pos.x + self.width, rect.x + rect.width);
            const right_bottom_y = @min(self.pos.y + self.width * hw_ratio, rect.y + rect.height);

            if (self.in_x_area(left_top_x) and self.in_y_area(hw_ratio, left_top_y) and
                self.in_x_area(right_bottom_x) and self.in_y_area(hw_ratio, right_bottom_y))
            {
                return .{
                    .x = left_top_x,
                    .y = left_top_y,
                    .width = right_bottom_x - left_top_x,
                    .height = right_bottom_y - left_top_y,
                };
            }
            return null;
        }
    };
}

test "ViewWin" {
    const origin: Self = .{
        .hw_ratio = 1,
        .viewport = .{ .pos = .{ .x = 0, .y = 0 }, .width = 5 },
        .winport = .{ .pos = .{ .x = 10, .y = 10 }, .width = 10 },
    };
    //

    try std.testing.expect(origin.inWinport(.{ .x = 12, .y = 12 }));
    try std.testing.expect(origin.inViewport(.{ .x = 4, .y = 4 }));

    //
    var result: Self = undefined;
    result.viewport.pos = .{ .x = 0, .y = 0 };
    try std.testing.expectEqual(
        result.viewport.pos,
        origin.dwinpos_to_dviewpos(.{ .x = 0, .y = 0 }),
    );

    result.viewport.pos = .{ .x = -5, .y = -5 };
    try std.testing.expectEqual(
        result.viewport.pos,
        origin.winpos_to_viewpos(.{ .x = 0, .y = 0 }),
    );

    result.viewport.pos = .{ .x = 5, .y = 5 };
    try std.testing.expectEqual(
        result.viewport.pos,
        origin.dwinpos_to_dviewpos(.{ .x = 10, .y = 10 }),
    );

    result.viewport.pos = .{ .x = 0, .y = 0 };
    try std.testing.expectEqual(
        result.viewport.pos,
        origin.winpos_to_viewpos(.{ .x = 10, .y = 10 }),
    );

    //

    result.winport.pos = .{ .x = 20, .y = 20 };
    try std.testing.expectEqual(
        result.winport.pos,
        origin.dviewpos_to_dwinpos(.{ .x = 10, .y = 10 }),
    );

    result.winport.pos = .{ .x = 30, .y = 30 };
    try std.testing.expectEqual(
        result.winport.pos,
        origin.viewpos_to_winpos(.{ .x = 10, .y = 10 }),
    );
}

const rl = @import("raylib");
const std = @import("std");
