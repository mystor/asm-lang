;;; -*- nasm -*-

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

;;; A horribly inefficient byte-by-byte memory copy loop
;;; If this ever becomes a bottleneck, we can implement
;;; A real copy loop
MemCpy:
        fn r12, r13, r14        ; r12 = src, r13 = dst, r14 = cnt
.loop:
        cmp r14, 0
        je .done
        mov BYTE al, [r12]
        mov BYTE [r13], al
        add r12, 1
        add r13, 1
        sub r14, 1
        jmp .loop
.done:
        fnret

;;; A inefficient byte-by-byte memory set loop
MemSet:
        fn r12, r13, r14        ; r12 = val, r13 = dst, r14 = cnt
.loop:
        cmp r14, 0
        je .done
        mov BYTE [r13], r12b
        add r13, 1
        sub r14, 1
        jmp .loop
.done:
        fnret

;;; 1 if r12 and r13's first r14 bytes are equal
;;; 0 otherwise
MemEq:
        fn r12, r13, r14
.loop:
        cmp r14, 0
        je .eq
        mov al, BYTE [r12]
        mov bl, BYTE [r13]
        cmp al, bl
        jne .neq
        add r12, 1
        add r13, 1
        sub r14, 1
        jmp .loop
.eq:
        fnret 1
.neq:
        fnret 0


;;; Offsets of the page and remainder properties in heaps
%define Heap_page 0
%define Heap_rem 8
%define SizeOfHeap 16

;;; Declare the global heap
        section .bss
Heap: resq 2

        section .text

;;; Allocate an 8-byte aligned block of memory with size r12
Alloc:
        fn r15, r12             ; r15 = heap, r12 = size
        fcall AlignHeap, r15
        fcall AllocUnal, r15, r12
        fnret rax

;;; Align the current allocation tip to r12 bytes
AlignHeap:
        fn r15                  ; r15 = heap
        mov rax, [r15+Heap_page]
        and rax, !7
        ;mov rdx, 0
        ;div r12                 ; rdx has remainder
        cmp rax, 0
        je .aligned
        sub r12, rax             ; r12 has align - remainder
        add [r15+Heap_page], r12 ; Move the page by the right amount
        sub [r15+Heap_rem], r12  ; Remove that amount from remaining space
.aligned:
        fnret

;;; Allocate an block of memory with size r12 at the current allocation tip
AllocUnal:
        fn r15, r12             ; r15 = heap, r12 = size
        cmp r12, [r15+Heap_rem]
        jge .newpage
.retptr:
        mov r13, [r15+Heap_page]
        sub [r15+Heap_rem], r12
        add [r15+Heap_page], r12
        fcall MemSet, 0, r13, r12
        fnret r13
.newpage:
        cmp r12, PAGE_SIZE      ; XXX: Currently cannot allocate a continuous block of more than a page...
        ja .failure

        fcall AllocNewPage
        mov [r15+Heap_page], rax
        mov QWORD [r15+Heap_rem], PAGE_SIZE
        jmp .retptr
.failure:
        Panic 'FATAL ERROR: Could not allocate memory on heap'

;;; Try to free the pointer/size.
;;; Only works if pointer is most recently allocated pointer, otherwise NOP
Free:
        fn r15, r12, r13        ; r15 = heap, r12 = ptr, r13 = size
        ;; Check if this is the most recently allocated pointer
        mov rax, [r15+Heap_page]
        sub rax, r13
        cmp rax, r12
        je .recent
        WriteLit STDOUT, 'WARNING: Attempt to free non-recent memory'
        fnret
.recent:
        mov [r15+Heap_page], r12
        add [r15+Heap_rem], r13
        fnret

Realloc:
        fn r15, r12, r13, r14   ; r15 = heap, r12 = ptr, r13 = size, r14 = new size
        cmp r12, 0              ; NULL always requires an allocation
        je .newalloc
        mov rax, [r15+Heap_page]
        sub rax, r13
        cmp rax, r12
        je .recent
.newalloc:                      ; Cannot re-use old allocation
        cmp r14, r13
        jle .nochange
        fcall Alloc, r15, r14
        push rax                ; Save the return value of Alloc across the call
        fcall MemCpy, r12, rax, r13
        pop rax
        fnret rax
.recent:                        ; Try to re-use old allocation
        mov rax, r14
        sub rax, r13            ; Calculate difference in sizes
        cmp rax, [r15+Heap_rem] ; Check if it's too big to fit (signed)
        jg .newalloc            ; No point freeing - will need new page
        sub [r15+Heap_rem], rax
        add [r15+Heap_page], rax
        lea rbx, [r12+r13]
        fcall MemSet, 0, rbx, rax
.nochange:
        fnret r12, rbx

;;; Allocate a full page from the OS with mmap
AllocNewPage:
        fn
        mov rax, SYS_MMAP
        mov rdi, 0                      ; addr
        mov rsi, PAGE_SIZE              ; # of bytes to allocate (1 page)
        mov rdx, PROT_READ | PROT_WRITE ; Protections
        mov r10, MAP_PRIVATE | MAP_ANON ; Flags
        mov r8, 0                       ; File Descriptor (unused)
        mov r9, 0                       ; Offset (unused)
        syscall

        cmp rax, MAP_FAILED
        je .failed
        fnret rax
.failed:
        Panic 'Could not allocate a page from the OS!'

;;;;;;;;;;;;;;;;;;;
;;; Array Logic ;;;
;;;;;;;;;;;;;;;;;;;

%define Array_heap -24
%define Array_len -16
%define Array_cap -8
%define Array_HeadSize 24

;;; Create a new array, returning a pointer to it
NewArr:
        fn r15, r12             ; r15 = heap, r12 = initial capacity
        ;; Allocate space for header before array capacity
        lea r9, [r12+Array_HeadSize]
        fcall Alloc, r15, r9
        add rax, Array_HeadSize
        mov [rax+Array_heap], r15
        mov QWORD [rax+Array_len], 0
        mov [rax+Array_cap], r12
        fnret rax

;;; Create a new array which owns its own heap. Allocates its heap on Heap
;;; XXX: Right now this is horribly inefficient, and will waste tons of space
NewBigArr:
        fn
        fcall Alloc, Heap, SizeOfHeap
        fcall NewArr, rax, PAGE_SIZE - Array_HeadSize
        fnret rax

;;; Helper macro for running ExtendArr and friends
%macro DoArr 3+
        fcall __%1Arr, %2, %3
        mov %2, rax
        mov rax, rbx
%endmacro
%macro DoArr 2
        fcall __%1Arr, %2
        mov %2, rax
        mov rax, rbx
%endmacro

;;; Extends the array by N bytes, returning the array pointer in rax,
;;; and a pointer to the new element in rbx
__ExtendArr:
        fn r12, r13             ; r12 = array, r13 = amount
        mov rax, [r12+Array_len]
        add rax, r13
        cmp rax, [r12+Array_cap]
        jg .resize              ; Intentionally signed
                                ; (so can ExtendArr negative)
.fits:
        mov rax, [r12+Array_len]
        lea rbx, [r12+rax]      ; Index of new array elt in rbx
        add rax, r13            ; Increment len property
        mov [r12+Array_len], rax
        fnret r12, rbx          ; ptr to new elt in rbx!
.resize:
        mov rax, [r12+Array_heap]     ; Target Heap
        lea rbx, [r12-Array_HeadSize] ; Allocation Pointer
        mov rcx, [r12+Array_cap]      ; Old Capacity
        add rcx, Array_HeadSize
        lea r15, [rcx*2]              ; New Capacity
        add r15, Array_HeadSize
        fcall Realloc, rax, rbx, rcx, r15
        lea r12, [rax+Array_HeadSize]
        sub r15, Array_HeadSize
        mov [r12+Array_cap], r15 ; Update capacity!
        jmp .fits

;;; Extend the array by 8 bytes, and insert the number. Returns the new array
__PushQWordArr:
        fn r12, r13             ; r12 = array, r13 = number
        fcall __ExtendArr, r12, 8
        mov [rbx], r13
        fnret rax, rbx

;;; Extends the array by one character, setting that character to r13
;;; Returns a pointer to the array
__PushChrArr:
        fn r12, r13             ; r12 = array, r13 = char
        fcall __ExtendArr, r12, 1
        mov BYTE [rbx], r13b
        fnret rax, rbx

;;; Seals an array, removing its header, and attempting to free any un-used space
;;; Returns a pointer to the newly-sealed array
__SealArr:
        fn r12                  ; r12 = array
        ;; Load the head into registers
        mov r15, [r12+Array_heap]
        mov r13, [r12+Array_len]
        mov r14, [r12+Array_cap]

        ;; Copy the length back over the head. As MemCpy copies from low
        ;; addresses to high addresses, this overlapping should be OK
        lea rax, [r12-Array_HeadSize]
        fcall MemCpy, r12, rax, r13

        sub r12, Array_HeadSize ; Move r12 to start of array

        ;; Free the remaining memory
        lea rax, [r14+Array_HeadSize] ; Get size of allocation
        sub rax, r13                  ; Remove useful size
        lea rbx, [r12+r13]            ; Get end of useful data
        fcall Free, r15, rbx, rax
        fnret r12, rbx

;;; Write the data and length to the array
__WriteArr:
        fn r12, r13, r14        ; r12 = array, r13 = data, r14 = len
        DoArr Extend, r12, r14
        fcall MemCpy, r13, rbx, r14
        fnret r12

;;; Add bytes to the end of the array such that it is 8-byte aligned
AlignArr:
        fn r12
        mov rax, [r12+Array_len]
        and rax, 7
        cmp rax, 0
        je .aligned
        add QWORD [r12+Array_len], 8 ; Can directly modify as will be in bounds
        sub [r12+Array_len], rax
.aligned:
        fnret r12

struct KVPair
        field key
        field value
endstruct

;;; Looks up a value by key - returns a pointer to the value
LookupByKey:
        fn r12, r13             ; r12 = address of array, r13 = string key
        mov r12, [r12]          ; Dereference r12!
        mov r14, [r12+Array_len]
.loop:
        cmp r14, 0
        jle .notfound
        sub r14, SizeOfKVPair
        mov rax, [r12+r14+KVPair_key]
        fcall StrCmp, rax, r13
        cmp rax, 0
        je .found
        jmp .loop
.found:
        lea rax, [r12+r14+KVPair_value]
        fnret rax
.notfound:
        fnret 0

;;; Looks up a value by key - returns a pointer to the value
;;; if the key is not present, inserts it, and returns a
;;; pointer to where the value should go
LookupOrInsertByKey:
        fn r12, r13             ; r12 = address of array, r13 = string key
        fcall LookupByKey, r12, r13
        cmp rax, 0
        jne .found
.notfound:
        DoArr Extend, [r12], SizeOfKVPair
        mov [rax+KVPair_key], r13
        lea rax, [rax+KVPair_value]
.found:
        fnret rax

%define SizeOfQWORD 8
%define SizeOfDWORD 4
%define SizeOfWORD 2
%define SizeOfBYTE 1


