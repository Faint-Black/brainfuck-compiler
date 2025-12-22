.PHONY: check verify clean target_x86 target_x64

BRAINFUCKS = $(wildcard *.bf)
COMPILER   = ../zig-out/bin/brainfuck-compiler

check: verify $(COMPILER) target_x86 target_x64

verify:
	@echo "verifying needed software..."
	@command -V zig
	@command -V gcc
	@command -V nasm
	@command -V qemu-i386
	@command -V qemu-x86_64
	@echo "done."

$(COMPILER):
	@echo "building compiler..."
	@zig build
	@echo "done."

target_x86:
	@for f in $(BRAINFUCKS); do \
		echo "testing \"$$f\" for target x86_32..."; \
		BASE=$$(basename -s .bf $$f); \
		$(COMPILER) --target=x86 $$BASE.bf -o $$BASE.x86.asm && \
		nasm -f elf32 $$BASE.x86.asm -o $$BASE.x86.o && \
		gcc -no-pie -m32 $$BASE.x86.o -o $$BASE.x86.exe && \
		qemu-i386 ./$$BASE.x86.exe < $$BASE.in > $$BASE.x86.cmp && \
		diff -u --color=always $$BASE.out $$BASE.x86.cmp && \
		echo "done."; \
	done

target_x64:
	@for f in $(BRAINFUCKS); do \
		echo "testing \"$$f\" for target x86_64..."; \
		BASE=$$(basename -s .bf $$f); \
		$(COMPILER) --target=x64 $$BASE.bf -o $$BASE.x64.asm && \
		nasm -f elf64 $$BASE.x64.asm -o $$BASE.x64.o && \
		gcc -no-pie -m64 $$BASE.x64.o -o $$BASE.x64.exe && \
		qemu-x86_64 ./$$BASE.x64.exe < $$BASE.in > $$BASE.x64.cmp && \
		diff -u --color=always $$BASE.out $$BASE.x64.cmp && \
		echo "done."; \
	done

clean:
	rm -f $(COMPILER)
	rm -f *.exe *.cmp *.o *.asm
