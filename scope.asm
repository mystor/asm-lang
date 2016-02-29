;;; -*- nasm -*-
        section .bss
globl_heap FrameHeap
frame_arr: resq 1               ; The array holding the current frame
curr: resq 1                    ; The index of the current frame start

        section .data
struct VarDef
        field name
        field type
endstruct

        section .text
StackInit:
        fn
        fcall NewArr, FrameHeap, 2048
        mov [frame_arr], rax
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
        fcall PushQWordArr, r12, [curr]
        mov [frame_arr], rax
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
        fn r12, r13             ; r12 = name, r13 = type
        mov rax, [frame_arr]
        mov r15, [rax+Array_len]
        mov r14, [curr]
        fcall StackLookupFrame, r12, r14, r15
        cmp rax, 0
        jne .repeated
        fcall Alloc, Heap, SizeOfVarDef
        mov [rax+VarDef_name], r12
        mov [rax+VarDef_type], r13
        fcall PushQWordArr, [frame_arr], rax
        mov [frame_arr], rax
        fnret
.repeated:
        Panic 101, 'Cannot insert a duplicate variable name'

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
        cmp r13, 0
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

        section .data
_EmitPSF_Data:
        db REX_BASE | REX_W
        db 0x81
        db 0xc4
.value: times 4 db 0
.len: equ $ - _EmitPSF_Data

;;; Emit the code for popping items from the frame stack
;;; Doesn't actually pop the frame stack
EmitPopStackFrame:
        fn
        mov r12, [frame_arr]
        mov r13, [curr]
        mov r14, [r12+Array_len]
        mov r15, 0
.loop:
        add r13, 8
        cmp r13, r14
        jae .done
        mov rax, [r12+r13]
        fcall SizeOfType, [rax+VarDef_type]
        add r15, rax
        jmp .loop
.done:
        push r15                ; XXX: Does this copy the high bits?
        fcall MemCpy, rsp, _EmitPSF_Data.value, 4
        pop r15
        fcall ElfWriteText, _EmitPSF_Data, _EmitPSF_Data.len
        fnret r15
