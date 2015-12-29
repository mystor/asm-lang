;; -*- nasm -*-
%include "util.asm"
%include "io.asm"
%include "memory.asm"
%include "string.asm"
%include "intern.asm"
%include "lexer.asm"

        section .text
        global _start
_start: fn
        alloca SizeOfToken, tok
        lea r12, [tok]
        WriteLit STDOUT, 'Welcome to Lang Compiler!', NL

ReadPrintTok:
        fcall ReadTok, r12
        ;; XXX: Make a PrintToken function which prints the token,
        ;; including (maybe) data.
        ; mov r13, [r12+Token_type]
        fcall PrintTOKEN, [r12+Token_type]
        cmp DWORD [r12+Token_type], TOKEN_EOF
        jne ReadPrintTok

        Panic 0, 'Exited normally', NL
