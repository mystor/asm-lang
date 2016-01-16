;;; -*- nasm -*-
%defstr REVISION %!REVISION

%include "util.asm"
%include "io.asm"
%include "memory.asm"
%include "string.asm"

;;; Compiler stages
%include "lexer.asm"
%include "ast.asm"
%include "parser.asm"
%include "sema.asm"
%include "bin.asm"


        section .text
        global _start
_start:
        loadargs
        ;; Set up base of stack for backtraces
        push QWORD _start
        push QWORD 0
        mov rbp, rsp

        ;; Print out the name of the executable
        mov rax, [argv]
        mov rcx, [rax+0]
        fcall StrRFind, rcx, '/'
        cmp rax, 0
        je .noslash
        lea rcx, [rax+1]
.noslash:
        fcall WriteStr, rcx
        WriteLit STDOUT, ' (HEAD ', REVISION, ')', NL, NL

        cmp QWORD [argc], 2
        jne .IncorrectArgLen

        ;; Open the first argument as an input file
        mov rax, SYS_OPEN
        mov rdi, [argv]
        mov rdi, [rdi+1*8]      ; First string argument
        mov rsi, O_RDONLY
        mov rdx, 0
        syscall
        cmp rax, -1             ; XXX: Actually handle errors
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
.Exit:
        fcall Exit, 0
.IncorrectArgLen:
        fcall WriteDec, [argc]
        WriteLit STDOUT, NL
        fcall WriteDec, [argv]
        Panic 101, 'Incorrect Argument Length', NL
.IncorrectArgValue:
        Panic 101, 'Incorrect Argument Value', NL

; ASDHASDHKSAD:                   ; Testing with generating executables
;         mov rax, SYS_OPEN
;         mov rdi, foo
;         mov rsi, O_WRONLY | O_TRUNC | O_CREAT
;         mov rdx, S_EXECUTABLE
;         syscall

;         mov r15, rax
;         fcall ElfInit
;         fcall ElfWriteStd
;         fcall ElfSetStart
;         fcall ElfWriteProg
;         fcall ElfWrite, r15

;         mov rax, SYS_CLOSE
;         mov rdi, r15
;         syscall

;         Panic 0, "DONE", NL
