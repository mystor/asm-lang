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

        ;; Special, Tokens (have data)
        opt IDENT
        opt STRING
        opt NUMBER

        ;; Special Cases
        opt EOF
        opt IGNORE
        opt INVALID

        ;; The number of items in the TOKEN enum
        opt COUNT
endenum


;;; ***************
;;; Peek/Eat Chars

        section .data
chr_cache:      dq      -2

        section .text
PeekChr:
        fn
        cmp QWORD [chr_cache], -2
        je __PeekChr_CacheMiss
__PeekChr_CacheHit:
        fnret [chr_cache]
__PeekChr_CacheMiss:
        GetChr r12, STDIN
        mov [chr_cache], r12
        fnret r12


EatChr:
        fn
        fcall PeekChr
        mov r12, rax
        cmp QWORD [chr_cache], -1
        je __EatChr_Done
        GetChr r13, STDIN
        mov [chr_cache], r13
__EatChr_Done:
        fnret r12

;;; **************
;;; Read in Tokens

        section .rodata
ReadTok_Map:
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
        dq __ReadTok_STRING           ;'''
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
ReadTok:
        fn
__ReadTok_IGNORE:               ; Jump back to here when should ignore
        fcall EatChr
        mov r12, rax

        ;; EOF
        cmp r12, -1
        je __ReadTok_EOF
        ;; Underflow
        sub r12, 10
        jl __ReadTok_INVALID
        ;; Overflow
        cmp r12, ReadTok_Map_LEN
        jge __ReadTok_INVALID        ; If chr >= ReadTok_Map_LEN, invalid

        jmp [r12*8 + ReadTok_Map]     ; Jump!
        ;; Dumb Tokens (no data)
__ReadTok_LBRACE:
        fnret TOKEN_LBRACE
__ReadTok_RBRACE:
        fnret TOKEN_RBRACE
__ReadTok_LPAREN:
        fnret TOKEN_LPAREN
__ReadTok_RPAREN:
        fnret TOKEN_RPAREN
__ReadTok_LBRACKET:
        fnret TOKEN_LBRACKET
__ReadTok_RBRACKET:
        fnret TOKEN_RBRACKET

        ;; Symbols
__ReadTok_NOT:
        fnret TOKEN_NOT
__ReadTok_HASH:
        fnret TOKEN_HASH
__ReadTok_MODULO:
        fnret TOKEN_MODULO
__ReadTok_AND:
        fnret TOKEN_AND
__ReadTok_STAR:
        fnret TOKEN_STAR
__ReadTok_PLUS:
        fnret TOKEN_PLUS
__ReadTok_DASH:
        fnret TOKEN_DASH
__ReadTok_DOT:
        fnret TOKEN_DOT
__ReadTok_COMMA:
        fnret TOKEN_COMMA
__ReadTok_SLASH:
        fnret TOKEN_SLASH
__ReadTok_COLON:
        fnret TOKEN_COLON
__ReadTok_SEMI:
        fnret TOKEN_SEMI
__ReadTok_LT:
        fnret TOKEN_LT
__ReadTok_EQ:
        fnret TOKEN_EQ
__ReadTok_GT:
        fnret TOKEN_GT
__ReadTok_QMARK:
        fnret TOKEN_QMARK
__ReadTok_AT:
        fnret TOKEN_AT
__ReadTok_CARET:
        fnret TOKEN_CARET
__ReadTok_BAR:
        fnret TOKEN_BAR
__ReadTok_TILDE:
        fnret TOKEN_TILDE

        ;; Special, Tokens (have data)
__ReadTok_IDENT:
        fnret TOKEN_IDENT
__ReadTok_STRING:
        mov r13, rsp            ; End of String
__ReadTok_STRING_ReadChr:
        fcall EatChr
        cmp rax, -1             ; EOF
        je __ReadTok_STRING_Fail
        cmp al, 34             ; "
        je __ReadTok_STRING_End
        cmp al, 92              ; \
        je __ReadTok_STRING_ReadEscChr

        ;; Add the character to the string
        sub rsp, 1
        mov BYTE [rsp], al
        jmp __ReadTok_STRING_ReadChr

        ;; A \ was read, read in chr after it
__ReadTok_STRING_ReadEscChr:
        fcall EatChr
        cmp rax, -1             ; EOF
        je __ReadTok_STRING_Fail
        sub rsp, 1
        mov BYTE [rsp], al
        jmp __ReadTok_STRING_ReadChr

__ReadTok_STRING_Fail:
        Panic 100, 'Unexpected EOF while parsing String', NL

__ReadTok_STRING_End:
        ;; TODO(michael): Reverse the string
        sub r13, rsp
        fcall Intern, rsp, r13  ; Intern the string
        mov r14, rax
        fcall Write64, r14
        fcall Write64, [r14-8]
        WriteStr STDOUT, 'This Far!', NL

        ;; Free the stack space
        add rsp, r13

        fnret TOKEN_STRING
__ReadTok_NUMBER:
        fnret TOKEN_NUMBER

        ;; Special Cases
__ReadTok_EOF:
        fnret TOKEN_EOF
__ReadTok_INVALID:
        Panic 100, 'Invalid Token!', NL

;;; ***************
;;; Peek/Eat Tokens

        section .data
tok_cache:      dq      TOKEN_INVALID
tok_data:       dq      0

        section .text
PeekTok:
        fn
        cmp QWORD [tok_cache], TOKEN_INVALID
        je __PeekTok_CacheMiss
__PeekTok_CacheHit:
        mov rdx, [tok_data]
        fnret [tok_cache]
__PeekTok_CacheMiss:
        fcall ReadTok
        mov [tok_cache], rax
        mov [tok_data], rdx
        fnret rax

EatTok:
        fn
        fcall PeekTok
        mov r12, rax
        fcall ReadTok
        mov [tok_cache], rax
        mov [tok_data], rdx
        fnret r12
