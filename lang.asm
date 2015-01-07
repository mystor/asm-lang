%include "io.asm"

%macro enum 2
    %1_%2:      equ     $ - %1
        db ' '
%endmacro

        section .data
TOKEN:
        ;; Dumb Tokens (no data)
        enum TOKEN, LBRACE
        enum TOKEN, RBRACE
        enum TOKEN, LPAREN
        enum TOKEN, RPAREN
        enum TOKEN, LBRACKET
        enum TOKEN, RBRACKET

        ;; Symbols
        enum TOKEN, NOT
        enum TOKEN, HASH
        enum TOKEN, MODULO
        enum TOKEN, AND
        enum TOKEN, STAR
        enum TOKEN, PLUS
        enum TOKEN, DASH
        enum TOKEN, DOT
        enum TOKEN, COMMA
        enum TOKEN, SLASH
        enum TOKEN, COLON
        enum TOKEN, SEMI
        enum TOKEN, LT
        enum TOKEN, EQ
        enum TOKEN, GT
        enum TOKEN, QMARK
        enum TOKEN, AT
        enum TOKEN, CARET
        enum TOKEN, BAR
        enum TOKEN, TILDE

        ;; Special, Tokens (have data)
        enum TOKEN, IDENT
        enum TOKEN, STRING
        enum TOKEN, NUMBER

        ;; The number of items in the TOKEN enum
        enum TOKEN, COUNT
        enum TOKEN, IGNORE
        enum TOKEN, INVALID

readtok_JUMPTABLE:
        dd TOKEN_IGNORE           ;LF
        times 2 dd TOKEN_INVALID  ;VT-FF
        dd TOKEN_IGNORE           ;CR
        times 18 dd TOKEN_INVALID ;SO-US
        dd TOKEN_IGNORE           ;' '
        dd TOKEN_NOT              ;'!'
        dd TOKEN_STRING           ;'"'
        dd TOKEN_HASH             ;'#'
        dd TOKEN_INVALID          ;'$'
        dd TOKEN_MODULO           ;'%'
        dd TOKEN_AND              ;'&'
        dd TOKEN_COMMA            ;','
        dd TOKEN_LPAREN           ;'('
        dd TOKEN_RPAREN           ;')'
        dd TOKEN_STAR             ;'*'
        dd TOKEN_PLUS             ;'+'
        dd TOKEN_INVALID          ;'`'
        dd TOKEN_DASH             ;'-'
        dd TOKEN_DOT              ;'.'
        dd TOKEN_SLASH            ;'/'
        times 10 dd TOKEN_NUMBER  ;'0'-'9'
        dd TOKEN_COLON            ;':'
        dd TOKEN_SEMI             ;';'
        dd TOKEN_LT               ;'<'
        dd TOKEN_EQ               ;'='
        dd TOKEN_GT               ;'>'
        dd TOKEN_QMARK            ;'?'
        dd TOKEN_AT               ;'@'
        times 26 dd TOKEN_IDENT   ;'A'-'Z'
        dd TOKEN_LBRACKET         ;'['
        dd TOKEN_RBRACKET         ;']'
        dd TOKEN_CARET            ;'^'
        dd TOKEN_IDENT            ;'_'
        dd TOKEN_STRING           ;'''
        times 26 dd TOKEN_IDENT   ;'a'-'z'
        dd TOKEN_LBRACE           ;'{'
        dd TOKEN_BAR              ;'|'
        dd TOKEN_RBRACE           ;'}'
        dd TOKEN_TILDE            ;'~'
readtok_JUMPTABLELEN:   equ     $ - readtok_JUMPTABLE


        section .text
ReadTok:
        GetChr rax, STDIN
        mov r12, rax
        call Write64
        mov rax, r12
        sub rax, 10             ; table starts at index 10
        jle ReadTok_FAIL
        cmp rax, readtok_JUMPTABLELEN
        jge ReadTok_FAIL
        mov rax, [rax + readtok_JUMPTABLE]
        ret
ReadTok_FAIL:
        mov rax, TOKEN_INVALID
        ret

        global _start
_start:
        WriteStr STDOUT, 'Hello, world!', NL
        mov rax, readtok_JUMPTABLELEN
        call Write64
ReadPrintTok:
        call ReadTok
        call Write64
        jmp ReadPrintTok

        mov rax, 60
        mov rdi, 0
        syscall
