%include "util.asm"
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
        db TOKEN_IGNORE           ;LF
        times 2 db TOKEN_INVALID  ;VT-FF
        db TOKEN_IGNORE           ;CR
        times 18 db TOKEN_INVALID ;SO-US
        db TOKEN_IGNORE           ;' '
        db TOKEN_NOT              ;'!'
        db TOKEN_STRING           ;'"'
        db TOKEN_HASH             ;'#'
        db TOKEN_INVALID          ;'$'
        db TOKEN_MODULO           ;'%'
        db TOKEN_AND              ;'&'
        db TOKEN_STRING           ;'''
        db TOKEN_LPAREN           ;'('
        db TOKEN_RPAREN           ;')'
        db TOKEN_STAR             ;'*'
        db TOKEN_PLUS             ;'+'
        db TOKEN_COMMA            ;','
        db TOKEN_DASH             ;'-'
        db TOKEN_DOT              ;'.'
        db TOKEN_SLASH            ;'/'
        times 10 db TOKEN_NUMBER  ;'0'-'9'
        db TOKEN_COLON            ;':'
        db TOKEN_SEMI             ;';'
        db TOKEN_LT               ;'<'
        db TOKEN_EQ               ;'='
        db TOKEN_GT               ;'>'
        db TOKEN_QMARK            ;'?'
        db TOKEN_AT               ;'@'
        times 26 db TOKEN_IDENT   ;'A'-'Z'
        db TOKEN_LBRACKET         ;'['
        db TOKEN_INVALID          ;'\'
        db TOKEN_RBRACKET         ;']'
        db TOKEN_CARET            ;'^'
        db TOKEN_IDENT            ;'_'
        db TOKEN_INVALID          ;'`'
        times 26 db TOKEN_IDENT   ;'a'-'z'
        db TOKEN_LBRACE           ;'{'
        db TOKEN_BAR              ;'|'
        db TOKEN_RBRACE           ;'}'
        db TOKEN_TILDE            ;'~'
readtok_JUMPTABLELEN:   equ     $ - readtok_JUMPTABLE


        section .text
ReadTok:
        fn
        GetChr r12, STDIN
        fcall Write64, r12
        sub r12, 10             ; table starts at index 10
        jl ReadTok_FAIL
        cmp r12, readtok_JUMPTABLELEN
        jge ReadTok_FAIL
        mov rax, 0              ; Clear the high bits, and set low bits
        mov al, [r12 + readtok_JUMPTABLE]
        fnret
ReadTok_FAIL:
        mov rax, 0              ; Clear the high bits, and set low bits
        mov al, TOKEN_INVALID
        fnret


        global _start
_start:
        WriteStr STDOUT, 'Hello, world!', NL
        WriteStr STDOUT, 'LBRACE: '
        fcall Write64, TOKEN_LBRACE
        WriteStr STDOUT, 'INVALID: '
        fcall Write64, TOKEN_INVALID
        WriteStr STDOUT, 'STRING: '
        fcall Write64, TOKEN_STRING

ReadPrintTok:
        fcall ReadTok
        fcall Write64, rax
        jmp ReadPrintTok

        mov rax, 60
        mov rdi, 0
        syscall
