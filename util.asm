;;; -*- nasm -*-

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
;; rax - return 1
;; rbx - return 2
;; rcx - stable local
;; rdx - stable local
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
        mov rax, $              ; Addr of start of fn
        multipush r12, r13, r14, r15, rcx, rdx
        push rax                ; Address of start of function
        push rbp
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
        mov rsp, rbp
        pop rbp
        add rsp, 8              ; Pop off the start addr of function
        multipop r12, r13, r14, r15, rcx, rdx
        ret
%endmacro
%macro fnret 1
        mov rax, %1
        fnret
%endmacro

;;; Allocating stack locals
%macro alloca 1
        sub rsp, %1
        mov rax, rsp
%endmacro

;;; Enums
%macro enum 1
        %assign cnt 0
        %xdefine ENAME %1
%endmacro
%macro opt 1
        %xdefine %[ENAME]_%1 cnt
        %define %[ENAME]_%[cnt]_ID %1
        %defstr %[ENAME]_%[cnt]_NAME %1
        %assign cnt cnt+1
%endmacro
%macro endenum 0
        %xdefine %[ENAME]_cnt cnt
;;; Support for debug printing
Write%[ENAME]:
        fn r12
        %rep cnt
            %push enum_item
            %assign cnt cnt-1
            cmp r12, cnt
            jne %$Next
            WriteLit STDOUT, %[ENAME]_%[cnt]_NAME
            jmp %%Done
    %$Next:
            %pop
        %endrep
    %%Done:
        fnret
%endmacro

%macro enumjmp 2
        cmp %2, %1_cnt
        jae .%1_INVALID
        jmp [.%1_tbl+%2*8]
.%1_tbl:
        %assign idx 0
        %rep %1_cnt
        dq .%1_%[%1_%[idx]_ID]
        %assign idx idx+1
        %endrep
%endmacro

;;; Structs
%macro struct 1
        %assign offset 0
        %xdefine SNAME %1
%endmacro
%macro field 1
        ;; Token_type
        ;; Token_data
        ;; e.g. mov rax, [r13+Token_type]

        %xdefine %[SNAME]_%1 offset
        %defstr %[SNAME]$at$%[offset] %1
        %assign offset offset+8
%endmacro
%macro endstruct 0
;;; Get the size of the type!
        %xdefine SizeOf%[SNAME] offset
        %xdefine %[SNAME]$$maxoffset offset
        %xdefine static_[SNAME] times offset db 0
%[SNAME]_copy:
        fn r8, r9
        fcall MemCpy, r8, r9, SizeOf%[SNAME]
        fnret
%endmacro
%macro endstruct 1
        struct_ensureprefix %1
        endstruct
%endmacro
%macro endstruct 2+
        struct_ensureprefix %1
        endstruct %2
%endmacro
%macro struct_ensureprefix 1
        %assign i 0
        %rep %1$$maxoffset/8
          %if %[SNAME]$at$%[i] != %1$at$%[i]
            %error 'Mismatched prefix'
          %endif
          %assign i i+8
        %endrep
%endmacro

;;; For consistency with SizeOf for structs
%define SizeOfReg 8

        section .data
argc: dq 0
argv: dq 0

%macro loadargs 0
        pop rsi
        mov [argc], rsi
        mov [argv], rsp
%endmacro

