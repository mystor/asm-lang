;;; -*- nasm -*-

;;; Declarations
;;; EX: Param, ItemFunc, ItemVar, ExprVar
struct Decl
        field variant
        field name
        field typeof
        field dvariant
endstruct
%undef Decl_variant             ; Shouldn't access
%undef SizeOfDecl               ; Don't instantiate

enum DECL
        opt FUNC
        opt PARAM
        opt LOCAL
        opt GLOBAL
endenum

;;; Items
struct Item
        field variant
        field name
endstruct
%undef SizeOfItem               ; Don't instantiate

enum ITEM
        opt FUNC
        opt STRUCT
        ; opt VAR
endenum

struct ItemFunc                 ; DECL
        field variant
        field name
        field typeof
        field dvariant
        field params
        field returns
        field body
endstruct Item, Decl

struct Param                    ; DECL
        field variant           ; for compat with Decl
        field name
        field typeof
        field dvariant
endstruct Decl
%undef Param_variant            ; Shouldn't access

struct ItemStruct
        field variant
        field name
        field fields
endstruct Item

struct Field
        field name
        field typeof
endstruct

struct ItemVar
        field variant
        field name
        field typeof
        field dvariant
        field init
endstruct Item

;;; STMTs
struct Stmt
        field variant
endstruct
%undef SizeOfStmt               ; Don't instantiate

enum STMT
        opt VAR
        opt EXPR
        opt IF
        opt WHILE
        opt COMPOUND
        opt RETURN
        ;opt FOR
        ;opt SWITCH
endenum

struct StmtVar
        field variant
        field name
        field typeof
        field dvariant
        field init
endstruct Stmt, Decl

struct StmtExpr
        field variant
        field expr
endstruct Stmt

struct StmtIf
        field variant
        field cond
        field cons
        field alt
endstruct Stmt

struct StmtWhile
        field variant
        field cond
        field body
endstruct Stmt

struct StmtCompound
        field variant
        field stmts
endstruct Stmt

struct StmtReturn
        field variant
        field value
endstruct Stmt

;;; Exprs
struct Expr
        field variant
        field typeof
        field lvalue
endstruct
%undef SizeOfExpr               ; Don't instantiate

enum EXPR
        opt INTEGER
        opt REF
        opt BINARY
        opt UNARY
        opt CALL
        opt MEMBER
        opt CAST
        opt SIZEOF
endenum

struct ExprInt
        field variant
        field typeof
        field lvalue
        field value
endstruct Expr

struct ExprRef
        field variant
        field typeof
        field lvalue
        field name
        field decl
endstruct Expr

enum OP
        opt PLUS
        opt MINUS
        opt MUL
        opt DIV
        opt MOD
        opt BSL
        opt BSR
        opt BOR
        opt BAND
        opt BXOR
        opt GT
        opt LT
        opt GTE
        opt LTE
        opt EQ
        opt NE
        opt AND
        opt OR
        opt ASSIGN
        opt ADDASSIGN
        opt SUBASSIGN
        opt MULASSIGN
        opt DIVASSIGN
        opt MODASSIGN
        opt BSLASSIGN
        opt BSRASSIGN
        opt BANDASSIGN
        opt BXORASSIGN
        opt BORASSIGN
        opt ANDTHEN
endenum

struct ExprBinOp
        field variant
        field typeof
        field lvalue
        field op
        field left
        field right
endstruct Expr

enum UNOP
        opt NEGATE
        opt DEREF
        opt ADDROF
        opt BNOT
        opt NOT
endenum

struct ExprUnOp
        field variant
        field typeof
        field lvalue
        field op
        field target
endstruct Expr

struct ExprCall
        field variant
        field typeof
        field lvalue
        field target
        field args
endstruct Expr

struct ExprMember
        field variant
        field typeof
        field lvalue
        field operand
        field name
        field field
endstruct Expr

struct ExprCast
        field variant
        field typeof
        field lvalue
        field target
        field typetarget
endstruct Expr

struct ExprSizeof
        field variant
        field typeof
        field lvalue
        field target
endstruct Expr

;;; Type
struct Type
        field variant
endstruct
%undef SizeOfType

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
        field func
endstruct Type

        section .data
I64_type:
        dq TYPE_INT
        dq 1
        dq 8

        section .text
WriteItem:
        fn r12
        mov rax, [r12+Item_variant]
        enumjmp ITEM, rax

.ITEM_FUNC:
        fcall WriteType, [r12+ItemFunc_returns]
        WriteLit STDOUT, ' '
        fcall WriteStr, [r12+ItemFunc_name]
        WriteLit STDOUT, '('
        mov r13, [r12+ItemFunc_params]
        mov r14, 0
._ITEM_FUNC_paramsloop:
        cmp r14, [r13+Array_len]
        je ._ITEM_FUNC_paramsloopdone
        mov r15, [r13+r14]
        fcall WriteType, [r15+Param_typeof]
        WriteLit STDOUT, ' '
        fcall WriteStr, [r15+Param_name]
        cmp r14, [r13+Array_len]
        je ._ITEM_FUNC_paramsloopdone
        WriteLit STDOUT, ', '
        add r14, 8
        jmp ._ITEM_FUNC_paramsloop
._ITEM_FUNC_paramsloopdone:
        WriteLit STDOUT, ')', NL
        fcall WriteStmt, [r12+ItemFunc_body]
        WriteLit STDOUT, NL
        fnret

.ITEM_STRUCT:
        WriteLit STDOUT, 'struct '
        fcall WriteStr, [r12+ItemStruct_name]
        WriteLit STDOUT, ' {', NL
        mov r13, [r12+ItemStruct_fields]
        mov r14, 0
._ITEM_STRUCT_fieldsloop:
        cmp r14, [r13+Array_len]
        je ._ITEM_STRUCT_fieldsloopdone
        mov r15, [r13+r14]
        WriteLit STDOUT, '    '
        fcall WriteType, [r15+Field_typeof]
        WriteLit STDOUT, ' '
        fcall WriteStr, [r15+Field_name]
        WriteLit STDOUT, ';', NL
        add r14, 8
        jmp ._ITEM_STRUCT_fieldsloop
._ITEM_STRUCT_fieldsloopdone:
        WriteLit STDOUT, '};', NL
        fnret

.ITEM_INVALID:
        Panic 101, 'Invalid Item Variant!', NL

WriteExpr:
        fn r12
        mov rax, [r12+Expr_variant]
        enumjmp EXPR, rax

.EXPR_INTEGER:
        fcall WriteDec, [r12+ExprInt_value]
        fnret

.EXPR_REF:
        fcall WriteStr, [r12+ExprRef_name]
        fnret

.EXPR_BINARY:
        WriteLit STDOUT, '('
        fcall WriteExpr, [r12+ExprBinOp_left]
        WriteLit STDOUT, ' '
        fcall WriteOP, [r12+ExprBinOp_op]
        WriteLit STDOUT, ' '
        fcall WriteExpr, [r12+ExprBinOp_right]
        WriteLit STDOUT, ')'
        fnret

.EXPR_UNARY:
        WriteLit STDOUT, '('
        fcall WriteUNOP, [r12+ExprUnOp_op]
        WriteLit STDOUT, ' '
        fcall WriteExpr, [r12+ExprUnOp_target]
        WriteLit STDOUT, ')'
        fnret

.EXPR_CALL:
        fcall WriteExpr, [r12+ExprCall_target]
        WriteLit STDOUT, '('
        mov r13, [r12+ExprCall_args]
        mov r14, 0
._EXPR_CALL_argsloop:
        cmp r14, [r13+Array_len]
        je ._EXPR_CALL_afterargs
        mov r15, [r13+r14]
        fcall WriteExpr, r15
        cmp r14, [r13+Array_len]
        je ._EXPR_CALL_afterargs
        WriteLit STDOUT, ', '
        add r14, 8
        jmp ._EXPR_CALL_argsloop
._EXPR_CALL_afterargs:
        WriteLit STDOUT, ')'
        fnret

.EXPR_MEMBER:
        fcall WriteExpr, [r12+ExprMember_operand]
        WriteLit STDOUT, '.'
        fcall WriteStr, [r12+ExprMember_name]
        fnret

.EXPR_CAST:
        WriteLit STDOUT, '(('
        fcall WriteType, [r12+ExprCast_typetarget]
        WriteLit STDOUT, ')'
        fcall WriteExpr, [r12+ExprCast_target]
        WriteLit STDOUT, ')'
        fnret

.EXPR_SIZEOF:
        WriteLit STDOUT, 'sizeof('
        fcall WriteType, [r12+ExprSizeof_target]
        WriteLit STDOUT, ')'
        fnret

.EXPR_INVALID:
        Panic 101, 'Invalid Expression Type?', NL

WriteStmt:
        fn r12
        mov rax, [r12+Stmt_variant]
        enumjmp STMT, rax

.STMT_VAR:
        fcall WriteType, [r12+StmtVar_typeof]
        WriteLit STDOUT, ' '
        fcall WriteStr, [r12+StmtVar_name]
        cmp QWORD [r12+StmtVar_init], 0
        je ._STMT_VAR_noinit
._STMT_VAR_hasinit:
        WriteLit STDOUT, ' = '
        fcall WriteExpr, [r12+StmtVar_init]
._STMT_VAR_noinit:
        WriteLit STDOUT, ';'
        fnret

.STMT_EXPR:
        fcall WriteExpr, [r12+StmtExpr_expr]
        WriteLit STDOUT, ';'
        fnret

.STMT_IF:
        WriteLit STDOUT, 'if ('
        fcall WriteExpr, [r12+StmtIf_cond]
        WriteLit STDOUT, ')'
        fcall WriteStmt, [r12+StmtIf_cons]
        cmp QWORD [r12+StmtIf_alt], 0
        je ._STMT_IF_noalt
._STMT_IF_alt:
        WriteLit STDOUT, ' else '
        fcall WriteStmt, [r12+StmtIf_alt]
._STMT_IF_noalt:
        fnret

.STMT_WHILE:
        WriteLit STDOUT, 'while ('
        fcall WriteExpr, [r12+StmtWhile_cond]
        WriteLit STDOUT, ')'
        fcall WriteStmt, [r12+StmtWhile_body]
        fnret

.STMT_COMPOUND:
        WriteLit STDOUT, '{', NL
        mov r13, [r12+StmtCompound_stmts]
        mov r14, 0
._STMT_COMPOUND_stmtloop:
        cmp r14, [r13+Array_len]
        je ._STMT_COMPOUND_stmtloopdone
        fcall WriteStmt, [r13+r14]
        WriteLit STDOUT, NL
        add r14, 8
        jmp ._STMT_COMPOUND_stmtloop
._STMT_COMPOUND_stmtloopdone:
        WriteLit STDOUT, '}'
        fnret

.STMT_RETURN:
        WriteLit STDOUT, 'return '
        fcall WriteExpr, [r12+StmtReturn_value]
        fnret

.STMT_INVALID:
        Panic 101, 'Invalid Statement Type?', NL

WriteType:
        fn r12
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
        Panic 101, 'Invalid Type Type?', NL
