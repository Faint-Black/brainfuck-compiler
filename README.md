# Brainfuck Compiler
Compiles brainfuck source into assembly for a select amount of platforms.

## Dependencies

### For building/running:
In order to just compile and run this compiler, all you need is:
* **Zig (0.15.x)**

### For testing:
In order to compile and run all platform tests, you need the additional software:
* **Qemu**
* **Nasm**
* **GCC**

## Building
```sh
zig build --release=safe
```

## Running
```sh
./zig-out/bin/brainfuck-compiler --help
```

## Testing
```sh
cd tests
make clean
make check
```
