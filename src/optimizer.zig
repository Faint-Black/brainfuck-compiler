const std = @import("std");
const IR = @import("ir.zig").IR;
const patterns = @import("patterns.zig");

/// takes in a raw IR array and outputs an optimized IR array
pub fn optimize(raw_ir: []IR, allocator: std.mem.Allocator) ![]IR {
    const accumulated_ir = try accumulate(raw_ir, allocator);
    defer allocator.free(accumulated_ir);
    const cleaned_ir = try clean(accumulated_ir, allocator);
    defer allocator.free(cleaned_ir);
    return try substitute(cleaned_ir, allocator);
}

/// will reduce consecutive move and change instructions into a single instruction
/// example: [MOVE:+1, MOVE:+1, MOVE:-1, MOVE:+1] will reduce to a single [MOVE:+2]
pub fn accumulate(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    // manual exception: code cannot work without a lookahead element
    if (ir_array.len == 0) return try allocator.alloc(IR, 0);
    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);
    var accumulator: IR = ir_array[0];
    var current: IR = undefined;
    var previous: IR = undefined;
    for (1..ir_array.len) |i| {
        current = ir_array[i];
        previous = ir_array[i - 1];
        const can_accumulate = switch (current) {
            .change => true,
            .move => true,
            else => false,
        };
        if (current.eqlType(previous) and can_accumulate) {
            switch (accumulator) {
                .change => |*value| value.* += current.change,
                .move => |*value| value.* += current.move,
                else => unreachable,
            }
        } else {
            try result.append(allocator, accumulator);
            accumulator = current;
        }
    }
    try result.append(allocator, accumulator);
    return try result.toOwnedSlice(allocator);
}

/// will remove redundant intermediary representation code
/// example: [MOVE:0, CHANGE:0] will both be discarded
pub fn clean(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);
    for (ir_array) |ir| {
        const empty_move = ir.eql(IR{ .move = 0 });
        const empty_change = ir.eql(IR{ .change = 0 });
        if (!empty_move and !empty_change) try result.append(allocator, ir);
    }
    return try result.toOwnedSlice(allocator);
}

/// will substitute known patterns for native IR codes
fn substitute(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);
    var i: usize = 0;
    while (i < ir_array.len) : (i += 1) {
        if (patterns.clearIdentify(ir_array[i..])) |matched| {
            i += matched.len - 1;
            try result.append(allocator, patterns.clearFromSlice(matched));
        } else if (patterns.transferAccumulatingIdentify(ir_array[i..])) |matched| {
            i += matched.len - 1;
            try result.append(allocator, patterns.transferAccumulatingFromSlice(matched));
        } else {
            try result.append(allocator, ir_array[i]);
        }
    }
    return try result.toOwnedSlice(allocator);
}

test "cell accumulation" {
    const input = "++-+++--+..-+<<>><<<>>><";
    const output =
        \\CHANGE 3
        \\OUT
        \\OUT
        \\CHANGE 0
        \\MOVE -1
        \\
    ;

    const allocator = std.testing.allocator;
    var buffer: [2048]u8 = undefined;
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.fixed(&buffer);

    const ir_array = try IR.lex(&reader, allocator);
    defer allocator.free(ir_array);
    const accumulated_ir_array = try accumulate(ir_array, allocator);
    defer allocator.free(accumulated_ir_array);

    for (accumulated_ir_array) |ir| try writer.print("{f}\n", .{ir});
    try std.testing.expectEqualStrings(output, writer.buffered());
}

test "cell cleaning" {
    const input = "+++---.<<<>>>>.<>";
    const output =
        \\OUT
        \\MOVE 1
        \\OUT
        \\
    ;

    const allocator = std.testing.allocator;
    var buffer: [2048]u8 = undefined;
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.fixed(&buffer);

    const ir_array = try IR.lex(&reader, allocator);
    defer allocator.free(ir_array);
    const accumulated_ir_array = try accumulate(ir_array, allocator);
    defer allocator.free(accumulated_ir_array);
    const cleaned_ir_array = try clean(accumulated_ir_array, allocator);
    defer allocator.free(cleaned_ir_array);

    for (cleaned_ir_array) |ir| try writer.print("{f}\n", .{ir});
    try std.testing.expectEqualStrings(output, writer.buffered());
}

test "pattern substitution" {
    const input = "[-][-][>>>>+<<<<-][-<<+>>]";
    const output =
        \\SET 0
        \\SET 0
        \\TRANSFER(+) 4
        \\TRANSFER(+) -2
        \\
    ;

    const allocator = std.testing.allocator;
    var buffer: [2048]u8 = undefined;
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.fixed(&buffer);

    const ir_array = try IR.lex(&reader, allocator);
    defer allocator.free(ir_array);
    const accumulated_ir_array = try accumulate(ir_array, allocator);
    defer allocator.free(accumulated_ir_array);
    const cleaned_ir_array = try clean(accumulated_ir_array, allocator);
    defer allocator.free(cleaned_ir_array);
    const substituted_ir_array = try substitute(cleaned_ir_array, allocator);
    defer allocator.free(substituted_ir_array);

    for (substituted_ir_array) |ir| try writer.print("{f}\n", .{ir});
    try std.testing.expectEqualStrings(output, writer.buffered());
}
