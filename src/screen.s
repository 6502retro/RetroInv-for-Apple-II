; ---------------------------------------------------------------
; 80-column text output with MouseText (direct to screen memory)
; Even columns live in aux memory (80STORE + PAGE2), odd in main.
; ---------------------------------------------------------------

        .segment "RODATA"
rowlo:
.repeat 24, I
        .byte <($400 + (I .mod 8) * $80 + (I / 8) * $28)
.endrepeat
rowhi:
.repeat 24, I
        .byte >($400 + (I .mod 8) * $80 + (I / 8) * $28)
.endrepeat

; glyph code -> MouseText screen code
glyphs: .byte $A0, $41, $40, $4D, $4B, $4A, $48, $55
        .byte $44, $49, $42, $4E, $4C, $5A, $5F, $56
        .byte $5B, $52, $51, $A0, $A0, $A0, $A0, $A0
        .byte $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0

        .segment "CODE"

; putsc: store screen code A at (cx,cy), advance cx. Clips to 80x24.
putsc:  ldy cx
        cpy #80
        bcs @skip
        ldy cy
        cpy #24
        bcs @skip
        pha
        lda rowlo,y
        sta ptr3
        lda rowhi,y
        sta ptr3+1
        lda cx
        lsr a
        tay
        pla
        bcs @main
        php
        sei
        sta HISCR
        sta (ptr3),y
        sta LOWSCR
        plp
        inc cx
        rts
@main:  sta (ptr3),y
@skip:  inc cx
        rts

; getsc: read screen code at (cx,cy) into A
getsc:  ldy cy
        lda rowlo,y
        sta ptr3
        lda rowhi,y
        sta ptr3+1
        lda cx
        lsr a
        tay
        bcs @main
        php
        sei
        sta HISCR
        lda (ptr3),y
        sta LOWSCR
        plp
        rts
@main:  lda (ptr3),y
        rts

; putch: ASCII char (or glyph code < $20) honouring inv; preserves A,X,Y
putch:  sta pc_a
        stx pc_x
        sty pc_y
        cmp #$20
        bcs @asc
        tax
        lda glyphs,x
        jmp @put
@asc:   and #$7F
        ldx inv
        bne @inv
        ora #$80
        bne @put
@inv:   cmp #$40
        bcc @put
        cmp #$60
        bcs @put
        and #$1F
@put:   jsr putsc
        lda pc_a
        ldx pc_x
        ldy pc_y
        rts

space:  lda #' '
        jmp putch

; spaces: X spaces.  rep: char A, X times
spaces: lda #' '
rep:    cpx #0
        beq @d
@l:     jsr putch
        dex
        bne @l
@d:     rts

; prt: zero-terminated string at A/Y
prt:    sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        beq @d
        jsr putch
        iny
        bne @l
@d:     rts

; prti: print the zero-terminated string that follows the JSR
prti:   pla
        sta sptr
        pla
        sta sptr+1
        ldy #0
@l:     inc sptr
        bne @n
        inc sptr+1
@n:     lda (sptr),y
        beq @d
        jsr putch
        jmp @l
@d:     lda sptr+1
        pha
        lda sptr
        pha
        rts

; prtw: string A/Y padded/truncated to width X
prtw:   sta sptr
        sty sptr+1
        stx t0
        ldy #0
@l:     cpy t0
        beq @d
        lda (sptr),y
        beq @pad
        jsr putch
        iny
        bne @l
@pad:   lda #' '
@p2:    jsr putch
        iny
        cpy t0
        bne @p2
@d:     rts

; prtr: string A/Y right-aligned in width X
prtr:   sta sptr
        sty sptr+1
        stx t0
        ldy #0
@len:   lda (sptr),y
        beq @g
        iny
        bne @len
@g:     sty t1
        lda t0
        sec
        sbc t1
        bcc @np
        beq @np
        tax
        jsr spaces
@np:    lda sptr
        ldy sptr+1
        jmp prt

; prtfld: length-prefixed string at ptr1 in width X (pad with spaces)
prtfld: stx t0
        ldy #0
        lda (ptr1),y
        cmp t0
        bcc @ok
        lda t0
@ok:    sta t1
        ldy #0
@l:     cpy t1
        beq @pad
        iny
        lda (ptr1),y
        jsr putch
        jmp @l
@pad:   lda t0
        sec
        sbc t1
        tax
        jmp spaces

; prtlen: length-prefixed string at ptr1 (no padding)
prtlen: ldy #0
        lda (ptr1),y
        sta t1
@l:     cpy t1
        beq @d
        iny
        lda (ptr1),y
        jsr putch
        jmp @l
@d:     rts

; clrscr: fill the whole 80x24 screen with spaces
clrscr: ldx #23
@r:     lda rowlo,x
        sta ptr3
        lda rowhi,x
        sta ptr3+1
        lda #$A0
        ldy #39
@m:     sta (ptr3),y
        dey
        bpl @m
        php
        sei
        sta HISCR
        ldy #39
@a:     sta (ptr3),y
        dey
        bpl @a
        sta LOWSCR
        plp
        dex
        bpl @r
        rts

; clrrow: blank row cy
clrrow: lda #0
        sta cx
        sta inv
        ldx #80
        jmp spaces

        .segment "BSS"
pc_a:   .res 1
pc_x:   .res 1
pc_y:   .res 1
