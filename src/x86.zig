//! ECX register is to always hold the current cell index.

const std = @import("std");
const IR = @import("ir.zig").IR;

const prolog =
    \\;;; Compile with:
    \\;;;  nasm -f elf32 <source>.asm -o <object>.o
    \\;;; Link with:
    \\;;;  gcc -no-pie -m32 <object>.o
    \\
    \\global main
    \\extern printf
    \\extern memset
    \\extern getchar
    \\
    \\section .note.GNU-stack noalloc noexec nowrite progbits
    \\
    \\section .data
    \\    good_output_fmt db "%c", 0x00
    \\    bad_output_fmt  db "Invalid Character: '%d'", 0x0A, 0x00
    \\
    \\section .bss
    \\    cells resd 30000
    \\
    \\section .text
    \\
    \\;; Set all cells to zero
    \\clear_cells:
    \\push ecx ; save ECX, memset may mutate it
    \\push DWORD (30000 * 4)
    \\push DWORD 0
    \\push DWORD cells
    \\call memset
    \\add  esp, 12
    \\pop ecx  ; get back saved ECX value
    \\ret
    \\
    \\;; Print integer at current cell
    \\print_char:
    \\push ecx ; save ECX, printf may mutate it
    \\mov eax, [cells + ecx*4]
    \\cmp eax, 10 ; (cells[ptr] == '\n') -> good char exception
    \\je .PRINT_GOOD_CHAR
    \\cmp eax, 32 ; (cells[ptr] < ' ') -> bad char
    \\jl .PRINT_BAD_CHAR
    \\cmp eax, 126 ; (cells[ptr] > '~') -> bad char
    \\jg .PRINT_BAD_CHAR
    \\.PRINT_GOOD_CHAR:
    \\push eax
    \\push good_output_fmt
    \\jmp .PRINT_EXIT
    \\.PRINT_BAD_CHAR:
    \\push eax
    \\push bad_output_fmt
    \\jmp .PRINT_EXIT
    \\.PRINT_EXIT:
    \\call printf
    \\add esp, 8
    \\pop ecx  ; get back saved ECX value
    \\ret
    \\
    \\;; Get character from stdin and store it on the current cell
    \\get_char:
    \\push ecx ; save ECX, getchar may mutate it
    \\call getchar
    \\pop ecx  ; get back saved ECX value
    \\mov [cells + ecx*4], eax
    \\ret
    \\
    \\main:
    \\xor ecx, ecx
    \\call clear_cells
    \\
    \\
;

const epilog =
    \\
    \\xor eax,eax
    \\ret
;

pub fn codegen(ir_array: []IR, allocator: std.mem.Allocator) ![]u8 {
    var allocating_writer = std.Io.Writer.Allocating.init(allocator);
    defer allocating_writer.deinit();
    const writer = &allocating_writer.writer;

    _ = try writer.write(prolog);
    for (ir_array) |ir| {
        switch (ir.ir_type) {
            .move => {
                try writer.print("add DWORD ecx, {}\n", .{ir.ir_value});
            },
            .change => {
                try writer.print("add DWORD [cells + ecx*4], {}\n", .{ir.ir_value});
            },
            .branch_forwards => {
                try writer.print("cmp DWORD [cells + ecx*4], 0\n", .{});
                try writer.print("je .END_BRACKET_{}\n", .{ir.ir_value});
                try writer.print(".START_BRACKET_{}:\n", .{ir.ir_value});
            },
            .branch_backwards => {
                try writer.print("cmp DWORD [cells + ecx*4], 0\n", .{});
                try writer.print("jne .START_BRACKET_{}\n", .{ir.ir_value});
                try writer.print(".END_BRACKET_{}:\n", .{ir.ir_value});
            },
            .out => {
                try writer.print("call print_char\n", .{});
            },
            .in => {
                try writer.print("call get_char\n", .{});
            },
        }
    }
    _ = try writer.write(epilog);

    return try allocating_writer.toOwnedSlice();
}
