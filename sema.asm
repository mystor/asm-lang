;;; -*- nasm -*-

        section .data
globl_heap ContextHeap
globals: dq 0
locals: dq 0
return_type: dq 0

globl_heap StructHeap
structs: dq 0

        section .text
IsValidCast:
        fn r12, r13             ; r12 = from, r13 = to
        mov rax, [r12+Type_variant]
        enumjmp TYPE, rax
.TYPE_INT:
.TYPE_PTR:
        cmp QWORD [r13+Type_variant], TYPE_INT
        je .yes
        cmp QWORD [r13+Type_variant], TYPE_PTR
        je .yes
        jmp .no
.TYPE_STRUCT:
        fcall TypeEq, r12, r13
        cmp rax, 0
        jne .yes
        jmp .no
.TYPE_ARRAY:
        cmp QWORD [r13+Type_variant], TYPE_INT
        je .yes
        cmp QWORD [r13+Type_variant], TYPE_PTR
        je .yes
        cmp QWORD [r13+Type_variant], TYPE_ARRAY
        jne .no
        fcall TypeEq, r12, r13
        cmp rax, 0
        jne .yes
        jmp .no
.TYPE_VOID:
        jmp .no
.TYPE_FUNC:
        jmp .no
.TYPE_INVALID:
        Panic 101, 'INVALID', NL
.yes:
        fnret 1
.no:
        fnret 0

;;; Generate an implicit type coersion, may avoid generating
;;; if the coersion is unnecessary. The expression must have
;;; already been type checked. Only implicit coersions are
;;; allowed (LOL all coersions are implicit)
;;; XXX: Warn on dumb implicit casts which shouldn't be allowed
;;; because C is a dumb language and just allows them
;;; Apparently C doesn't actually have types >.>
TyckMkCoerce:
        fn r12, r13             ; r12 = expr, r13 = type
        ; XXX: Integers totally can just cast to pointers
        ; It's cool man
        ; XXX: Nevermind, everything can be implicitly cast
        ; C is a terrible language
        fcall TyckMkCast, r12, r13
        fnret rax

TyckMkCast:
        fn r12, r13             ; r12 = expr, r13 = type
        fcall IsValidCast, [r12+Expr_typeof], r13
        cmp rax, 0
        je .invalid
        fcall Alloc, Heap, SizeOfExprCast
        mov QWORD [rax+ExprCast_variant], EXPR_CAST
        mov [rax+ExprCast_typeof], r13
        mov [rax+ExprCast_typetarget], r13
        mov [rax+ExprCast_target], r12
        fnret rax
.invalid:
        Panic 101, 'Invalid type cast', NL

;;; Check if two types are equal
TypeEq:
        fn r12, r13
        mov rax, [r12+Type_variant]
        cmp rax, [r13+Type_variant]
        jne .diffvariant
        enumjmp TYPE, rax
.TYPE_INT:
        mov rax, SizeOfTypeInt
        jmp .mcmp
.TYPE_STRUCT:
        mov rax, SizeOfTypeStruct
        jmp .mcmp
.TYPE_PTR:
        mov rax, SizeOfTypePtr
        jmp .mcmp
.TYPE_ARRAY:
        mov rax, SizeOfTypeArray
        jmp .mcmp
.TYPE_VOID:
        mov rax, SizeOfTypeVoid
        jmp .mcmp
.TYPE_FUNC:
        mov rax, SizeOfTypeFunc
        jmp .mcmp
.TYPE_INVALID:
        Panic 101, 'Invalid type!', NL
.diffvariant:
        fnret 0
.mcmp:
        fcall MemEq, r12, r13, rax
        fnret rax

TypeckInit:
        fn
        fcall NewArr, ContextHeap, SizeOfKVPair*16
        mov [globals], rax
        fcall NewArr, StructHeap, SizeOfKVPair*16
        mov [structs], rax
        fnret

TypeckAddVar:
        fn r12, r13             ; r12 = var, r13 = context
        fcall LookupOrInsertByKey, r13, [r12+Decl_name]
        cmp QWORD [rax], 0
        je .first
.redef:
        Panic 101, 'Redefinitions prohibited', NL
.first:
        mov [rax], r12
        fnret

TypeckItem:
        fn r12                  ; r12 = item
        mov rax, [r12+Item_variant]
        enumjmp ITEM, rax

.ITEM_FUNC:
        fcall TypeckAddVar, globals, r12
        ;; Allocate the new context pointer on the stack!
        fcall NewArr, ContextHeap, SizeOfKVPair*16
        mov [locals], rax

        mov rax, [r12+ItemFunc_returns]
        mov [return_type], rax

        ;; Put the parameters into the context!?!?!
        mov r13, [r12+ItemFunc_params]
        mov r14, 0
._ITEM_FUNC_paramsloop:
        cmp r14, [r13+Array_len]
        je ._ITEM_FUNC_paramsloopdone
        mov r15, [r13+r14]
        fcall TypeckAddVar, locals, r15
        add r14, 8
        jmp ._ITEM_FUNC_paramsloop
._ITEM_FUNC_paramsloopdone:
        fcall TypeckStmt, [r12+ItemFunc_body], locals
        fnret

.ITEM_STRUCT:
        Panic 101, 'Unimplemented', NL
        fnret
.ITEM_INVALID:
        Panic 101, "INVALID ITEM", NL

TypeckStmt:
        fn r12                  ; r12 = stmt
        mov rax, [r12+Stmt_variant]
        enumjmp STMT, rax

.STMT_VAR:
        mov rax, [r12+StmtVar_typeof]
        cmp QWORD [rax+Type_variant], TYPE_VOID
        je ._STMT_VAR_void
        fcall TypeckAddVar, locals, r12
        cmp QWORD [r12+StmtVar_init], 0
        je ._STMT_VAR_noinit
._STMT_VAR_hasinit:
        fcall TypeckExpr, [r12+StmtVar_init]
        fcall TyckMkCoerce, [r12+StmtVar_init], [r12+StmtVar_typeof]
        mov [r12+StmtVar_init], rax
._STMT_VAR_noinit:
        fnret
._STMT_VAR_void:
        Panic 101, 'Void is not a valid type for a variable', NL

.STMT_EXPR:
        fcall TypeckExpr, [r12+StmtExpr_expr]
        fnret

.STMT_IF:
        fcall TypeckExpr, [r12+StmtIf_cond]
        fcall TyckMkCast, [r12+StmtIf_cond], I64_type
        mov [r12+StmtIf_cond], rax
        fcall TypeckStmt, [r12+StmtIf_cons]
        cmp QWORD [r12+StmtIf_alt], 0
        je ._STMT_IF_noalt
._STMT_IF_alt:
        fcall TypeckStmt, [r12+StmtIf_alt]
._STMT_IF_noalt:
        fnret

.STMT_WHILE:
        fcall TypeckExpr, [r12+StmtWhile_cond]
        fcall TyckMkCast, [r12+StmtWhile_cond], I64_type
        mov [r12+StmtWhile_cond], rax
        fcall TypeckStmt, [r12+StmtWhile_body]
        fnret

.STMT_COMPOUND:
        mov r13, [r12+StmtCompound_stmts]
        mov r14, 0
._STMT_COMPOUND_stmtloop:
        cmp r14, [r13+Array_len]
        je ._STMT_COMPOUND_stmtloopdone
        fcall TypeckStmt, [r13+r14]
        add r14, 8
        jmp ._STMT_COMPOUND_stmtloop
._STMT_COMPOUND_stmtloopdone:
        fnret

.STMT_RETURN:
        fcall TypeckExpr, [r12+StmtReturn_value]
        fcall TyckMkCoerce, [r12+StmtReturn_value], [return_type]
        mov [r12+StmtReturn_value], rax
        fnret

.STMT_INVALID:
        Panic 101, 'Invalid Statement Type?', NL

TypeckExpr:
        fn r12                  ; r12 = expr
        mov rax, [r12+Expr_variant]
        enumjmp EXPR, rax

.EXPR_INTEGER:
        mov QWORD [r12+ExprInt_typeof], I64_type
        fnret I64_type

.EXPR_REF:
        cmp QWORD [locals], 0
        je ._EXPR_REF_global
        fcall LookupByKey, locals, [r12+ExprRef_name]
        cmp rax, 0
        jne ._EXPR_REF_found
._EXPR_REF_global:
        fcall LookupByKey, globals, [r12+ExprRef_name]
        cmp rax, 0
        jne ._EXPR_REF_found
        Panic 101, 'Unable to find name!?!?!', NL
._EXPR_REF_found:
        mov [r12+ExprRef_decl], rax
        mov rax, [rax+Decl_typeof]
        mov [r12+ExprRef_typeof], rax
        mov QWORD [r12+ExprRef_lvalue], 1
        fnret rax

.EXPR_BINARY:
        ;; Typecheck the two branches
        fcall TypeckExpr, [r12+ExprBinOp_left]
        fcall TypeckExpr, [r12+ExprBinOp_right]
        ;; Branch for operation-specific checks
        mov rax, [r12+ExprBinOp_op]
        enumjmp OP, rax

.OP_PLUS:
.OP_MINUS:
        mov rax, [r12+ExprBinOp_left]
        mov rax, [rax+Expr_typeof]
        cmp QWORD [rax+Type_variant], TYPE_PTR
        ;je ._OP_ADDSUB_pointer

        ; It's not pointer/integer, so off
        ; XXX: Pointer / integer
.OP_MUL:
.OP_DIV:
.OP_MOD:
.OP_BSL:
.OP_BSR:
.OP_BOR:
.OP_BAND:
.OP_BXOR:
        ; Unify integer arguments w/ casts
.OP_GT:
.OP_LT:
.OP_GTE:
.OP_LTE:
        ; Unify integer arguments result I64
.OP_EQ:
.OP_NE:
        ; Cast to I64 and compare
.OP_AND:
.OP_OR:
        ; Unify integer arguments to I64. Result I64
.OP_ASSIGN:
.OP_ADDASSIGN:
.OP_SUBASSIGN:
.OP_MULASSIGN:
.OP_DIVASSIGN:
.OP_MODASSIGN:
.OP_BSLASSIGN:
.OP_BSRASSIGN:
.OP_BANDASSIGN:
.OP_BXORASSIGN:
.OP_BORASSIGN:
        ; Assignments
.OP_ANDTHEN:
        mov rax, [r12+ExprBinOp_right]
        mov rax, [rax+Expr_typeof]
        mov [r12+ExprBinOp_typeof], rax
        fnret rax

.EXPR_UNARY:
        mov rax, [r12+ExprUnOp_op]
        enumjmp UNOP, rax
.UNOP_NEGATE:
.UNOP_BNOT:
        fcall TypeckExpr, [r12+ExprUnOp_target]
        mov [r12+ExprUnOp_typeof], rax
        fnret rax

.UNOP_NOT:
        fcall TypeckExpr, [r12+ExprUnOp_target]
        fcall TyckMkCast, [r12+ExprUnOp_target], I64_type
        mov [r12+ExprUnOp_target], rax
        fnret I64_type

.UNOP_DEREF:
        fcall TypeckExpr, [r12+ExprUnOp_target]
        mov r15, rax
        cmp QWORD [r15+Type_variant], TYPE_PTR
        je ._UNOP_DEREF_ptr
        cmp QWORD [r15+Type_variant], TYPE_ARRAY
        je ._UNOP_DEREF_array
        Panic 101, 'Wow, this sucks', NL
._UNOP_DEREF_array:
        mov r14, [r15+TypePtr_target]
        fcall Alloc, Heap, SizeOfTypePtr
        mov QWORD [rax+TypePtr_variant], TYPE_PTR
        mov [rax+TypePtr_target], r14
        fcall TyckMkCast, [r12+ExprUnOp_target], rax
._UNOP_DEREF_ptr:
        mov rax, [r15+TypePtr_target]
        mov [r12+ExprUnOp_typeof], rax
        mov QWORD [r12+ExprUnOp_lvalue], 1
        fnret rax

.UNOP_ADDROF:
        mov rax, [r12+ExprUnOp_target]
        cmp QWORD [rax+Expr_lvalue], 0
        je ._UNOP_ADDROF_rvalue
        fcall TypeckExpr, rax
        mov r15, rax
        fcall Alloc, Heap, SizeOfTypePtr
        mov QWORD [rax+TypePtr_variant], TYPE_PTR
        mov [rax+TypePtr_target], r15
        mov [r12+ExprUnOp_typeof], rax
        fnret rax
._UNOP_ADDROF_rvalue:
        Panic 101, 'Crap', NL

.EXPR_CALL:
        fnret

.EXPR_MEMBER:
        mov rcx, [r12+ExprMember_operand]
        fcall TypeckExpr, rcx
        cmp QWORD [rax+Type_variant], TYPE_STRUCT
        jne ._EXPR_MEMBER_nonstruct

        ;; Copy over the lvalue property
        mov rax, [rcx+Expr_lvalue]
        mov [r12+ExprMember_lvalue], rax

        ;; Lookup the struct declaration and load into rax
        fcall LookupByKey, structs, [rax+TypeStruct_name]
        cmp rax, 0
        je ._EXPR_MEMBER_missingstruct
        mov rax, [rax]

        ;; Lookup the field in the struct
        mov r13, [rax+ItemStruct_fields]
        mov r14, 0
._ITEM_STRUCT_fieldsloop:
        cmp r14, [r13+Array_len]
        je ._ITEM_STRUCT_fieldmissing
        mov r15, [r13+r14]
        fcall StrCmp, [r15+Field_name], [r12+ExprMember_name]
        cmp rax, 0
        je ._ITEM_STRUCT_fieldfound
        add r14, 8
        jmp ._ITEM_STRUCT_fieldsloop
._ITEM_STRUCT_fieldfound:
        mov [r12+ExprMember_field], r15
        mov rax, [r15+Field_typeof]
        mov [r12+ExprMember_typeof], rax
        fnret rax
._ITEM_STRUCT_fieldmissing:
        Panic 101, 'No such field in struct', NL
._EXPR_MEMBER_nonstruct:
        Panic 101, 'Cannot get member of non-struct type', NL
._EXPR_MEMBER_missingstruct:
        Panic 101, 'No such struct', NL

.EXPR_CAST:
        fcall TypeckExpr, [r12+ExprCast_target]
        fcall IsValidCast, rax, [r12+ExprCast_typetarget]
        cmp rax, 0
        je ._EXPR_CAST_invalid
        mov rax, [r12+ExprCast_typetarget]
        mov [r12+ExprCast_typeof], rax
        fnret rax
._EXPR_CAST_invalid:
        Panic 101, 'Invalid cast', NL

.EXPR_SIZEOF:
        mov rax, [r12+ExprSizeof_target]
        cmp QWORD [rax+Type_variant], TYPE_VOID
        je ._EXPR_INVALID_SIZEOF
        cmp QWORD [rax+Type_variant], TYPE_FUNC
        je ._EXPR_INVALID_SIZEOF
        mov QWORD [r12+ExprSizeof_typeof], I64_type
        fnret I64_type
._EXPR_INVALID_SIZEOF:
        Panic 101, 'Sizeof on invalid type', NL

.OP_INVALID:
.UNOP_INVALID:
.EXPR_INVALID:
        Panic 101, 'Invalid expression type?', NL

