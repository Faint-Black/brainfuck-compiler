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
        .{ .match_fn = IR.eqlType, .target = IR{ .ir_type = .branch_forwards } },
        .{ .match_fn = IR.eql, .target = IR{ .ir_type = .change, .ir_value = -1 } },
        .{ .match_fn = IR.eqlType, .target = IR{ .ir_type = .branch_backwards } },
    };
    return if (matches(ir_slice[0..], &pattern)) ir_slice[0..pattern.len] else null;
}

/// turns the '[-]' pattern into a "Set cell to 0" IR code
pub fn clearFromSlice(_: []const IR) IR {
    return IR{
        .ir_type = .set_cell,
        .ir_value = 0,
    };
}

test "identifying transfer patterns" {
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
