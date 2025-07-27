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

    /// Returns the state of the cell in the grid.
    fn getState(self: GridCell, grid: *Grid) CellState {
        return grid.cells.items[self.y].items[self.x];
    }

    /// Sets the state of the cell in the grid.
    fn setState(self: GridCell, grid: *Grid, state: CellState) void {
        grid.cells.items[self.y].items[self.x] = state;
    }
};

pub const Grid = struct {
    width: u32,
    height: u32,
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
            .cells = cells,
            .cat = cat,
        };

        cat.setState(&grid, CellState.cat);

        return grid;
    }

    pub fn deinit(self: *Grid) void {
        for (self.cells.items) |*row| {
            row.deinit();
        }
        self.cells.deinit();
    }

    /// Returns the position of the cell in pixel coordinates.
    fn getCellCenterPosition(self: *Grid, cell: *const GridCell) rl.Vector2 {
        const i = cell.x;
        const j = cell.y;
        const x = i * self.cell_radius * 2 + (j % 2) * self.cell_radius + self.cell_radius;
        const y = j * self.cell_radius * 2 + self.cell_radius;
        return rl.Vector2{
            .x = @as(f32, @floatFromInt(x)),
            .y = @as(f32, @floatFromInt(y)),
        };
    }

    /// Returns the cell that contains the point, or null if no cell contains the point.
    fn getCellContainingPoint(self: *Grid, point: rl.Vector2) ?GridCell {
        for (0..self.height) |j| {
            for (0..self.width) |i| {
                const center = self.getCellCenterPosition(&GridCell{
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

    /// Renders the grid to the raylib window.
    pub fn render(self: *Grid) !void {
        for (0..self.height) |j| {
            for (0..self.width) |i| {
                const cell = GridCell{
                    .x = @intCast(i),
                    .y = @intCast(j),
                };
                const center = self.getCellCenterPosition(&cell);
                const color = cell.getState(self).getColor();

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
        cell.setState(self, CellState.blocked);
    }
};
