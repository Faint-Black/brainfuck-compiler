const std = @import("std");
const optimize = @import("optimizer.zig").optimize;
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
    defer file.close();
    var file_reader = file.reader(&reader_buffer);
    const reader = &file_reader.interface;

    const raw_ir_code = try IR.lex(reader, allocator);
    defer allocator.free(raw_ir_code);
    const optimized_ir_code = try optimize(raw_ir_code, allocator);
    defer allocator.free(optimized_ir_code);

    const assembly: []const u8 = switch (clap.target_platform) {
        .none => error.NoTargetProvided,
        .x86 => try x86.codegen(optimized_ir_code, allocator),
    } catch |err| {
        std.debug.print("ERROR: No valid target provided!\n", .{});
        return err;
    };
    defer allocator.free(assembly);

    if (clap.output_filepath) |output_filepath| {
        const out_file = try std.fs.cwd().createFile(output_filepath, std.fs.File.CreateFlags{ .read = false });
        defer out_file.close();
        try out_file.writeAll(assembly);
    } else {
        std.debug.print("{s}\n", .{assembly});
    }
}

test "test index" {
    comptime {
        _ = @import("ir.zig");
        _ = @import("optimizer.zig");
        _ = @import("x86.zig");
    }
    std.testing.refAllDecls(@This());
}
