#!/bin/sh

set -x

if nasm -f elf64 -g -l lang.lst lang.asm -o lang.o; then
    if ld -o lang lang.o; then
        if [ "$1" = "--debug" ]; then
            gdb -- ./lang
        else
            ./lang
        fi

        exit $?
    else
        exit $?
    fi
else
    exit $?
fi
