const std = @import("std");
const optimize = @import("optimizer.zig").optimize;
const CLAP = @import("clap.zig").CLAP;
const IR = @import("ir.zig").IR;

pub fn main() !void {
    // set up allocator
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // set up stdout
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    // parse command line arguments
    const clap = try CLAP.parseArgs(allocator);
    defer clap.deinit(allocator);
    if (clap.anyInfoFlagIsActive()) {
        if (clap.print_help) try stdout.print(CLAP.help_string, .{});
        if (clap.print_version) try stdout.print(CLAP.version_string, .{});
        try stdout.flush();
        return;
    }

    // set up readers/writers/buffers and open input source file
    var reader_buffer: [4096]u8 = undefined;
    var file = try std.fs.cwd().openFile(clap.input_filepath.?, .{});
    defer file.close();
    var file_reader = file.reader(&reader_buffer);
    const reader = &file_reader.interface;

    // turn file contents into intermediary representation
    const raw_ir_code = try IR.lex(reader, allocator);
    defer allocator.free(raw_ir_code);
    const optimized_ir_code = try optimize(raw_ir_code, allocator);
    defer allocator.free(optimized_ir_code);

    // emit output assembly for given target
    const assembly: []const u8 = switch (clap.target_platform) {
        .none => error.NoTargetProvided,
        .x86 => try @import("x86.zig").codegen(optimized_ir_code, allocator),
        .x64 => try @import("x64.zig").codegen(optimized_ir_code, allocator),
    } catch |err| {
        try stdout.print("ERROR: No valid target provided!\n", .{});
        try stdout.flush();
        return err;
    };
    defer allocator.free(assembly);

    // either write assembly to file or print it to stdout
    if (clap.output_filepath) |output_filepath| {
        const out_file = try std.fs.cwd().createFile(output_filepath, std.fs.File.CreateFlags{ .read = false });
        defer out_file.close();
        try out_file.writeAll(assembly);
    } else {
        _ = try stdout.write(assembly);
        try stdout.flush();
    }
}

test "test index" {
    comptime {
        _ = @import("clap.zig");
        _ = @import("ir.zig");
        _ = @import("optimizer.zig");
        _ = @import("patterns.zig");
        _ = @import("x86.zig");
        _ = @import("x64.zig");
    }
    std.testing.refAllDecls(@This());
}
