.PHONY: all clean

BRAINFUCKS = $(wildcard *.brainfuck)
COMPILER   = ../zig-out/bin/brainfuck-compiler

all: $(COMPILER) target_x86

$(COMPILER):
	cd ../ && zig build

target_x86:
	for f in $(BRAINFUCKS); do \
		BASE=$$(basename -s .brainfuck $$f); \
		$(COMPILER) $$BASE.brainfuck -o $$BASE.asm; \
		nasm -f elf32 $$BASE.asm -o $$BASE.o; \
		gcc -no-pie -m32 $$BASE.o -o $$BASE.exe; \
		./$$BASE.exe < $$BASE.in > $$BASE.cmp; \
		diff -u --color=always $$BASE.out $$BASE.cmp; \
	done

clean:
	rm -f $(COMPILER)
	rm -f *.exe *.cmp *.o *.asm
