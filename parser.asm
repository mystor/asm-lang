;;; -*- nasm -*-
NextTokenIsType:
        fn
        fcall PeekTokType
        cmp rax, TOKEN_UNSIGNED
        je .ok
        cmp rax, TOKEN_SHORT
        je .ok
        cmp rax, TOKEN_LONG
        je .ok
        cmp rax, TOKEN_INT
        je .ok
        cmp rax, TOKEN_CHAR
        je .ok
        cmp rax, TOKEN_VOID
        je .ok
        cmp rax, TOKEN_STRUCT
        je .ok
        fnret 0
.ok:
        fnret 1

Expect:
        fn r12
        alloca SizeOfToken
        mov r13, rax
        fcall EatTok, r13
        cmp QWORD [r13+Token_type], r12
        jne .fail
        fnret [r13+Token_data]
.fail:
        WriteLit STDERR, 'Expected '
        fcall WriteTOKEN, r12
        WriteLit STDERR, ', instead found '
        fcall WriteTOKEN, [r13+Token_type]
        Panic 100, NL

ParseItem:
        fn
        fcall PeekTokType
        ;; XXX: Check for typedef token here?

        ;; XXX: TYPEDEF?
        fcall ParseType
        mov r14, rax            ; r14 has return type

        fcall PeekTokType
        cmp rax, TOKEN_LBRACE
        je .struct_def

        ;; Not a struct - must be some type of decl
        fcall Expect, TOKEN_IDENT
        mov r15, rax            ; r15 has name

        fcall PeekTokType
        cmp rax, TOKEN_LPAREN
        je .func_def

.var_def:
        fcall Expect, TOKEN_SEMI
        Panic 100, "Global var definitions NOT SUPPORTED YET", NL

.struct_def:
        fcall Expect, TOKEN_LBRACE
        cmp QWORD [r14+Type_type], TYPE_STRUCT
        jne .expected_name
        fcall Alloc, Heap, SizeOfItemStruct
        mov rcx, rax
        mov QWORD [rcx+ItemStruct_type], ITEM_STRUCT
        mov rax, [r14+TypeStruct_name]
        mov [rcx+ItemStruct_name], rax
        fcall NewArr, Heap, 8*8
        mov r15, rax
.fieldsloop:
        fcall PeekTokType
        cmp rax, TOKEN_RBRACE
        je .fieldsloop_done
        fcall Alloc, Heap, SizeOfField
        mov r12, rax
        fcall ParseType
        mov [r12+Field_typeof], rax
        fcall Expect, TOKEN_IDENT
        mov [r12+Field_name], rax
        fcall ExtendArr, r15, 8
        mov r15, rax
        mov [rbx], r12          ; Save the field
        jmp .fieldsloop
.fieldsloop_done:
        mov [rcx+ItemStruct_fields], r15
        fcall EatTok, r13
        fcall Expect, TOKEN_RBRACE
        fcall Expect, TOKEN_SEMI
        fnret rcx
.expected_name:                 ; XXX: Used above for struct_def
        WriteLit STDERR, 'Expected NAME, instead found '
        fcall WriteTOKEN, [r13+Token_type] ; XXX: Write to STDERR?
        Panic 100, NL

.func_def:
        fcall Expect, TOKEN_LPAREN
        fcall Alloc, Heap, SizeOfItemFunc
        mov rcx, rax
        mov QWORD [rcx+ItemFunc_type], ITEM_FUNC
        mov [rcx+ItemFunc_name], r15
        mov [rcx+ItemFunc_returns], r14
        fcall NewArr, Heap, 8*8
        mov r15, rax
        fcall PeekTokType       ; Handle empty params lists
        cmp rax, TOKEN_RPAREN
        je .paramsdone
.paramsloop:
        fcall Alloc, Heap, SizeOfParam
        mov r12, rax
        fcall ParseType
        mov [r12+Param_typeof], rax
        fcall Expect, TOKEN_IDENT
        mov [r12+Param_name], rax
        fcall ExtendArr, r15, 8
        mov r15, rax
        mov [rbx], r12          ; Save the arg
        fcall PeekTokType
        cmp rax, TOKEN_COMMA
        jne .paramsdone
        fcall Expect, TOKEN_COMMA
        jmp .paramsloop
.paramsdone:
        fcall Expect, TOKEN_RPAREN
        mov [rcx+ItemFunc_params], r15
        fcall ParseStmt
        mov [rcx+ItemFunc_body], rax
        ;; Compound statements are the only legal function bodies
        cmp QWORD [rax+Stmt_type], STMT_COMPOUND
        jne .bad_body_type
        fnret rcx
.bad_body_type:
        Panic 101, 'Unexpected invalid body type', NL


ParseType:
        fn
        fcall ParseTypeAtom
        mov r12, rax
.loop:
        fcall PeekTokType
        cmp rax, TOKEN_STAR
        je .pointer
        cmp rax, TOKEN_LBRACE
        je .array
        fnret r12
.pointer:
        fcall Expect, TOKEN_STAR
        fcall Alloc, Heap, SizeOfTypePtr
        mov QWORD [rax+TypePtr_type], TYPE_PTR
        mov [rax+TypePtr_target], r12
        mov r12, rax
        jmp .loop
.array:
        fcall Expect, TOKEN_LBRACE
        fcall Alloc, Heap, SizeOfTypeArray
        mov QWORD [rax+TypeArray_type], TYPE_ARRAY
        mov [rax+TypeArray_target], r12
        mov r12, rax
        fcall Expect, TOKEN_NUMBER
        mov [r12+TypeArray_length], rax
        fcall Expect, TOKEN_RBRACE
        jmp .loop

        ;; Valid Combinations:
        ;; int = 32 bits / 4 bytes
        ;; long int = 64 bits / 8 bytes
        ;; long long int = 64 bits / 8 bytes
        ;; short int = 16 bits / 2 bytes
        ;; long = 64 bits / 8 bytes
        ;; long long = 64 bits / 8 bytes
        ;; short = 16 bits / 2 bytes
        ;; char = 8 bits / 1 byte
        ;; All optionally prefixed by unsigned
ParseTypeAtom:
        fn
        fcall PeekTokType
        cmp rax, TOKEN_STRUCT
        je .struct_type
        cmp rax, TOKEN_VOID
        je .void_type

.int_type:
        fcall Alloc, Heap, SizeOfTypeInt
        mov r12, rax
        mov QWORD [r12+TypeInt_type], TYPE_INT
        mov QWORD [r12+TypeInt_signed], 1 ; true
        mov QWORD [r12+TypeInt_size], 4   ; default size for int
        mov r13, 0                  ; Recently seen modifier
.int_loop:
        fcall PeekTokType
        cmp rax, TOKEN_LONG
        je .long_modify
        cmp rax, TOKEN_SHORT
        je .short_modify
        cmp rax, TOKEN_INT
        je .int_done
        cmp rax, TOKEN_CHAR
        je .char_done
        cmp rax, TOKEN_UNSIGNED
        je .unsigned_modify
        jmp .no_int_final

.long_modify:
        fcall Expect, TOKEN_LONG
        cmp r13, 0
        jne .long_prev
.long_ok:
        mov r13, TOKEN_LONG
        mov QWORD [r12+TypeInt_size], 8
        jmp .int_loop
.long_prev:
        cmp r13, TOKEN_LONG
        je .long_ok
        Panic 101, 'Cannot modify a long with short'

.short_modify:
        fcall Expect, TOKEN_SHORT
        cmp r13, 0
        jne .modified_short
.short_ok:
        mov r13, TOKEN_SHORT
        mov QWORD [r12+TypeInt_size], 2
        jmp .int_loop
.modified_short:
        Panic 101, 'Cannot modify a short with short or long'

.unsigned_modify:
        fcall Expect, TOKEN_UNSIGNED
        mov QWORD [r12+TypeInt_signed], 0 ; false
        jmp .int_loop

.char_done:
        cmp r13, 0
        jne .unexpected_modified_char
        mov QWORD [r12+TypeInt_size], 1
        fnret r12
.unexpected_modified_char:
        Panic 101, "Unexpected modifier on char type"

.int_done:
        fcall Expect, TOKEN_INT
        fnret r12
.no_int_final:
        cmp QWORD [r12+TypeInt_signed], 1
        jne .no_int_ok
        cmp r13, 0
        jne .no_int_ok
        fcall Expect, TOKEN_INT ; Will fail
        Panic 99, 'Unreachable'
.no_int_ok:
        fnret r12

.struct_type:
        fcall Expect, TOKEN_STRUCT
        fcall Alloc, Heap, SizeOfTypeStruct
        mov r12, rax
        mov QWORD [r12+TypeStruct_type], TYPE_STRUCT
        fcall Expect, TOKEN_IDENT
        mov [r12+TypeStruct_name], rax
        fnret r12

.void_type:
        fcall Expect, TOKEN_VOID
        fcall Alloc, Heap, SizeOfTypeVoid
        mov QWORD [rax+TypeVoid_type], TYPE_VOID
        fnret rax

;;; Parse a statement from the input stream
ParseStmt:
        fn
        fcall PeekTokType
        cmp rax, TOKEN_IF
        je .ifstmt
        cmp rax, TOKEN_WHILE
        je .whilestmt
        cmp rax, TOKEN_LBRACE
        je .compoundstmt
        cmp rax, TOKEN_RETURN
        je .returnstmt

        fcall NextTokenIsType
        cmp rax, 0
        jne .vardecl

.expr:
        fcall Alloc, Heap, SizeOfStmtExpr
        mov rcx, rax
        mov QWORD [rcx+StmtExpr_type], STMT_EXPR
        fcall ParseExpr
        mov [rcx+StmtExpr_expr], rax
        fnret rcx

.vardecl:
        fcall Alloc, Heap, SizeOfStmtVar
        mov rcx, rax
        mov QWORD [rcx+StmtVar_type], STMT_VAR
        fcall ParseType
        mov [rcx+StmtVar_typeof], rax
        fcall Expect, TOKEN_IDENT
        mov [rcx+StmtVar_name], rax
        fcall PeekTokType
        cmp rax, TOKEN_EQ
        jne .vardecl_done
        fcall Expect, TOKEN_EQ
        fcall ParseExpr
        mov [rcx+StmtVar_init], rax
.vardecl_done:
        fnret rcx

.ifstmt:
        fcall Expect, TOKEN_IF
        fcall Alloc, Heap, SizeOfStmtIf
        mov rcx, rax
        mov QWORD [rcx+StmtIf_type], STMT_IF
        fcall Expect, TOKEN_LPAREN
        fcall ParseExpr
        mov [rcx+StmtIf_cond], rax
        fcall Expect, TOKEN_RPAREN
        fcall ParseStmt
        mov [rcx+StmtIf_cons], rax
        fcall PeekTokType
        cmp rax, TOKEN_ELSE
        jne .ifstmt_done
        fcall Expect, TOKEN_ELSE
        fcall ParseStmt
        mov [rcx+StmtIf_alt], rax
.ifstmt_done:
        fnret rcx

.whilestmt:
        fcall Expect, TOKEN_WHILE
        fcall Alloc, Heap, SizeOfStmtWhile
        mov rcx, rax
        mov QWORD [rcx+StmtWhile_type], STMT_WHILE
        fcall Expect, TOKEN_LPAREN
        fcall ParseExpr
        mov [rcx+StmtWhile_cond], rax
        fcall Expect, TOKEN_RPAREN
        fcall ParseStmt
        mov [rcx+StmtWhile_body], rax
        fnret rcx

.compoundstmt:
        fcall Expect, TOKEN_LBRACE
        fcall Alloc, Heap, SizeOfStmtCompound
        mov rcx, rax
        mov QWORD [rcx+StmtCompound_type], STMT_COMPOUND
        fcall NewArr, Heap, 8*8
        mov r15, rax
.compoundloop:
        fcall PeekTokType
        cmp rax, TOKEN_RBRACE
        je .compounddone
        fcall ParseStmt
        mov r12, rax
        fcall ExtendArr, r15, 8
        mov r15, rax
        mov [rbx], r12
        fcall Expect, TOKEN_SEMI
        jmp .compoundloop
.compounddone:
        mov [rcx+StmtCompound_stmts], r15
        fcall Expect, TOKEN_RBRACE
        fnret rcx

.returnstmt:
        fcall Expect, TOKEN_RETURN
        fcall Alloc, Heap, SizeOfStmtReturn
        mov rcx, rax
        mov QWORD [rcx+StmtReturn_type], STMT_RETURN
        fcall ParseExpr
        mov [rcx+StmtReturn_value], rax
        fnret rcx

;;; Utility for creating a binary operator
MkBinOp:
        fn r12, r13             ; r12 = left, r13 = op
        fcall Alloc, Heap, SizeOfExprBinOp
        mov r15, rax
        mov QWORD [r15+ExprBinOp_type], EXPR_BINARY
        mov [r15+ExprBinOp_left], r12
        mov [r15+ExprBinOp_op], r13
        fnret r15

ParseExpr:
        fn
        fnret

ParseFactor:
        fn
        fcall ParseTerm
        mov r12, rax
.loop:
        fcall PeekTokType
        cmp rax, TOKEN_PLUS
        je .plus
        cmp rax, TOKEN_DASH
        je .minus
        fnret r12
.plus:
        fcall Expect, TOKEN_PLUS
        fcall MkBinOp, r12, OP_PLUS
        jmp .rhs
.minus:
        fcall Expect, TOKEN_DASH
        fcall MkBinOp, r12, OP_MINUS
        jmp .rhs
.rhs:
        mov r12, rax
        fcall ParseTerm
        mov [r12+ExprBinOp_right], rax
        jmp .loop

ParseTerm:
        fn
        fcall ParsePrefix
        mov r12, rax
.loop:
        fcall PeekTokType
        cmp rax, TOKEN_STAR
        je .mul
        cmp rax, TOKEN_SLASH
        je .div
        cmp rax, TOKEN_MODULO
        je .mod
        fnret r12
.mul:
        fcall Expect, TOKEN_STAR
        fcall MkBinOp, r12, OP_MUL
        jmp .rhs
.div:
        fcall Expect, TOKEN_SLASH
        fcall MkBinOp, r12, OP_DIV
        jmp .rhs
.mod:
        fcall Expect, TOKEN_MODULO
        fcall MkBinOp, r12, OP_MOD
        jmp .rhs
.rhs:
        mov r12, rax
        fcall ParsePrefix
        mov [r12+ExprBinOp_right], rax
        jmp .loop

ParsePrefix:
        fn
        fcall PeekTokType
        cmp rax, TOKEN_STAR
        je .deref
        cmp rax, TOKEN_DASH
        je .negate
        cmp rax, TOKEN_TILDE
        je .bnot
        cmp rax, TOKEN_NOT
        je .not
        cmp rax, TOKEN_LPAREN
        je .maybecast
        fcall ParseTrailer
        fnret rax

.deref:
        fcall Expect, TOKEN_STAR
        fcall Alloc, Heap, SizeOfExprUnOp
        mov r12, rax
        mov QWORD [r12+ExprUnOp_type], EXPR_UNARY
        mov QWORD [r12+ExprUnOp_op], UNOP_DEREF
        fcall ParsePrefix       ; Recurse to allow mult derefs
        mov [r12+ExprUnOp_target], rax
        fnret r12

.negate:
        fcall Expect, TOKEN_DASH
        fcall Alloc, Heap, SizeOfExprUnOp
        mov r12, rax
        mov QWORD [r12+ExprUnOp_type], EXPR_UNARY
        mov QWORD [r12+ExprUnOp_op], UNOP_NEGATE
        fcall ParsePrefix       ; Recurse to allow mult negations
        mov [r12+ExprUnOp_target], rax
        fnret r12

.bnot:
        fcall Expect, TOKEN_TILDE
        fcall Alloc, Heap, SizeOfExprUnOp
        mov r12, rax
        mov QWORD [r12+ExprUnOp_type], EXPR_UNARY
        mov QWORD [r12+ExprUnOp_op], UNOP_BNOT
        fcall ParsePrefix       ; Recurse to allow mult negations
        mov [r12+ExprUnOp_target], rax
        fnret r12

.not:
        fcall Expect, TOKEN_NOT
        fcall Alloc, Heap, SizeOfExprUnOp
        mov r12, rax
        mov QWORD [r12+ExprUnOp_type], EXPR_UNARY
        mov QWORD [r12+ExprUnOp_op], UNOP_NOT
        fcall ParsePrefix       ; Recurse to allow mult negations
        mov [r12+ExprUnOp_target], rax
        fnret r12

.maybecast:
        fcall Expect, TOKEN_LPAREN
        fcall NextTokenIsType
        cmp rax, 0
        jne .cast
.paren:
        fcall ParseExpr
        mov r12, rax
        fcall Expect, TOKEN_RPAREN
        fnret r12
.cast:
        fcall Alloc, Heap, SizeOfExprCast
        mov r12, rax
        mov QWORD [r12+ExprCast_type], EXPR_CAST
        fcall ParseType
        mov [r12+ExprCast_newtype], rax
        fcall ParsePrefix
        mov [r12+ExprCast_target], rax
        fnret r12

ParseTrailer:
        fn
        fcall ParseAtom
        mov r12, rax
.loop:
        fcall PeekTokType
        cmp rax, TOKEN_LPAREN
        je .call
        cmp rax, TOKEN_LBRACE
        je .index
        cmp rax, TOKEN_DOT
        je .direct
        cmp rax, TOKEN_ARROW
        je .indirect
        fnret r12

.call:
        fcall Expect, TOKEN_LPAREN
        fcall Alloc, Heap, SizeOfExprCall
        mov QWORD [rax+ExprCall_type], EXPR_CALL
        mov [rax+ExprCall_target], r12
        mov r12, rax
        fcall NewArr, Heap, 8*8
        mov r15, rax
        fcall PeekTokType       ; Handle empty args lists
        cmp rax, TOKEN_RPAREN
        je .argsdone
.argsloop:
        fcall ParseExpr
        mov rcx, rax
        fcall ExtendArr, r15, 8
        mov r15, rax
        mov [rbx], rcx
        fcall PeekTokType
        cmp rax, TOKEN_COMMA
        jne .argsdone
        fcall Expect, TOKEN_COMMA
        jmp .argsloop
.argsdone:
        mov [r12+ExprCall_args], r15
        fcall Expect, TOKEN_RPAREN
        jmp .loop

.index:
        fcall Expect, TOKEN_LBRACE
        fcall Alloc, Heap, SizeOfExprIndex
        mov QWORD [rax+ExprIndex_type], EXPR_INDEX
        mov [rax+ExprIndex_target], r12
        mov r12, rax
        fcall ParseExpr
        mov [r12+ExprIndex_index], rax
        fcall Expect, TOKEN_RBRACE
        jmp .loop

.direct:
        fcall Expect, TOKEN_DOT
        fcall Alloc, Heap, SizeOfExprMember
        mov QWORD [rax+ExprMember_type], EXPR_MEMBER
        mov QWORD [rax+ExprMember_indirect], 0
        jmp .member
.indirect:
        fcall Expect, TOKEN_ARROW
        fcall Alloc, Heap, SizeOfExprMember
        mov QWORD [rax+ExprMember_type], EXPR_MEMBER
        mov QWORD [rax+ExprMember_indirect], 1
        jmp .member
.member:
        mov [rax+ExprMember_operand], r12
        mov r12, rax
        fcall Expect, TOKEN_IDENT
        mov [r12+ExprMember_name], rax
        jmp .loop

ParseAtom:
        fn
        fcall PeekTokType
        cmp rax, TOKEN_NUMBER
        jmp .integer
        cmp rax, TOKEN_SIZEOF
        jmp .sizeof
        cmp rax, TOKEN_IDENT
        jmp .ref
        Panic 101, 'Unrecognized Atom Starter', NL

.integer:
        fcall Expect, TOKEN_NUMBER
        mov r12, rax
        fcall Alloc, Heap, SizeOfExprInt
        mov QWORD [rax+ExprInt_type], EXPR_INTEGER
        mov [rax+ExprInt_value], r12
        fnret rax

.sizeof:
        fcall Expect, TOKEN_SIZEOF
        fcall Expect, TOKEN_LPAREN
        fcall Alloc, Heap, SizeOfExprSizeof
        mov r12, rax
        mov QWORD [r12+ExprSizeof_type], EXPR_SIZEOF
        fcall ParseType
        mov [r12+ExprSizeof_target], rax
        fcall Expect, TOKEN_RPAREN
        fnret r12

.ref:
        fcall Expect, TOKEN_IDENT
        mov r12, rax
        fcall Alloc, Heap, SizeOfExprRef
        mov QWORD [rax+ExprRef_type], EXPR_REF
        mov [rax+ExprRef_name], r12
        fnret rax

