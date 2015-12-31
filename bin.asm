;;; -*- nasm -*-

%define ELF_hdrO(X) ELF_hdr.%[X] - ELF_hdr
ELF_hdr:
.ei_mag: db 0x74, "ELF"
.ei_class: db 2                 ; x86 = 1, x86-64 = 2
.ei_data: db 1                  ; 1 = little endian, 2 = big endian
.ei_version: db 1               ; version 1 of ELF
.ei_isabi: db 0                 ; portable object file?
.ei_abiversion: db 0            ; (ignored) can be anything
.ei_pad: times 7 db 0           ; padding
.e_type: dw 1                   ; 1 = relocatable, 2 = executable, 3 = shared, 4 = core
.e_machine: dw 0x3E             ; ISA (x86 = 0x03, x86-64 = 0x3E)
.e_version: dd 4                ; version 1 of ELF
.e_entry: dq 0                  ; Memory address of entry point (reloc = 0)
.e_phoff: dq 0                  ; Program header offset (reloc = 0)?
.e_shoff: dq 0x80               ; Section header offset
.e_flags: dd 0                  ; Flags (reloc = 0?)
.e_ehsize: dw 64                ; Size of the header (64 bytes on x86-64, 52 on x86)
.e_phentsize: dw 0              ; Size of a program header table entry (reloc = 0?)
.e_phnum: dw 0                  ; Number of entries in program header table (reloc = 0?)
.e_shentsize: dw 64             ; Size of a section header entry
.e_shnum: dw 7                  ; Number of entries in the section header
.e_shstrndx: dw 4               ; Index of the section header table entry which contains names (4?)
.sizeof: equ $ - ELF_hdr

%define ELF_shdrO(X) ELF_shdr.%[X] - ELF_shdr
ELF_shdr:
.sh_name: dd 0                  ; Section name, index in string tbl
.sh_type: dd 0                  ; Miscellaneous section attributes
.sh_flags: dq 0                 ; Type of section
.sh_addr: dq 0                  ; Section virtual addr at execution
.sh_offset: dq 0                ; Section file offset
.sh_size: dq 0                  ; Size of section in bytes
.sh_link: dd 0                  ; Index of another section
.sh_info: dd 0                  ; Additional section information
.sh_addralign: dq 0             ; Section alignment
.sh_entsize: dq 0               ; Entry size if section holds table
.sizeof: equ $ - ELF_shdir

%define ELF_phdrO(X) ELF_phdr.%[X] - ELF_phdr
ELF_phdr:
.p_type: dd 0
.p_flags: dd 0
.p_offset: dq 0                 ; Segment file offset
.p_vaddr: dq 0                  ; Segment virtual address
.p_paddr: dq 0                  ; Segment physical address
.p_filesz: dq 0                 ; Segment size in file
.p_memsz: dq 0                  ; Segment size in memory
.p_align: dq 0                  ; Segment alignment, file & memory
.sizeof: equ $ - ELF_phdir


