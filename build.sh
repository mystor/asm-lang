#!/bin/bash

function build() {
    set -x
    nasm $ASMFLAGS -o asmcc.o start.asm || exit $?
    ld -o asmcc asmcc.o || exit $?
    { set +x; } 2> /dev/null # Disable logging
}

function run() {
    set -x
    ./asmcc examples/test.c
}

function run_with_debugger() {
    set -x
    gdb --args asmcc examples/test.c
}

function run_with_backtrace() {
    set -x
    nm asmcc -l > syms
    { ./asmcc examples/test.c; exit $?; } | \
        { tee log | sed -e '/fn>>/d'; } 2>/dev/null
    { set +x; } 2> /dev/null # Disable logging

    # Print out the backtrace if it is present
    sed -e '/fn>>/ !d' -e 's/fn>> //' log | \
        xargs -I pat -n1 grep pat syms
}

# defaults
RUN=yes
DEBUG=yes
DEBUGGER=no
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
    if [ "$ARG" = "--debug" ]; then
        DEBUGGER=yes
    fi
done

if [ $DEBUG = yes ]; then
    ASMFLAGS="$ASMFLAGS -g -F stabs"
fi

if [ $BACKTRACE = yes ]; then
    ASMFLAGS="$ASMFLAGS -dBACKTRACE"
fi

# Debug Build & Run
build
if [ $RUN = yes ]; then
    if [ $DEBUGGER = yes ]; then
        run_with_debugger
    elif [ $BACKTRACE = yes ]; then
        run_with_backtrace
    else
        run
    fi
fi
