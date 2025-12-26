const std = @import("std");
const IR = @import("ir.zig").IR;
const accumulate = @import("optimizer.zig").accumulate;

const MatchEntry = struct {
    target: IR,
    match_fn: *const fn (IR, IR) bool,
};

/// check if all input IR codes match the given pattern
fn matches(input: []const IR, pattern: []const MatchEntry) bool {
    if (input.len < pattern.len) return false;
    for (pattern, 0..) |match_entry, i| {
        if (!match_entry.match_fn(input[i], match_entry.target)) return false;
    }
    return true;
}

/// identifies the '[-]' pattern
pub fn clearIdentify(ir_slice: []const IR) ?[]const IR {
    const pattern = [_]MatchEntry{
        .{ .match_fn = IR.eqlType, .target = IR{ .branch_forwards = undefined } },
        .{ .match_fn = IR.eql, .target = IR{ .change = -1 } },
        .{ .match_fn = IR.eqlType, .target = IR{ .branch_backwards = undefined } },
    };
    return if (matches(ir_slice[0..], &pattern)) ir_slice[0..pattern.len] else null;
}

/// turns the '[-]' pattern into a "Set cell to 0" IR code
pub fn clearFromSlice(_: []const IR) IR {
    return IR{ .set_cell = 0 };
}

/// identifies the '[->>>+<<<]' pattern
pub fn transferAccumulatingIdentify(ir_slice: []const IR) ?[]const IR {
    // [->>+<<]
    const left_minus_pattern = [_]MatchEntry{
        .{ .match_fn = IR.eqlType, .target = IR{ .branch_forwards = undefined } },
        .{ .match_fn = IR.eql, .target = IR{ .change = -1 } },
        .{ .match_fn = IR.eqlType, .target = IR{ .move = undefined } },
        .{ .match_fn = IR.eql, .target = IR{ .change = 1 } },
        .{ .match_fn = IR.eqlType, .target = IR{ .move = undefined } },
        .{ .match_fn = IR.eqlType, .target = IR{ .branch_backwards = undefined } },
    };
    // [>>+<<-]
    const right_minus_pattern = [_]MatchEntry{
        .{ .match_fn = IR.eqlType, .target = IR{ .branch_forwards = undefined } },
        .{ .match_fn = IR.eqlType, .target = IR{ .move = undefined } },
        .{ .match_fn = IR.eql, .target = IR{ .change = 1 } },
        .{ .match_fn = IR.eqlType, .target = IR{ .move = undefined } },
        .{ .match_fn = IR.eql, .target = IR{ .change = -1 } },
        .{ .match_fn = IR.eqlType, .target = IR{ .branch_backwards = undefined } },
    };

    const matches_lmp: bool = matches(ir_slice[0..], &left_minus_pattern);
    const matches_rmp: bool = matches(ir_slice[0..], &right_minus_pattern);
    const moves_match: bool = if (matches_lmp) (ir_slice[2].move == -ir_slice[4].move) else if (matches_rmp) (ir_slice[1].move == -ir_slice[3].move) else false;

    return if (matches_lmp and moves_match) ir_slice[0..left_minus_pattern.len] else if (matches_rmp and moves_match) ir_slice[0..right_minus_pattern.len] else null;
}

/// turns the '[->>>+<<<]' pattern into a "Transfer accumulating" IR code
pub fn transferAccumulatingFromSlice(ir_slice: []const IR) IR {
    const offset: i32 = if (ir_slice[1] == .change) ir_slice[2].move else ir_slice[1].move;
    return IR{ .transfer_accumulating = offset };
}

test "identifying cell clear patterns" {
    const allocator = std.testing.allocator;
    const test_cases = [_]struct { bool, []const u8 }{
        .{ true, "[-]" },
        .{ false, "[--]" },
        .{ false, "[---]" },
        .{ false, "[[-]]" },
        .{ false, "[[--]]" },
        .{ false, "[[---]]" },
        .{ false, "[-[-]]" },
        .{ false, "[-[--]]" },
        .{ false, "[-[---]]" },
        .{ true, "[-][-]" },
        .{ true, "[-][--]" },
        .{ true, "[-][---]" },
    };
    for (test_cases) |test_case| {
        const expected_result, const input = test_case;
        var reader = std.Io.Reader.fixed(input);

        const raw_ir_array = try IR.lex(&reader, allocator);
        defer allocator.free(raw_ir_array);
        const accumulated_ir_array = try accumulate(raw_ir_array, allocator);
        defer allocator.free(accumulated_ir_array);

        const actual_result: bool = clearIdentify(accumulated_ir_array) != null;
        try std.testing.expect(expected_result == actual_result);
    }
}

test "identifying transfer patterns" {
    const allocator = std.testing.allocator;
    const test_cases = [_]struct { bool, []const u8 }{
        .{ true, "[->+<]" },
        .{ true, "[->>+<<]" },
        .{ true, "[->>>+<<<]" },
        .{ true, "[-<+>]" },
        .{ true, "[-<<+>>]" },
        .{ true, "[-<<<+>>>]" },
        .{ true, "[>+<-]" },
        .{ true, "[>>+<<-]" },
        .{ true, "[>>>+<<<-]" },
        .{ true, "[<+>-]" },
        .{ true, "[<<+>>-]" },
        .{ true, "[<<<+>>>-]" },
        .{ false, "[->+>]" },
        .{ false, "[-<+<]" },
        .{ false, "[->-<]" },
        .{ false, "[>+<]" },
    };
    for (test_cases) |test_case| {
        const expected_result, const input = test_case;
        var reader = std.Io.Reader.fixed(input);

        const raw_ir_array = try IR.lex(&reader, allocator);
        defer allocator.free(raw_ir_array);
        const accumulated_ir_array = try accumulate(raw_ir_array, allocator);
        defer allocator.free(accumulated_ir_array);

        const actual_result: bool = transferAccumulatingIdentify(accumulated_ir_array) != null;
        try std.testing.expect(expected_result == actual_result);
    }
}
