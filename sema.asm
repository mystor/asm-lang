;;; -*- nasm -*-

        section .data
globl_heap ContextHeap
globals: dq 0

globl_heap StructHeap
structs: dq 0

        section .text
TypeckInit:
        fn
        fcall NewArr, ContextHeap, SizeOfKVPair*16
        mov [globals], rax
        fcall NewArr, StructHeap, SizeOfKVPair*16
        mov [structs], rax
        fnret

TypeckItem:
        fn r12                  ; r12 = item
        enumjmp ITEM, r12

.ITEM_FUNC:
        fcall LookupOrInsertByKey, globals, [r12+ItemFunc_name]
        cmp QWORD [rax], 0
        je ._ITEM_FUNC_first
._ITEM_FUNC_redef:
        ;; XXX: Should be able to handle forward definitions
        WriteLit STDOUT, 'Attempt to redefine name '
        fcall WriteStr, [r12+ItemFunc_name]
        WriteLit STDOUT, ' rejected'
        Panic 101, NL
._ITEM_FUNC_first:
        mov [rax], r12
._ITEM_FUNC_typeck:
        ;; Allocate the array pointer on the stack!
        fcall NewArr, ContextHeap, SizeOfKVPair*16
        sub rsp, 8
        mov [rsp], rax
        fnret

.ITEM_STRUCT:

        fnret
.ITEM_INVALID:
        Panic 101, "INVALID ITEM"

TypeckStmt:
        fn r12, r13             ; r12 = stmt, r13 = context
        fnret

TypeckExpr:
        fn r12, r13             ; r12 = expr, r13 = context
        fnret

