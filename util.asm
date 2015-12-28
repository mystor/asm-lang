;; -*- nasm -*-

;;; From http://www.tortall.net/projects/yasm/manual/html/nasm-multi-line-macros.html#nasm-macro-rotate
%macro  multipush 1-*
  %rep  %0
        push    %1
  %rotate 1
  %endrep
%endmacro

%macro  multipop 1-*
  %rep %0
  %rotate -1
        pop     %1
  %endrep
%endmacro

;; Only move if the two arguments aren't identical (ignoring case)
%macro mbmov 2
%ifnidni %1, %2
        mov %1, %2
%endif
%endmacro

;; Function Calling Convention used in this program:
;; Registers are used wherever possible.
;; rax - arg 5, return
;; rbx - arg 6
;; rcx - arg 7
;; rdx - arg 8
;; r8  - arg 1
;; r9  - arg 2
;; r10 - arg 3
;; r11 - arg 4
;; r12 - stable local
;; r13 - stable local
;; r14 - stable local
;; r15 - stable local

;;; Call a function
%macro fcall 1
        call %1
%endmacro
%macro fcall 2
        mbmov r8, %2
        call %1
%endmacro
%macro fcall 3
        mbmov r8, %2
        mbmov r9, %3
        call %1
%endmacro
%macro fcall 4
        mbmov r8, %2
        mbmov r9, %3
        mbmov r10, %4
        call %1
%endmacro
%macro fcall 5
        mbmov r8, %2
        mbmov r9, %3
        mbmov r10, %4
        mbmov r11, %5
        call %1
%endmacro

;;; Declare a fn
%macro fn 0
        multipush rbp, r12, r13, r14, r15
        mov rbp, rsp
%endmacro
%macro fn 1
        fn
        mbmov %1, r8
%endmacro
%macro fn 2
        fn %1
        mbmov %2, r9
%endmacro
%macro fn 3
        fn %1, %2
        mbmov %3, r10
%endmacro
%macro fn 4
        fn %1, %2, %3
        mbmov %4, r11
%endmacro

;;; Return from a function
%macro fnret 0
        multipop rbp, r12, r13, r14, r15
        ret
%endmacro
%macro fnret 1
        mov rax, %1
        fnret
%endmacro

;;; Enums
%macro enum 1
        %assign cnt 0
        %xdefine ENAME %1
%endmacro
%macro opt 1
        %xdefine %[ENAME]_%1 cnt
        %defstr %[ENAME]_%[cnt]_NAME %1
        %assign cnt cnt+1
%endmacro
%macro endenum 0
;;; Support for debug printing
Print%[ENAME]:
        fn r12
        %rep cnt
            %push enum_item
            %assign cnt cnt-1
            cmp r12, cnt
            jne %$Next
            WriteLit STDOUT, %[ENAME]_%[cnt]_NAME, NL
            jmp %%Done
    %$Next:
            %pop
        %endrep
    %%Done:
        fnret
%endmacro
