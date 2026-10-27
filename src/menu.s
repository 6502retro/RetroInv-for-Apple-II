; ---------------------------------------------------------------
; Menu bar and pull-down menus (mouse drag, click, or keyboard)
; ---------------------------------------------------------------
NMENUS = 5

        .segment "RODATA"
mtx:    .byte 1, 4, 10, 16, 22          ; title text column
mtw:    .byte 1, 4, 4, 4, 4             ; title width
mbx:    .byte 1, 3, 9, 15, 21           ; pull-down interior column
mbw:    .byte 21, 29, 18, 13, 16        ; pull-down interior width
mcnt:   .byte 1, 8, 5, 6, 1             ; items
mstart: .byte 0, 1, 9, 14, 20           ; first command of each menu

mt0:    .byte G_CA, 0
mt1:    .byte "File", 0
mt2:    .byte "Item", 0
mt3:    .byte "Sort", 0
mt4:    .byte "View", 0
mtlo:   .byte <mt0, <mt1, <mt2, <mt3, <mt4
mthi:   .byte >mt0, >mt1, >mt2, >mt3, >mt4

mi0:    .byte "About RetroInv", G_DOTS, 0
mi1:    .byte "New Inventory", 0
mi2:    .byte "Open", G_DOTS, 0
mi3:    .byte "Save", 0
mi4:    .byte "Save As", G_DOTS, 0
mi5:    .byte "Revert to Saved", 0
mi6:    .byte "Import from Mouse Calc", G_DOTS, 0
mi7:    .byte "Export to Mouse Calc", G_DOTS, 0
mi8:    .byte "Quit", 0
mi9:    .byte "New Item", G_DOTS, 0
mi10:   .byte "Edit Item", G_DOTS, 0
mi11:   .byte "Delete Item", 0
mi12:   .byte "Find", G_DOTS, 0
mi13:   .byte "Find Next", 0
mi14:   .byte "By Name", 0
mi15:   .byte "By Maker", 0
mi16:   .byte "By Year", 0
mi17:   .byte "By Type", 0
mi18:   .byte "By Value", 0
mi19:   .byte "By System", 0
mi20:   .byte "Report", G_DOTS, 0
milo:   .byte <mi0,<mi1,<mi2,<mi3,<mi4,<mi5,<mi6,<mi7,<mi8,<mi9
        .byte <mi10,<mi11,<mi12,<mi13,<mi14,<mi15,<mi16,<mi17,<mi18,<mi19,<mi20
mihi:   .byte >mi0,>mi1,>mi2,>mi3,>mi4,>mi5,>mi6,>mi7,>mi8,>mi9
        .byte >mi10,>mi11,>mi12,>mi13,>mi14,>mi15,>mi16,>mi17,>mi18,>mi19,>mi20
mikey:  .byte 0,0,'O','S',0,0,'I','X','Q','N','E','D','F','G',0,0,0,0,0,0,'R'

apptitle: .byte "RetroInv  by 6502Retro", 0

        .segment "CODE"

drawmenubar:
        lda #0
        sta cy
        jsr clrrow
        ldx #0
@t:     stx dm_i
        lda mtx,x
        sta cx
        dec cx
        lda #0
        cpx mopen
        bne @n
        lda #1
@n:     sta inv
        jsr space
        ldx dm_i
        lda mtlo,x
        ldy mthi,x
        jsr prt
        jsr space
        lda #0
        sta inv
        ldx dm_i
        inx
        cpx #NMENUS
        bne @t
        jsr drawinvname
        POS 57, 0
        PRT apptitle
        POS 0, 1
        lda #G_OVER
        ldx #80
        jmp rep

; drawpull: pull-down for mopen with item mhil highlighted
drawpull:
        ldx mopen
        lda mbx,x
        sta dp_x
        lda mbw,x
        sta dp_w
        lda mcnt,x
        sta dp_n
        lda mstart,x
        sta dp_first
        lda #0
        sta dp_r
@r:     lda dp_r
        clc
        adc #2
        sta cy
        ldx dp_x
        dex
        stx cx
        lda #0
        sta inv
        lda #G_RBAR
        jsr putch
        lda dp_r
        cmp mhil
        bne @n
        lda #1
        sta inv
@n:     ldx dp_w
        jsr spaces
        lda dp_x
        sta cx
        inc cx
        lda dp_r
        clc
        adc dp_first
        tax
        stx dp_c
        lda milo,x
        ldy mihi,x
        jsr prt
        ldx dp_c
        lda mikey,x
        beq @nk
        pha
        lda dp_x
        clc
        adc dp_w
        sec
        sbc #3
        sta cx
        lda #G_OA
        jsr putch
        pla
        jsr putch
@nk:    lda #0
        sta inv
        lda dp_x
        clc
        adc dp_w
        sta cx
        lda #G_LBAR
        jsr putch
        inc dp_r
        lda dp_r
        cmp dp_n
        bne @r
        lda dp_n
        clc
        adc #2
        sta cy
        lda dp_x
        sta cx
        lda #G_OVER
        ldx dp_w
        jmp rep

; menuhit: A = column on row 0 -> A = menu index or $FF
menuhit:
        sta t0
        ldx #0
@l:     lda mtx,x
        sec
        sbc #1
        cmp t0
        beq @y
        bcs @n
        lda mtx,x
        clc
        adc mtw,x
        cmp t0
        bcs @y
@n:     inx
        cpx #NMENUS
        bne @l
        lda #$FF
        rts
@y:     txa
        rts

; itemhit: mouse position -> A = item in mopen or $FF
itemhit:
        ldx mopen
        lda mrow
        sec
        sbc #2
        bcc @no
        cmp mcnt,x
        bcs @no
        sta t0
        lda mcol
        cmp mbx,x
        bcc @no
        sec
        sbc mbx,x
        cmp mbw,x
        bcs @no
        lda t0
        rts
@no:    lda #$FF
        rts

; menuloop: A = menu to open, X = 0 mouse (button held) / 1 keyboard
; returns A = command or $FF
menuloop:
        sta mopen
        lda #$FF
        sta mhil
        cpx #0
        beq @m
        lda #0
        sta mhil
@m:     stx msticky
@full:  jsr hidecursor
        jsr drawall
        jsr drawpull
@loop:  jsr showcursor
        lda KBD
        bpl @mouse
        jmp @key
@mouse: lda hasmouse
        beq @loop
        jsr pollmouse
        lda mrow
        bne @items
        lda mcol
        jsr menuhit
        cmp #$FF
        beq @trans
        cmp mopen
        beq @trans
        ldx mbtn
        bmi @switch
        ldx msticky
        beq @trans
@switch:
        sta mopen
        lda #$FF
        sta mhil
        jmp @full
@items: jsr itemhit
        cmp mhil
        beq @trans
        ldx mmoved
        bne @seth
        ldx mbtn
        bpl @trans
@seth:  sta mhil
        jsr hidecursor
        jsr drawpull
@trans: lda mrel
        beq @press
        lda mrow
        bne @relit
        lda #1
        sta msticky
        jmp @loop
@relit: jsr itemhit
        cmp #$FF
        jne @select
        lda msticky
        bne @loop2
        jmp @close
@loop2: jmp @loop
@press: lda mpress
        beq @loop2
        lda mrow
        beq @loop2
        jsr itemhit
        cmp #$FF
        bne @loop2
        jmp @close
@key:   sta KBDSTRB
        and #$7F
        cmp #$1B
        jeq @close
        cmp #$08
        beq @left
        cmp #$15
        beq @right
        cmp #$0B
        beq @up
        cmp #$0A
        beq @down
        cmp #$0D
        bne @loop2
        lda mhil
        cmp #$FF
        beq @loop2
        jmp @select
@left:  ldx mopen
        dex
        bpl @setm
        ldx #NMENUS-1
@setm:  stx mopen
        lda #0
        sta mhil
        lda #1
        sta msticky
        jmp @full
@right: ldx mopen
        inx
        cpx #NMENUS
        bcc @setm
        ldx #0
        beq @setm
@up:    ldx mhil
        dex
        bpl @seth2
        ldy mopen
        ldx mcnt,y
        dex
@seth2: stx mhil
        jsr hidecursor
        jsr drawpull
        jmp @loop
@down:  ldx mhil
        inx
        ldy mopen
        txa
        cmp mcnt,y
        bcc @dn2
        ldx #0
@dn2:   stx mhil
        jsr hidecursor
        jsr drawpull
        jmp @loop
@select:
        clc
        ldx mopen
        adc mstart,x
        sta mcmd
        jmp @exit
@close: lda #$FF
        sta mcmd
@exit:  jsr hidecursor
        lda #$FF
        sta mopen
        lda mcmd
        rts

        .segment "BSS"
mopen:    .res 1
mhil:     .res 1
msticky:  .res 1
mcmd:     .res 1
dm_i:     .res 1
dp_x:     .res 1
dp_w:     .res 1
dp_n:     .res 1
dp_r:     .res 1
dp_c:     .res 1
dp_first: .res 1
