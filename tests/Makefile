.PHONY: check verify clean target_x86

BRAINFUCKS = $(wildcard *.brainfuck)
COMPILER   = ../zig-out/bin/brainfuck-compiler

check: verify $(COMPILER) target_x86

verify:
	@echo "verifying needed software..."
	@command -V zig
	@command -V gcc
	@command -V nasm
	@command -V qemu-i386
	@echo "done."

$(COMPILER):
	@echo "building compiler..."
	@cd ../ && zig build --release=safe
	@echo "done."

target_x86:
	@for f in $(BRAINFUCKS); do \
		echo "testing \"$$f\" for target x86_32..."; \
		BASE=$$(basename -s .brainfuck $$f); \
		$(COMPILER) --target=x86 $$BASE.brainfuck -o $$BASE.asm && \
		nasm -f elf32 $$BASE.asm -o $$BASE.o && \
		gcc -no-pie -m32 $$BASE.o -o $$BASE.exe && \
		qemu-i386 ./$$BASE.exe < $$BASE.in > $$BASE.cmp && \
		diff -u --color=always $$BASE.out $$BASE.cmp && \
		echo "done."; \
	done

clean:
	rm -f $(COMPILER)
	rm -f *.exe *.cmp *.o *.asm
