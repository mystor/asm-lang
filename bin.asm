;;; -*- nasm -*-

        section .data
;%define ELF_hdrO(X) ELF_hdr.%[X] - ELF_hdr
;ELF_hdr:
;.ei_mag: db 0x7F, "ELF"
;.ei_class: db 2                  ; x86 = 1, x86-64 = 2
;.ei_data: db 1                   ; 1 = little endian, 2 = big endian
;.ei_version: db 1                ; version 1 of ELF
;.ei_isabi: db 0                  ; portable object file?
;.ei_abiversion: db 0             ; (ignored) can be anything
;.ei_pad: times 7 db 0            ; padding
;.e_type: dw 2                    ; 1 = relocatable, 2 = executable, 3 = shared, 4 = core
;.e_machine: dw 0x3E              ; ISA (x86 = 0x03, x86-64 = 0x3E)
;.e_version: dd 1                 ; version 1 of ELF
;.e_entry: dq 0x400080            ; Memory address of entry point
;.e_phoff: dq 64                  ; Program header offset
;.e_shoff: dq 0                   ; Section header offset (absent)
;.e_flags: dd 0                   ; Flags
;.e_ehsize: dw .sizeof            ; Size of this header (64 bytes on x86-64, 52 on x86)
;.e_phentsize: dw ELF_phdr.sizeof ; Size of a program header table entry
;.e_phnum: dw 1                   ; Number of entries in program header table
;.e_shentsize: dw ELF_shdr.sizeof ; Size of a section header entry
;.e_shnum: dw 0                   ; Number of entries in the section header
;.e_shstrndx: dw 0                ; Section header table for names index
;.sizeof: equ $ - ELF_hdr

        ;section .rodata
;%define ELF_shdrO(X) ELF_shdr.%[X] - ELF_shdr
;ELF_shdr:
;.sh_name: dd 0                  ; Section name, index in string tbl
;.sh_type: dd 0                  ; Miscellaneous section attributes
;.sh_flags: dq 0                 ; Type of section
;.sh_addr: dq 0                  ; Section virtual addr at execution
;.sh_offset: dq 0                ; Section file offset
;.sh_size: dq 0                  ; Size of section in bytes
;.sh_link: dd 0                  ; Index of another section
;.sh_info: dd 0                  ; Additional section information
;.sh_addralign: dq 0             ; Section alignment
;.sh_entsize: dq 0               ; Entry size if section holds table
;.sizeof: equ $ - ELF_shdr

;;; Possible values for p_type
%define PT_NULL 0
%define PT_LOAD 1
%define PT_DYNAMIC 2
%define PT_INTERP 3
%define PT_NOTE 4
%define PT_SHLIB 5
%define PT_PHDR 6

;;; Possible values for p_flags
%define PF_X 0x1
%define PF_W 0x2
%define PF_R 0x4

;%define ELF_phdrO(X) ELF_phdr.%[X] - ELF_phdr
;ELF_phdr:
;.p_type: dd PT_LOAD
;.p_flags: dd PF_X | PF_R
;.p_offset: dq 0                 ; Segment file offset
;.p_vaddr: dq 0x400000           ; Segment virtual address
;.p_paddr: dq 0x400000           ; Segment physical address (unused)
;.p_filesz: dq prog_len+0x80     ; Segment size in file
;.p_memsz: dq prog_len+0x80      ; Segment size in memory
;.p_align: dq 0x200000           ; Segment alignment, file & memory
;.sizeof: equ $ - ELF_phdr

%define ELF_hdr_size 64
%define ELF_phdr_size 56
%define ELF_shdr_size 64

%define ELF_base_addr 0x400000

ELF_prelude:
.ei_mag: db 0x7F, "ELF"         ; Magic number
.ei_class: db 2                 ; pointer size (32-bit = 1, 64-bit = 2)
.ei_data: db 1                  ; 1 = little endian, 2 = big endian
.ei_version: db 1               ; version 1 of ELF
.ei_osabi: db 0x03              ; Operating System ABI (linux = 0x03)
.ei_abiversion: db 0            ; ignored by linux
.ei_pad: times 7 db 0           ; padding
.e_type: dw 2                   ; 1 = relocatable, 2 = executable, 3 = shared, 4 = core
.e_machine: dw 0x3E             ; ISA (x86 = 0x03, x86-64 = 0x3E)
.e_version: dd 1                ; version 1 of ELF
.e_entry: dq 0xDEADBEEF         ; Memory address of entry point
.e_phoff: dq ELF_hdr_size       ; Program header offset
.e_shoff: dq 0                  ; Section header offset (absent from executable)
.e_flags: dd 0                  ; Flags
.e_ehsize: dw ELF_hdr_size      ; Size of this header
.e_phentsize: dw ELF_phdr_size  ; Size of a program header table entry
.e_phnum: dw 2                  ; Number of entries in program header table
.e_shentsize: dw ELF_shdr_size  ; Size of a section header entry
.e_shnum: dw 0                  ; Number of entries in the section header
.e_shstrndx: dw 0               ; Section header table for names index

ELF_text:
.p_type: dd PT_LOAD
.p_flags: dd PF_X | PF_R
.p_offset: dq ELF_prelude_size  ; Segment file offset
.p_vaddr: dq ELF_text_start     ; Segment virtual address
.p_paddr: dq ELF_text_start     ; Segment physical address (unused)
.p_filesz: dq 0xDEADBEEF        ; Segment size in file
.p_memsz: dq 0xDEADBEEF         ; Segment size in memory
.p_align: dq 0x200000           ; Segment alignment, file & memory

ELF_data:
.p_type: dd PT_LOAD
.p_flags: dd PF_W | PF_R
.p_offset: dq 0xDEADBEEF        ; Segment file offset
.p_vaddr: dq 0xDEADBEEF         ; Segment virtual address
.p_paddr: dq 0xDEADBEEF         ; Segment physical address (unused)
.p_filesz: dq 0xDEADBEEF        ; Segment size in file
.p_memsz: dq 0xDEADBEEF         ; Segment size in memory
.p_align: dq 0x200000           ; Segment alignment, file & memory

ELF_prelude_size: equ $ - ELF_prelude

;;; The memory location where the first instruction occurs
;;; XXX: Make a utility function to change this for later when we emit
;;; functions in an arbitrary order
ELF_text_start: equ ELF_prelude_size + ELF_base_addr

        section .data
globl_heap TextHeap
text_arr: dq 0
globl_heap DataHeap
data_arr: dq 0

        section .text
ElfInit:
        fn
        ;; Initialize the text and data heaps
        fcall NewArr, TextHeap, 2048
        mov [text_arr], rax
        fcall NewArr, DataHeap, 2048
        mov [data_arr], rax
        fnret

;;; Write out the standard library
ElfWriteStd:
        fn
        fcall ExtendArr, [text_arr], stdlib.len
        mov [text_arr], rax
        fcall MemCpy, stdlib, rbx, stdlib.len
        fnret

ElfSetStart:
        fn
        mov rax, [text_arr]
        mov rbx, [rax+Array_len]
        add rbx, ELF_text_start
        mov [ELF_prelude.e_entry], rbx
        fnret

ElfWriteProg:
        fn

        fcall ExtendArr, [text_arr], testing123_len
        mov [text_arr], rax
        fcall MemCpy, testing123, rbx, testing123_len

        fnret

;;; Finalize the current elf setup, filling in the headers with accurate data
ElfFinalize:
        fn

        ;; Copy over the correct lengths
        mov rbx, [text_arr]
        mov rax, [rbx+Array_len]
        mov [ELF_text.p_filesz], rax
        mov [ELF_text.p_memsz], rax
        mov rbx, [data_arr]
        mov rax, [rbx+Array_len]
        mov [ELF_data.p_filesz], rax
        mov [ELF_data.p_memsz], rax

        ;; Determine data start point, and address
        mov rax, [ELF_text.p_offset]
        add rax, [ELF_text.p_filesz]
        mov [ELF_data.p_offset], rax
        add rax, ELF_base_addr
        mov [ELF_data.p_vaddr], rax
        mov [ELF_data.p_paddr], rax
        fnret

ElfWrite:
        fn r12                  ; r12 = file
        fcall ElfFinalize

        ;; Write out the prelude
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, ELF_prelude
        mov rdx, ELF_prelude_size
        syscall

        ;; Write out the text
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, [text_arr]
        mov rdx, [ELF_text.p_filesz]
        syscall

        ;; Write out the data
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, [data_arr]
        mov rdx, [ELF_data.p_filesz]
        syscall
        fnret

%define REX_BASE 0b01000000
%define REX_W 0b00001000        ; 64-bit operand size
%define REX_R 0b00000100        ; Extension of ModR/M reg field
%define REX_X 0b00000010        ; Extension of SIB index field
%define REX_B 0b00000001        ; Extension of ModR/M r/m field, SIB base field,
                                ; or Opcode reg field

%define REG_RAX 0b000
%define REG_RBX 0b001
%define REG_RCX 0b010
%define REG_RDX 0b011
%define REG_RSP 0b100
%define REG_RBP 0b101
%define REG_RSI 0b110
%define REG_RDI 0b111

%define OP_MovImmReg 0xb8

section .rodata
;;; The standard library used by emitted programs
;;; Must only use short jumps and loads, as code must be relocatable
;;; Into the binary.
;;; Will be loaded in at the start of the text section
stdlib:
;;; Print number found in rax
.PrintNum: equ $ - stdlib + ELF_text_start
        ;; rax contains input number
        push rbp
        mov rbp, rsp
._PrintNum_CharLoop:
        sub rsp, 1
        mov rdx, 0
        mov r8, 10
        div r8
        add rdx, '0'
        mov [rsp], dl
        cmp rax, 0                    ; Print at least 1 char (test at end)
        je short ._PrintNum_EndLoop   ; Short jump for portable code
        jmp short ._PrintNum_CharLoop ; Short jump for portable code
._PrintNum_EndLoop:
        mov rax, SYS_WRITE      ; Print
        mov rdi, STDOUT
        mov rsi, rsp
        mov rdx, rbp
        sub rdx, rsp
        syscall
        mov rsp, rbp            ; Clean up & return
        pop rbp
        ret
;;; Print character found in rax
.PrintChr: equ $ - stdlib + ELF_text_start
        push rbp
        mov rbp, rsp
        sub rsp, 1
        mov [rsp], al
        mov rax, SYS_WRITE      ; Print
        mov rdi, STDOUT
        mov rsi, rsp
        mov rdx, 1
        syscall
        mov rsp, rbp            ; Clean up & return
        pop rbp
        ret
.Exit: equ $ - stdlib + ELF_text_start
        mov rdi, rax
        mov rax, SYS_EXIT
        syscall
.len: equ $ - stdlib

testing123:
        db REX_BASE | REX_W ; mov rsi, stdlib.Exit
        db OP_MovImmReg + REG_RSI
        dq stdlib.Exit
        db 0xFF                 ; jmp rsi
        db 0b11100000 + REG_RSI
testing123_len: equ $ - testing123

