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
        mov r8, 0xffdead
        mov r9, 0xffdead
        mov r10, 0xffdead
        mov r11, 0xffdead
%endmacro
%macro fcall 2
        mbmov r8, %2
        mov r9, 0xffdead
        mov r10, 0xffdead
        mov r11, 0xffdead
        call %1
%endmacro
%macro fcall 3
        mbmov r8, %2
        mbmov r9, %3
        mov r10, 0xffdead
        mov r11, 0xffdead
        call %1
%endmacro
%macro fcall 4
        mbmov r8, %2
        mbmov r9, %3
        mbmov r10, %4
        mov r11, 0xffdead
        call %1
%endmacro
%macro fcall 5
        mbmov r8, %2
        mbmov r9, %3
        mbmov r10, %4
        mbmov r11, %5
        call %1
%endmacro

%macro pushgarb 1
        push %1
        mov %1, 0xaadead
%endmacro

%define BPrax 112
%define BPrbx 104
%define BPrcx 96
%define BPrdx 88
%define BPrsi 80
%define BPrdi 72
%define BPr8 64
%define BPr9 56
%define BPr10 48
%define BPr11 40
%define BPr12 32
%define BPr13 24
%define BPr14 16
%define BPr15 8
%define BPrbp 0

%define BPframesize 120

PushRegs:
        sub rsp, BPframesize-8
        mov [rsp+BPrbp], rbp
        mov [rsp+BPr15], r15
        mov [rsp+BPr14], r14
        mov [rsp+BPr13], r13
        mov [rsp+BPr12], r12
        mov [rsp+BPr11], r11
        mov [rsp+BPr10], r10
        mov [rsp+BPr9], r9
        mov [rsp+BPr8], r8
        mov [rsp+BPrdi], rdi
        mov [rsp+BPrsi], rsi
        mov [rsp+BPrdx], rdx
        mov [rsp+BPrcx], rcx
        mov [rsp+BPrbx], rbx
        mov rcx, [rsp+BPrax]    ; load return address
        mov [rsp+BPrax], rax
        mov rbp, rsp
        push rcx
        ret

PopRegs:
        pop rcx
        mov [rsp+BPrax], rcx
        mov rbp, [rsp+BPrbp]
        mov r15, [rsp+BPr15]
        mov r14, [rsp+BPr14]
        mov r13, [rsp+BPr13]
        mov r12, [rsp+BPr12]
        mov r11, [rsp+BPr11]
        mov r10, [rsp+BPr10]
        mov r9, [rsp+BPr9]
        mov r8, [rsp+BPr8]
        mov rdi, [rsp+BPrdi]
        mov rsi, [rsp+BPrsi]
        mov rdx, [rsp+BPrdx]
        mov rcx, [rsp+BPrcx]
        add rsp, BPframesize-8
        ret

;;; Declare a fn
%macro fn 0
        call PushRegs
        xor r8, r8
        xor r9, r9
        xor r10, r10
        xor r11, r11
._fn_body:
%endmacro
%macro fn 1
        call PushRegs
        mbmov %1, r8
        xor r9, r9
        xor r10, r10
        xor r11, r11
._fn_body:
%endmacro
%macro fn 2
        call PushRegs
        mbmov %1, r8
        mbmov %2, r9
        xor r10, r10
        xor r11, r11
._fn_body:
%endmacro
%macro fn 3
        call PushRegs
        mbmov %1, r8
        mbmov %2, r9
        mbmov %3, r10
        xor r11, r11
._fn_body:
%endmacro
%macro fn 4
        call PushRegs
        mbmov %1, r8
        mbmov %2, r9
        mbmov %3, r10
        mbmov %4, r11
._fn_body:
%endmacro

;;; Return from a function
%macro fnret 0
        mov rax, 0xdddead
        mov rbx, 0xdddead
        mov rsp, rbp
        call PopRegs
        ret
%endmacro
%macro fnret 1
        mov rax, %1
        mov rbx, 0xdddead
        mov rsp, rbp
        call PopRegs
        ret
%endmacro
%macro fnret 2
        mov rax, %1
        mov rbx, %2
        mov rsp, rbp
        call PopRegs
        ret
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

        section .bss
argc: resq 1
argv: resq 1

%macro loadargs 0
        pop rsi
        mov [argc], rsi
        mov [argv], rsp
%endmacro

