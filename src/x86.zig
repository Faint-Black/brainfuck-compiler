//! ECX register is to always hold the current cell pointer

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
    \\
    \\section .note.GNU-stack noalloc noexec nowrite progbits
    \\
    \\section .data
    \\    good_output_fmt db "%c", 0x0A, 0x00
    \\    bad_output_fmt  db "Bad Char: '%d'", 0x0A, 0x00
    \\
    \\section .bss
    \\    cells resd 30000
    \\
    \\section .text
    \\
    \\clear_cells:
    \\push DWORD (30000 * 4)
    \\push DWORD 0
    \\push DWORD cells
    \\call memset
    \\add  esp, 12
    \\ret
    \\
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
    \\main:
    \\call clear_cells
    \\
;

const epilog =
    \\
    \\xor eax,eax
    \\ret
;

pub fn codegen(ir_array: []IR, allocator: std.mem.Allocator) ![]u8 {
    var assembly_buffer: std.ArrayList(u8) = .empty;
    defer assembly_buffer.deinit(allocator);

    try assembly_buffer.appendSlice(allocator, prolog);
    _ = ir_array;
    try assembly_buffer.appendSlice(allocator, epilog);

    return try assembly_buffer.toOwnedSlice(allocator);
}
