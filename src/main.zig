const std = @import("std");

pub fn main() !void {
    std.debug.print("hello world!\n", .{});
}

test "test index" {
    comptime {
        _ = @import("ir.zig");
    }
    std.testing.refAllDecls(@This());
}
