; ---------------------------------------------------------------
; Sorting and the collection report
; ---------------------------------------------------------------
        .segment "CODE"

cmd_sortname:
        lda #0
        beq dosortk
cmd_sortmaker:
        lda #1
        bne dosortk
cmd_sortyear:
        lda #2
        bne dosortk
cmd_sorttype:
        lda #3
        bne dosortk
cmd_sortvalue:
        lda #4
dosortk:
        sta skey
        lda #2
        sta redraw
        lda count
        cmp #2
        bcc @d
        lda #<s_sorting
        ldy #>s_sorting
        jsr statusmsg
        jsr dosort
        lda #0
        sta sel
        sta top
        lda #1
        sta dirty
@d:     rts

; Shell sort of the record pointer table (gaps n/2, n/4 ... 1)
dosort: lda count
        lsr a
        sta so_g
@g:     lda so_g
        beq @d
        sta so_i
@i:     lda so_i
        cmp count
        bcs @ng
        sta so_j
@j:     lda so_j
        cmp so_g
        bcc @ni
        jsr recaddr             ; rp = item j
        lda rp
        sta rp2
        lda rp+1
        sta rp2+1
        lda so_j
        sec
        sbc so_g
        sta so_k
        jsr recaddr             ; rp = item j-gap, rp2 = item j
        jsr before              ; carry set: item j belongs before j-gap
        bcc @ni
        ldx so_j
        ldy so_k
        lda PTRLO,x
        pha
        lda PTRLO,y
        sta PTRLO,x
        pla
        sta PTRLO,y
        lda PTRHI,x
        pha
        lda PTRHI,y
        sta PTRHI,x
        pla
        sta PTRHI,y
        lda so_k
        sta so_j
        jmp @j
@ni:    inc so_i
        bne @i
@ng:    lsr so_g
        jmp @g
@d:     rts

; before: carry set if record rp2 sorts before record rp (by skey)
before: lda skey
        cmp #3
        beq @type
        cmp #4
        beq @value
        tax
        lda skoff,x
        pha
        clc
        adc rp2
        sta ptr1
        lda rp2+1
        adc #0
        sta ptr1+1
        pla
        clc
        adc rp
        sta ptr2
        lda rp+1
        adc #0
        sta ptr2+1
        jmp strless
@type:  ldy #F_TYPE             ; in display order: Computer, Card, ...
        lda (rp),y
        jsr rankof
        sta so_r
        lda (rp2),y
        jsr rankof
        cmp so_r
        bcc @yes
        clc
        rts
@yes:   sec
        rts
@value: ; most valuable first: rp2 before rp if value(rp2) > value(rp)
        ldy #F_VAL
        sec
        lda (rp),y
        sbc (rp2),y
        iny
        lda (rp),y
        sbc (rp2),y
        iny
        lda (rp),y
        sbc (rp2),y
        iny
        lda (rp),y
        sbc (rp2),y
        bcc @yes
        clc
        rts

        .segment "RODATA"
skoff:  .byte F_NAME, F_MAKER, F_YEAR
s_sorting: .byte "Sorting", G_DOTS, 0
        .segment "CODE"

; yearnum: num = the year of record rp if it is exactly four digits
; (1000-2999), otherwise 0
yearnum:
        jsr zeronum
        lda #F_YEAR
        jsr fldptr
        ldy #0
        lda (ptr1),y
        cmp #4
        bne @d
        iny
        lda (ptr1),y
        cmp #'1'
        bcc @d
        cmp #'2'+1
        bcs @d
@c:     lda (ptr1),y
        cmp #'0'
        bcc @d
        cmp #'9'+1
        bcs @d
        iny
        cpy #5
        bne @c
        jsr fld2tmp
        jmp parseint
@d:     rts

; strless: carry set if string ptr1 < string ptr2 (case-insensitive)
strless:
        ldy #0
        lda (ptr1),y
        sta sl_a
        lda (ptr2),y
        sta sl_b
        ldx #0
@l:     cpx sl_a
        beq @end1
        cpx sl_b
        beq @ge
        txa
        tay
        iny
        lda (ptr2),y
        jsr toupper
        sta sl_c
        lda (ptr1),y
        jsr toupper
        cmp sl_c
        bcc @lt
        bne @ge
        inx
        bne @l
@end1:  cpx sl_b
        beq @ge
@lt:    sec
        rts
@ge:    clc
        rts

; ---------------------------------------------------------------
; Report
; ---------------------------------------------------------------
        .segment "RODATA"
t_report: .byte "Collection Report", 0
s_rhead:  .byte "Type", 0
s_ritems: .byte "Items", 0
s_rvalue: .byte "Value", 0
s_rtotal: .byte "Total", 0
s_roldest: .byte "Oldest item:", 0
s_rtop:   .byte "Most valuable:", 0
s_rnone:  .byte "-", 0
s_rsys:   .byte "In systems:", 0
s_rsys2:  .byte " items belong to ", 0
s_rsys3:  .byte " computers", 0
        .segment "CODE"

cmd_report:
        ; tally
        ldx #NTYPES*5+NTYPES-1
        lda #0
        sta rp_ins
@z:     sta rp_cnt,x
        dex
        bpl @z
        lda #$FF
        sta rp_old
        sta rp_top
        sta rp_oy
        sta rp_oy+1
        lda #0
        sta rp_tv
        sta rp_tv+1
        sta rp_tv+2
        sta rp_tv+3
        sta rp_i
@t:     lda rp_i
        cmp count
        bcc @t1
        jmp @draw
@t1:    jsr recaddr
        jsr getpar              ; items that belong to a computer
        lda fi_a
        ora fi_a+1
        beq @t0
        inc rp_ins
@t0:    ldy #F_TYPE
        lda (rp),y
        cmp #NTYPES
        bcc @t2
        lda #5
@t2:    tax
        inc rp_cnt,x
        sta t0                  ; 5-byte total per type
        asl a
        asl a
        adc t0
        tax
        ldy #F_VAL
        clc
        lda (rp),y
        adc rp_val,x
        sta rp_val,x
        iny
        lda (rp),y
        adc rp_val+1,x
        sta rp_val+1,x
        iny
        lda (rp),y
        adc rp_val+2,x
        sta rp_val+2,x
        iny
        lda (rp),y
        adc rp_val+3,x
        sta rp_val+3,x
        bcc @t3
        inc rp_val+4,x
@t3:
        ; most valuable: value > rp_tv ?
        ldy #F_VAL
        sec
        lda rp_tv
        sbc (rp),y
        iny
        lda rp_tv+1
        sbc (rp),y
        iny
        lda rp_tv+2
        sbc (rp),y
        iny
        lda rp_tv+3
        sbc (rp),y
        bcs @nott
        ldy #F_VAL
        ldx #0
@ct:    lda (rp),y
        sta rp_tv,x
        iny
        inx
        cpx #4
        bne @ct
        lda rp_i
        sta rp_top
@nott:  ; oldest: a four-digit year, smaller than rp_oy
        jsr yearnum
        lda num
        ora num+1
        beq @noy
        lda num
        cmp rp_oy
        lda num+1
        sbc rp_oy+1
        bcs @noy
        lda num
        sta rp_oy
        lda num+1
        sta rp_oy+1
        lda rp_i
        sta rp_old
@noy:   inc rp_i
        jmp @t

@draw:  jsr hidecursor
        lda #12
        sta wx
        lda #2
        sta wy
        lda #56
        sta ww
        lda #19
        sta wh
        lda #<t_report
        ldy #>t_report
        jsr drawwin
        POS 15, 5
        PRT s_rhead
        POS 36, 5
        PRT s_ritems
        POS 59, 5
        PRT s_rvalue
        lda #0
        sta rp_i
@row:   lda rp_i
        clc
        adc #6
        sta cy
        lda #15
        sta cx
        ldx rp_i                ; rows in display order
        lda tord,x
        sta rp_c
        jsr typename
        ldx #14
        jsr prtw
        lda #35
        sta cx
        ldx rp_c
        lda rp_cnt,x
        jsr setnum8
        ldx #6
        jsr prnum
        lda #50
        sta cx
        lda rp_c
        asl a
        asl a
        adc rp_c
        tax
        lda rp_val,x
        sta num
        lda rp_val+1,x
        sta num+1
        lda rp_val+2,x
        sta num+2
        lda rp_val+3,x
        sta num+3
        lda rp_val+4,x
        sta num+4
        ldx #14
        jsr prmoney
        inc rp_i
        lda rp_i
        cmp #NTYPES
        bne @row
        POS 15, 14
        lda #G_OVER
        ldx #49
        jsr rep
        POS 15, 15
        PRT s_rtotal
        lda #35
        sta cx
        lda count
        jsr setnum8
        ldx #6
        jsr prnum
        lda #50
        sta cx
        jsr totalvalue
        ldx #14
        jsr prmoney
        ; oldest
        POS 15, 17
        PRT s_roldest
        POS 31, 17
        lda rp_old
        cmp #$FF
        beq @on
        jsr recaddr
        lda #F_NAME
        jsr fldptr
        ldx #22
        jsr prtfld
        PRTS " ("
        lda #F_YEAR
        jsr fldptr
        jsr prtlen
        lda #')'
        jsr putch
        jmp @top
@on:    PRT s_rnone
@top:   POS 15, 18
        PRT s_rtop
        POS 31, 18
        lda rp_top
        cmp #$FF
        beq @tn
        jsr recaddr
        lda #F_NAME
        jsr fldptr
        ldx #22
        jsr prtfld
        jsr space
        lda rp_tv
        sta num
        lda rp_tv+1
        sta num+1
        lda rp_tv+2
        sta num+2
        lda rp_tv+3
        sta num+3
        lda #0
        sta num+4
        ldx #0
        jsr prmoney
        jmp @btn
@tn:    PRT s_rnone
@btn:   POS 15, 19              ; systems
        PRT s_rsys
        POS 31, 19
        lda rp_ins
        jsr setnum8
        ldx #0
        jsr prnum
        PRT s_rsys2
        lda rp_cnt+T_COMPUTER
        jsr setnum8
        ldx #0
        jsr prnum
        PRT s_rsys3
        POS 37, 21
        lda #<s_ok
        ldy #>s_ok
        ldx #1
        jsr drawbtn
@w:     jsr getevent
        cmp #EV_KEY
        beq @x
        lda mrow
        cmp #21
        bne @w
@x:     lda #2
        sta redraw
        rts

        .segment "BSS"
skey:   .res 1
so_i:   .res 1
so_j:   .res 1
so_g:   .res 1
so_k:   .res 1
sl_a:   .res 1
sl_b:   .res 1
sl_c:   .res 1
rp_cnt: .res NTYPES
rp_val: .res NTYPES*5
rp_ins: .res 1
rp_c:   .res 1
so_r:   .res 1
rp_tv:  .res 4
rp_top: .res 1
rp_old: .res 1
rp_oy:  .res 2
rp_i:   .res 1
