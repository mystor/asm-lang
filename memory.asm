;;; Memory "management" module. Provides mechanisms for allocating memory
;;; Including building strings. (N.B. Horribly naive and inefficient)
;;; No mechanism is provided for freeing memory. (GC is an optimization ^.^)

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

        section .text
;;; A horribly inefficient byte-by-byte memory copy loop
MemCpy:
        fn r12, r13, r14        ; r12 = src, r13 = dst, r14 = cnt
__MemCpy_Loop:
        cmp r14, 0
        je __MemCpy_Done
        mov BYTE al, [r12]
        mov BYTE [r13], al
        add r12, 1
        add r13, 1
        sub r14, 1
        jmp __MemCpy_Loop

__MemCpy_Done:
        fnret

;;; Allocate Aligned Memory
Malloc:
        fn r12                  ; r12 = size
        fcall Malloc_Align, 8
        fcall Malloc_Unaligned, r12
        fnret rax

;;; Align current allocation start
Malloc_Align:
        fn r12                  ; r12 = alignment
        mov rax, [malloc_page]
        div r12                 ; rdx has remainder
        cmp rdx, 0
        je __Malloc_Aligned
        sub r12, rdx            ; r12 has align - remainder
        add [malloc_page], r12  ; Move the page by the right amount
__Malloc_Aligned:
        fnret

;;; Allocate Unaligned Memory
Malloc_Unaligned:
        fn r12                  ; r12 = size
        cmp r12, [malloc_rem]
        jge __Malloc_NewPage

__Malloc_RetPtr:
        mov rax, [malloc_page]
        sub [malloc_rem], r12
        add [malloc_page], r12

        fnret rax

__Malloc_NewPage:
        ;; TODO(michael): Detect if r12 is larger than a page!
        cmp r12, PAGE_SIZE
        jge __Malloc_AllocFailure

        ;; mmap(2) a new page to store in
        mov rax, SYS_MMAP
        mov rdi, 0                      ; addr
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; String Builder Routines ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        section .data
string_start:   dq      0
string_end:     dq      0

        section .text
;;; Add a character to the current string buffer,
;;; Re-allocating the string buffer if the current page runs out of space.
;;; Is built on the super-sketchy internals of Malloc and Malloc_Unaligned
;;; above, which is why it is here, rather than in string.asm. If those
;;; are changed, this will almost certainly explode.
StringBuilder_Addc:
        fn r12                  ; r12 = the character
        cmp QWORD [string_start], 0
        je __StringBuilder_Addc_New_Alloc

        cmp QWORD [malloc_rem], 0
        je __StringBuilder_Addc_New_Alloc

__StringBuilder_Addc_Extend_Alloc:
        ;; Get the next byte from Malloc_Unaligned
        fcall Malloc_Unaligned, 1
        ;; Assert that we got back [string_end] as rax
        cmp QWORD [string_end], rax
        jne __StringBuilder_Addc_Failure

        jmp __StringBuilder_Addc_Write

__StringBuilder_Addc_New_Alloc:
        ;; Length into r13
        mov r13, [string_end]
        sub r13, [string_start]

        mov rax, r13
        add rax, 1
        fcall Malloc_Unaligned, rax
        mov r14, rax
        fcall MemCpy, [string_start], r14, r13

        add r13, r14
        mov [string_end], r13
        mov [string_start], r14
        jmp __StringBuilder_Addc_Write

__StringBuilder_Addc_Write:
        ;; Write out the character to memory
        mov r13, [string_end]
        mov BYTE [r13], r12b
        ;; Increment the string end value
        add QWORD [string_end], 1
        fnret

__StringBuilder_Addc_Failure:
        Panic 101, 'Could not add character!', NL

;;; Finish the current string, returning the pointer to the start of the string
StringBuilder_Done:
        fn
        ;; Add a trailing null character
        fcall StringBuilder_Addc, 0
        ;; Get the string's start
        mov r12, [string_start]
        ;; Reset the global state
        mov QWORD [string_start], 0
        mov QWORD [string_end], 0
        ;; Return the pointer to the string
        fnret r12
