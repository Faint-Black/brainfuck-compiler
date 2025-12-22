const std = @import("std");

const JumpStack = struct {
    stack: [2048]i32,
    size: usize,

    pub const empty = JumpStack{ .stack = undefined, .size = 0 };

    /// returns pushed value
    pub fn push(self: *JumpStack, value: i32) !i32 {
        if (self.size >= self.stack.len) return error.StackOverflow;
        self.stack[self.size] = value;
        self.size += 1;
        return value;
    }

    /// returns popped value
    pub fn pop(self: *JumpStack) !i32 {
        if (self.size == 0) return error.StackUnderflow;
        self.size -= 1;
        return self.stack[self.size];
    }
};

pub const IR = struct {
    ir_value: i32 = 0,
    ir_type: enum {
        /// '>'(positive value) and '<'(negative value)
        move,
        /// '+'(positive value) and '-'(negative value)
        change,
        /// '['(unique label id)
        branch_forwards,
        /// ']'(matching label id)
        branch_backwards,
        /// '.'(unused value)
        out,
        /// ','(unused value)
        in,
        /// cell(current) = value
        set_cell,
        /// cell(current + offset) += cell(current); cell(current) = 0
        transfer_accumulating,
    },

    pub fn format(self: IR, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self.ir_type) {
            .move => try writer.print("MOVE {}", .{self.ir_value}),
            .change => try writer.print("CHANGE {}", .{self.ir_value}),
            .branch_forwards => try writer.print("BRANCH_F {}", .{self.ir_value}),
            .branch_backwards => try writer.print("BRANCH_B {}", .{self.ir_value}),
            .out => try writer.print("OUT", .{}),
            .in => try writer.print("IN", .{}),
            .set_cell => try writer.print("SET {}", .{self.ir_value}),
            .transfer_accumulating => try writer.print("TRANSFER(+) {}", .{self.ir_value}),
        }
    }

    pub fn eqlType(self: IR, other: IR) bool {
        return self.ir_type == other.ir_type;
    }

    pub fn eqlValue(self: IR, other: IR) bool {
        return self.ir_value == other.ir_value;
    }

    pub fn eql(self: IR, other: IR) bool {
        return self.eqlType(other) and self.eqlValue(other);
    }

    pub fn lex(reader: *std.Io.Reader, allocator: std.mem.Allocator) ![]IR {
        var ir_array: std.ArrayList(IR) = .empty;
        defer ir_array.deinit(allocator);

        var jump_id_stack: JumpStack = .empty;
        var current_jump_id: i32 = 0;

        while (reader.takeByte()) |c| {
            switch (c) {
                '>' => try ir_array.append(allocator, .{ .ir_value = 1, .ir_type = .move }),
                '<' => try ir_array.append(allocator, .{ .ir_value = -1, .ir_type = .move }),
                '+' => try ir_array.append(allocator, .{ .ir_value = 1, .ir_type = .change }),
                '-' => try ir_array.append(allocator, .{ .ir_value = -1, .ir_type = .change }),
                '[' => {
                    try ir_array.append(allocator, .{
                        .ir_value = try jump_id_stack.push(current_jump_id),
                        .ir_type = .branch_forwards,
                    });
                    current_jump_id += 1;
                },
                ']' => {
                    try ir_array.append(allocator, .{
                        .ir_value = try jump_id_stack.pop(),
                        .ir_type = .branch_backwards,
                    });
                },
                '.' => try ir_array.append(allocator, .{ .ir_type = .out }),
                ',' => try ir_array.append(allocator, .{ .ir_type = .in }),
                else => {},
            }
        } else |_| {}

        if (jump_id_stack.size != 0) return error.UnclosedBrackets;

        return try ir_array.toOwnedSlice(allocator);
    }
};

test "jump stack" {
    var js: JumpStack = .empty;

    try std.testing.expectEqual(1, try js.push(1));
    try std.testing.expectEqual(2, try js.push(2));
    try std.testing.expectEqual(3, try js.push(3));
    try std.testing.expectEqual(4, try js.push(4));

    try std.testing.expectEqual(4, try js.pop());
    try std.testing.expectEqual(3, try js.pop());
    try std.testing.expectEqual(2, try js.pop());
    try std.testing.expectEqual(1, try js.pop());

    try std.testing.expectError(error.StackUnderflow, js.pop());
}

test "simple lexing" {
    const input = "Hellooo  [+[  +-[ + ]>]<[]\n]\n";
    const output =
        \\BRANCH_F 0
        \\CHANGE 1
        \\BRANCH_F 1
        \\CHANGE 1
        \\CHANGE -1
        \\BRANCH_F 2
        \\CHANGE 1
        \\BRANCH_B 2
        \\MOVE 1
        \\BRANCH_B 1
        \\MOVE -1
        \\BRANCH_F 3
        \\BRANCH_B 3
        \\BRANCH_B 0
        \\
    ;
    const allocator = std.testing.allocator;
    var buffer: [2048]u8 = undefined;
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.fixed(&buffer);

    const ir_array = try IR.lex(&reader, allocator);
    defer allocator.free(ir_array);

    for (ir_array) |ir| try writer.print("{f}\n", .{ir});
    try std.testing.expectEqualStrings(output, writer.buffered());
}
