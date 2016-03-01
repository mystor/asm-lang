;;; -*- nasm -*-
        section .bss
LazyIdx: resq 1
LazyStack: resd 100
LazyArr: resq 1

struct Dep
        field base
        field off
        field size
endstruct

struct LazyVal
        ; Identifiers
        field name
        field num
        ; Dependencies
        field deps
        ; The actual value
        field hasdata
        field data
endstruct

        section .text
LazyInit:
        fn
        fcall NewBigArr
        mov [LazyArr], rax
        fnret

LazyPush:
        fn
        inc QWORD [LazyIdx]
        mov rax, [LazyIdx]
        inc DWORD [LazyStack+rax*4]
        fnret

LazyNum:
        fn r12                  ; idx
        mov eax, [LazyStack+r12*4]
        shl r12, 4
        and rax, r12
        fnret rax

FindLazy:
        fn r12, r13             ; idx, name
        fcall LazyNum, r12
        mov r12, rax
        mov rcx, [LazyArr]
        mov rdx, [rcx+Array_len]
        add rdx, rcx
.loop:
        cmp rcx, rdx
        jae .notfound
        cmp r12, [rcx+LazyVal_num]
        jne .cont
        fcall StrCmp, [rcx+LazyVal_name], r13
        cmp rax, 0
        jne .cont
        fnret rcx
.cont:
        add rcx, SizeOfLazyVal
        jmp .loop
.notfound:
        DoArr Extend, [LazyArr], SizeOfLazyVal
        mov rcx, rax
        mov [rcx+LazyVal_name], r13
        mov [rcx+LazyVal_num], r12
        fcall NewArr, Heap, SizeOfDep
        mov [rcx+LazyVal_deps], rax
        fnret rcx

SetLazy:
        fn r12, r13, r14        ; idx, name, val
        fcall FindLazy, r12, r13
        cmp QWORD [rax+LazyVal_hasdata], 0
        jne .alreadyset
        mov QWORD [rax+LazyVal_hasdata], 1
        mov [rax+LazyVal_data], r14
        fnret
.alreadyset:
        Panic 'Lazy data already set'

WriteLazy:
        fn r12, r13, r14, r15   ; arr, idx, name, size
        DoArr Extend, [r12], r15
        sub rax, [r12]          ; Get the offset
        mov rdx, rax
        fcall FindLazy, r13, r14
        DoArr Extend, [rax+LazyVal_deps], SizeOfDep
        mov [rax+Dep_base], r12
        mov [rax+Dep_off], rdx
        mov [rax+Dep_size], r15
        fnret
