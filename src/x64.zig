//! RCX register is to always hold the current cell index.

const std = @import("std");
const IR = @import("ir.zig").IR;

const prolog =
    \\;;; Assemble with:
    \\;;;  nasm -f elf64 <source>.asm -o <object>.o
    \\;;; Link with:
    \\;;;  gcc -no-pie -m64 <object>.o
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
    \\push rcx ; save RCX, memset may mutate it
    \\mov rdi, cells
    \\mov rsi, 0
    \\mov rdx, (30000 * 4)
    \\call memset
    \\pop rcx  ; get back saved RCX value
    \\ret
    \\
    \\;; Print integer at current cell
    \\print_char:
    \\push rcx ; save RCX, printf may mutate it
    \\mov eax, DWORD [cells + rcx*4]
    \\cmp eax, 10 ; (cells[ptr] == '\n') -> good char exception
    \\je .PRINT_GOOD_CHAR
    \\cmp eax, 32 ; (cells[ptr] < ' ') -> bad char
    \\jl .PRINT_BAD_CHAR
    \\cmp eax, 126 ; (cells[ptr] > '~') -> bad char
    \\jg .PRINT_BAD_CHAR
    \\.PRINT_GOOD_CHAR:
    \\lea rdi, [rel good_output_fmt]
    \\mov esi, eax
    \\jmp .PRINT_EXIT
    \\.PRINT_BAD_CHAR:
    \\lea rdi, [rel bad_output_fmt]
    \\mov esi, eax
    \\jmp .PRINT_EXIT
    \\.PRINT_EXIT:
    \\xor rax, rax
    \\call printf
    \\pop rcx  ; get back saved RCX value
    \\ret
    \\
    \\;; Get character from stdin and store it on the current cell
    \\get_char:
    \\push rcx ; save RCX, getchar may mutate it
    \\call getchar
    \\pop rcx  ; get back saved RCX value
    \\mov DWORD [cells + rcx*4], eax
    \\ret
    \\
    \\main:
    \\xor rcx, rcx
    \\call clear_cells
    \\
    \\
;

const epilog =
    \\
    \\xor rax,rax
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
                try writer.print("add rcx, {}\n", .{ir.ir_value});
            },
            .change => {
                try writer.print("add DWORD [cells + rcx*4], {}\n", .{ir.ir_value});
            },
            .branch_forwards => {
                try writer.print("cmp DWORD [cells + rcx*4], 0\n", .{});
                try writer.print("je .END_BRACKET_{}\n", .{ir.ir_value});
                try writer.print(".START_BRACKET_{}:\n", .{ir.ir_value});
            },
            .branch_backwards => {
                try writer.print("cmp DWORD [cells + rcx*4], 0\n", .{});
                try writer.print("jne .START_BRACKET_{}\n", .{ir.ir_value});
                try writer.print(".END_BRACKET_{}:\n", .{ir.ir_value});
            },
            .out => {
                try writer.print("call print_char\n", .{});
            },
            .in => {
                try writer.print("call get_char\n", .{});
            },
            .set_cell => {
                try writer.print("mov DWORD [cells + rcx*4], {}\n", .{ir.ir_value});
            },
            .transfer_accumulating => {
                try writer.print("mov eax, DWORD [cells + rcx*4]\n", .{});
                try writer.print("add DWORD [(cells + ({} * 4)) + rcx*4], eax\n", .{ir.ir_value});
                try writer.print("mov DWORD [cells + rcx*4], 0\n", .{});
            },
        }
    }
    _ = try writer.write(epilog);

    return try allocating_writer.toOwnedSlice();
}
