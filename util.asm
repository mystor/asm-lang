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

;;; Call a function
%macro fcall 1
        call %1
%endmacro
%macro fcall 2
        mov rdi, %2
        call %1
%endmacro
%macro fcall 3
        mov rdi, %2
        mov rsi, %3
        call %1
%endmacro
%macro fcall 4
        mov rdi, %2
        mov rsi, %3
        mov rdx, %4
        call %1
%endmacro
%macro fcall 5
        mov rdi, %2
        mov rsi, %3
        mov rdx, %4
        mov rcx, %5
        call %1
%endmacro
%macro fcall 6
        mov rdi, %2
        mov rsi, %3
        mov rdx, %4
        mov rcx, %5
        mov r8, %6
        call %1
%endmacro
%macro fcall 7
        mov rdi, %2
        mov rsi, %3
        mov rdx, %4
        mov rcx, %5
        mov r8, %6
        mov r7, %7
        call %1
%endmacro

;;; Declare a fn
%macro fn 0
        multipush rbp, rbx, r12, r13, r14, r15
        mov rbp, rsp
%endmacro
%macro fn 1
        fn
        mov %1, rdi
%endmacro
%macro fn 2
        fn %1
        mov %2, rsi
%endmacro
%macro fn 3
        fn %1, %2
        mov %3, rdx
%endmacro
%macro fn 4
        fn %1, %2, %3
        mov %4, rcx
%endmacro
%macro fn 5
        fn %1, %2, %3, %4
        mov %5, r8
%endmacro
%macro fn 6
        fn %1, %2, %3, %4, %5
        mov %6, r9
%endmacro

;;; Return from a function
%macro fnret 0
        multipop rbp, rbx, r12, r13, r14, r15
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
            WriteStr STDOUT, %[ENAME]_%[cnt]_NAME, NL
            jmp %%Done
    %$Next:
            %pop
        %endrep
    %%Done:
        fnret
%endmacro
