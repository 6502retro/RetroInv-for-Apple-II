; ---------------------------------------------------------------
; 40-bit number helpers, money formatting and parsing.
; num and num2 are 5 bytes, so totals of up to 138 items at the
; largest value ($9,999,999.99) can never overflow.
; ---------------------------------------------------------------
        .segment "CODE"

zeronum:
        lda #0
; setnum8: num = A  (X and Y are kept)
setnum8:
        sta num
        lda #0
        sta num+1
        sta num+2
        sta num+3
        sta num+4
        rts

; addnum8: num += A  (X and Y are kept)
addnum8:
        clc
        adc num
        sta num
        bcc @d
        inc num+1
        bne @d
        inc num+2
        bne @d
        inc num+3
        bne @d
        inc num+4
@d:     rts

; addrec32: num += 4 bytes at (ptr1)+Y  (X is kept)
addrec32:
        clc
        lda (ptr1),y
        adc num
        sta num
        iny
        lda (ptr1),y
        adc num+1
        sta num+1
        iny
        lda (ptr1),y
        adc num+2
        sta num+2
        iny
        lda (ptr1),y
        adc num+3
        sta num+3
        bcc @d
        inc num+4
@d:     rts

; div10: num /= 10, remainder in A (uses Y)
div10:  lda #0
        ldy #40
@l:     asl num
        rol num+1
        rol num+2
        rol num+3
        rol num+4
        rol a
        cmp #10
        bcc @n
        sbc #10
        inc num
@n:     dey
        bne @l
        rts

; mul10: num *= 10 (uses num2; X and Y are kept)
mul10:  jsr @dbl                ; num*2
        lda num
        sta num2
        lda num+1
        sta num2+1
        lda num+2
        sta num2+2
        lda num+3
        sta num2+3
        lda num+4
        sta num2+4
        jsr @dbl
        jsr @dbl                ; num*8
        clc
        lda num
        adc num2
        sta num
        lda num+1
        adc num2+1
        sta num+1
        lda num+2
        adc num2+2
        sta num+2
        lda num+3
        adc num2+3
        sta num+3
        lda num+4
        adc num2+4
        sta num+4
        rts
@dbl:   asl num
        rol num+1
        rol num+2
        rol num+3
        rol num+4
        rts

; capval: if num > MAXCENTS make it MAXCENTS and set carry
capval: ldx #4
@c:     lda num,x
        cmp maxc,x
        bcc @ok
        bne @big
        dex
        bpl @c
@ok:    clc
        rts
@big:   ldx #4
@s:     lda maxc,x
        sta num,x
        dex
        bpl @s
        sec
        rts
        .segment "RODATA"
maxc:   .byte <MAXCENTS, >MAXCENTS, ^MAXCENTS, MAXCENTS >> 24, 0
        .segment "CODE"

; fmtnum: num -> numbuf as decimal, zero-terminated (destroys num)
fmtnum: ldx #0
@loop:  jsr div10
        ora #'0'
        pha
        inx
        lda num
        ora num+1
        ora num+2
        ora num+3
        ora num+4
        bne @loop
        ldy #0
@pop:   pla
        sta numbuf,y
        iny
        dex
        bne @pop
        lda #0
        sta numbuf,y
        rts

; fmtmoney: num (cents) -> moneybuf "$d.cc"; empty string when zero
fmtmoney:
        lda num
        ora num+1
        ora num+2
        ora num+3
        ora num+4
        bne @nz
        sta moneybuf
        rts
@nz:    jsr fmtmoney0
        rts

; fmtmoney0: like fmtmoney but zero gives "$0.00"
fmtmoney0:
        jsr fmtnum
        ldx #0
@len:   lda numbuf,x
        beq @pad
        inx
        bne @len
@pad:   cpx #3
        bcs @ok
        txa
        tay
@sh:    lda numbuf,y
        sta numbuf+1,y
        dey
        bpl @sh
        lda #'0'
        sta numbuf
        inx
        bne @pad
@ok:    stx t0
        lda #'$'
        sta moneybuf
        ldy #1
        ldx #0
@c1:    txa
        clc
        adc #2
        cmp t0
        bcs @dot
        lda numbuf,x
        sta moneybuf,y
        iny
        inx
        bne @c1
@dot:   lda #'.'
        sta moneybuf,y
        iny
        lda numbuf,x
        sta moneybuf,y
        iny
        lda numbuf+1,x
        sta moneybuf,y
        iny
        lda #0
        sta moneybuf,y
        rts

; parsemoney: zero-terminated string at sptr -> num (cents).
; Skips "$", "," and spaces; reads E notation the way Applesoft
; prints it ("1E-03", "1.5E+09"); rounds to the nearest cent.
; Anything else (a minus sign, letters) ends the number.
; Carry set (and num = MAXCENTS) if the value is too large.
parsemoney:
        jsr zeronum
        lda #0
        sta pm_dot
        sta pm_dec
        sta pm_sig
        sta pm_exp
        sta pm_eneg
        ldy #0
@l:     lda (sptr),y
        jeq @end
        and #$7F
        cmp #'$'
        beq @next
        cmp #','
        beq @next
        cmp #' '
        beq @next
        cmp #'.'
        bne @e
        lda pm_dot
        jne @end
        inc pm_dot
        bne @next
@e:     jsr toupper
        cmp #'E'
        beq @exp
        cmp #'0'
        bcc @end
        cmp #'9'+1
        bcs @end
        sec
        sbc #'0'
        sta pm_d
        lda pm_sig              ; keep 11 significant digits at most
        cmp #11
        bcs @skip
        lda pm_sig
        ora pm_d
        beq @lead               ; leading zeros don't count
        inc pm_sig
@lead:  sty pm_y
        jsr mul10
        lda pm_d
        jsr addnum8
        ldy pm_y
        lda pm_dot
        beq @next
        inc pm_dec
        bne @next
@skip:  lda pm_dot              ; an extra whole digit scales by ten
        bne @next
        dec pm_dec
@next:  iny
        bne @l
        beq @end
@exp:   iny                     ; E, optional sign, digits
        lda (sptr),y
        cmp #'+'
        beq @es
        cmp #'-'
        bne @ed
        inc pm_eneg
@es:    iny
@ed:    lda (sptr),y
        sec
        sbc #'0'
        cmp #10
        bcs @end
        sta pm_d
        lda pm_exp
        cmp #10
        bcs @ese
        asl a                   ; exp*10 + digit
        asl a
        adc pm_exp
        asl a
        adc pm_d
        sta pm_exp
@ese:   iny
        bne @ed
@end:   ; scale = 2 - decimals + exponent
        lda pm_exp
        ldx pm_eneg
        beq @ep
        eor #$FF
        clc
        adc #1
@ep:    clc
        adc #2
        sec
        sbc pm_dec
        sta pm_sc
        bmi @down
@up:    lda pm_sc
        beq @done
        jsr capval              ; already too big: stop (carry set)
        bcs @big
        jsr mul10
        dec pm_sc
        jmp @up
@down:  jsr div10
        inc pm_sc
        bne @down
        cmp #5                  ; round the last digit dropped
        bcc @done
        lda #1
        jsr addnum8
@done:  jmp capval
@big:   rts

; parseint: zero-terminated decimal at sptr -> num (skips spaces)
parseint:
        jsr zeronum
        ldy #0
@l:     lda (sptr),y
        and #$7F
        cmp #' '
        beq @n
        cmp #'0'
        bcc @d
        cmp #'9'+1
        bcs @d
        sec
        sbc #'0'
        sta pm_d
        lda num+3               ; already huge: stop (callers reject it)
        ora num+4
        bne @n
        sty pm_y
        jsr mul10
        lda pm_d
        jsr addnum8
        ldy pm_y
@n:     iny
        bne @l
@d:     rts

; fld2tmp: copy length-prefixed string at ptr1 to TMPSTR (zero-terminated)
fld2tmp:
        ldy #0
        lda (ptr1),y
        sta t0
        ldx #0
@l:     cpx t0
        beq @d
        inx
        txa
        tay
        lda (ptr1),y
        sta TMPSTR-1,x
        jmp @l
@d:     lda #0
        sta TMPSTR,x
        lda #<TMPSTR
        sta sptr
        lda #>TMPSTR
        sta sptr+1
        rts

; toupper
toupper:
        cmp #'a'
        bcc @d
        cmp #'z'+1
        bcs @d
        and #$DF
@d:     rts

; prnum: print num right-aligned in width X
prnum:  stx t3
        jsr fmtnum
        ldx t3
        lda #<numbuf
        ldy #>numbuf
        jmp prtr

; prmoney: print num as money right-aligned in width X ("$0.00" for zero)
prmoney:
        stx t3
        jsr fmtmoney0
        ldx t3
        lda #<moneybuf
        ldy #>moneybuf
        jmp prtr

        .segment "BSS"
numbuf:   .res 16
moneybuf: .res 20
pm_dot:   .res 1
pm_dec:   .res 1
pm_d:     .res 1
pm_y:     .res 1
pm_sig:   .res 1
pm_exp:   .res 1
pm_eneg:  .res 1
pm_sc:    .res 1
