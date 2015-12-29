;;; -*- nasm -*-
;;; Let's go!
;;; PRINT expr
enum STMT
        opt PRINT
endenum
;;; Offset of the type in a statement
%define Stmt_type 0

struct StmtPrint
        field type              ; STMT
        field expr              ; *Expr
endstruct

enum EXPR
        opt INTEGER
        opt BINARY
endenum

;;; Offset of the type in an expression
%define Expr_type 0

struct ExprInt
        field type              ; EXPR
        field value             ; signed
endstruct

enum OP
        opt PLUS
        opt MINUS
        opt MULTIPLY
        opt DIVIDE
endenum

struct ExprBinOp
        field type
        field op
        field left
        field right
endstruct

WriteExpr:
        fn r12
        ;; Switch based on the type of the expression
        mov rax, [r12+Expr_type]
        ;; XXX: Currently we don't consider the possibility of rax
        ;; falling outside of .jumptbl
        jmp [.jumptbl+rax*8]
.jumptbl:
        dq .integer
        dq .binary
.integer:
        WriteLit STDOUT, 'INTEGER('
        fcall WriteHex, [r12+ExprInt_value]
        WriteLit STDOUT, ')'
        fnret
.binary:
        WriteLit STDOUT, 'BINOP('
        fcall WriteOP, [r12+ExprBinOp_op]
        WriteLit STDOUT, ', '
        fcall WriteExpr, [r12+ExprBinOp_left]
        WriteLit STDOUT, ', '
        fcall WriteExpr, [r12+ExprBinOp_right]
        WriteLit STDOUT, ')'
        fnret

WriteStmt:
        fn r12
        ;; Switch based on the type of the statement
        mov rax, [r12+Stmt_type]
        ;; XXX: Currently we don't consider the possibility of rax
        ;; falling outside of .jumptbl
        jmp [.jumptbl+rax*8]
.jumptbl:
        dq .print
.print:
        WriteLit STDOUT, 'PRINT('
        fcall WriteExpr, [r12+StmtPrint_expr]
        WriteLit STDOUT, ')'
        fnret

