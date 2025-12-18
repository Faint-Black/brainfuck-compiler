.PHONY: all clean target_x86

BRAINFUCKS = $(wildcard *.brainfuck)
COMPILER   = ../zig-out/bin/brainfuck-compiler

check: $(COMPILER) target_x86

$(COMPILER):
	cd ../ && zig build

target_x86:
	@for f in $(BRAINFUCKS); do \
		echo "testing \"$$f\" for target x86_32..."; \
		BASE=$$(basename -s .brainfuck $$f); \
		$(COMPILER) --target=x86 $$BASE.brainfuck -o $$BASE.asm && \
		nasm -f elf32 $$BASE.asm -o $$BASE.o && \
		gcc -no-pie -m32 $$BASE.o -o $$BASE.exe && \
		qemu-i386 ./$$BASE.exe < $$BASE.in > $$BASE.cmp && \
		diff -u --color=always $$BASE.out $$BASE.cmp; \
	done

clean:
	rm -f $(COMPILER)
	rm -f *.exe *.cmp *.o *.asm
