;;; -*- nasm -*-

        section .text
enum TOKEN
        ;; Dumb Tokens (no data)
        opt LBRACE
        opt RBRACE
        opt LPAREN
        opt RPAREN
        opt LBRACKET
        opt RBRACKET

        ;; Symbols
        opt NOT
        opt HASH
        opt MODULO
        opt AND
        opt STAR
        opt PLUS
        opt DASH
        opt DOT
        opt COMMA
        opt SLASH
        opt COLON
        opt SEMI
        opt LT
        opt EQ
        opt GT
        opt QMARK
        opt AT
        opt CARET
        opt BAR
        opt TILDE

        opt ARROW               ; ->
        opt ANDAND
        opt BARBAR
        opt LTEQ
        opt GTEQ
        opt EQEQ
        opt LTLT
        opt GTGT
        opt NOTEQ

        opt PLUSEQ
        opt DASHEQ
        opt STAREQ
        opt SLASHEQ
        opt MODULOEQ
        opt LTLTEQ
        opt GTGTEQ
        opt ANDEQ
        opt CARETEQ
        opt BAREQ

        ;; Keywords
        opt IF
        opt ELSE
        opt WHILE
        opt STRUCT
        opt UNSIGNED
        opt SHORT
        opt LONG
        opt INT
        opt CHAR
        opt VOID
        opt RETURN
        opt SIZEOF
        opt SYSCALL

        ;; Special, Tokens (have data)
        opt IDENT
        opt STRING
        opt NUMBER              ; XXX: Only integer

        ;; Special Cases
        opt EOF
        opt IGNORE
        opt INVALID

        ;; The number of items in the TOKEN enum
        opt COUNT
endenum

struct Token
        field variant
        field data
endstruct

;;; ***************
;;; Peek/Eat Chars

        section .data
chr_cache: dq -2
chr_infile: dq STDIN
chr_line: dq 1
chr_col: dq 0
tok_line: dq 1
tok_col: dq 0

        section .text
PeekChr:
        fn
        cmp QWORD [chr_cache], -2
        je .cachemiss
.cachehit:
        fnret [chr_cache]
.cachemiss:
        fcall GetChr, [chr_infile]
        mov [chr_cache], rax
        fnret rax


EatChr:
        fn
        fcall PeekChr
        inc QWORD [chr_col]
        cmp rax, NL
        jne .no_newline
.newline:
        inc QWORD [chr_line]
        mov QWORD [chr_col], 0
.no_newline:
        mov r12, rax
        cmp QWORD [chr_cache], -1
        je .done
        fcall GetChr, [chr_infile]
        mov [chr_cache], rax
.done:
        fnret r12

;;; **************
;;; Read in Tokens

        section .rodata
ReadTok_Map:
        times 10 dq __ReadTok_INVALID ;'\0'-'\t'
        dq __ReadTok_IGNORE           ;LF
        times 2 dq __ReadTok_INVALID  ;VT-FF
        dq __ReadTok_IGNORE           ;CR
        times 18 dq __ReadTok_INVALID ;SO-US
        dq __ReadTok_IGNORE           ;' '
        dq __ReadTok_NOT              ;'!'
        dq __ReadTok_STRING           ;'"'
        dq __ReadTok_HASH             ;'#'
        dq __ReadTok_INVALID          ;'$'
        dq __ReadTok_MODULO           ;'%'
        dq __ReadTok_AND              ;'&'
        dq __ReadTok_INVALID          ;'''  ; XXX: Char?
        dq __ReadTok_LPAREN           ;'('
        dq __ReadTok_RPAREN           ;')'
        dq __ReadTok_STAR             ;'*'
        dq __ReadTok_PLUS             ;'+'
        dq __ReadTok_COMMA            ;','
        dq __ReadTok_DASH             ;'-'
        dq __ReadTok_DOT              ;'.'
        dq __ReadTok_SLASH            ;'/'
        times 10 dq __ReadTok_NUMBER  ;'0'-'9'
        dq __ReadTok_COLON            ;':'
        dq __ReadTok_SEMI             ;';'
        dq __ReadTok_LT               ;'<'
        dq __ReadTok_EQ               ;'='
        dq __ReadTok_GT               ;'>'
        dq __ReadTok_QMARK            ;'?'
        dq __ReadTok_AT               ;'@'
        times 26 dq __ReadTok_IDENT   ;'A'-'Z'
        dq __ReadTok_LBRACKET         ;'['
        dq __ReadTok_INVALID          ;'\'
        dq __ReadTok_RBRACKET         ;']'
        dq __ReadTok_CARET            ;'^'
        dq __ReadTok_IDENT            ;'_'
        dq __ReadTok_INVALID          ;'`'
        times 26 dq __ReadTok_IDENT   ;'a'-'z'
        dq __ReadTok_LBRACE           ;'{'
        dq __ReadTok_BAR              ;'|'
        dq __ReadTok_RBRACE           ;'}'
        dq __ReadTok_TILDE            ;'~'
ReadTok_Map_LEN:   equ     $ - ReadTok_Map


        section .text

%macro rettok 1-2 0
        mov QWORD [r12+Token_variant], %1
        mov QWORD [r12+Token_data], %2
        fnret
%endmacro

ReadTok:
        fn r12                  ; r12 = OUT token
__ReadTok_IGNORE: ; Jump back to here when should ignore
        mov rax, [chr_line]
        mov [tok_line], rax
        mov rax, [chr_col]
        mov [tok_col], rax
        fcall EatChr

        ;; Handle EOF seperately
        cmp rax, -1
        je __ReadTok_EOF

        ;; Bounds Check
        cmp rax, ReadTok_Map_LEN ; XXX: Make sure that this is an unsigned comparison
        jge __ReadTok_INVALID ; If chr >= ReadTok_Map_LEN, invalid

        jmp [rax*8 + ReadTok_Map] ; Jump!

__ReadTok_LBRACE:
        rettok TOKEN_LBRACE
__ReadTok_RBRACE:
        rettok TOKEN_RBRACE
__ReadTok_LPAREN:
        rettok TOKEN_LPAREN
__ReadTok_RPAREN:
        rettok TOKEN_RPAREN
__ReadTok_LBRACKET:
        rettok TOKEN_LBRACKET
__ReadTok_RBRACKET:
        rettok TOKEN_RBRACKET

        ;; Symbols
__ReadTok_NOT:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_NOTEQ
        rettok TOKEN_NOT
__ReadTok_NOTEQ:
        rettok TOKEN_NOTEQ
__ReadTok_HASH:
        rettok TOKEN_HASH
__ReadTok_MODULO:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_MODULOEQ
        rettok TOKEN_MODULO
__ReadTok_MODULOEQ:
        fcall EatChr
        rettok TOKEN_MODULOEQ
__ReadTok_AND:
        fcall PeekChr
        cmp rax, '&'
        je __ReadTok_ANDAND
        cmp rax, '='
        je __ReadTok_ANDEQ
        rettok TOKEN_AND
__ReadTok_ANDAND:
        fcall EatChr
        rettok TOKEN_ANDAND
__ReadTok_ANDEQ:
        fcall EatChr
        rettok TOKEN_ANDEQ
__ReadTok_STAR:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_STAREQ
        rettok TOKEN_STAR
__ReadTok_STAREQ:
        fcall EatChr
        rettok TOKEN_STAREQ
__ReadTok_PLUS:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_PLUSEQ
        rettok TOKEN_PLUS
__ReadTok_PLUSEQ:
        fcall PeekChr
        rettok TOKEN_PLUSEQ
__ReadTok_DASH:
        fcall PeekChr
        cmp rax, '>'
        je __ReadTok_ARROW
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_DASHEQ
        rettok TOKEN_DASH
__ReadTok_ARROW:
        fcall EatChr
        rettok TOKEN_ARROW
__ReadTok_DASHEQ:
        fcall EatChr
        rettok TOKEN_DASHEQ
__ReadTok_DOT:
        rettok TOKEN_DOT
__ReadTok_COMMA:
        rettok TOKEN_COMMA
__ReadTok_SLASH:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_SLASHEQ
        rettok TOKEN_SLASH
__ReadTok_SLASHEQ:
        fcall EatChr
        rettok TOKEN_SLASHEQ
__ReadTok_COLON:
        rettok TOKEN_COLON
__ReadTok_SEMI:
        rettok TOKEN_SEMI
__ReadTok_LT:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_LTEQ
        cmp rax, '<'
        je __ReadTok_LTLT
        rettok TOKEN_LT
__ReadTok_LTEQ:
        fcall EatChr
        rettok TOKEN_LTEQ
__ReadTok_LTLT:
        fcall EatChr
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_LTLTEQ
        rettok TOKEN_LTLT
__ReadTok_LTLTEQ:
        fcall EatChr
        rettok TOKEN_LTLTEQ
__ReadTok_EQ:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_EQEQ
        rettok TOKEN_EQ
__ReadTok_EQEQ:
        fcall EatChr
        rettok TOKEN_EQEQ
__ReadTok_GT:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_GTEQ
        cmp rax, '>'
        je __ReadTok_GTGT
        rettok TOKEN_GT
__ReadTok_GTEQ:
        fcall EatChr
        rettok TOKEN_GTEQ
__ReadTok_GTGT:
        fcall EatChr
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_GTGTEQ
        rettok TOKEN_GTGT
__ReadTok_GTGTEQ:
        fcall EatChr
        rettok TOKEN_GTGTEQ
__ReadTok_QMARK:
        rettok TOKEN_QMARK
__ReadTok_AT:
        rettok TOKEN_AT
__ReadTok_CARET:
        fcall PeekChr
        cmp rax, '='
        je __ReadTok_CARETEQ
        rettok TOKEN_CARET
__ReadTok_CARETEQ:
        fcall EatChr
        rettok TOKEN_CARETEQ
__ReadTok_BAR:
        fcall PeekChr
        cmp rax, '|'
        je __ReadTok_BARBAR
        cmp rax, '='
        je __ReadTok_BAREQ
        rettok TOKEN_BAR
__ReadTok_BARBAR:
        fcall EatChr
        rettok TOKEN_BARBAR
__ReadTok_BAREQ:
        fcall EatChr
        rettok TOKEN_BAREQ
__ReadTok_TILDE:
        rettok TOKEN_TILDE

        ;; Special, Tokens (have data)
__ReadTok_IDENT:
        ;; Create an array, and push rax onto it
        push rax
        fcall NewArr, Heap, 8
        mov r13, rax
        pop rax
        DoArr PushChr, r13, rax

__ReadTok_IDENT_Loop:
        fcall PeekChr
        cmp rax, '0'
        jl __ReadTok_IDENT_Done
        cmp rax, '9'
        jle __ReadTok_IDENT_Read

        cmp rax, 'A'
        jl __ReadTok_IDENT_Done
        cmp rax, 'Z'
        jle __ReadTok_IDENT_Read

        cmp rax, 'a'
        jl __ReadTok_IDENT_Done
        cmp rax, 'z'
        jle __ReadTok_IDENT_Read
        jmp __ReadTok_IDENT_Done

__ReadTok_IDENT_Read:
        DoArr PushChr, r13, rax
        fcall EatChr
        jmp __ReadTok_IDENT_Loop

__ReadTok_IDENT_Done:
        DoArr PushChr, r13, 0
        DoArr Seal, r13

        ;; Check for matches with keywords
%macro kwtok 2
        section .data
%%str: db %1, 0
%%strlen: equ $ - %%str
        section .text
        fcall StrCmp, r13, %%str
        cmp rax, 0
        je %%match
        jmp %%after
%%match:
        ;; Free the just-allocated string
        fcall Free, Heap, r13, %%strlen
        rettok %2
%%after:
%endmacro
        kwtok 'if', TOKEN_IF
        kwtok 'else', TOKEN_ELSE
        kwtok 'while', TOKEN_WHILE
        kwtok 'struct', TOKEN_STRUCT
        kwtok 'unsigned', TOKEN_UNSIGNED
        kwtok 'short', TOKEN_SHORT
        kwtok 'long', TOKEN_LONG
        kwtok 'int', TOKEN_INT
        kwtok 'char', TOKEN_CHAR
        kwtok 'void', TOKEN_VOID
        kwtok 'return', TOKEN_RETURN
        kwtok 'sizeof', TOKEN_SIZEOF
        kwtok 'syscall', TOKEN_SYSCALL ; XXX: Cheaty cheaty
%undef kwtok
        rettok TOKEN_IDENT, r13

__ReadTok_STRING:
        mov r13, rax            ; Store string delimiter
        fcall NewArr, Heap, 8
        mov r14, rax
__ReadTok_STRING_Loop:
        fcall EatChr
        cmp rax, -1             ; EOF
        je __ReadTok_STRING_Fail
        cmp al, r13b            ; " or ' (delimiter)
        je __ReadTok_STRING_End
        cmp al, 92              ; \ ('\' messes up syntax highlighting)
        je __ReadTok_STRING_ReadEscChr

        DoArr PushChr, r14, rax
        jmp __ReadTok_STRING_Loop
__ReadTok_STRING_ReadEscChr:
        ;; A \ was read, read in chr after it
        fcall EatChr
        cmp rax, -1             ; EOF
        je __ReadTok_STRING_Fail

        DoArr PushChr, r14, rax
        jmp __ReadTok_STRING_Loop
__ReadTok_STRING_End:
        DoArr PushChr, r14, 0
        DoArr Seal, r14
        rettok TOKEN_STRING, r14
__ReadTok_STRING_Fail:
        Panic 'Unexpected EOF while parsing String'

__ReadTok_NUMBER:
        mov r15, rax ; r15 = accumulator
        sub r15, '0'
__ReadTok_NUMBER_Loop:
        fcall PeekChr
        cmp rax, '0'
        jl __ReadTok_NUMBER_Done
        cmp rax, '9'
        jg __ReadTok_NUMBER_Done

        fcall EatChr
        ;; Get numeric value of digit
        mov r13, rax
        sub r13, '0'

        ;; Multiply accumulator by 10
        mov rax, r15
        mov rdx, 10             ; mul accum by 10
        imul rdx                 ; multiply accumulator by 10
        cmp rdx, 0
        jne __ReadTok_NUMBER_Overflow

        ;; Save new sum
        add rax, r13
        jo __ReadTok_NUMBER_Overflow
        mov r15, rax
        jmp __ReadTok_NUMBER_Loop
__ReadTok_NUMBER_Done:
        ; fcall WriteHex, r15
        rettok TOKEN_NUMBER, r15
__ReadTok_NUMBER_Overflow:
        Panic 'Number overflowed while reading'

        ;; Special Cases
__ReadTok_EOF:
        rettok TOKEN_EOF
__ReadTok_INVALID:
        Panic 'Invalid Token!'

%undef rettok

;;; ***************
;;; Peek/Eat Tokens

        section .data
tok_cache:
.type: dq TOKEN_INVALID
.data: dq 0

        section .text
PeekTok:
        fn
        cmp QWORD [tok_cache + Token_variant], TOKEN_INVALID
        jne .CacheHit
.CacheMiss:
        fcall ReadTok, tok_cache
.CacheHit:
        fnret [tok_cache.type], [tok_cache.data]

EatTok:
        fn
        fcall PeekTok
        mov r12, rax
        mov r13, rbx
        fcall ReadTok, tok_cache
        fnret r12, r13
