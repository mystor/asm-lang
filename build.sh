#!/bin/sh

set -x

DEBUG_TYPE=stabs # dwarf doesn't seem to be working right now :(

if nasm -g -w+all -f elf64 -F $DEBUG_TYPE -o lang.o lang.asm; then
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
