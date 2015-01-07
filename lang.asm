%include "util.asm"
%include "io.asm"

%macro enum 1
        %assign cnt 0
        %xdefine ENAME %1
%endmacro
%macro opt 1
        %xdefine %[ENAME]_%1 cnt
        %defstr %[ENAME]_%[cnt]_NAME %1
        %assign cnt cnt+1
%endmacro
%macro endenum 0
;;; Support for debug printing
Print%[ENAME]:
        fn r12
        %rep cnt
            %push enum_item
            %assign cnt cnt-1
            cmp r12, cnt
            jne %$Next
            WriteStr STDOUT, %[ENAME]_%[cnt]_NAME, NL
            jmp %%Done
    %$Next:
            %pop
        %endrep
    %%Done:
        fnret
%endmacro

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

        section .rodata

ReadTok_Map:
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
ReadTok_Map_LEN:   equ     $ - ReadTok_Map


        section .text
ReadTok:
        fn
__ReadTok_ReadChr:
        GetChr r12, STDIN

        ;; EOF
        cmp r12, -1
        je __ReadTok_EOF
        ;; Underflow
        sub r12, 10
        jl __ReadTok_Invalid
        ;; Overflow
        cmp r12, ReadTok_Map_LEN
        jge __ReadTok_Invalid        ; If chr >= ReadTok_Map_LEN, invalid

        ;; Read the token from JUMPTABLE
        mov al, [r12 + ReadTok_Map] ; Read from JUMPTABLE

        ;; Skip IGNORE values
        cmp al, TOKEN_IGNORE
        je __ReadTok_ReadChr

        ;; Fail on INVALID values
        cmp al, TOKEN_INVALID
        je __ReadTok_Done

        ;; Detect Compound Values
        cmp al, TOKEN_IDENT
        jge __ReadTok_Compound

        jmp __ReadTok_Done

__ReadTok_Compound:
        ;; Parse compound values (like IDENT, STRING or INT)
        ;; TODO(michael): Implement
        jmp __ReadTok_Done
__ReadTok_Done:
        and rax, 0xff           ; Clear all but low 8 bits
        fnret ; rax
__ReadTok_Invalid:
        fnret TOKEN_INVALID
__ReadTok_EOF:
        fnret TOKEN_EOF


        global _start
_start:
        WriteStr STDOUT, 'Hello, world!', NL

ReadPrintTok:
        fcall ReadTok
        mov r12, rax
        fcall PrintTOKEN, r12
        cmp r12, TOKEN_INVALID
        jne ReadPrintTok

        mov rax, 60
        mov rdi, 0
        syscall
