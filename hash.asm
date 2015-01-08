        section .text
;;; A very simple hash function for strings. Should be replaced with a better
;;; hash function at some point, but will work adequately for now.
HashStr:
        fn r12, r13, r14        ; r12 = string, r13 = length, r14 = M
        ;; Accumulate the u32 components
        mov rax, 0
__HashStr_DWORD_Loop:
        cmp r13, 4              ; If we have < 4 chars left, we're done
        jl __HashStr_DWORD_Done

        mov r15, 0              ; Clear r15 (so high bits are 0)
        mov r15d, [r12]         ; Load a DWORD into r15
        add rax, r15            ; add rax to r15

        ;; Increment ptr, and decrement length
        add r12, 4              ; inc str ptr
        sub r13, 4              ; dec length
        jmp __HashStr_DWORD_Loop
__HashStr_DWORD_Done:

__HashStr_BYTE_Loop:
        cmp r13, 1
        jl __HashStr_BYTE_Done

        mov r15, 0              ; Store a 0 into r15 (as mov into r15b doesn't clear high bits)
        mov r15b, [r12]         ; Load a BYTE into r15
        add rax, r15            ; Add it to rax

        ;; Increment ptr, and decrement length
        add r12, 1
        sub r13, 1
        jmp __HashStr_BYTE_Loop
__HashStr_BYTE_Done:
        ;; rax contains the value we are dividing
        div r14
        fnret rdx               ; rdx will contain remainder
