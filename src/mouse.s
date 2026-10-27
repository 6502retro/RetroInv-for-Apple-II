; ---------------------------------------------------------------
; Mouse support via AppleMouse / IIc / IIgs mouse firmware (passive)
; ---------------------------------------------------------------
        .segment "CODE"

; findmouse: scan slots 7..1 for the mouse firmware signature
findmouse:
        lda #0
        sta hasmouse
        sta mrom
        ldx #7
@s:     txa
        ora #$C0
        sta mrom+1
        ldy #$0C
        lda (mrom),y
        cmp #$20
        bne @n
        ldy #$FB
        lda (mrom),y
        cmp #$D6
        bne @n
        stx mslotn
        lda mrom+1
        sta mslot
        sta $07F8
        txa
        asl a
        asl a
        asl a
        asl a
        sta mslot16
        lda #1
        sta hasmouse
        rts
@n:     dex
        bne @s
        rts

; mousecall: Y = firmware entry offset, A = argument
mousecall:
        sta mc_a
        lda (mrom),y
        sta mjmp
        lda mslot
        sta mjmp+1
        lda mc_a
        ldx mslot
        ldy mslot16
        php
        sei
        jsr @go
        plp
        rts
@go:    jmp (mjmp)

initmouse:
        jsr findmouse
        lda hasmouse
        bne @have
        rts
@have:  lda #0
        ldy #INITMOUSE
        jsr mousecall
        lda #$01
        ldy #SETMOUSE
        jsr mousecall
        ; clamp X to 0..319 (4 counts per column)
        lda #0
        sta $0478
        sta $0578
        lda #<319
        sta $04F8
        lda #>319
        sta $05F8
        lda #0
        ldy #CLAMPMOUSE
        jsr mousecall
        ; clamp Y to 0..191 (8 counts per row)
        lda #0
        sta $0478
        sta $0578
        sta $05F8
        lda #191
        sta $04F8
        lda #1
        ldy #CLAMPMOUSE
        jsr mousecall
        ; centre the pointer
        ldx mslotn
        lda #<160
        sta $0478,x
        lda #>160
        sta $0578,x
        lda #96
        sta $04F8,x
        lda #0
        sta $05F8,x
        ldy #POSMOUSE
        jsr mousecall
        lda #0
        sta mlast
        sta curon
        lda #40
        sta mcol
        lda #12
        sta mrow
        rts

; pollmouse: read position/button, update pointer, set mpress/mrel/mmoved
pollmouse:
        lda #0
        sta mpress
        sta mrel
        sta mmoved
        lda hasmouse
        bne @rd
        rts
@rd:    ldy #READMOUSE
        jsr mousecall
        ldx mslotn
        lda $0578,x
        sta t1
        lda $0478,x
        lsr t1
        ror a
        lsr t1
        ror a
        cmp #80
        bcc @x1
        lda #79
@x1:    cmp mcol
        beq @y
        sta mcol
        inc mmoved
@y:     lda $04F8,x
        lsr a
        lsr a
        lsr a
        cmp #24
        bcc @y1
        lda #23
@y1:    cmp mrow
        beq @b
        sta mrow
        inc mmoved
@b:     lda $0778,x
        and #$80
        sta mbtn
        cmp mlast
        beq @c
        sta mlast
        cmp #$80
        beq @p
        inc mrel
        bne @c
@p:     inc mpress
@c:     lda mmoved
        beq @d
        lda curon
        beq @d
        jsr hidecursor
        jsr showcursor
@d:     rts

; showcursor / hidecursor: draw the MouseText pointer over the screen
showcursor:
        lda hasmouse
        beq @d
        lda curon
        bne @d
        lda cx
        pha
        lda cy
        pha
        lda mcol
        sta cx
        sta curx
        lda mrow
        sta cy
        sta cury
        jsr getsc
        sta curunder
        lda #$42
        jsr putsc
        lda #1
        sta curon
        pla
        sta cy
        pla
        sta cx
@d:     rts

hidecursor:
        lda curon
        beq @d
        lda cx
        pha
        lda cy
        pha
        lda curx
        sta cx
        lda cury
        sta cy
        lda curunder
        jsr putsc
        lda #0
        sta curon
        pla
        sta cy
        pla
        sta cx
@d:     rts

; getevent: wait for a key or a mouse press.
; returns A = EV_KEY (keych, keyoa) or EV_MOUSE (mcol, mrow)
getevent:
@l:     jsr showcursor
        lda KBD
        bmi @key
        jsr pollmouse
        lda mpress
        beq @l
        jsr hidecursor
        lda #EV_MOUSE
        rts
@key:   sta KBDSTRB
        and #$7F
        sta keych
        lda BUTN0
        ora BUTN1
        and #$80
        sta keyoa
        jsr hidecursor
        lda #EV_KEY
        rts

        .segment "BSS"
hasmouse: .res 1
mslot:    .res 1
mslotn:   .res 1
mslot16:  .res 1
mc_a:     .res 1
mcol:     .res 1
mrow:     .res 1
mbtn:     .res 1
mlast:    .res 1
mpress:   .res 1
mrel:     .res 1
mmoved:   .res 1
curon:    .res 1
curx:     .res 1
cury:     .res 1
curunder: .res 1
keych:    .res 1
keyoa:    .res 1
