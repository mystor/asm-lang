;;; -*- nasm -*-
        section .bss
frame_arr: resq 1               ; The array holding the current frame
curr: resq 1                    ; The index of the current frame start
salloc_offset: resq 1           ; The current offset from rbp of new allocs

        section .data
enum DALLOC
        opt GLOBAL
        opt LOCAL
        opt CONST
endenum

struct VarDef
        field name
        field type
        field alloc
        ;; If alloc is GLOBAL, data is a string containing the name
        ;; of the lazy scope 0 variable which needs to be read to get
        ;; the memory location of interest.
        ;; If alloc is CONST, data is a string containing the name
        ;; of the lazy scope 0 variable which needs to be read to get
        ;; the value of interest.
        ;; If alloc is LOCAL, data is the offset down from rbp of the value.
        field data
endstruct

        section .text
StackInit:
        fn
        fcall NewBigArr
        mov [frame_arr], rax
        DoArr PushQWord, [frame_arr], -1
        mov QWORD [curr], 0
        fnret

;;; Adds a new frame to the frame stack
StackPushFrame:
        fn
        ; x = frame_arr->len
        ; frame_arr->push(curr)
        ; curr = x
        mov r12, [frame_arr]
        mov r14, [r12+Array_len] ; Save the index of the start of the frame
        DoArr PushQWord, [frame_arr], [curr]
        mov [curr], r14
        fnret

StackPopFrame:
        fn
        ; x = frame_arr[curr]
        ; frame_arr->len = curr
        ; curr = x
        mov r12, [frame_arr]
        mov r13, [curr]
        mov rbx, [r12+r13]
        mov [curr], rbx
        mov [r12+Array_len], r13
        fnret

StackInsert:
        fn r12, r13, r14, r15   ; name, type, alloc, data
        mov rax, [frame_arr]
        fcall StackLookupFrame, r12, [curr], [rax+Array_len]
        cmp rax, 0
        jne .repeated
        fcall Alloc, Heap, SizeOfVarDef
        mov [rax+VarDef_name], r12
        mov [rax+VarDef_type], r13
        mov [rax+VarDef_alloc], r14
        mov [rax+VarDef_data], r15
        mov rcx, rax
        DoArr PushQWord, [frame_arr], rax
        fnret rcx
.repeated:
        Panic 'Cannot insert a duplicate variable name'

;;; Looks up a variable with the given name in the current scope.
;;; Returns 0 if there is no such variable
StackLookup:
        fn r12                  ; r12 = name
        mov rax, [frame_arr]
        mov r14, [rax+Array_len]
        mov r13, [curr]
.lookup:
        fcall StackLookupFrame, r12, r13, r14
        cmp rax, 0
        jne .done
        mov r14, r13
        mov r13, rbx
        cmp r13, -1
        jne .lookup
.done:
        fnret rax

;;; Lookup
StackLookupFrame:
        fn r12, r13, r14        ; r12 = name, r13 = base, r14 = end
        ;; Move past the first entry
        mov rcx, [frame_arr]
        mov r15, [rcx+r13]    ; r15 = next_base
.loop:
        add r13, 8
        cmp r13, r14
        jae .notfound
        mov rdx, [rcx+r13]    ; rax = the value
        fcall StrCmp, [rdx+VarDef_name], r12
        cmp rax, 0
        jne .loop
.found:
        mov rax, [rdx+VarDef_name] ; The type!
        fnret rax, r15
.notfound:
        fnret 0, r15

        section .rodata
S_$fsize: db "$fsize", 0

C_PopSA: db REX_BASE | REX_W, 0x81, 0xc4
.len: equ $ - C_PopSA

C_PushSA: db REX_BASE | REX_W, 0x81, 0xc4
.len: equ $ - C_PushSA

        section .text
EmitPopStackAllocs:
        fn
        DoArr Write, [ElfText], C_PopSA, C_PopSA.len
        fcall WriteLazy, ElfText, 1, S_$fsize, SizeOfDWORD
        fnret

EmitPushStackAlloc:
        fn
        DoArr Write, [ElfText], C_PushSA, C_PushSA.len
        fcall WriteLazy, ElfText, 1, S_$fsize, SizeOfDWORD
        fnret

;;; Clear all of the allocation data from the stack, filling in alloc values
StackClear:
        fn
        fcall SetLazy, 1, S_$fsize, [salloc_offset]
        mov QWORD [salloc_offset], 0
        fnret

;;; Allocate enough space on the stack for the type passed in
;;; And return the offset from rbp for it.
StackAlloc:
        fn r12
        fcall SizeOfType, r12
        add [salloc_offset], rax ; increase size of stack frame
        fnret [salloc_offset]
