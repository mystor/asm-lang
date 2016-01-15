#!/bin/sh

# Configuration
export REVISION=$(git rev-parse --short HEAD)
ASMFLAGS="-g -w+all -f elf64 -F stabs"
if [ "$1" = "--debug" ]; then
    ASMCC="gdb -- ./asmcc"
else
    ASMCC="./asmcc"
fi

# Build
set -e -x

nasm $ASMFLAGS -o asmcc.o start.asm
ld -o asmcc asmcc.o
$ASMCC examples/test.c
