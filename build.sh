#!/bin/sh

set -x

if nasm -f elf64 -g lang.asm -o lang.o; then
    if ld -o lang lang.o; then
        ./lang
        exit $?
    else
        exit $?
    fi
else
    exit $?
fi
