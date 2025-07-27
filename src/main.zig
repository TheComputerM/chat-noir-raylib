const rl = @import("raylib");
const builtin = @import("builtin");
const game = @import("game.zig");
const std = @import("std");

// const c = if (builtin.os.tag == .emscripten) @cImport({
//     @cInclude("emscripten/emscripten.h");
// });

var grid: game.Grid = undefined;

pub fn main() anyerror!void {
    grid = try game.Grid.init(
        std.heap.page_allocator,
        7,
        7,
    );
    defer grid.deinit();

    const width = grid.cell_radius * grid.width * 2 + grid.cell_radius;
    const height = grid.cell_radius * grid.height * 2;

    rl.initWindow(@intCast(width), @intCast(height), "Le Chat Noir - TheComputerM");
    defer rl.closeWindow();

    if (builtin.os.tag == .emscripten) {
        // c.emscripten_set_main_loop(@ptrCast(&updateDrawFrame), 0, 1);
    } else {
        rl.setTargetFPS(30);
        while (!rl.windowShouldClose()) {
            updateDrawFrame();
        }
    }
}

fn updateDrawFrame() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.white);

    if (rl.isMouseButtonReleased(.left)) {
        grid.handleClick(rl.getMousePosition());
    }

    grid.render() catch |err| {
        std.debug.print("Error rendering grid: {}\n", .{err});
    };
}
