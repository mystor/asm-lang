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
%else
        %error "Unsupported Platform"
%endif

;;; Default files
%define STDIN           0
%define STDOUT          1

;;; Write out a file to FILENAME
;;; USAGE: WriteStr FILE 'string','com','pon','ents'
%macro WriteStr 2+
        jmp     %%endstr
    %%str:      db      %2
    %%endstr:
        mov     rax,    SYS_WRITE
        mov     rdi,    %1
        mov     rsi,    %%str
        mov     rdx,    %%endstr-%%str
        syscall
%endmacro

;;; Write out a single character
;;; USAGE: WriteChr <FILE = STDOUT> chr
%macro WriteChr 1
        WriteChr STDOUT, %1
%endmacro

%macro WriteChr 2
        mov rax, %2
        mov [rsp-8], rax
        mov rax, SYS_WRITE
        mov rdi, %1
        ;; Get the address just below the current stack ptr
        ;; (Allocating 8 bytes, for one character.)
        mov rsi, rsp
        sub rsi, 8
        mov rdx, 1
        syscall
%endmacro

hex_table:      db      '0123456789abcdef'
hex_prefix:     db      '0x'
hex_len:        equ     $ - hex_prefix

Write64:
        fn rax
        mov r8, rsp

        ;; Add the newline character
        sub r8, 1
        mov BYTE [r8], 10

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
        je __Write64Done
        %endrep

__Write64Done:
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

;;; Read in a single character
;;; USAGE: GetChr reg <FILE = STDIN>
%macro GetChr 1
        GetChr %1, STDIN
%endmacro

%macro GetChr 2
        mov rax, SYS_READ
        mov rdi, %2
        mov rsi, rsp                  ; Get some space on the stack
        sub rsi, 8
        mov QWORD [rsi], 0            ; Fill with 0s
        mov rdx, 1
        syscall
        cmp rax, 0
        je  %%fail
%%success:
        mov %1, [rsp-8]
        jmp %%done
%%fail:
        mov %1, -1
        jmp %%done
%%done:
        nop
%endmacro
