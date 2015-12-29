;;; -*- nasm -*-
%define NL              10      ; EOL

;;; System Calls
%ifidn __OUTPUT_FORMAT__, macho64 ; OSX
        ;; macho64 requires relative addressing
        %define SYS_READ        0x2000003
        %define SYS_WRITE       0x2000004

        %define SYS_EXIT        0x2000001
%elifidn __OUTPUT_FORMAT__, elf64 ; Linux
        %define SYS_READ        0
        %define SYS_WRITE       1

        %define SYS_EXIT        60

        %define SYS_FORK        57
        %define SYS_VFORK       58
        %define SYS_EXECVE      59
%else
        %error "Unsupported Platform"
%endif

;;; Default files
%define STDIN           0
%define STDOUT          1
%define STDERR          2

;;; Write out a file to FILENAME
;;; USAGE: WriteLit FILE 'string','com','pon','ents'
%macro WriteLit 2+
        jmp     %%endstr
    %%str:      db      %2
    %%endstr:
        mov     rax,    SYS_WRITE
        mov     rdi,    %1
        mov     rsi,    %%str
        mov     rdx,    %%endstr-%%str
        syscall
%endmacro

;;; Write out an error message to STDERR
;;; And then abort the current program
%macro Panic 2+
        WriteLit STDERR, %2

        mov rax, SYS_EXIT
        mov rdi, %1
        syscall
%endmacro

WriteChr:
        fn r8, r9
        mov [rsp-8], r9
        mov rax, SYS_WRITE
        mov rdi, r8
        lea rsi, [rsp-8]
        mov rdx, 1
        syscall
        fnret

hex_table:      db      '0123456789abcdef'
hex_prefix:     db      '0x'
hex_len:        equ     $ - hex_prefix

WriteHex:
        fn rax
        mov r8, rsp

        ;; Calculate each of the hex characters
        %rep 16
        sub r8, 1
        mov r9, rax
        and r9, 0xF
        mov bl, [hex_table+r9]
        mov [r8], bl
        shr rax, 4
        ;; Check if we're done already
        cmp rax, 0
        je .done
        %endrep

.done:
        ;; Print the 0x prefix
        mov rax, SYS_WRITE
        mov rdi, STDOUT
        mov rsi, hex_prefix
        mov rdx, hex_len
        syscall

        ;; Print the hexadecimal values
        mov rax, SYS_WRITE
        mov rdi, STDOUT
        mov rsi, r8
        mov rdx, rsp
        sub rdx, r8
        syscall
        fnret

WriteStr:
        fn r12
        fcall StrLen, r12

        mov rdx, rax
        mov rax, SYS_WRITE
        mov rdi, STDOUT
        mov rsi, r12
        syscall
        fnret

Spawn:
        fn r12, r13             ; r12 = process, r13 = args

        ;; Fork off a subprocess
        mov rax, SYS_VFORK
        syscall
        cmp rax, -1
        je __Spawn_Fail
        cmp rax, 0
        jne __Spawn_Exit

        ;; Execute the new process
        mov rax, SYS_EXECVE
        mov rdi, r12
        mov rsi, r13
        mov rdx, 0
        syscall
__Spawn_Fail:
        Panic 100, "Failed to spawn subprocess", NL
__Spawn_Exit:
        fnret

GetChr:
        fn rdi
        mov rax, SYS_READ
        lea rsi, [rsp-8]
        mov QWORD [rsi], 0
        mov rdx, 1
        syscall
        cmp rax, 0
        je __GetChr_Fail
        fnret [rsp-8]
__GetChr_Fail:
        fnret -1

