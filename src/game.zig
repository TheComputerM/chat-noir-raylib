const std = @import("std");
const rl = @import("raylib");

const CellState = enum {
    available,
    blocked,
    cat,

    /// Returns the raylib color associated with the cell state.
    fn getColor(self: CellState) rl.Color {
        return switch (self) {
            .available => rl.Color.green,
            .blocked => rl.Color.light_gray,
            .cat => rl.Color.red,
        };
    }
};

// TODO: think of a better name for this struct
const GridCell = struct {
    x: u32,
    y: u32,
};

pub const Grid = struct {
    width: u32,
    height: u32,
    padding: u32,
    cells: std.ArrayList(std.ArrayList(CellState)),
    cell_radius: u32 = 25,
    cat: GridCell = .{ .x = 0, .y = 0 },

    /// Initializes a new grid with the given width and height.
    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Grid {
        var cells = try std.ArrayList(std.ArrayList(CellState)).initCapacity(allocator, height);

        for (0..height) |_| {
            var row = try std.ArrayList(CellState).initCapacity(allocator, width);
            for (0..width) |_| {
                row.appendAssumeCapacity(CellState.available);
            }
            cells.appendAssumeCapacity(row);
        }

        // Initialize the cat position in the center of the grid
        const cat = GridCell{
            .x = width / 2,
            .y = height / 2,
        };

        var grid = Grid{
            .width = width,
            .height = height,
            .padding = 8,
            .cells = cells,
            .cat = cat,
        };

        grid.setCellState(cat, CellState.cat);

        // Set some of the initial cells to blocked state randomly
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const rand = prng.random();
        var initial_blocks = rand.intRangeAtMost(u32, (width + height) / 2, (width + height));
        for (0..initial_blocks) |_| {
            const cell = GridCell{
                .x = rand.uintLessThan(u32, width),
                .y = rand.uintLessThan(u32, height),
            };
            if (grid.getCellState(cell) == CellState.available) {
                grid.setCellState(cell, CellState.blocked);
            } else {
                // If the cell is not available, try again
                initial_blocks += 1;
            }
        }
        return grid;
    }

    pub fn deinit(self: *Grid) void {
        for (self.cells.items) |*row| {
            row.deinit();
        }
        self.cells.deinit();
    }

    /// Renders the grid to the raylib window.
    pub fn render(self: *Grid) !void {
        for (0..self.height) |j| {
            for (0..self.width) |i| {
                const cell = GridCell{
                    .x = @intCast(i),
                    .y = @intCast(j),
                };
                const center = self.getCellCenterPosition(cell);
                const color = self.getCellState(cell).getColor();

                rl.drawPoly(
                    center,
                    6,
                    @as(f32, @floatFromInt(self.cell_radius)),
                    90.0,
                    color,
                );
            }
        }
    }

    pub fn handleClick(self: *Grid, mouse: rl.Vector2) void {
        const cell = self.getCellContainingPoint(mouse) orelse return;

        self.setCellState(cell, CellState.blocked);
        const path = self.shortestPath(self.cat) catch |err| {
            std.log.err("Error finding path: {}\n", .{err});
            return;
        };
        std.log.info("Shortest path found: {any}", .{path});
        if (path.len == 0) {
            std.log.warn("No path found to the edge of the grid.", .{});
            return;
        }
        self.moveCat(path[0]) catch |err| {
            std.log.err("Error moving cat: {}\n", .{err});
        };
    }

    /// Sets the state of the cell at the given grid coordinates.
    fn getCellState(self: *Grid, cell: GridCell) CellState {
        return self.cells.items[cell.y].items[cell.x];
    }

    /// Sets the state of the cell at the given grid coordinates.
    fn setCellState(self: *Grid, cell: GridCell, state: CellState) void {
        self.cells.items[cell.y].items[cell.x] = state;
    }

    /// Returns the position of the cell in pixel coordinates.
    fn getCellCenterPosition(self: *Grid, cell: GridCell) rl.Vector2 {
        const x = (cell.x * self.cell_radius + self.padding) * 2 + (cell.y % 2) * self.cell_radius + self.cell_radius;
        const y = (cell.y * self.cell_radius + self.padding) * 2 + self.cell_radius;
        return rl.Vector2{
            .x = @as(f32, @floatFromInt(x)),
            .y = @as(f32, @floatFromInt(y)),
        };
    }

    /// Returns the dimensions of the grid in pixels.
    pub fn getGridDimensions(self: *Grid) struct { width: i32, height: i32 } {
        return .{
            .width = @intCast((self.cell_radius * self.width + self.padding * 2) * 2 + self.cell_radius),
            .height = @intCast((self.cell_radius * self.height + self.padding * 2) * 2),
        };
    }

    /// Returns the cell that contains the point, or null if no cell contains the point.
    fn getCellContainingPoint(self: *Grid, point: rl.Vector2) ?GridCell {
        for (0..self.height) |j| {
            for (0..self.width) |i| {
                const center = self.getCellCenterPosition(GridCell{
                    .x = @intCast(i),
                    .y = @intCast(j),
                });
                if (rl.checkCollisionPointCircle(
                    point,
                    center,
                    @as(f32, @floatFromInt(self.cell_radius)),
                )) {
                    return GridCell{
                        .x = @intCast(i),
                        .y = @intCast(j),
                    };
                }
            }
        }
        return null;
    }

    /// Returns a list of surrounding cells for the given cell.
    fn getSurroundingCells(self: *Grid, cell: GridCell) ![]GridCell {
        var output = try std.ArrayList(GridCell).initCapacity(
            std.heap.page_allocator,
            6,
        );
        defer output.deinit();
        if (cell.x > 0) {
            output.appendAssumeCapacity(GridCell{
                .x = cell.x - 1,
                .y = cell.y,
            });
        }
        if (cell.x < self.width - 1) {
            output.appendAssumeCapacity(GridCell{
                .x = cell.x + 1,
                .y = cell.y,
            });
        }

        if (cell.y > 0) {
            output.appendAssumeCapacity(GridCell{
                .x = cell.x,
                .y = cell.y - 1,
            });
            if (cell.y % 2 == 0) {
                if (cell.x > 0) {
                    output.appendAssumeCapacity(GridCell{
                        .x = cell.x - 1,
                        .y = cell.y - 1,
                    });
                }
            } else if (cell.x < self.width - 1) {
                output.appendAssumeCapacity(GridCell{
                    .x = cell.x + 1,
                    .y = cell.y - 1,
                });
            }
        }
        if (cell.y < self.height - 1) {
            output.appendAssumeCapacity(GridCell{
                .x = cell.x,
                .y = cell.y + 1,
            });
            if (cell.y % 2 == 0) {
                if (cell.x > 0) {
                    output.appendAssumeCapacity(GridCell{
                        .x = cell.x - 1,
                        .y = cell.y + 1,
                    });
                }
            } else if (cell.x < self.width - 1) {
                output.appendAssumeCapacity(GridCell{
                    .x = cell.x + 1,
                    .y = cell.y + 1,
                });
            }
        }

        return output.toOwnedSlice();
    }

    fn shortestPath(self: *Grid, source: GridCell) ![]GridCell {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var visited = try allocator.alloc([]bool, self.height);
        for (0..self.height) |i| {
            visited[i] = try allocator.alloc(bool, self.width);
            @memset(visited[i], false);
        }

        var parent = try allocator.alloc([]?GridCell, self.height);
        for (0..self.height) |i| {
            parent[i] = try allocator.alloc(?GridCell, self.width);
            @memset(parent[i], null);
        }

        var queue = std.ArrayList(GridCell).init(allocator);
        defer queue.deinit();

        visited[source.y][source.x] = true;
        try queue.append(source);

        var destination: GridCell = undefined;
        while (queue.items.len > 0) {
            const node = queue.orderedRemove(0);

            if (node.x == 0 or node.y == 0 or node.x == self.width - 1 or node.y == self.height - 1) {
                destination = node;
                break;
            }

            const surrounding = try self.getSurroundingCells(node);
            for (surrounding) |cell| {
                if (!visited[cell.y][cell.x] and self.getCellState(cell) == CellState.available) {
                    visited[cell.y][cell.x] = true;
                    try queue.append(cell);
                    parent[cell.y][cell.x] = node;
                }
            }
        }

        var path = std.ArrayList(GridCell).init(std.heap.page_allocator);
        var current: ?GridCell = destination;
        while (current) |c| {
            try path.append(c);
            current = parent[c.y][c.x];
        }

        const output = try path.toOwnedSlice();
        std.mem.reverse(GridCell, output);
        return output[1..];
    }

    fn moveCat(self: *Grid, destination: GridCell) !void {
        if (self.getCellState(destination) != CellState.available) {
            return error.InvalidMove;
        }
        self.setCellState(self.cat, CellState.available);
        self.cat = destination;
        self.setCellState(self.cat, CellState.cat);
    }
};
