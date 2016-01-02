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
%include "bin.asm"

        section .rodata
foo: db "output", 0
.len: equ $ - foo

        section .text
        global _start
_start: fn
        alloca SizeOfToken
        mov r12, rax
        WriteLit STDOUT, 'Welcome to Lang Compiler!', NL

        mov rax, SYS_OPEN
        mov rdi, foo
        mov rsi, O_WRONLY | O_TRUNC | O_CREAT
        mov rdx, S_EXECUTABLE
        syscall

        mov r15, rax
        fcall ElfInit
        fcall ElfWriteStd
        fcall ElfSetStart
        fcall ElfWriteProg
        fcall ElfWrite, r15

        ;fcall WriteBasicElf, r15

        mov rax, SYS_CLOSE
        mov rdi, r15
        syscall

        Panic 0, "DONE"

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
