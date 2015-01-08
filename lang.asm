%include "util.asm"
%include "io.asm"
%include "lexer.asm"

        section .text
        global _start
_start:
        WriteStr STDOUT, 'Welcome to Lang Compiler!', NL

ReadPrintTok:
        fcall ReadTok
        mov r12, rax
        fcall PrintTOKEN, r12
        cmp r12, TOKEN_EOF
        jne ReadPrintTok

        mov rax, 60
        mov rdi, 0
        syscall
