;;; -*- nasm -*-

;;; Parse a statement from the input stream
ParseStmt:
        fn
        alloca SizeOfToken, tok

        lea r8, [tok]
        fcall EatTok, r8

        mov rax, [tok+Token_type]
        cmp rax, TOKEN_PRINT
        je __ParseStmt_PRINT
        ;; ...

        jmp __ParseStmt_INVALID
__ParseStmt_PRINT:
        fcall Malloc, SizeOfStmtPrint
        mov r12, rax
        mov QWORD [r12+StmtPrint_type], STMT_PRINT

        fcall ParseExpr
        mov [r12+StmtPrint_expr], rax

        fnret r12
__ParseStmt_INVALID:
        Panic 100, "Unrecognized statement starter!", NL
%undef tok

ParseExpr:
        fn
        alloca SizeOfToken, tok

        fcall ParseTerm
        mov r12, rax
__ParseExpr_Loop:
        lea r8, [tok]
        fcall PeekTok, r8
        cmp QWORD [tok+Token_type], TOKEN_PLUS
        je __ParseExpr_PLUS
        cmp QWORD [tok+Token_type], TOKEN_DASH
        je __ParseExpr_MINUS
        fnret r12

__ParseExpr_PLUS:
        mov r15, OP_PLUS
        jmp __ParseExpr_BinOp
__ParseExpr_MINUS:
        mov r15, OP_MINUS
        jmp __ParseExpr_BinOp
__ParseExpr_BinOp:
        fcall EatTok, 0
        fcall Malloc, SizeOfExprBinOp
        mov QWORD [rax+ExprBinOp_type], EXPR_BINARY
        mov [rax+ExprBinOp_op], r15
        mov [rax+ExprBinOp_left], r12
        mov r12, rax
        fcall ParseTerm
        mov [r12+ExprBinOp_right], rax
        jmp __ParseExpr_Loop
%undef tok

ParseTerm:
        fn
        alloca SizeOfToken, tok

        fcall ParseFactor
        mov r12, rax
__ParseTerm_Loop:
        lea r8, [tok]
        fcall PeekTok, r8
        cmp QWORD [tok+Token_type], TOKEN_STAR
        je __ParseTerm_MULTIPLY
        cmp QWORD [tok+Token_type], TOKEN_SLASH
        je __ParseTerm_DIVIDE
        fnret r12

__ParseTerm_MULTIPLY:
        mov r15, OP_MULTIPLY
        jmp __ParseTerm_BinOp
__ParseTerm_DIVIDE:
        mov r15, OP_DIVIDE
        jmp __ParseTerm_BinOp
__ParseTerm_BinOp:
        fcall EatTok, 0
        fcall Malloc, SizeOfExprBinOp
        mov QWORD [rax+ExprBinOp_type], EXPR_BINARY
        mov [rax+ExprBinOp_op], r15
        mov [rax+ExprBinOp_left], r12
        mov r12, rax
        fcall ParseFactor
        mov [r12+ExprBinOp_right], rax
        jmp __ParseTerm_Loop
%undef tok

ParseFactor:
        fn
        alloca SizeOfToken, tok

        lea r8, [tok]
        fcall EatTok, r8

        mov r12, [tok+Token_type]
        cmp r12, TOKEN_NUMBER
        je __ParseFactor_NUMBER
        jmp __ParseFactor_FAIL
__ParseFactor_NUMBER:
        fcall Malloc, SizeOfExprInt
        mov r13, rax
        mov QWORD [r13+ExprInt_type], EXPR_INTEGER
        mov rbx, [tok+Token_data]
        mov [r13+ExprInt_value], rbx
        fnret r13
__ParseFactor_FAIL:
        Panic 100, 'Failure while parsing a Factor', NL
%undef tok
