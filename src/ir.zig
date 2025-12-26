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

pub const IR = union(enum) {
    /// '>'(positive value) and '<'(negative value)
    move: i32,
    /// '+'(positive value) and '-'(negative value)
    change: i32,
    /// '['(unique label id)
    branch_forwards: i32,
    /// ']'(matching label id)
    branch_backwards: i32,
    /// '.'(unused value)
    out: void,
    /// ': i32,'(unused value)
    in: void,
    /// cell(current) = value
    set_cell: i32,
    /// cell(current + offset) += cell(current); cell(current) = 0
    transfer_accumulating: i32,

    pub fn format(self: IR, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .move => |offset| try writer.print("MOVE {}", .{offset}),
            .change => |value| try writer.print("CHANGE {}", .{value}),
            .branch_forwards => |id| try writer.print("BRANCH_F {}", .{id}),
            .branch_backwards => |id| try writer.print("BRANCH_B {}", .{id}),
            .out => try writer.print("OUT", .{}),
            .in => try writer.print("IN", .{}),
            .set_cell => |value| try writer.print("SET {}", .{value}),
            .transfer_accumulating => |offset| try writer.print("TRANSFER(+) {}", .{offset}),
        }
    }

    pub fn eqlType(self: IR, other: IR) bool {
        return std.meta.activeTag(self) == std.meta.activeTag(other);
    }

    pub fn eqlValue(self: IR, other: IR) bool {
        return self.eqlType(other) and switch (self) {
            .move => self.move == other.move,
            .change => self.change == other.change,
            .branch_forwards => self.branch_forwards == other.branch_forwards,
            .branch_backwards => self.branch_backwards == other.branch_backwards,
            .out => true,
            .in => true,
            .set_cell => self.set_cell == other.set_cell,
            .transfer_accumulating => self.transfer_accumulating == other.transfer_accumulating,
        };
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
                '>' => try ir_array.append(allocator, IR{ .move = 1 }),
                '<' => try ir_array.append(allocator, IR{ .move = -1 }),
                '+' => try ir_array.append(allocator, IR{ .change = 1 }),
                '-' => try ir_array.append(allocator, IR{ .change = -1 }),
                '[' => {
                    try ir_array.append(allocator, IR{
                        .branch_forwards = try jump_id_stack.push(current_jump_id),
                    });
                    current_jump_id += 1;
                },
                ']' => {
                    try ir_array.append(allocator, IR{
                        .branch_backwards = try jump_id_stack.pop(),
                    });
                },
                '.' => try ir_array.append(allocator, IR.out),
                ',' => try ir_array.append(allocator, IR.in),
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
