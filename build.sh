#!/bin/sh

set -x

ASMFLAGS="-g -w+all -f elf64 -F stabs"

if nasm $ASMFLAGS -o lang.o lang.asm && ld -o lang lang.o
then
        if [ "$1" = "--debug" ]; then
            gdb -- ./lang examples/test.lang
        else
            ./lang examples/test.lang
        fi

        exit $?
else
    exit $?
fi
