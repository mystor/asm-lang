;;; -*- nasm -*-
%macro EmitLit 0
%push emit
[section .rodata]
%xdefine %$__SECT__ __SECT__
        %$data:
%endmacro
%macro EndEmitLit 0
        %$len: equ $ - %$data
        %$__SECT__
        fcall ElfWriteText, %$data, %$len
%pop emit
%endmacro

%macro SwSign 1
%ifidni %1, rax
%error 'Cannot use rax as operand to SwSign'
%endif
        %push switchsign
        mov rax, [%1+Type_variant]
        cmp rax, TYPE_INT
        je %%int
        cmp rax, TYPE_PTR
        je %$unsigned
        jmp %%invalid
%%int:
        mov rax, [%1+TypeInt_signed]
        cmp rax, 0
        jne %$signed
        jmp %$unsigned
%%invalid:
        Panic 'SwSign on non signed type'
%endmacro

%macro SwOpSize 1
%ifidni %1, rax
%error 'Cannot use rax as operand to SwOpSize'
%endif
        %push switchsize
        [section .rodata]
%%jmptbl:
        dq %%int                ; INT
        dq %%invalid            ; STRUCT (XXX: Should this be changed?)
        dq %$qword              ; PTR
        dq %%invalid            ; ARRAY
        dq %%invalid            ; VOID
        dq %%invalid            ; FUNC (XXX: Should this be changed?)
        __SECT__
        mov rax, [%1+Type_variant]
        cmp rax, 6
        jae %%invalid
        jmp [%%jmptbl+rax]
%%int:
        mov rax, [%1+TypeInt_size]
        cmp rax, 1
        je %$byte
        cmp rax, 2
        je %$word
        cmp rax, 4
        je %$dword
        cmp rax, 8
        je %$qword
%%invalid:
        Panic 'Invalid type as argument to SwOpSize'
%endmacro

EmitPushRax:
        fn
        EmitLit
        push rax
        EndEmitLit
        fnret

DupStackTop:
        fn
        EmitLit
        push QWORD [rsp]
        EndEmitLit
        fnret

EnsureLValue:
        fn r12
        cmp QWORD [r12+Value_alloc], ALLOC_LVALUE
        jne .bad
.good:
        fnret [r12+Value_type]
.bad:
        Panic 'Expected lvalue, and got non-lvalue'

ExtractRValue:
        fn r12                  ; value
        mov r13, [r12+Value_type]
        cmp QWORD [r12+Value_alloc], ALLOC_RVALUE
        je .done
        SwOpSize r13
%$byte:
        EmitLit
        mov al, [rax]
        EndEmitLit
        fnret r13
%$word:
        EmitLit
        mov ax, [rax]
        EndEmitLit
        fnret r13
%$dword:
        EmitLit
        mov eax, [rax]
        EndEmitLit
        fnret r13
%$qword:
        EmitLit
        mov rax, [rax]
        EndEmitLit
        fnret r13
%pop switchsize
.done:
        fnret r13

;; Takes in types, and returns a type
GetCommonType:
        fn r12, r13             ; r12 = type, r13 = type
        cmp QWORD [r12+Type_variant], TYPE_INT
        jne .notint
        cmp QWORD [r13+Type_variant], TYPE_INT
        jne .notint
        mov rax, [r12+TypeInt_size]
        mov rbx, [r13+TypeInt_size]
        cmp rax, rbx
        je .samesize
        ja .r12
        jmp .r13
.samesize:
        cmp QWORD [r12+TypeInt_signed], 0
        je .r12
        jmp .r13
.r13:
        fnret r13
.r12:
        fnret r12
.notint:
        Panic 'Not implemented for non-int types'

;;; r12 on stack, r13 in rax
;;; Cast r13 to r12, and emit an assignment
EmitAssign:
        fn r12, r13             ; r12 = lhs, r13 = rhs
        fcall EnsureLValue, r12
        mov r14, rax
        fcall EmitCast, r13, r14 ; Cast the value to the type of lhs!
        SwOpSize r14
%$byte:
        EmitLit
        pop rbx
        mov [rbx], al
        mov rax, rbx
        EndEmitLit
        fnret r12
%$word:
        EmitLit
        pop rbx
        mov [rbx], ax
        mov rax, rbx
        EndEmitLit
        fnret r12
%$dword:
        EmitLit
        pop rbx
        mov [rbx], eax
        mov rax, rbx
        EndEmitLit
        fnret r12
%$qword:
        EmitLit
        pop rbx
        mov [rbx], rax
        mov rax, rbx
        EndEmitLit
        fnret r12
%pop switchsize

%macro EmitXXXAssign 1
Emit%1Assign:
        fn r12, r13             ; r12 = lhs, r13 = rhs
        fcall DupStackTop
        fcall Emit%1, r12, r13
        fcall EmitAssign, r12, rax
        fnret rax
%endmacro

        EmitXXXAssign Add
        EmitXXXAssign Sub
        EmitXXXAssign Mul
        EmitXXXAssign Div
        EmitXXXAssign Mod
        EmitXXXAssign Shl
        EmitXXXAssign Shr
        EmitXXXAssign BAnd
        EmitXXXAssign BXor
        EmitXXXAssign BOr

        section .rodata
_ArithBinop_START:
        mov rcx, rax
        pop rax
.len: equ $ - _ArithBinop_START
        section .text

;;; lhs in rax, rhs in rbx
;;; Types have been cast to common type
;;; Switches on the operation size
;;; Puts the type of the operands in r14
%macro ArithBinopSetup 0
        fn r12, r13             ; r12 = lhs, r13 = rhs
        fcall GetCommonType, [r12+Value_type], [r13+Value_type]
        mov r14, rax            ; r14 is type
        fcall EmitCast, r13, r14
        fcall ElfWriteText, _ArithBinop_START, _ArithBinop_START.len
        fcall EmitCast, r12, r14
%endmacro

%macro StandardBinop 2
        ArithBinopSetup
%ifnidni %1, %2                 ; If %1 and %2 are same, don't check sign
        SwSign r14
%$unsigned:
%endif                          ; nidni %1, %2
        SwOpSize r14
%$byte:
        EmitLit
        %1 al, cl
        EndEmitLit
        jmp %%exit
%$word:
        EmitLit
        %1 ax, cx
        EndEmitLit
        jmp %%exit
%$dword:
        EmitLit
        %1 eax, ecx
        EndEmitLit
        jmp %%exit
%$qword:
        EmitLit
        %1 rax, rcx
        EndEmitLit
        jmp %%exit
%pop switchsize
%ifnidni %1, %2                 ; If %1 and %2 are same, don't check sign
%$signed:
        SwOpSize r14
%$byte:
        EmitLit
        %2 al, cl
        EndEmitLit
        jmp %%exit
%$word:
        EmitLit
        %2 ax, cx
        EndEmitLit
        jmp %%exit
%$dword:
        EmitLit
        %2 eax, ecx
        EndEmitLit
        jmp %%exit
%$qword:
        EmitLit
        %2 rax, rcx
        EndEmitLit
        jmp %%exit
%pop switchsize
%pop switchsign
%endif                          ; nidni %1, %2
%%exit:
        fcall WrapTypeRValue, r14
%endmacro

EmitBXor:
        StandardBinop xor, xor
        fnret rax
EmitBOr:
        StandardBinop or, or
        fnret rax
EmitBAnd:
        StandardBinop and, and
        fnret rax
EmitAdd:
        StandardBinop add, add
        fnret rax
EmitSub:
        StandardBinop sub, sub
        fnret rax

EmitShl:
        ArithBinopSetup
        SwSign r14
%$unsigned:
        EmitLit
        shl rax, cl
        EndEmitLit
        fnret r14
%$signed:
        EmitLit
        sal rax, cl
        EndEmitLit
        fnret r14
%pop switchsign

EmitShr:
        ArithBinopSetup
        SwSign r14
%$unsigned:
        EmitLit
        shr rax, cl
        EndEmitLit
        fnret r14
%$signed:
        EmitLit
        sar rax, cl
        EndEmitLit
        fnret r14
%pop switchsign

EmitMul:
        ArithBinopSetup
        fcall WrapTypeRValue, r14
        mov r15, rax
        SwSign r14
%$unsigned:
        SwOpSize r14
%$byte:
        EmitLit
        mul cl
        EndEmitLit
        fnret r15
%$word:
        EmitLit
        mul cx
        EndEmitLit
        fnret r15
%$dword:
        EmitLit
        mul ecx
        EndEmitLit
        fnret r15
%$qword:
        EmitLit
        mul rcx
        EndEmitLit
        fnret r15
%pop switchsize
%$signed:
        SwOpSize r14
%$byte:
        EmitLit
        imul cl
        EndEmitLit
        fnret r15
%$word:
        EmitLit
        imul cx
        EndEmitLit
        fnret r15
%$dword:
        EmitLit
        imul ecx
        EndEmitLit
        fnret r15
%$qword:
        EmitLit
        imul rcx
        EndEmitLit
        fnret r15
%pop switchsize
%pop switchsign

EmitDiv:
        ArithBinopSetup
        fcall WrapTypeRValue, r14
        mov r15, rax
        SwSign r14
%$unsigned:
        SwOpSize r14
%$byte:
        EmitLit
        and ax, 0xff            ; Clear upper bits of word
        div cl
        EndEmitLit
        fnret r15
%$word:
        EmitLit
        xor rdx, rdx            ; Clear edx register
        div cx
        EndEmitLit
        fnret r15
%$dword:
        EmitLit
        xor rdx, rdx            ; Clear edx register
        div ecx
        EndEmitLit
        fnret r15
%$qword:
        EmitLit
        xor rdx, rdx            ; Clear rdx register
        div rcx
        EndEmitLit
        fnret r15
%pop switchsize
%$signed:
        SwOpSize r14
%$byte:
        EmitLit
        cbw                     ; Sign extend into ax
        idiv cl
        EndEmitLit
        fnret r15
%$word:
        EmitLit
        cwd                     ; Sign extend into dx:ax
        idiv cx
        EndEmitLit
        fnret r15
%$dword:
        EmitLit
        cdq                     ; Sign extend into edx:eax
        idiv ecx
        EndEmitLit
        fnret r15
%$qword:
        EmitLit
        cqo                     ; Sign extend into rdx:rax
        idiv rcx
        EndEmitLit
        fnret r15
%pop switchsize
%pop switchsign

EmitMod:
        ArithBinopSetup
        fcall WrapTypeRValue, r14
        mov r15, rax
        SwSign r14
%$unsigned:
        SwOpSize r14
%$byte:
        EmitLit
        and ax, 0xff            ; Clear upper bits of word
        div cl
        mov al, ah
        EndEmitLit
        fnret r15
%$word:
        EmitLit
        xor rdx, rdx            ; Clear edx register
        div cx
        mov ax, dx
        EndEmitLit
        fnret r15
%$dword:
        EmitLit
        xor rdx, rdx            ; Clear edx register
        div ecx
        mov eax, edx
        EndEmitLit
        fnret r15
%$qword:
        EmitLit
        xor rdx, rdx            ; Clear rdx register
        div rcx
        mov rax, rdx
        EndEmitLit
        fnret r15
%pop switchsize
%$signed:
        SwOpSize r14
%$byte:
        EmitLit
        cbw                     ; Sign extend into ax
        idiv cl
        mov al, ah
        EndEmitLit
        fnret r15
%$word:
        EmitLit
        cwd                     ; Sign extend into dx:ax
        idiv cx
        mov ax, dx
        EndEmitLit
        fnret r15
%$dword:
        EmitLit
        cdq                     ; Sign extend into edx:eax
        idiv ecx
        mov eax, edx
        EndEmitLit
        fnret r15
%$qword:
        EmitLit
        cqo                     ; Sign extend into rdx:rax
        idiv rcx
        mov rax, rdx
        EndEmitLit
        fnret r15
%pop switchsize
%pop switchsign

%macro StandardCompare 2
        StandardBinop cmp, cmp
%ifnidn %1, %2
        SwSign r14
%$unsigned:
%endif                          ; nidn %1, %2
        EmitLit
        %1 short %%yes1
        mov eax, 0
        jmp short %%done1
%%yes1:
        mov eax, 1
%%done1:
        EndEmitLit
        jmp %%done
%ifnidn %1, %2
%$signed:
        EmitLit
        %2 short %%yes2
        mov eax, 0
        jmp short %%done2
%%yes2:
        mov eax, 1
%%done2:
        EndEmitLit
        jmp %%done
%pop switchsign
%endif                          ; nidn %1, %2
%%done:
        fnret I32_value
%endmacro

EmitEq:
        StandardCompare je, je
EmitNotEq:
        StandardCompare jne, jne
EmitLessThan:
        StandardCompare jb, jl
EmitGreaterThan:
        StandardCompare ja, jg
EmitLessThanEq:
        StandardCompare jbe, jle
EmitGreaterThanEq:
        StandardCompare jae, jge

EmitDeref:
        fn r12                  ; r12 = operand
        fcall ExtractRValue, r12
        cmp QWORD [rax+Type_variant], TYPE_PTR
        jne .invalid
        mov rax, [rax+TypePtr_target]
        fcall WrapTypeLValue, rax
        fnret rax
.invalid:
        Panic 'Cannot dereference non pointer type'

EmitAddrof:
        fn r12                  ; r12 = operand
        cmp QWORD [r12+Value_alloc], ALLOC_LVALUE
        jne .invalid
        fcall Alloc, Heap, SIZE_TypePtr
        mov QWORD [rax+TypePtr_variant], TYPE_PTR
        mov rbx, [r12+Value_type]
        mov [rax+TypePtr_target], rbx
        fcall WrapTypeRValue, rax
        fnret rax
.invalid:
        Panic 'Cannot take address of non lvalue'

EmitNegate:
        fn r12
        fcall ExtractRValue, r12
        mov rcx, rax
        fcall WrapTypeRValue, rax
        mov r13, rax
        SwOpSize rcx
%$byte:
        EmitLit
        neg al
        EndEmitLit
        fnret r13
%$word:
        EmitLit
        neg ax
        EndEmitLit
        fnret r13
%$dword:
        EmitLit
        neg eax
        EndEmitLit
        fnret r13
%$qword:
        EmitLit
        neg rax
        EndEmitLit
        fnret r13
%pop switchsize

EmitBNot:
        fn r12
        fcall ExtractRValue, r12
        mov rcx, rax
        fcall WrapTypeRValue, rax
        mov r13, rax
        SwOpSize rcx
%$byte:
        EmitLit
        not al
        EndEmitLit
        fnret r13
%$word:
        EmitLit
        not ax
        EndEmitLit
        fnret r13
%$dword:
        EmitLit
        not eax
        EndEmitLit
        fnret r13
%$qword:
        EmitLit
        not rax
        EndEmitLit
        fnret r13
%pop switchsize

EmitNot:
        fn r12
        fcall ExtractRValue, r12
        mov r13, rax
        SwOpSize r13
%$byte:
        EmitLit
        cmp al, 0
        EndEmitLit
        jmp %$done
%$word:
        EmitLit
        cmp ax, 0
        EndEmitLit
        jmp %$done
%$dword:
        EmitLit
        cmp eax, 0
        EndEmitLit
        jmp %$done
%$qword:
        EmitLit
        cmp rax, 0
        EndEmitLit
        jmp %$done
%$done:
        EmitLit
        jne short %$yes
    %$no:
        mov eax, 0
        jmp short %$done
    %$yes:
        mov eax, 1
    %$done:
        EndEmitLit
        fnret I32_value
%pop switchsize

        section .data
C_EmitInt:
        db REX_BASE | REX_W
        db 0xb8 + REG_RAX
;.value: times 8 db 0
.len: equ $ - C_EmitInt

        section .text
;;; XXX: Always emits 64-bit integer - consider 32/16-bit?
EmitInt:
        fn r12                  ; r12 = value
        ;push r12
        ;fcall MemCpy, rsp, _EmitInt_Data.value, 8
        ;pop r12
        DoArr Write, [ElfText], C_EmitInt, C_EmitInt.len
        push r12
        DoArr Write, [ElfText], rsp, 8
        pop r12
        ;fcall ElfWriteText, _EmitInt_Data, _EmitInt_Data.len
        fnret I64_value

EmitLazyInt:
        fn r12, r13
        DoArr Write, [ElfText], C_EmitInt, C_EmitInt.len
        fcall WriteLazy, ElfText, r12, r13, 8
        fnret I64_value

        section .data
_EmitJnz_Data:
.len: equ $ - _EmitJnz_Data

        section .text
EmitJnz:
        fn r12, r13             ; r12 = condition, r13 = label
        Panic 'Crap'

        section .data
_EmitJz_Data:
.len: equ $ - _EmitJz_Data

        section .text
EmitJz:
        fn r12, r13             ; r12 = condition, r13 = label
        Panic 'Crap'

_EmitJmp_Data:
.len: equ $ - _EmitJmp_Data

        section .text
EmitJmp:
        fn r12                  ; r12 = label
        Panic 'Crap'

EmitCast:
        fn r12, r13             ; r12 = from value, r13 = to type
        fcall ExtractRValue, r12
        mov r14, rax
        SwOpSize r14
%$byte:
        SwOpSize r13
  %$byte:
        fnret
  %$word:
  %$dword:
  %$qword:
        SwSign r13
    %$unsigned:
        EmitLit
        and rax, 0xff
        EndEmitLit
        fnret
    %$signed:
        EmitLit
        cbw
        cwde
        cdqe
        EndEmitLit
        fnret
    %pop switchsign
  %pop switchsize
%$word:
        SwOpSize r13
  %$byte:
  %$word:
        fnret
  %$dword:
  %$qword:
        SwSign r13
    %$unsigned:
        EmitLit
        and rax, 0xffff
        EndEmitLit
        fnret
    %$signed:
        EmitLit
        cwde
        cdqe
        EndEmitLit
        fnret
    %pop switchsign
  %pop switchsize
%$dword:
        SwOpSize r13
  %$byte:
  %$word:
  %$dword:
        fnret
  %$qword:
        SwSign r13
    %$unsigned:
        ;EmitLit
        ; XXX: 
        ;and rax, 0xffffffff
        ;EndEmitLit
        fnret
    %$signed:
        EmitLit
        cdqe
        EndEmitLit
        fnret
    %pop switchsign
  %pop switchsize
%$qword:
        fnret                   ; Shrinking is always OK
%pop switchsize

        section .data
C_LocalLea:
        db REX_BASE | REX_W
        db 0x8d                 ; lea
        db 0x85                 ; rax, [rbp+...]
.offset: times 4 db 0           ; offset
.len: equ $ - C_LocalLea

        section .text
EmitLaddr:
        fn r12                  ; r12 = address
        cmp QWORD [r12+VarDef_alloc], DALLOC_LOCAL
        je .local
        cmp QWORD [r12+VarDef_alloc], DALLOC_GLOBAL
        je .global
        cmp QWORD [r12+VarDef_alloc], DALLOC_CONST
        je .const
        fcall WriteDec, [r12+VarDef_alloc]
        Panic 'Unexpected alloc type'
.local:
        mov rax, [r12+VarDef_data]
        neg rax
        push rax
        fcall MemCpy, rsp, C_LocalLea.offset, 4
        pop rax
        fcall ElfWriteText, C_LocalLea, C_LocalLea.len
        fcall WrapTypeLValue, [r12+VarDef_type]
        fnret rax
.global:
        fcall EmitLazyInt, 0, [r12+VarDef_data]
        fcall WrapTypeLValue, [r12+VarDef_type]
        fnret rax
.const:
        fcall EmitLazyInt, 0, [r12+VarDef_data]
        fcall WrapTypeRValue, [r12+VarDef_type]
        fnret rax

EmitNops:
        fn
        EmitLit
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        EndEmitLit
        fnret
