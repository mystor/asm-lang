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
        alloca SizeOfToken
        mov r12, rax
        WriteLit STDOUT, 'Welcome to Lang Compiler!', NL

.ParsePrintStmt:
        fcall PeekTok, r12
        cmp DWORD [r12+Token_type], TOKEN_EOF
        je .Exit

        fcall ParseStmt
        fcall WriteStmt, rax
        WriteLit STDOUT, NL

        jmp .ParsePrintStmt
.Exit:
        Panic 0, 'Exited Normally', NL
