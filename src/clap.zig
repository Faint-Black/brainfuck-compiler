const std = @import("std");

pub const TargetPlatform = enum {
    none,
    x86,
    x64,
};

const target_flag_map = std.StaticStringMap(TargetPlatform).initComptime(.{
    .{ "--target=none", TargetPlatform.none },
    .{ "--target=x86", TargetPlatform.x86 },
    .{ "--target=x64", TargetPlatform.x64 },
});

pub const CLAP = struct {
    input_filepath: ?[]const u8 = null,
    output_filepath: ?[]const u8 = null,
    print_help: bool = false,
    print_version: bool = false,
    target_platform: TargetPlatform = .none,

    pub fn deinit(self: CLAP, allocator: std.mem.Allocator) void {
        if (self.input_filepath) |mem| allocator.free(mem);
        if (self.output_filepath) |mem| allocator.free(mem);
    }

    pub fn parseArgs(allocator: std.mem.Allocator) !CLAP {
        var result = CLAP{};
        errdefer result.deinit(allocator);
        var iterator = try std.process.ArgIterator.initWithAllocator(allocator);
        defer iterator.deinit();
        var counter: usize = 0;

        var expecting_output_filepath: bool = false;
        while (iterator.next()) |arg| : (counter += 1) {
            // skip binary path
            if (counter == 0) continue;

            if (expecting_output_filepath) {
                if (result.output_filepath != null) return error.OnlyNeedOneOutFilepath;
                result.output_filepath = try allocator.dupe(u8, arg);
                expecting_output_filepath = false;
                continue;
            }

            if (target_flag_map.get(arg)) |valid_target| {
                result.target_platform = valid_target;
            } else if (std.mem.eql(u8, arg, "-h")) {
                result.print_help = true;
            } else if (std.mem.eql(u8, arg, "--help")) {
                result.print_help = true;
            } else if (std.mem.eql(u8, arg, "--version")) {
                result.print_version = true;
            } else if (std.mem.eql(u8, arg, "-o")) {
                expecting_output_filepath = true;
            } else if (std.mem.eql(u8, arg, "--output")) {
                expecting_output_filepath = true;
            } else {
                if (result.input_filepath != null) return error.OnlyNeedOneInFilepath;
                result.input_filepath = try allocator.dupe(u8, arg);
            }
        }

        if (!result.anyInfoFlagIsActive() and result.input_filepath == null) {
            return error.NoSourceProvided;
        }

        return result;
    }

    /// returns true if either 'help' or 'version' flags are active
    pub fn anyInfoFlagIsActive(self: CLAP) bool {
        return (self.print_help or self.print_version);
    }

    pub const help_string =
        \\Brainfuck Compiler, a brainfuck compiler...
        \\
        \\SYNOPSIS
        \\       brainfuck-compiler [--target=<platform>] [-o output] [input]
        \\
        \\USAGE
        \\       brainfuck-compiler --target=x86 brainfuck-source.txt -o assembly.asm
        \\       brainfuck-compiler brainfuck-source.txt --target=x64
        \\
        \\PLATFORMS
        \\       x86
        \\              32-bit x86 assembly.
        \\       x64
        \\              64-bit x86 assembly.
        \\
    ;

    pub const version_string =
        \\Brainfuck Compiler
        \\version 1.0.0
        \\
    ;
};
