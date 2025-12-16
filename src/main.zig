const std = @import("std");
const CLAP = @import("clap.zig").CLAP;
const IR = @import("ir.zig").IR;
const x86 = @import("x86.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const clap = try CLAP.parseArgs(allocator);
    defer clap.deinit(allocator);
    if (clap.anyInfoFlagIsActive()) {
        if (clap.print_help) std.debug.print("{s}", .{CLAP.help_string});
        if (clap.print_version) std.debug.print("{s}", .{CLAP.version_string});
        return;
    }

    var reader_buffer: [4096]u8 = undefined;
    var file = try std.fs.cwd().openFile(clap.input_filepath.?, .{});
    var file_reader = file.reader(&reader_buffer);
    const reader = &file_reader.interface;

    const ir_code = try IR.lex(reader, allocator);
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
