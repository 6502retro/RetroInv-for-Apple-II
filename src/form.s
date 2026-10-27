; ---------------------------------------------------------------
; Item editor form and Find dialog
; ---------------------------------------------------------------
NFIELDS = 11
FBTNROW = 18
RIGHTCOL = 38

        .segment "RODATA"
; field kinds: 0 text, 1 digits, 2 money, 3 type, 4 condition,
; 5 part of (a computer), 6 slot.  Kinds 3-6 are choices made with arrows.
ftype:  .byte 0, 0, 0, 1, 3, 4, 5, 6, 0, 2, 0
foff:   .byte F_NAME, F_MAKER, F_SERIAL, F_YEAR, F_TYPE, F_COND
        .byte F_PARENT, F_SLOT, F_LOC, 0, F_NOTES
fmax:   .byte 30, 20, 20, 4, 0, 0, 0, 0, 20, 10, 60
frow:   .byte 5, 6, 7, 8, 10, 11, 10, 11, 13, 14, 16
fcol:   .byte 16, 16, 16, 16, 16, 16, 48, 48, 16, 17, 16
flcol:  .byte 4, 4, 4, 4, 4, 4, RIGHTCOL, RIGHTCOL, 4, 4, 4
fsw:    .byte 0, 0, 0, 0, 13, 13, 22, 13, 0, 0, 0
fl9:    .byte "Part of", 0
fl10:   .byte "Slot", 0
s_itemno: .byte "Item No. ", 0
fl0:    .byte "Name", 0
fl1:    .byte "Maker", 0
fl2:    .byte "Year", 0
fl3:    .byte "Type", 0
fl4:    .byte "Condition", 0
fl5:    .byte "Location", 0
fl6:    .byte "Value", 0
fl7:    .byte "Notes", 0
fl8:    .byte "Serial #", 0
fllo:   .byte <fl0, <fl1, <fl8, <fl2, <fl3, <fl4, <fl9, <fl10, <fl5, <fl6, <fl7
flhi:   .byte >fl0, >fl1, >fl8, >fl2, >fl3, >fl4, >fl9, >fl10, >fl5, >fl6, >fl7
s_fhint: .byte "TAB or ", G_UP, G_DOWN, " next field   ", G_LEFT, G_RIGHT
         .byte " change   CTRL-X clear   ESC cancel", 0
s_ok:    .byte "OK", 0
s_noname: .byte "Please give the item a name.", 0
al_noname: .word t_alert, s_noname
           .byte 1
           .word b_ok
s_badyear: .byte "Please type the year with four|"
           .byte "digits, like 1984, or leave it|"
           .byte "blank.", 0
al_badyear: .word t_alert, s_badyear
           .byte 1
           .word b_ok
s_bigval:  .byte "The largest value RetroInv can|"
           .byte "keep is $9,999,999.99.", 0
al_bigval: .word t_alert, s_bigval
           .byte 1
           .word b_ok

        .segment "CODE"

clearedit:
        ldx #RECSIZE
        lda #0
@l:     sta EDITREC-1,x
        dex
        bne @l
        lda #2
        sta EDITREC+F_COND
        lda #0
        sta VALSTR
        rts

; rec2edit: copy (rp) to EDITREC and value to VALSTR
rec2edit:
        ldy #RECSIZE-1
@l:     lda (rp),y
        sta EDITREC,y
        dey
        cpy #$FF
        bne @l
        lda EDITREC+F_VAL
        sta num
        lda EDITREC+F_VAL+1
        sta num+1
        lda EDITREC+F_VAL+2
        sta num+2
        lda EDITREC+F_VAL+3
        sta num+3
        lda #0
        sta num+4
        jsr fmtmoney
        ldx #0
        lda moneybuf
        beq @vs
@v:     lda moneybuf+1,x
        beq @vs
        cpx #10
        bcs @vs
        sta VALSTR+1,x
        inx
        bne @v
@vs:    stx VALSTR
        rts

; edit2rec: copy EDITREC to (rp)
edit2rec:
        ldy #RECSIZE-1
@l:     lda EDITREC,y
        sta (rp),y
        dey
        cpy #$FF
        bne @l
        rts

; setuptf: X = field -> text field registers
setuptf:
        lda ftype,x
        cmp #2
        beq @m
        clc
        lda #<EDITREC
        adc foff,x
        sta ptr2
        lda #>EDITREC
        adc #0
        sta ptr2+1
        jmp @c
@m:     lda #<VALSTR
        sta ptr2
        lda #>VALSTR
        sta ptr2+1
@c:     lda fmax,x
        sta tf_max
        lda fcol,x
        sta tf_col
        lda frow,x
        sta tf_row
        lda ftype,x
        sta tf_filt
        rts

; drawfld: X = field
drawfld:
        stx df_f
        lda frow,x
        sta cy
        lda flcol,x
        sta cx
        lda #0
        cpx ffoc
        bne @n
        lda #1
@n:     sta inv
        sta df_foc
        lda fllo,x
        ldy flhi,x
        ldx #10
        jsr prtw
        lda #0
        sta inv
        ldx df_f
        lda ftype,x
        cmp #3
        bcs @sel
        cmp #2
        bne @t
        lda #16
        sta cx
        lda #'$'
        jsr putch
@t:     ldx df_f
        jsr setuptf
        lda df_foc
        jmp drawtf
@sel:   lda fcol,x
        sta cx
        lda #G_LEFT
        jsr putch
        jsr space
        lda df_foc
        sta inv
        ldx df_f
        ldy foff,x
        lda EDITREC,y
        pha
        lda ftype,x
        cmp #3
        bne @cond
        pla
        jsr typename
        jmp @pn
@cond:  cmp #4
        bne @slot
        pla
        jsr condname
        jmp @pn
@slot:  cmp #6
        bne @part
        pla
        jsr slotname
        jmp @pn
@part:  pla                     ; part of: the computer's name
        lda EDITREC+F_PARENT
        sta fi_id
        lda EDITREC+F_PARENT+1
        sta fi_id+1
        jsr finditem
        bcs @pnone
        clc
        lda fptr
        adc #F_NAME
        sta ptr1
        lda fptr+1
        adc #0
        sta ptr1+1
        ldx df_f
        lda fsw,x
        tax
        jsr prtfld
        jmp @pe
@pnone: lda #<s_none
        ldy #>s_none
@pn:    pha
        ldx df_f
        lda fsw,x
        tax
        pla
        jsr prtw
@pe:
        lda #0
        sta inv
        jsr space
        lda #G_RIGHT
        jmp putch

drawform:
        lda #2
        sta wx
        sta wy
        lda #76
        sta ww
        lda #17
        sta wh
        lda ftitle
        ldy ftitle+1
        jsr drawwin
        ldx #0
@f:     stx df_i
        jsr drawfld
        ldx df_i
        inx
        cpx #NFIELDS
        bne @f
        POS 60, 5
        PRT s_itemno
        lda EDITREC+F_ITEMNO
        sta num
        lda EDITREC+F_ITEMNO+1
        sta num+1
        lda #0
        sta num+2
        sta num+3
        sta num+4
        ldx #0
        jsr prnum
        POS 4, 17
        PRT s_fhint
        POS 60, FBTNROW
        lda #<s_ok
        ldy #>s_ok
        ldx #1
        jsr drawbtn
        POS 66, FBTNROW
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jmp drawbtn

; edititem: A/Y = title.  Edits EDITREC/VALSTR.  Carry clear = OK.
edititem:
        sta ftitle
        sty ftitle+1
        lda #0
        sta ffoc
@full:  jsr hidecursor
        jsr drawform
@loop:  jsr getevent
        cmp #EV_KEY
        beq @key
        jmp @mouse
@key:   lda keych
        cmp #$0D
        bne @k1
        jmp @ok
@k1:    cmp #$1B
        bne @k2
        sec
        rts
@k2:    cmp #$09
        jeq @next
        cmp #$0A
        jeq @next
        cmp #$0B
        jeq @prev
        ldx ffoc
        ldy ftype,x
        cpy #3
        bcs @selkey
        jsr setuptf
        lda keych
        jsr tfkey
        bcc @loop
        ldx ffoc
        jsr drawfld
        jmp @loop
@selkey:
        cmp #$08
        beq @sprev
        cmp #$15
        beq @snext
        cmp #' '
        beq @snext
        jmp @loop
@snext: lda #1
        bne @step
@sprev: lda #$FF
@step:  sta ef_dir
        ldx ffoc
        lda ftype,x
        cmp #5
        bne @nump
        lda ef_dir              ; part of: next / previous computer
        jsr pcstep
        jmp @sdraw
@nump:  ldy foff,x
        cmp #3
        bne @plain
        lda EDITREC,y           ; type: step in display order
        cmp #NTYPES
        bcc @tr
        lda #5
@tr:    tax
        lda trank,x
        clc
        adc ef_dir
        and #NTYPES-1
        tax
        lda tord,x
        sta EDITREC+F_TYPE
        cmp #T_COMPUTER         ; a computer isn't part of anything
        bne @sdraw
        lda #0
        sta EDITREC+F_PARENT
        sta EDITREC+F_PARENT+1
        ldx #6
        jsr drawfld
        jmp @sdraw
@plain: ldx #6                  ; condition 0-5, slot 0-9
        cmp #4
        beq @mx
        ldx #NSLOTS
@mx:    stx ef_max
        lda EDITREC,y
        clc
        adc ef_dir
        bmi @wrapl
        cmp ef_max
        bcc @sst
        lda #0
        beq @sst
@wrapl: ldx ef_max
        dex
        txa
@sst:   sta EDITREC,y
@sdraw: ldx ffoc
        jsr drawfld
        jmp @loop
@next:  ldx ffoc
        inx
        cpx #NFIELDS
        bcc @setf
        ldx #0
        beq @setf
@prev:  ldx ffoc
        dex
        bpl @setf
        ldx #NFIELDS-1
@setf:  lda ffoc
        stx ffoc
        tax
        jsr drawfld
        ldx ffoc
        jsr drawfld
        jmp @loop
@mouse: lda mrow
        cmp #FBTNROW
        bne @fhit
        lda mcol
        cmp #60
        bcc @lp
        cmp #64
        bcc @ok
        cmp #66
        bcc @lp
        cmp #74
        bcs @lp
        sec
        rts
@lp:    jmp @loop
@fhit:  lda #0                  ; which side was clicked?
        ldx mcol
        cpx #RIGHTCOL-1
        bcc @sd
        lda #RIGHTCOL
@sd:    sta ef_side
        ldx #0
@fh:    lda frow,x
        cmp mrow
        bne @fn
        lda flcol,x
        cmp #RIGHTCOL
        beq @fr
        lda #0
@fr:    cmp ef_side
        beq @fgot
@fn:    inx
        cpx #NFIELDS
        bne @fh
        jmp @loop
@fgot:  stx ef_hit
        lda ffoc
        stx ffoc
        tax
        jsr drawfld
        ldx ffoc
        jsr drawfld
        ldx ef_hit
        lda ftype,x
        cmp #3
        bcc @lp
        lda mcol                ; left arrow area steps back,
        sec                     ; the rest of the choice steps on
        sbc fcol,x
        bcc @lp
        sta ef_side
        lda fsw,x
        clc
        adc #4
        cmp ef_side
        bcc @lp
        beq @lp
        lda ef_side
        cmp #2
        bcs @mnext
        jmp @sprev
@mnext: jmp @snext
@ok:    lda EDITREC+F_NAME
        bne @y
        lda #<al_noname
        ldy #>al_noname
        ldx #0
        jmp @bad
@y:     ldx EDITREC+F_YEAR      ; year: blank, or four digits 1000-2999
        beq @v
        cpx #4
        bne @by
        lda EDITREC+F_YEAR+1
        cmp #'1'
        bcc @by
        cmp #'2'+1
        bcs @by
@yd:    lda EDITREC+F_YEAR,x
        cmp #'0'
        bcc @by
        cmp #'9'+1
        bcs @by
        dex
        bne @yd
        beq @v
@by:    lda #<al_badyear
        ldy #>al_badyear
        ldx #3
@bad:   stx ffoc
        jsr alert
        jmp @full
@v:     ; value text -> cents
        ldx VALSTR
        lda #0
        sta TMPSTR,x
@vc:    cpx #0
        beq @vp
        lda VALSTR,x
        sta TMPSTR-1,x
        dex
        jmp @vc
@vp:    lda #<TMPSTR
        sta sptr
        lda #>TMPSTR
        sta sptr+1
        jsr parsemoney
        bcc @vok
        lda #<al_bigval
        ldy #>al_bigval
        ldx #9
        jmp @bad
@vok:   lda num
        sta EDITREC+F_VAL
        lda num+1
        sta EDITREC+F_VAL+1
        lda num+2
        sta EDITREC+F_VAL+2
        lda num+3
        sta EDITREC+F_VAL+3
        clc
        rts

; ---------------------------------------------------------------
; Find
; ---------------------------------------------------------------
        .segment "RODATA"
t_find:   .byte "Find", 0
s_findl:  .byte "Find:", 0
s_findh:  .byte "Name, maker, serial, location, notes", 0
b_find:   .byte "Find", 0
s_nomatch: .byte "No item matches that text.", 0
al_nomatch: .word t_find, s_nomatch
            .byte 1
            .word b_ok
        .segment "CODE"

cmd_find:
@full:  jsr hidecursor
        lda #20
        sta wx
        lda #8
        sta wy
        lda #40
        sta ww
        lda #7
        sta wh
        lda #<t_find
        ldy #>t_find
        jsr drawwin
        POS 22, 11
        PRT s_findl
        POS 21, 13
        PRT s_findh
        POS 44, 15
        lda #<b_find
        ldy #>b_find
        ldx #1
        jsr drawbtn
        POS 51, 15
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jsr drawbtn
@fld:   jsr @setf
        lda #1
        jsr drawtf
@loop:  jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        beq @go
        cmp #$1B
        beq @x
        pha
        jsr @setf
        pla
        jsr tfkey
        bcc @loop
        jmp @fld
@mouse: lda mrow
        cmp #15
        bne @loop
        lda mcol
        cmp #44
        bcc @loop
        cmp #50
        bcc @go
        cmp #51
        bcc @loop
        cmp #59
        bcs @loop
@x:     lda #2
        sta redraw
        rts
@go:    lda #2
        sta redraw
        lda FINDSTR
        beq @x
        jmp dosearch
@setf:  lda #<FINDSTR
        sta ptr2
        lda #>FINDSTR
        sta ptr2+1
        lda #20
        sta tf_max
        lda #0
        sta tf_filt
        lda #28
        sta tf_col
        lda #11
        sta tf_row
        rts

cmd_findnext:
        lda FINDSTR
        bne dosearch
        jmp cmd_find

; dosearch: from sel+1, wrapping, for FINDSTR in name/maker/location/notes
dosearch:
        lda #2
        sta redraw
        lda count
        beq @nf
        sta fs_n
        lda sel
        sta fs_i
@l:     inc fs_i
        lda fs_i
        cmp count
        bcc @c
        lda #0
        sta fs_i
@c:     lda fs_i
        jsr recaddr
        ldx #0
@f:     stx fs_f
        lda fs_offs,x
        jsr fldptr
        jsr instr
        bcs @found
        ldx fs_f
        inx
        cpx #5
        bne @f
        dec fs_n
        bne @l
@nf:    lda #<al_nomatch
        ldy #>al_nomatch
        jmp alert
@found: lda fs_i
        sta sel
        rts

        .segment "RODATA"
fs_offs: .byte F_NAME, F_MAKER, F_SERIAL, F_LOC, F_NOTES
        .segment "CODE"

; instr: is FINDSTR inside the length-prefixed string at ptr1?
; (case-insensitive)  carry set = found
instr:  ldy #0
        lda (ptr1),y
        sta is_hl
        lda FINDSTR
        sta is_nl
        beq @no
        lda is_hl
        sec
        sbc is_nl
        bcc @no
        sta is_last
        lda #0
        sta is_st
@outer: ldx #0
@inner: txa
        clc
        adc is_st
        tay
        iny
        lda (ptr1),y
        jsr toupper
        sta is_c
        lda FINDSTR+1,x
        jsr toupper
        cmp is_c
        bne @nx
        inx
        cpx is_nl
        bne @inner
        sec
        rts
@nx:    lda is_st
        cmp is_last
        beq @no
        inc is_st
        jmp @outer
@no:    clc
        rts

        .segment "BSS"
EDITREC:  .res RECSIZE
VALSTR:   .res 12
ftitle:   .res 2
ffoc:     .res 1
df_f:     .res 1
df_foc:   .res 1
df_i:     .res 1
ef_hit:   .res 1
ef_dir:   .res 1
ef_max:   .res 1
ef_side:  .res 1
fs_n:     .res 1
fs_i:     .res 1
fs_f:     .res 1
is_hl:    .res 1
is_nl:    .res 1
is_last:  .res 1
is_st:    .res 1
is_c:     .res 1
