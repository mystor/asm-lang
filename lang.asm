;;; -*- nasm -*-
%include "util.asm"
%include "io.asm"
%include "memory.asm"
%include "string.asm"

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
_start:
        loadargs
        WriteLit STDOUT, 'Welcome to Lang Compiler!', NL

        cmp QWORD [argc], 2
        jne .IncorrectArgLen

        ;; Open the first argument as an input file
        mov rax, SYS_OPEN
        mov rdi, [argv]
        mov rdi, [rdi+1*8]      ; First string argument
        mov rsi, O_RDONLY
        mov rdx, 0
        syscall
        cmp rax, -1
        je .IncorrectArgValue
        mov [chr_infile], rax

.ParsePrintItem:
        fcall PeekTokType
        cmp rax, TOKEN_EOF
        je .Exit

        fcall ParseItem
        fcall WriteItem, rax
        WriteLit STDOUT, NL

        jmp .ParsePrintItem

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
.IncorrectArgLen:
        fcall WriteDec, [argc]
        WriteLit STDOUT, NL
        fcall WriteDec, [argv]
        Panic 101, 'Incorrect Argument Length', NL
.IncorrectArgValue:
        Panic 101, 'Incorrect Argument Value', NL

ASDHASDHKSAD:                   ; Testing with generating executables
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

        mov rax, SYS_CLOSE
        mov rdi, r15
        syscall

        Panic 0, "DONE", NL
