const std = @import("std");
const IR = @import("ir.zig").IR;
const x86 = @import("x86.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = "+++.";
    var reader = std.Io.Reader.fixed(input);

    const ir_code = try IR.lex(&reader, allocator);
    defer allocator.free(ir_code);

    const x86_code = try x86.codegen(ir_code, allocator);
    defer allocator.free(x86_code);

    std.debug.print("{s}\n", .{x86_code});
}

test "test index" {
    comptime {
        _ = @import("ir.zig");
        _ = @import("x86.zig");
    }
    std.testing.refAllDecls(@This());
}
