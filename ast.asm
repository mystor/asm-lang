;;; -*- nasm -*-

;;; Value
struct Value
        field alloc
        field type
endstruct

enum ALLOC
        opt garbage1
        opt garbage2
        opt garbage3
        opt garbage4
        opt garbage5
        opt garbage6
        opt garbage7
        opt garbage8
        opt RVALUE
        opt LVALUE
endenum

;;; Type
struct Type
        field variant
endstruct
%undef SIZE_Type

enum TYPE
        opt INT
        opt STRUCT
        opt PTR
        opt ARRAY
        opt VOID
        opt FUNC
endenum

struct TypeInt
        field variant
        field signed
        field size
endstruct Type

struct TypeStruct
        field variant
        field name
endstruct Type

struct TypePtr
        field variant
        field target
endstruct Type

struct TypeArray
        field variant           ; Must share prefix with TypePtr
        field target
        field length
endstruct Type

struct TypeVoid
        field variant
endstruct Type

struct TypeFunc                 ; XXX: Actually implement function ptrs
        field variant
        field returns
        field params
endstruct Type

        section .rodata
I64_type:
        dq TYPE_INT
        dq 1
        dq 8
I32_type:
        dq TYPE_INT
        dq 1
        dq 4
I32_value:
        dq ALLOC_RVALUE
        dq I32_type
I64_value:
        dq ALLOC_RVALUE
        dq I64_type

        section .text
SizeOfType:
        fn r12                  ; r12 = type
        mov rax, [r12+Type_variant]
        enumjmp TYPE, rax
.TYPE_INT:
        fnret [r12+TypeInt_size]
.TYPE_STRUCT:
        Panic 'unsupported'
.TYPE_PTR:
        fnret 8
.TYPE_ARRAY:
        fcall SizeOfType, [r12+TypeArray_target]
        mov rbx, [r12+TypeArray_length]
        xor rdx, rdx
        imul rbx
        fnret rax
.TYPE_VOID:
.TYPE_FUNC:
        Panic 'Size of unsized type'
.TYPE_INVALID:
        Panic 'Unknown type'


WrapTypeRValue:
        fn r12                  ; r12 = type
        fcall Alloc, Heap, SIZE_Value
        mov [rax+Value_type], r12
        mov QWORD [rax+Value_alloc], ALLOC_RVALUE
        fnret rax

WrapTypeLValue:
        fn r12                  ; r12 = type
        fcall WrapTypeRValue, r12
        mov QWORD [rax+Value_alloc], ALLOC_LVALUE
        fnret rax

WriteType:
        fn r12
        cmp r12, 0
        je .NOTYPE
        mov rax, [r12+Type_variant]
        enumjmp TYPE, rax

.TYPE_INT:
        cmp QWORD [r12+TypeInt_signed], 0
        je ._TYPE_INT_UNSIGNED
._TYPE_INT_SIGNED:
        WriteLit STDOUT, 'i'
        jmp ._TYPE_INT_AFTERSIGN
._TYPE_INT_UNSIGNED:
        WriteLit STDOUT, 'u'
        jmp ._TYPE_INT_AFTERSIGN
._TYPE_INT_AFTERSIGN:
        mov rax, [r12+TypeInt_size]
        shl rax, 3              ; * 8
        fcall WriteDec, rax
        fnret

.TYPE_STRUCT:
        WriteLit STDOUT, 'struct '
        fcall WriteStr, [r12+TypeStruct_name]
        fnret

.TYPE_PTR:
        fcall WriteType, [r12+TypePtr_target]
        WriteLit STDOUT, '*'
        fnret

.TYPE_ARRAY:
        fcall WriteType, [r12+TypeArray_target]
        WriteLit STDOUT, '['
        fcall WriteDec, [r12+TypeArray_length]
        WriteLit STDOUT, ']'
        fnret

.TYPE_VOID:
        WriteLit STDOUT, 'void'
        fnret

.TYPE_FUNC:
        WriteLit STDOUT, 'func'
        fnret

.TYPE_INVALID:
        Panic 'Invalid Type Type?'

.NOTYPE:
        WriteLit STDOUT, 'NIL'
        fnret
