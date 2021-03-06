;;; -*- nasm -*-
%define NL              10      ; EOL

;;; System Calls
%ifidn __OUTPUT_FORMAT__, elf64 ; Linux
        %define SYS_READ        0
        %define SYS_WRITE       1
        %define SYS_OPEN        2
        %define SYS_CLOSE       3

        %define SYS_EXIT        60

        %define SYS_FORK        57
        %define SYS_VFORK       58
        %define SYS_EXECVE      59

        %define SYS_RT_SIGACTION 13
        %define SYS_RT_SIGRETURN 15

        %define SIGSEGV 11
%else
        %error "Unsupported Platform"
%endif

;;; Open Flags
%define O_RDONLY 0
%define O_WRONLY 1
%define O_RDWR 2

%define O_CREAT 0x40
%define O_EXCL 0x80
%define O_NOCTTY 0x100
%define O_TRUNC 0x200
%define O_APPEND 0x400

;;; Permissions flags
%define S_IRUSR 0x100           ; Read user
%define S_IWUSR 0x80            ; Write user
%define S_IXUSR 0x40            ; Exec user
%define S_IALLUSR S_IRUSR | S_IWUSR | S_IXUSR

%define	S_IRGRP	(S_IRUSR >> 3)  ; Read grp
%define	S_IWGRP	(S_IWUSR >> 3)  ; Write grp
%define	S_IXGRP	(S_IXUSR >> 3)  ; Exec grp
%define S_IALLGRP S_IRGRP | S_IWGRP | S_IXGRP

%define	S_IROTH	(S_IRGRP >> 3)  ; Read other
%define	S_IWOTH	(S_IWGRP >> 3)  ; Write other
%define	S_IXOTH	(S_IXGRP >> 3)  ; Exec other
%define S_IALLOTH S_IROTH | S_IWOTH | S_IXOTH

;;; Default permissions for an executable
%define S_EXECUTABLE S_IALLUSR | S_IALLGRP | S_IROTH | S_IXOTH

;;; Default files
%define STDIN           0
%define STDOUT          1
%define STDERR          2

;;; Write out a file to FILENAME
;;; USAGE: WriteLit FILE 'string','com','pon','ents'
%macro WriteLit 2+
        section .rodata
%%str: db %2
%%len: equ $ - %%str
        section .text
        multipush rbp, r12, r13, r14, r15, rcx, rdx
        mov rax, SYS_WRITE
        mov rdi, %1
        mov rsi, %%str
        mov rdx, %%len
        syscall
        multipop rbp, r12, r13, r14, r15, rcx, rdx
%endmacro

;;; Write out an error message to STDERR
;;; And then abort the current program
%macro Panic 2+
        WriteLit STDOUT, %2, NL
        %ifdef BACKTRACE
        fcall DumpBacktrace
        %endif
        fcall Exit, %1
%endmacro

        section .text
Exit:
        fn rdi
        mov rax, SYS_EXIT
        syscall

%ifdef BACKTRACE
DumpBacktrace:
        fn r8
        mov r12, rbp
        WriteLit STDOUT, '==== BACKTRACE ====', NL
.loop:
        cmp r12, 0
        je .done
        WriteLit STDOUT, 'fn>> '
        fcall WriteHex, STDOUT, [r12+8]
        WriteLit STDOUT, NL
        ;; XXX: Maybe dump registers?
        mov r12, [r12]
        jmp .loop
.done:
        fnret
%endif


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

%macro NumToBinBuf 1
        mov rax, %1
        multipush r8, rdx
        mov r8, rsp
        sub rsp, 1
        mov BYTE [rsp], 0
%%charloop:
        sub rsp, 1
        mov rdx, 0
        mov r8, 10
        div r8
        add rdx, '0'
        mov [rsp], dl
        cmp rax, 0
        je %%done
        jmp %%charloop
%%done:
        mov rax, rsp
        multipop r8, rdx
%endmacro

WriteHex:
        fn r12, rax
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
        ;; Print the hexadecimal values
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, r8
        mov rdx, rsp
        sub rdx, r8
        syscall
        fnret

WriteDec:
        fn rax
_WriteDec_CharLoop:
        sub rsp, 1
        mov rdx, 0
        mov r8, 10
        div r8
        add rdx, '0'
        mov [rsp], dl
        cmp rax, 0              ; Write at least 1 char (test at end)
        je _WriteDec_EndLoop
        jmp _WriteDec_CharLoop
_WriteDec_EndLoop:
        mov rax, SYS_WRITE      ; Write
        mov rdi, STDOUT
        mov rsi, rsp
        mov rdx, rbp
        sub rdx, rsp
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


; %define SizeOfSigaction 4*8
%define Sigaction_sa_handler 0
%define Sigaction_sa_flags 8
%define Sigaction_sa_restorer 16
%define Sigaction_sa_mask 24
%define SizeOfSigset 128         ; Seems unnecessarially big
%define Sig_MAGIC_FLAGS 67108864 ; ???

        section .data
SigSEGVHandler:
        dq SegvHandler
        dq Sig_MAGIC_FLAGS
        dq __restore_rt
        times SizeOfSigset db 0

        section .text
SegvHandler:
        Panic 101, 'Received SIGSEGV - aborting.', NL

__restore_rt:
        mov rax, SYS_RT_SIGRETURN
        syscall
