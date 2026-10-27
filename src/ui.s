; ---------------------------------------------------------------
; Windows, alerts, text fields, message builder
; ---------------------------------------------------------------
        .segment "CODE"

; drawwin: window at wx,wy (top border row), ww interior width, wh rows,
; title A/Y (zero-terminated) shown in an inverse title bar
drawwin:
        sta wtitle
        sty wtitle+1
        lda wx
        sta cx
        lda wy
        sta cy
        lda #0
        sta inv
        lda #'_'
        ldx ww
        jsr rep
        lda #1
        sta dw_r
@row:   lda wy
        clc
        adc dw_r
        sta cy
        ldx wx
        dex
        stx cx
        lda #G_RBAR
        jsr putch
        ldx ww
        jsr spaces
        lda #G_LBAR
        jsr putch
        inc dw_r
        lda dw_r
        cmp wh
        bcc @row
        beq @row
        ; bottom border
        lda wy
        clc
        adc wh
        adc #1
        sta cy
        lda wx
        sta cx
        lda #G_OVER
        ldx ww
        jsr rep
        ; title bar
        ldx wy
        inx
        stx cy
        lda wx
        sta cx
        lda #1
        sta inv
        ldx ww
        jsr spaces
        lda wtitle
        ldy wtitle+1
        jsr strlen
        sta t0
        lda ww
        sec
        sbc t0
        lsr a
        clc
        adc wx
        sta cx
        lda wtitle
        ldy wtitle+1
        jsr prt
        lda #0
        sta inv
        rts

; strlen: A/Y -> A = length
strlen: sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        beq @d
        iny
        bne @l
@d:     tya
        rts

; drawbtn: button label A/Y at cx (cy set); X=1 default (inverse),
; X=0 framed with MouseText bars.  Width is always len+2.
drawbtn:
        sta db_p
        sty db_p+1
        cpx #0
        beq @plain
        lda #1
        sta inv
        jsr space
        lda db_p
        ldy db_p+1
        jsr prt
        jsr space
        lda #0
        sta inv
        rts
@plain: lda #G_RBAR
        jsr putch
        lda db_p
        ldy db_p+1
        jsr prt
        lda #G_LBAR
        jmp putch

; ---------------------------------------------------------------
; alert: A/Y -> spec: .word title, .word msg, .byte n, .word b0,b1,b2
; message lines separated by '|'.  Returns A = button index.
; RETURN = first button, ESC = last, or the first letter of a button.
; ---------------------------------------------------------------
ALROW  = 14
alert:  sta ptr2
        sty ptr2+1
        ldy #0
        lda (ptr2),y
        sta al_title
        iny
        lda (ptr2),y
        sta al_title+1
        iny
        lda (ptr2),y
        sta al_msg
        iny
        lda (ptr2),y
        sta al_msg+1
        iny
        lda (ptr2),y
        sta al_n
        ldx #0
@cp:    iny
        lda (ptr2),y
        sta al_blo,x
        iny
        lda (ptr2),y
        sta al_bhi,x
        inx
        cpx al_n
        bne @cp
        jsr hidecursor
        lda #20
        sta wx
        lda #7
        sta wy
        lda #40
        sta ww
        lda #8
        sta wh
        lda al_title
        ldy al_title+1
        jsr drawwin
        ; message text
        lda al_msg
        sta ptr2
        lda al_msg+1
        sta ptr2+1
        lda #10
        sta cy
        lda #22
        sta cx
        ldy #0
@m:     lda (ptr2),y
        beq @lay0
        cmp #'|'
        bne @mc
        inc cy
        lda #22
        sta cx
        iny
        bne @m
@mc:    jsr putch
        iny
        bne @m
        ; lay buttons out right to left, ending at column 58
@lay0:  lda #59
        sta al_xe
        ldx al_n
        dex
@lay:   stx al_i
        lda al_blo,x
        ldy al_bhi,x
        jsr strlen
        clc
        adc #2
        ldx al_i
        sta al_bw,x
        lda al_xe
        sec
        sbc al_bw,x
        sta al_bx,x
        sec
        sbc #2
        sta al_xe
        dex
        bpl @lay
        lda #0                  ; the first button has the focus
        sta al_foc
@redo:  ldx #0                  ; draw buttons, the focused one inverse
@db:    stx al_i
        lda al_bx,x
        sta cx
        lda #ALROW
        sta cy
        lda al_blo,x
        ldy al_bhi,x
        pha
        lda #0
        cpx al_foc
        bne @go
        lda #1
@go:    tax
        pla
        jsr drawbtn
        ldx al_i
        inx
        cpx al_n
        bne @db
@ev:    jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        bne @k1
        lda al_foc
        jmp @ret
@k1:    cmp #$1B
        bne @kt
        ldx al_n
        dex
        txa
        jmp @ret
@kt:    ldx al_foc              ; TAB or right arrow: next button
        cmp #$09
        beq @kr
        cmp #$15
        bne @kb
@kr:    inx
        cpx al_n
        bcc @kf2
        ldx #0
        beq @kf2
@kb:    cmp #$08                ; left arrow: previous button
        bne @k2
        dex
        bpl @kf2
        ldx al_n
        dex
@kf2:   stx al_foc
        jmp @redo
@k2:    jsr toupper
        sta al_key
        ldx #0
@kl:    stx al_i
        lda al_blo,x
        sta ptr1
        lda al_bhi,x
        sta ptr1+1
        ldy #0
        lda (ptr1),y
        jsr toupper
        cmp al_key
        beq @kf
        ldx al_i
        inx
        cpx al_n
        bne @kl
        jmp @ev
@kf:    lda al_i
        jmp @ret
@mouse: lda mrow
        cmp #ALROW
        bne @ev
        ldx #0
@ml:    lda mcol
        cmp al_bx,x
        bcc @mn
        sec
        sbc al_bx,x
        cmp al_bw,x
        bcc @mf
@mn:    inx
        cpx al_n
        bne @ml
        jmp @ev
@mf:    txa
@ret:   sta al_res
        lda #2
        sta redraw
        lda al_res
        rts

; ---------------------------------------------------------------
; text field: ptr2 -> length-prefixed buffer, tf_max, tf_filt
; (0 = any, 1 = digits, 2 = money), tf_col, tf_row
; ---------------------------------------------------------------
; drawtf: A = 1 if focused (shows block cursor)
drawtf: sta tf_foc
        lda tf_col
        sta cx
        lda tf_row
        sta cy
        lda #0
        sta inv
        ldy #0
        lda (ptr2),y
        sta tf_len
        ldy #0
@c:     cpy tf_len
        beq @fill
        iny
        lda (ptr2),y
        jsr putch
        jmp @c
@fill:  cpy tf_max
        bcs @cur
        lda #'_'
        jsr putch
        iny
        bne @fill
@cur:   lda tf_foc
        beq @d
        lda tf_len
        cmp tf_max
        bcs @d
        clc
        adc tf_col
        sta cx
        lda #$20                ; inverse space = cursor block
        jsr putsc
@d:     rts

; tfkey: A = key.  Carry set if the buffer changed.
tfkey:  cmp #$08
        beq @del
        cmp #$7F
        beq @del
        cmp #$18
        beq @clr
        cmp #$20
        bcc @no
        cmp #$7F
        bcs @no
        cmp #'"'
        beq @no
        ldx tf_filt
        beq @ok
        cpx #3
        bne @num
        jsr toupper             ; filter 3: ProDOS names
        cmp #'.'
        beq @ok
        cmp #'A'
        bcc @num
        cmp #'Z'+1
        bcc @ok
        bcs @no
@num:   cmp #'0'
        bcc @f2
        cmp #'9'+1
        bcc @ok
@f2:    cpx #2
        bne @no
        cmp #'.'
        bne @no
@ok:    pha
        ldy #0
        lda (ptr2),y
        cmp tf_max
        bcs @full
        clc
        adc #1
        sta (ptr2),y
        tay
        pla
        sta (ptr2),y
        sec
        rts
@full:  pla
        clc
        rts
@del:   ldy #0
        lda (ptr2),y
        beq @no
        sec
        sbc #1
        sta (ptr2),y
        sec
        rts
@clr:   lda #0
        tay
        sta (ptr2),y
        sec
        rts
@no:    clc
        rts

; ---------------------------------------------------------------
; message builder into MSGBUF
; ---------------------------------------------------------------
mb_reset:
        lda #0
        sta mblen
        sta MSGBUF
        rts

mb_char:
        ldx mblen
        cpx #126
        bcs @d
        sta MSGBUF,x
        inx
        lda #0
        sta MSGBUF,x
        stx mblen
@d:     rts

mb_str: sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        beq @d
        jsr mb_char
        iny
        bne @l
@d:     rts

; mb_fld: append length-prefixed string at ptr1
mb_fld: ldy #0
        lda (ptr1),y
        sta t1
@l:     cpy t1
        beq @d
        iny
        lda (ptr1),y
        jsr mb_char
        jmp @l
@d:     rts

mb_hex: pha
        lsr a
        lsr a
        lsr a
        lsr a
        jsr @dig
        pla
        and #$0F
@dig:   cmp #10
        bcc @n
        adc #6
@n:     adc #'0'
        jmp mb_char

        .segment "BSS"
wx:       .res 1
wy:       .res 1
ww:       .res 1
wh:       .res 1
wtitle:   .res 2
dw_r:     .res 1
db_p:     .res 2
al_title: .res 2
al_msg:   .res 2
al_n:     .res 1
al_blo:   .res 3
al_bhi:   .res 3
al_bx:    .res 3
al_bw:    .res 3
al_xe:    .res 1
al_i:     .res 1
al_key:   .res 1
al_res:   .res 1
al_foc:   .res 1
tf_max:   .res 1
tf_filt:  .res 1
tf_col:   .res 1
tf_row:   .res 1
tf_foc:   .res 1
tf_len:   .res 1
mblen:    .res 1
MSGBUF:   .res 128
