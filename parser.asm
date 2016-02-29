;;; -*- nasm -*-
NextTokenIsType:
        fn
        fcall PeekTok
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
        ;; XXX: Typedef
        fnret 0
.ok:
        fnret 1

%macro Expect 1
        fcall PeekTok
        cmp rax, %1
        je %%after
        mov r13, rax
        WriteLit STDOUT, 'Expected '
        fcall WriteTOKEN, %1
        WriteLit STDOUT, ', instead found '
        fcall WriteTOKEN, r13
        Panic
%%after:
        fcall EatTok
        mov rax, rbx
%endmacro

ParseItem:
        fn
        fcall PeekTok
        ;; XXX: Check for typedef token here?

        ;; XXX: TYPEDEF?
        fcall ParseType
        mov r14, rax            ; r14 has return type

        fcall PeekTok
        cmp rax, TOKEN_LBRACE
        je .struct_def

        ;; Not a struct - must be some type of decl
        Expect TOKEN_IDENT
        mov r15, rax            ; r15 has name

        fcall PeekTok
        cmp rax, TOKEN_LPAREN
        je .func_def

.var_def:
        Expect TOKEN_SEMI
        Panic 'Global var definitions NOT SUPPORTED YET'

.struct_def:
;;; XXX: Implement
        cmp QWORD [r14+Type_variant], TYPE_STRUCT
        jne .expected_name
        Expect TOKEN_LBRACE
        mov rax, [r14+TypeStruct_name] ; Struct name
.fieldsloop:
        fcall PeekTok
        cmp rax, TOKEN_RBRACE
        je .fieldsloop_done
        fcall ParseType
        Expect TOKEN_IDENT
        ; Save the field info
        jmp .fieldsloop
.fieldsloop_done:
        Expect TOKEN_RBRACE
        Expect TOKEN_SEMI
        Panic 'Unexpected struct definition'
        fnret rcx
.expected_name:                 ; XXX: Used above for struct_def
        ; We got a { after a non struct type - var_def.
        Expect TOKEN_NAME

.func_def:
        Expect TOKEN_LPAREN
        fcall Alloc, Heap, SizeOfTypeFunc
        mov r12, rax
        mov [r12+TypeFunc_variant], TYPE_FUNC
        mov [r12+TypeFunc_returns], r14 ; XXX: Treat void differently?
        fcall PeekTok       ; Handle empty params lists
        cmp rax, TOKEN_RPAREN
        je .paramsdone
.paramsloop:
        fcall ParseType
        Expect TOKEN_IDENT
        fcall PeekTok
        cmp rax, TOKEN_COMMA
        jne .paramsdone
        Expect TOKEN_COMMA
        jmp .paramsloop
.paramsdone:
        Expect TOKEN_RPAREN
        fcall ParseCompoundStmt
        Panic 'Unexpected function definition'
        fnret rcx

ParseType:
        fn
        fcall ParseTypeAtom
        mov r12, rax
.loop:
        fcall PeekTok
        cmp rax, TOKEN_STAR
        je .pointer
        cmp rax, TOKEN_LBRACE
        je .array
        fnret r12
.pointer:
        Expect TOKEN_STAR
        fcall Alloc, Heap, SizeOfTypePtr
        mov QWORD [rax+TypePtr_variant], TYPE_PTR
        mov [rax+TypePtr_target], r12
        mov r12, rax
        jmp .loop
.array:
        Expect TOKEN_LBRACE
        fcall Alloc, Heap, SizeOfTypeArray
        mov QWORD [rax+TypeArray_variant], TYPE_ARRAY
        mov [rax+TypeArray_target], r12
        mov r12, rax
        Expect TOKEN_NUMBER
        mov [r12+TypeArray_length], rax
        Expect TOKEN_RBRACE
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
        fcall PeekTok
        cmp rax, TOKEN_STRUCT
        je .struct_type
        cmp rax, TOKEN_VOID
        je .void_type

.int_type:
        fcall Alloc, Heap, SizeOfTypeInt
        mov r12, rax
        mov QWORD [r12+TypeInt_variant], TYPE_INT
        mov QWORD [r12+TypeInt_signed], 1 ; true
        mov QWORD [r12+TypeInt_size], 4   ; default size for int
        mov r13, 0                  ; Recently seen modifier
.int_loop:
        fcall PeekTok
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
        Expect TOKEN_LONG
        cmp r13, 0
        jne .long_prev
.long_ok:
        mov r13, TOKEN_LONG
        mov QWORD [r12+TypeInt_size], 8
        jmp .int_loop
.long_prev:
        cmp r13, TOKEN_LONG
        je .long_ok
        Panic 'Cannot modify a long with short'

.short_modify:
        Expect TOKEN_SHORT
        cmp r13, 0
        jne .modified_short
.short_ok:
        mov r13, TOKEN_SHORT
        mov QWORD [r12+TypeInt_size], 2
        jmp .int_loop
.modified_short:
        Panic 'Cannot modify a short with short or long'

.unsigned_modify:
        Expect TOKEN_UNSIGNED
        mov QWORD [r12+TypeInt_signed], 0 ; false
        jmp .int_loop

.char_done:
        Expect TOKEN_CHAR
        cmp r13, 0
        jne .unexpected_modified_char
        mov QWORD [r12+TypeInt_size], 1
        fnret r12
.unexpected_modified_char:
        Panic 'Unexpected modifier on char type'

.int_done:
        Expect TOKEN_INT
        fnret r12
.no_int_final:
        cmp QWORD [r12+TypeInt_signed], 1
        jne .no_int_ok
        cmp r13, 0
        jne .no_int_ok
        Expect TOKEN_INT ; Will fail
        Panic 'Unreachable'
.no_int_ok:
        fnret r12

.struct_type:
        Expect TOKEN_STRUCT
        fcall Alloc, Heap, SizeOfTypeStruct
        mov r12, rax
        mov QWORD [r12+TypeStruct_variant], TYPE_STRUCT
        Expect TOKEN_IDENT
        mov [r12+TypeStruct_name], rax
        fnret r12

.void_type:
        Expect TOKEN_VOID
        fcall Alloc, Heap, SizeOfTypeVoid
        mov QWORD [rax+TypeVoid_variant], TYPE_VOID
        fnret rax

;;; Parse a statement from the input stream
ParseStmt:
        fn
        fcall PeekTok
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
        fcall ParseExpr
        fnret

.vardecl:
        ; Create the entry in the stack frame
        fcall ParseType
        mov r12, rax
        Expect TOKEN_IDENT
        fcall StackInsert, rax, r12
        mov r13, rax
        fcall PeekTok
        cmp rax, TOKEN_EQ
        jne .vardecl_done
        fcall EmitLaddr, r13
        mov r14, rax
        fcall EmitPushRax
        Expect TOKEN_EQ
        fcall ParseExpr
        fcall EmitAssign, r14, rax
.vardecl_done:
        fnret

.ifstmt:
        Expect TOKEN_IF
        ElfLitUniqueSymbol "if_then"
        mov r12, rax
        ElfLitUniqueSymbol "if_else"
        mov r13, rax
        ElfLitUniqueSymbol "if_after"
        mov r14, rax

        Expect TOKEN_LPAREN
        fcall ParseExpr         ; XXX: Make sure that this is an int
        Expect TOKEN_RPAREN
        fcall EmitJz, rax, r13  ; Jump to else if cond false
        fcall ElfSetTextSymbol, r12
        fcall ParseStmt
        fcall EmitJmp, r14      ; Body and jump to after
        fcall ElfSetTextSymbol, r13 ; Else will start here if exists
        fcall PeekTok
        cmp rax, TOKEN_ELSE
        jne .ifstmt_done
        fcall ParseStmt
.ifstmt_done:
        fcall ElfSetTextSymbol, r14 ; End of if statement
        fnret

.whilestmt:
        Expect TOKEN_WHILE
        ; Record the start of the expression
        ElfLitUniqueSymbol "while_start"
        mov r12, rax            ; The unique start symbol
        ElfLitUniqueSymbol "while_end"
        mov r13, rax            ; The unique exit symbol
        fcall ElfSetTextSymbol, r12
        Expect TOKEN_LPAREN ; Condition
        fcall ParseExpr
        fcall EmitJnz, rax, r13
        Expect TOKEN_RPAREN
        fcall ParseStmt         ; Body and exit point
        fcall EmitJmp, r12
        fcall ElfSetTextSymbol, r13 ; Set the exit point
        fnret

.compoundstmt:
        fcall ParseCompoundStmt
        fnret

.returnstmt:
        Expect TOKEN_RETURN
        fcall ParseExpr
        EmitLit
        ret
        EndEmitLit
        fnret

ParseCompoundStmt:
        fn
        Expect TOKEN_LBRACE
        ; XXX: Push a new scope
.compoundloop:
        fcall PeekTok
        cmp rax, TOKEN_RBRACE
        je .compounddone
        fcall ParseStmt
        Expect TOKEN_SEMI
        jmp .compoundloop
.compounddone:
        ; XXX: Pop a scope
        Expect TOKEN_RBRACE
        fnret

;;; name, nextlvl
%macro start_bopreclvl 2
        %push bopreclvl
        %xdefine %$lower %2
%1:
        fn
        fcall %$lower
        mov r12, rax
%$loop:
        fcall PeekTok
%endmacro
%macro binop 2
        cmp rax, %1
        je %%eq
        jmp %%after
%%eq:
        Expect %1
        fcall EmitPushRax
        fcall %$lower
        fcall %2, r12, rax
        mov r12, rax
        jmp %$loop
%%after:
%endmacro
%macro end_bopreclvl 0
        fnret r12
        %pop bopreclvl
%endmacro

ParseCommaExpr:
        fn
        fcall ParseExpr
        mov r12, rax
.loop:
        fcall PeekTok
        cmp rax, TOKEN_COMMA
        jne .done
        fcall ParseExpr
        mov r12, rax
        jmp .loop
.done:
        fnret r12

ParseExpr:
        fn
        fcall ParseAssign
        fnret rax

start_bopreclvl ParseAssign, ParseTernary
        binop TOKEN_EQ, EmitAssign
        binop TOKEN_PLUSEQ, EmitAddAssign
        binop TOKEN_DASHEQ, EmitSubAssign
        binop TOKEN_STAREQ, EmitMulAssign
        binop TOKEN_SLASHEQ, EmitDivAssign
        binop TOKEN_MODULOEQ, EmitModAssign
        binop TOKEN_LTLTEQ, EmitShlAssign
        binop TOKEN_GTGTEQ, EmitShrAssign
        binop TOKEN_ANDEQ, EmitBAndAssign
        binop TOKEN_CARETEQ, EmitBXorAssign
        binop TOKEN_BAREQ, EmitBOrAssign
end_bopreclvl

ParseTernary:
        fn
        fcall ParseOr
        mov r12, rax
        ;; XXX: Implement the ternary operator!
        fnret r12

ParseOr:
        fn
        fcall ParseAnd
        mov r12, rax
        fcall PeekTok
        cmp rax, TOKEN_BARBAR
        je .barbar
        fnret r12
.barbar:
        Panic 'Unsupported'

ParseAnd:
        fn
        fcall ParseBor
        mov r12, rax
        fcall PeekTok
        cmp rax, TOKEN_ANDAND
        je .andand
        fnret r12
.andand:
        Panic 'Unsupported'

start_bopreclvl ParseBor, ParseBxor
        binop TOKEN_BAR, EmitBOr
end_bopreclvl

start_bopreclvl ParseBxor, ParseBand
        binop TOKEN_CARET, EmitBXor
end_bopreclvl

start_bopreclvl ParseBand, ParseEquality
        binop TOKEN_AND, EmitBAnd
end_bopreclvl

start_bopreclvl ParseEquality, ParseCompare
        binop TOKEN_EQEQ, EmitEq
        binop TOKEN_NOTEQ, EmitNotEq
end_bopreclvl

start_bopreclvl ParseCompare, ParseBitShift
        binop TOKEN_LT, EmitLessThan
        binop TOKEN_GT, EmitGreaterThan
        binop TOKEN_LTEQ, EmitLessThanEq
        binop TOKEN_GTEQ, EmitGreaterThanEq
end_bopreclvl

start_bopreclvl ParseBitShift, ParseArith
        binop TOKEN_LTLT, EmitShl
        binop TOKEN_GTGT, EmitShr
end_bopreclvl

start_bopreclvl ParseArith, ParseTerm
        binop TOKEN_PLUS, EmitAdd
        binop TOKEN_DASH, EmitSub
end_bopreclvl

start_bopreclvl ParseTerm, ParsePrefix
        binop TOKEN_STAR, EmitMul
        binop TOKEN_SLASH, EmitDiv
        binop TOKEN_MODULO, EmitMod
end_bopreclvl

ParsePrefix:
        fn
        fcall PeekTok
        cmp rax, TOKEN_STAR
        je .deref
        cmp rax, TOKEN_AND
        je .addrof
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
        Expect TOKEN_STAR
        fcall ParsePrefix
        fcall EmitDeref, rax
        fnret rax

.addrof:
        Expect TOKEN_AND
        fcall ParsePrefix
        fcall EmitAddrof, rax
        fnret rax

.negate:
        Expect TOKEN_DASH
        fcall ParsePrefix
        fcall EmitNegate, rax
        fnret rax

.bnot:
        Expect TOKEN_TILDE
        fcall ParsePrefix
        fcall EmitBNot, rax
        fnret rax

.not:
        Expect TOKEN_NOT
        fcall ParsePrefix
        fcall EmitNot, rax
        fnret rax

.maybecast:
        Expect TOKEN_LPAREN
        fcall NextTokenIsType
        cmp rax, 0
        jne .cast
.paren:
        fcall ParseExpr
        mov r12, rax
        Expect TOKEN_RPAREN
        fnret r12
.cast:
        fcall ParseType
        mov r13, rax
        fcall ParsePrefix
        fcall EmitCast, rax, r13
        fcall WrapTypeRValue, r13 ; EmitCast doesn't return a value
        fnret rax

ParseTrailer:
        fn
        fcall ParseAtom
        mov r12, rax
.loop:
        fcall PeekTok
        cmp rax, TOKEN_LPAREN
        je .call
        cmp rax, TOKEN_LBRACKET
        je .index
        cmp rax, TOKEN_DOT
        je .direct
        cmp rax, TOKEN_ARROW
        je .indirect
        fnret r12

        ;; XXX: This needs to do the right thing
.call:                          ; XXX: IMPLEMENT
        Expect TOKEN_LPAREN
        Panic 'Unsupported call'
        ; r12 = target
        fcall PeekTok       ; Handle empty args lists
        cmp rax, TOKEN_RPAREN
        je .argsdone
.argsloop:
        fcall ParseExpr
        ; Argument n
        fcall PeekTok
        cmp rax, TOKEN_COMMA
        jne .argsdone
        Expect TOKEN_COMMA
        jmp .argsloop
.argsdone:
        Expect TOKEN_RPAREN
        ; Emit the actual call
        jmp .loop

.index:
        ;; The index expression a[b] ~~ *(a+b)
        Expect TOKEN_LBRACKET
        fcall ParseExpr
        fcall EmitAdd, r12, rax
        fcall EmitDeref, rax
        mov r12, rax
        Expect TOKEN_RBRACKET
        jmp .loop

.direct:
        Expect TOKEN_DOT
        jmp .member
.indirect:
        Expect TOKEN_ARROW
        fcall EmitDeref, r12
        mov r12, rax
.member:
        Panic 'Shit'
        Expect TOKEN_IDENT
        ;fcall EmitMember, r12, rax
        mov r12, rax
        jmp .loop

ParseAtom:
        fn
        fcall PeekTok
        cmp rax, TOKEN_NUMBER
        je .integer
        cmp rax, TOKEN_SIZEOF
        je .sizeof
        cmp rax, TOKEN_IDENT
        je .ref
        Panic 'Unrecognized Atom Starter'

.integer:
        Expect TOKEN_NUMBER
        fcall EmitInt, rax
        fnret rax

.sizeof:
        Expect TOKEN_SIZEOF
        Expect TOKEN_LPAREN
        fcall ParseType
        fcall SizeOfType, rax
        fcall EmitInt, rax
        mov r12, rax
        Expect TOKEN_RPAREN
        fnret r12

.ref:
        Expect TOKEN_IDENT
        fcall StackLookup, rax
        fcall EmitLaddr, rax
        fnret rax


