const std = @import("std");

const engine = @import("engine.zig");

pub fn main() !void {
    // Allocate all memory up front.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var rosalie = try engine.Engine.new(allocator);
    try rosalie.run();
}
