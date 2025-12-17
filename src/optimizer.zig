const std = @import("std");
const IR = @import("ir.zig").IR;

pub fn optimize(raw_ir: []IR, allocator: std.mem.Allocator) ![]IR {
    const accumulated_ir = try accumulate(raw_ir, allocator);
    defer allocator.free(accumulated_ir);
    const shaved_ir = try shave(accumulated_ir, allocator);
    return shaved_ir;
}

/// will reduce consecutive move and change instructions into a single instruction
/// example: [MOVE:+1, MOVE:+1, MOVE:-1, MOVE:+1] will reduce to a single [MOVE:+2]
fn accumulate(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    // manual exception: code cannot work without a lookahead element
    if (ir_array.len == 0) return try allocator.alloc(IR, 0);

    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);

    var accumulator: IR = ir_array[0];
    var current_ir: IR = undefined;
    var previous_ir: IR = undefined;
    for (1..ir_array.len) |i| {
        current_ir = ir_array[i];
        previous_ir = ir_array[i - 1];
        const equal_types = (current_ir.ir_type == previous_ir.ir_type);
        const can_accumulate = (current_ir.ir_type == .change or current_ir.ir_type == .move);
        if (equal_types and can_accumulate) {
            accumulator.ir_value += current_ir.ir_value;
        } else {
            try result.append(allocator, accumulator);
            accumulator = current_ir;
        }
    }
    try result.append(allocator, accumulator);

    return result.toOwnedSlice(allocator);
}

/// will remove redundant intermediary representation code
/// example: [MOVE:0, CHANGE:0] will reduce to []
fn shave(ir_array: []IR, allocator: std.mem.Allocator) ![]IR {
    var result: std.ArrayList(IR) = .empty;
    defer result.deinit(allocator);

    for (ir_array) |ir| {
        const empty_move = (ir.ir_type == .move and ir.ir_value == 0);
        const empty_change = (ir.ir_type == .change and ir.ir_value == 0);
        if (!empty_move and !empty_change) try result.append(allocator, ir);
    }

    return result.toOwnedSlice(allocator);
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

test "shaving" {
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
    const shaved_ir_array = try shave(accumulated_ir_array, allocator);
    defer allocator.free(shaved_ir_array);

    for (shaved_ir_array) |ir| try writer.print("{f}\n", .{ir});
    try std.testing.expectEqualStrings(output, writer.buffered());
}
