;;; -*- nasm -*-

        section .data
;ELF_symtab:
;.offset: equ $ - ELF_prelude
;.st_name: dd ELF_shstrtab._start
;.st_info: db STB_LOCAL
;.st_other: db 0
;.st_shndx: dw 1
;.st_value: dq 0xDEADBEEF
;.st_size: dq 0
;.length: equ $ - ELF_symtab

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

;;; Possible values for sh_type
%define ST_NULL 0
%define ST_PROGBITS 1
%define ST_SYMTAB 2
%define ST_STRTAB 3

;;; Possible values for sh_flags
%define SF_W 0x1
%define SF_A 0x2
%define SF_X 0x4

%define STB_LOCAL 0 << 4
%define STB_GLOBAL 1 << 4

%define ST_entry_size 0x18
%define ST_name 0               ; DWORD
%define ST_info 4               ; BYTE
%define ST_other 5              ; BYTE
%define ST_shndx 6              ; DWORD
%define ST_value 8              ; QWORD
%define ST_size 16              ; QWORD

%define ELF_hdr_size 64
%define ELF_phdr_size 56
%define ELF_shdr_size 64
%define ELF_base_addr 0x400000

%define SHN_Text 1
%define SHN_Data 2

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
.e_phoff: dq ELF_phoff          ; Program header offset
.e_shoff: dq ELF_shoff          ; Section header offset (absent from executable)
.e_flags: dd 0                  ; Flags
.e_ehsize: dw ELF_hdr_size      ; Size of this header
.e_phentsize: dw ELF_phdr_size  ; Size of a program header table entry
.e_phnum: dw 2                  ; Number of entries in program header table
.e_shentsize: dw ELF_shdr_size  ; Size of a section header entry
.e_shnum: dw 6                  ; Number of entries in the section header
.e_shstrndx: dw 3               ; Section header table for names index

ELF_phoff: equ $ - ELF_prelude
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

ELF_shoff: equ $ - ELF_prelude
ELF_snull:
.sh_name: dd 0                   ; Section name, index in string tbl
.sh_type: dd 0                   ; Miscellaneous section attributes
.sh_flags: dq 0                  ; Type of section
.sh_addr: dq 0                   ; Section virtual addr at execution
.sh_offset: dq 0                 ; Section file offset
.sh_size: dq 0                   ; Size of section in bytes
.sh_link: dd 0                   ; Index of another section
.sh_info: dd 0                   ; Additional section information
.sh_addralign: dq 0              ; Section alignment
.sh_entsize: dq 0                ; Entry size if section holds table

ELF_stext:
.sh_name: dd ELF_shstrtab.text  ; Section name, index in string tbl
.sh_type: dd ST_PROGBITS        ; Miscellaneous section attributes
.sh_flags: dq SF_X | SF_A       ; Type of section
.sh_addr: dq ELF_text_start     ; Section virtual addr at execution
.sh_offset: dq ELF_prelude_size ; Section file offset
.sh_size: dq 0xDEADBEEF         ; Size of section in bytes
.sh_link: dd 0                  ; Index of another section
.sh_info: dd 0                  ; Additional section information
.sh_addralign: dq 0x200000      ; Section alignment
.sh_entsize: dq 0               ; Entry size if section holds table

ELF_sdata:
.sh_name: dd ELF_shstrtab.data  ; Section name, index in string tbl
.sh_type: dd ST_PROGBITS        ; Miscellaneous section attributes
.sh_flags: dq SF_W | SF_A       ; Type of section
.sh_addr: dq 0xDEADBEEF         ; Section virtual addr at execution
.sh_offset: dq 0xDEADBEEF       ; Section file offset
.sh_size: dq 0xDEADBEEF         ; Size of section in bytes
.sh_link: dd 0                  ; Index of another section
.sh_info: dd 0                  ; Additional section information
.sh_addralign: dq 0x200000      ; Section alignment
.sh_entsize: dq 0               ; Entry size if section holds table

ELF_sshstrtab:
.sh_name: dd ELF_shstrtab.shstrtab ; Section name, index in string tbl
.sh_type: dd ST_STRTAB             ; Miscellaneous section attributes
.sh_flags: dq 0                    ; Type of section
.sh_addr: dq 0                     ; Section virtual addr at execution
.sh_offset: dq ELF_shstrtab.offset ; Section file offset
.sh_size: dq ELF_shstrtab.length   ; Size of section in bytes
.sh_link: dd 0                     ; Index of another section
.sh_info: dd 0                     ; Additional section information
.sh_addralign: dq 0x200000         ; Section alignment
.sh_entsize: dq 0                  ; Entry size if section holds table

ELF_ssymtab:
.sh_name: dd ELF_shstrtab.symtab  ; Section name, index in string tbl
.sh_type: dd ST_SYMTAB            ; Miscellaneous section attributes
.sh_flags: dq 0                   ; Type of section
.sh_addr: dq 0                    ; Section virtual addr at execution
.sh_offset: dq 0xDEADBEEF         ; Section file offset
.sh_size: dq 0xDEADBEEF           ; Size of section in bytes
.sh_link: dd 5                    ; Index of another section
.sh_info: dd 0                    ; Additional section information
.sh_addralign: dq 0x200000        ; Section alignment
.sh_entsize: dq ST_entry_size     ; Entry size if section holds table

ELF_sstrtab:
.sh_name: dd ELF_shstrtab.strtab ; Section name, index in string tbl
.sh_type: dd ST_STRTAB           ; Miscellaneous section attributes
.sh_flags: dq 0                  ; Type of section
.sh_addr: dq 0                   ; Section virtual addr at execution
.sh_offset: dq 0xDEADBEEF        ; Section file offset
.sh_size: dq 0xDEADBEEF          ; Size of section in bytes
.sh_link: dd 0                   ; Index of another section
.sh_info: dd 0                   ; Additional section information
.sh_addralign: dq 0x200000       ; Section alignment
.sh_entsize: dq 0                ; Entry size if section holds table

ELF_shstrtab:
.offset: equ $ - ELF_prelude
.data: equ $ - ELF_shstrtab
        db ".data", 0
.text: equ $ - ELF_shstrtab
        db ".text", 0
.shstrtab: equ $ - ELF_shstrtab
        db ".shstrtab", 0
.symtab: equ $ - ELF_shstrtab
        db ".symtab", 0
.strtab: equ $ - ELF_shstrtab
        db ".strtab", 0
.length: equ $ - ELF_shstrtab

ELF_prelude_size: equ $ - ELF_prelude

;;; The memory location where the first instruction occurs
;;; XXX: Make a utility function to change this for later when we emit
;;; functions in an arbitrary order
ELF_text_start: equ ELF_prelude_size + ELF_base_addr

        section .bss
ElfText: resq 1
data_arr: resq 1
symtab_arr: resq 1
strtab_arr: resq 1

%macro ElfFindLitSymbol 1
        section .rodata
%%label: db %1, 0
        section .text
        fcall ElfFindSymbol, %%label
%endmacro

        section .text
ElfInit:
        fn
        ;; Initialize the text and data heaps
        fcall NewBigArr
        mov [ElfText], rax
        fcall NewBigArr
        mov [data_arr], rax
        fcall NewBigArr
        mov [symtab_arr], rax
        fcall NewBigArr
        mov [strtab_arr], rax

        DoArr Extend, [symtab_arr], ST_entry_size
        DoArr Extend, [strtab_arr], 1
        fnret

;;; Write out the standard library
ElfWriteStd:
        fn
        DoArr Extend, [ElfText], stdlib.len
        fcall MemCpy, stdlib, rbx, stdlib.len

        ElfFindLitSymbol "std$$PrintNum"
        mov DWORD [rax+ST_shndx], SHN_Text
        mov QWORD [rax+ST_value], stdlib.PrintNum

        ElfFindLitSymbol "std$$PrintChr"
        mov DWORD [rax+ST_shndx], SHN_Text
        mov QWORD [rax+ST_value], stdlib.PrintChr

        ElfFindLitSymbol "std$$Exit"
        mov DWORD [rax+ST_shndx], SHN_Text
        mov QWORD [rax+ST_value], stdlib.Exit
        fnret

        section .rodata
StartSymbol: db "_start", 0
        section .text
ElfSetStart:
        fn
        mov rax, [ElfText]
        mov r12, [rax+Array_len]
        add r12, ELF_text_start
        mov [ELF_prelude.e_entry], r12

        fcall ElfFindSymbol, StartSymbol
        mov DWORD [rax+ST_shndx], SHN_Text
        mov QWORD [rax+ST_value], r12
        fnret

ElfFindSymbol:
        fn r12                  ; r12 = symbol name
        mov r13, [symtab_arr]   ; r13 = symbol table
        mov r14, [strtab_arr]   ; r14 = string table
        mov rcx, 0
        mov rdx, [r13+Array_len]

.search:
        cmp rcx, rdx
        jae .absent

        mov eax, [r13+rcx+ST_name] ; Get the name offset
        lea rax, [r14+rax]         ; Get a pointer to the actual string
        fcall StrCmp, rax, r12
        cmp rax, 0
        je .found

        add rcx, ST_entry_size
        jmp .search
.absent:
        fcall StrLen, r12       ; Allocate space for the name
        lea rcx, [rax+1]        ; Space for the nil
        DoArr Extend, [strtab_arr], rcx
        mov rdx, rax
        fcall MemCpy, r12, rdx, rcx ; Copy the data over
        sub rdx, [strtab_arr]   ; r14 is index in string array
        mov r14, rdx

        DoArr Extend, [symtab_arr], ST_entry_size ; Allocate space for symbol
        mov DWORD [rax+ST_name], r14d
        fnret rax
.found:
        fnret rcx

        section .data
SymbolMonotonic: dq 0

        section .text
%macro ElfLitUniqueSymbol 1
        [section .rodata]
        %%l: db %1, 0
        __SECT__
        fcall ElfUniqueSymbol, %%l
%endmacro
;;; Generate a unique symbol!?!?!?!?!?!?!?
ElfUniqueSymbol:
        fn r12                  ; r12 = symbol name hint
        ;; Increment the symbol monotonic
        NumToBinBuf [SymbolMonotonic]
        inc QWORD [SymbolMonotonic]

        ;; Get the length of the symbol monotonic number
        mov rdx, rbp
        sub rdx, rsp
        dec rdx                 ; Exclude nil

        ;; Load into array
        DoArr Extend, [strtab_arr], rdx
        mov r14, rax            ; r14 = offset of string
        sub r14, [strtab_arr]
        fcall MemCpy, rsp, rax, rdx

        ;; Also bring in the base, but include nil this time
        fcall StrLen, r12       ; Copy in the symbol name hint
        lea rdx, [rax+1]        ; Include nil
        DoArr Extend, [strtab_arr], rdx
        fcall MemCpy, r12, rax, rdx

        ;; Create the symbol table
        DoArr Extend, [symtab_arr], ST_entry_size
        mov DWORD [rax+ST_name], r14d
        fnret rax

ElfSetTextSymbol:
        fn r12                  ; r12 = symbol
        mov rax, [ElfText]
        mov r13, [rax+Array_len]
        add r13, ELF_text_start
        mov DWORD [r13+ST_shndx], SHN_Text
        mov QWORD [r13+ST_value], r12
        fnret r12

ElfWriteText:
        fn r12, r13             ; r12 = ptr, r13 = len
        DoArr Extend, [ElfText], r13
        fcall MemCpy, r12, rax, r13
        fnret

;;; XXX: Testing program
ElfWriteProg:
        fn
        DoArr Extend, [ElfText], testing123_len
        fcall MemCpy, testing123, rax, testing123_len
        fnret

;;; Finalize the current elf setup, filling in the headers with accurate data
ElfFinalize:
        fn
        ;; Copy over the correct lengths
        mov r12, [ElfText]     ; text
        fcall AlignArr, r12
        mov rax, [r12+Array_len]
        mov [ELF_text.p_filesz], rax
        mov [ELF_text.p_memsz], rax
        mov [ELF_stext.sh_size], rax

        mov r12, [data_arr]     ; data
        fcall AlignArr, r12
        mov rax, [r12+Array_len]
        mov [ELF_data.p_filesz], rax
        mov [ELF_data.p_memsz], rax
        mov [ELF_sdata.sh_size], rax

        mov r12, [symtab_arr]   ; symtab
        fcall AlignArr, r12
        mov rax, [r12+Array_len]
        mov [ELF_ssymtab.sh_size], rax

        mov r12, [strtab_arr]   ; strtab
        fcall AlignArr, r12
        mov rax, [r12+Array_len]
        mov [ELF_sstrtab.sh_size], rax

        ;; Setup start point and offsets
        mov rax, [ELF_stext.sh_offset] ; data
        add rax, [ELF_stext.sh_size]
        mov [ELF_data.p_offset], rax
        mov [ELF_sdata.sh_offset], rax
        add rax, ELF_base_addr
        mov [ELF_data.p_vaddr], rax
        mov [ELF_data.p_paddr], rax
        mov [ELF_sdata.sh_addr], rax

        mov rax, [ELF_sdata.sh_offset] ; symtab
        add rax, [ELF_sdata.sh_size]
        mov [ELF_ssymtab.sh_offset], rax

        mov rax, [ELF_ssymtab.sh_offset] ; strtab
        add rax, [ELF_ssymtab.sh_size]
        mov [ELF_sstrtab.sh_offset], rax
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
        mov rsi, [ElfText]
        mov rdx, [ELF_text.p_filesz]
        syscall

        ;; Write out the data
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, [data_arr]
        mov rdx, [ELF_data.p_filesz]
        syscall

        ;; Write out the symtab
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, [symtab_arr]
        mov rdx, [ELF_ssymtab.sh_size]
        syscall

        ;; Write out the strtab
        mov rax, SYS_WRITE
        mov rdi, r12
        mov rsi, [strtab_arr]
        mov rdx, [ELF_sstrtab.sh_size]
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

stdlib__PrintNum: db "$std_PrintNum", 0
stdlib__PrintChr: db "$std_PrintChr", 0
stdlib_syms:
        dq stdlib.PrintNum, stdlib__PrintNum
        dq stdlib.PrintChr, stdlib__PrintChr
.length: equ ($ - stdlib_syms) / 16

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

