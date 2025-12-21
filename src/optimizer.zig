const std = @import("std");
const IR = @import("ir.zig").IR;

/// takes in a raw IR array and outputs an optimized IR array
pub fn optimize(raw_ir: []IR, allocator: std.mem.Allocator) ![]IR {
    const cleared_ir = try clear(raw_ir, allocator);
    defer allocator.free(cleared_ir);
    const accumulated_ir = try accumulate(cleared_ir, allocator);
    defer allocator.free(accumulated_ir);
    return try clean(accumulated_ir, allocator);
}

/// will reduce consecutive move and change instructions into a single instruction
/// example: [MOVE:+1, MOVE:+1, MOVE:-1, MOVE:+1] will reduce to a single [MOVE:+2]
fn accumulate(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
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
        const can_accumulate = switch (current.ir_type) {
            .change => true,
            .move => true,
            else => false,
        };
        if (current.eqlType(previous) and can_accumulate) {
            accumulator.ir_value += current.ir_value;
        } else {
            try result.append(allocator, accumulator);
            accumulator = current;
        }
    }
    try result.append(allocator, accumulator);
    return try result.toOwnedSlice(allocator);
}

/// will substitute the '[-]' pattern for the appropriate IR
/// example: [BRANCH_F, CHANGE:-1, BRANCH_B] will reduce to a [CLEAR]
fn clear(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);
    const pattern: [3]IR = .{
        IR{ .ir_type = .branch_forwards, .ir_value = 0 },
        IR{ .ir_type = .change, .ir_value = -1 },
        IR{ .ir_type = .branch_backwards, .ir_value = 0 },
    };
    var succesful_match: bool = false;
    var match_counter: usize = 0;
    var broken_pattern_buffer: [pattern.len]IR = undefined;
    var broken_pattern_buffer_size: usize = 0;
    for (ir_array) |ir| {
        succesful_match = switch (match_counter) {
            0 => ir.eqlType(pattern[0]),
            1 => ir.eql(pattern[1]),
            2 => ir.eqlType(pattern[2]),
            else => unreachable,
        };
        if (succesful_match) {
            broken_pattern_buffer[broken_pattern_buffer_size] = ir;
            broken_pattern_buffer_size += 1;
            match_counter += 1;
            if (match_counter == pattern.len) {
                try result.append(allocator, IR{ .ir_type = .clear_cell, .ir_value = 0 });
                broken_pattern_buffer_size = 0;
                match_counter = 0;
            }
        } else {
            try result.appendSlice(allocator, broken_pattern_buffer[0..broken_pattern_buffer_size]);
            try result.append(allocator, ir);
            broken_pattern_buffer_size = 0;
            match_counter = 0;
        }
    }
    return try result.toOwnedSlice(allocator);
}

/// will remove redundant intermediary representation code
/// example: [MOVE:0, CHANGE:0] will both be discarded
fn clean(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);
    for (ir_array) |ir| {
        const empty_move = (ir.ir_type == .move and ir.ir_value == 0);
        const empty_change = (ir.ir_type == .change and ir.ir_value == 0);
        if (!empty_move and !empty_change) try result.append(allocator, ir);
    }
    return try result.toOwnedSlice(allocator);
}

test "accumulation" {
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

test "cell clearing" {
    const input = "+[-+[-].[--]]";
    const output =
        \\CHANGE 1
        \\BRANCH_F 0
        \\CHANGE -1
        \\CHANGE 1
        \\CLEAR
        \\OUT
        \\BRANCH_F 2
        \\CHANGE -1
        \\CHANGE -1
        \\BRANCH_B 2
        \\BRANCH_B 0
        \\
    ;

    const allocator = std.testing.allocator;
    var buffer: [2048]u8 = undefined;
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.fixed(&buffer);

    const ir_array = try IR.lex(&reader, allocator);
    defer allocator.free(ir_array);

    const cleared_ir_array = try clear(ir_array, allocator);
    defer allocator.free(cleared_ir_array);

    for (cleared_ir_array) |ir| try writer.print("{f}\n", .{ir});
    try std.testing.expectEqualStrings(output, writer.buffered());
}

test "cleaning" {
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
