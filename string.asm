;;  -*- nasm -*-

        section .text
;;; Get the length of the input string
StrLen:
        fn r12                  ; r12 = string
        mov rax, 0
__StrLen_Loop:
        cmp BYTE [r12], 0
        je __StrLen_Done
        add rax, 1
        add r12, 1
        jmp __StrLen_Loop
__StrLen_Done:
        fnret rax

;;; Compare the two strings
StrCmp:
        fn r12, r13             ; r12 = string 1, r13 = string 2
__StrCmp_Main:
        mov al, [r12]
        mov bl, [r13]
        sub al, bl
        je __StrCmp_Same
__StrCmp_Diff:
        fnret rax
__StrCmp_Same:
        cmp bl, 0              ; End of the string!
        je __StrCmp_Eq
        ;; Loop back around with incremented args
        add r12, 1
        add r13, 1
        jmp __StrCmp_Main
__StrCmp_Eq:
        fnret 0

;;; Find the last instance of a char in the string,
;;; and return a pointer to it
StrRFind:
        fn r12, r13             ; r12 = string, r13 = char
        fcall StrLen, r12
        mov r14, rax
__StrRFind_Loop:
        dec r14
        cmp r14, 0
        je __StrRFind_Absent
        mov al, [r12+r14]
        cmp al, r13b
        je __StrRFind_Found
        jmp __StrRFind_Loop
__StrRFind_Found:
        lea rax, [r12+r14]
        fnret rax
__StrRFind_Absent:
        fnret 0                 ; XXX: Correct behavior?

;;; Hash a string
StrHash:
        fn r12, r14        ; r12 = string, r14 = M
        fcall StrLen, r12
        mov r13, rax

        ;; Accumulate the u32 components
        mov rax, 0
__StrHash_DWORD_Loop:
        cmp r13, 4              ; If we have < 4 chars left, we're done
        jl __StrHash_DWORD_Done

        mov r15, 0              ; Clear r15 (so high bits are 0)
        mov r15d, [r12]         ; Load a DWORD into r15
        add rax, r15            ; add rax to r15

        ;; Increment ptr, and decrement length
        add r12, 4              ; inc str ptr
        sub r13, 4              ; dec length
        jmp __StrHash_DWORD_Loop
__StrHash_DWORD_Done:

__StrHash_BYTE_Loop:
        cmp r13, 1
        jl __StrHash_BYTE_Done

        mov r15, 0              ; Store a 0 into r15 (as mov into r15b doesn't clear high bits)
        mov r15b, [r12]         ; Load a BYTE into r15
        add rax, r15            ; Add it to rax

        ;; Increment ptr, and decrement length
        add r12, 1
        sub r13, 1
        jmp __StrHash_BYTE_Loop
__StrHash_BYTE_Done:
        ;; rax contains the value we are dividing
        mov rdx, 0
        div QWORD r14
        fnret rdx               ; rdx will contain remainder
        fn r12, r13             ; r12 = string, r13 = M
        ;; It's a legal hash function! I swear!
        ;; XXX: Implement
        fnret 0
