;;; -*- nasm -*-
%include "util.asm"
%include "io.asm"
%include "memory.asm"
%include "string.asm"
%include "intern.asm"

;;; Compiler stages
%include "lexer.asm"
%include "ast.asm"
%include "parser.asm"

        section .text
        global _start
_start: fn
        alloca SizeOfToken, tok
        lea r12, [tok]
        WriteLit STDOUT, 'Welcome to Lang Compiler!', NL

.ParsePrintStmt:
        fcall PeekTok, r12
        cmp DWORD [r12+Token_type], TOKEN_EOF
        je .Exit

        fcall ParseStmt
        fcall WriteStmt, rax

        jmp .ParsePrintStmt
.Exit:
        Panic 0, 'Exited Normally', NL

ReadPrintTok:
        fcall ReadTok, r12
        ;; XXX: Make a PrintToken function which prints the token,
        ;; including (maybe) data.
        ; mov r13, [r12+Token_type]
        fcall WriteTOKEN, [r12+Token_type]
        cmp DWORD [r12+Token_type], TOKEN_EOF
        jne ReadPrintTok

        Panic 0, 'Exited normally', NL
