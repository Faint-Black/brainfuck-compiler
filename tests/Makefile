.PHONY: all clean

COMPILER  = ../zig-out/bin/brainfuck-compiler
ASSEMBLER = nasm
LINKER    = gcc -no-pie

all: $(COMPILER)
	$(COMPILER) hello-world.brainfuck -o hello-world.asm
	$(ASSEMBLER) -f elf32 hello-world.asm -o hello-world.o
	$(LINKER) -m32 hello-world.o -o hello-world.exe
	./hello-world.exe > hello-world.cmp
	diff -u --color=always hello-world.out hello-world.cmp

$(COMPILER):
	cd ../ && zig build

clean:
	rm -f $(COMPILER)
	rm -f *.exe *.cmp *.o *.asm
