;;; Memory management. Request a pointer to memory
;;; This is horrifically inefficient, and the memory can't be freed. But that's OK
;;; 'cause this process is short lived, and most Malloced values should live for the full duration of the program
%define SYS_MMAP        9

%define PROT_READ       0x1
%define PROT_WRITE      0x2
%define PROT_EXEC       0x4

%define MAP_PRIVATE     0x2
%define MAP_ANON        0x20
%define MAP_FAILED      -1

%define PAGE_SIZE       4096

        section .data

malloc_page:    dq      0
malloc_rem:     dq      0

Malloc:
        fn r12                  ; r12 = size
        cmp r12, malloc_rem
        jl __Malloc_NewPage

__Malloc_RetPtr:
        mov rax, [malloc_page]
        sub [malloc_rem], r12
        add [malloc_page], r12

        fnret rax

__Malloc_NewPage:
        ;; mmap(2) a new page to store in
        ;; TODO(michael): Detect if r12 is larger than a page!
        mov rax, SYS_MMAP
        mov rdi, 0                      ; addr (zero works?)
        mov rsi, PAGE_SIZE              ; # of bytes to allocate (1 page)
        mov rdx, PROT_READ | PROT_WRITE ; Protections
        mov r10, MAP_PRIVATE | MAP_ANON ; Flags
        mov r8, 0                       ; File Descriptor (unused)
        mov r9, 0                       ; Offset (unused)

        syscall

        cmp rax, MAP_FAILED
        je __Malloc_AllocFailure

        mov [malloc_page], rax
        mov QWORD [malloc_rem], PAGE_SIZE
        jmp __Malloc_RetPtr

__Malloc_AllocFailure:
        Panic 101, 'Could not allocate memory!', NL
