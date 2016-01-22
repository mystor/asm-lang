#!/bin/bash

function build() {
    set -x
    nasm $ASMFLAGS -o asmcc.o start.asm || exit $?
    ld -o asmcc asmcc.o || exit $?
    { set +x; } 2> /dev/null # Disable logging
}

# defaults
RUN=yes
DEBUG=yes
BACKTRACE=yes
ASMFLAGS="-w+all -f elf64"

# Configuration
export REVISION=$(git rev-parse --short HEAD)
for ARG in $*; do
    if [ "$ARG" = "--release" ]; then
        ASMFLAGS="-w+all -f elf64"
        RUN=no
        DEBUG=no
        BACKTRACE=no
    fi
done

if [ $DEBUG = yes ]; then
    ASMFLAGS="$ASMFLAGS -g -F stabs -O0"
fi

if [ $BACKTRACE = yes ]; then
    ASMFLAGS="$ASMFLAGS -dBACKTRACE"
fi

# Debug Build & Run
build
if [ $RUN = yes ]; then
    if [ $BACKTRACE = yes ]; then
        rr ./asmcc examples/test.c | perl btparse.pl
    else
        rr ./asmcc examples/test.c
    fi
fi
