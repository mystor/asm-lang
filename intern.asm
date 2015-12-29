;;; -*- nasm -*-

;;; XXX: We aren't using the intern table right now, because it's inconvenient compared
;;; to just strcmp-ing every time we want to perform a comparison.
        section .data
%define INTERN_HT_SIZE  (1024*1024/8)   ;1 mb
__Intern_HashTable:     times   INTERN_HT_SIZE  dq      0

        section .text
Intern:
        fn r12, r13             ; r12=string, r13=length
        ;; Hash the string
        fcall StrHash, r12, r13, INTERN_HT_SIZE
        mov r14, rax

__Intern_CheckSlot:
        mov r15, [__Intern_HashTable+r14*8]
        cmp r15, 0
        je __Intern_FillSlot

__Intern_CompStr:
        ;; Compare if the lengths are the same
        cmp [r15-8], r13
        jne __Intern_NextSlot
        mov r10, r15
        mov r11, r12
        mov rax, r13

__Intern_CompStr_Loop:
        cmp rax, 0
        jle __Intern_FoundMatch
        sub rax, 1
        mov cl, [r11]
        cmp [r10], cl
        je __Intern_CompStr_Loop
        jmp __Intern_NextSlot

__Intern_FoundMatch:
        ;; The value we found matches the value we were passed
        ;; We can return the existing address!
        fnret r15

__Intern_NextSlot:
        ;; Increment r14 to the next valid slot
        add r14, 1
        ;; TODO(michael): This should probably be done with div
        cmp r14, INTERN_HT_SIZE
        jl __Intern_CheckSlot
        mov r14, 0
        jmp __Intern_CheckSlot

__Intern_FillSlot:
        mov rax, r13
        add rax, 8              ; Add enough space for length header
        fcall Malloc, rax

        mov [rax], r13          ; Store the string's length
        add rax, 8              ; Move the ptr past the string's length
        mov [__Intern_HashTable+r14*8], rax ; Save the pointer in the HashTable

        mov r15, rax            ; Save the pointer in r15 for returning

__Intern_CopyChr_Loop:
        cmp r13, 0              ; Check if we have 0 chars left
        jle __Intern_CopyChr_Done

        mov cl, [r12]
        mov BYTE [rax], cl
        add rax, 1
        add r12, 1
        sub r13, 1
        jmp __Intern_CopyChr_Loop

__Intern_CopyChr_Done:
        fnret r15               ; Return that pointer
