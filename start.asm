;;; -*- nasm -*-
%push asmcc                     ; Make sure that all scopes are popped
%defstr REVISION %!REVISION

%include "util.asm"
%include "io.asm"
%include "memory.asm"
%include "string.asm"
%include "lazy.asm"

;;; Compiler stages
%include "lexer.asm"
%include "ast.asm"
;%include "sema.asm"
%include "bin.asm"
%include "scope.asm"
%include "emit.asm"
%include "parser.asm"


        section .text
        global _start
        nop
_start:
        loadargs

        ;; Set up base of stack for backtraces
        ;; We have to add a bunch of garbage here... unfortunately
        call .__PROG_START__
.__PROG_START__:
        mov rbp, 0
        fn

%ifdef BACKTRACE
        ;; Hook up the segv handler
        mov rax, SYS_RT_SIGACTION
        mov rdi, SIGSEGV
        mov rsi, SigSEGVHandler
        mov rdx, 0
        mov r10, 8              ; MAGIC
        syscall
        cmp rax, 0
        jne .SigHandlerFailed
%endif

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

        ;fcall TypeckInit
        fcall LazyInit
        fcall StackInit
        fcall ElfInit
.ParsePrintItem:
        fcall PeekTok
        cmp rax, TOKEN_EOF
        je .Exit

        fcall ParseItem
        ;mov r12, rax
        ;fcall WriteItem, r12
        ;fcall TypeckItem, r12
        WriteLit STDOUT, NL

        jmp .ParsePrintItem
.Exit:
        fcall ElfWrite, 0       ; XXX: FIXME
        fcall Exit, 0
.IncorrectArgLen:
        fcall WriteDec, [argc]
        WriteLit STDOUT, NL
        fcall WriteDec, [argv]
        Panic 'Incorrect Argument Length'
.IncorrectArgValue:
        Panic 'Incorrect Argument Value'
.SigHandlerFailed:
        fcall WriteDec, rax
        Panic 'Signal handler Failed to Attach'
        nop
%pop asmcc
