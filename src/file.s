; ---------------------------------------------------------------
; ProDOS file I/O.  Inventories are text files shared with the Applesoft
; version.  Format 3 (written):  RETROINV3, count, then 12 lines per item:
;   "name" "maker" "year" type(1-8) cond(1-6) "location" value "notes"
;   "serial" itemno partof slot
; Format 2: 9 lines per item (no item no./part of/slot).  Format 1
; (RetroInv 1.x/2.0): no header line, 8 lines per item.
;
; Saving never overwrites the inventory in place: the new copy is written
; to RETROINV.SAVING, and only when that worked is the old file replaced.
; ---------------------------------------------------------------
        .segment "DATA"
pathname:   .byte 12, "RETROINV.DAT"
            .res 3
tmpname:    .byte 15, "RETROINV.SAVING"
destroy_p:  .byte 1
dp_path:    .word tmpname
rename_p:   .byte 2
            .word tmpname
            .word pathname
create_p:   .byte 7
            .word pathname
            .byte $C3, $04
            .word $0000
            .byte $01
            .word 0, 0
open_p:     .byte 3
            .word pathname
            .word FILEBUF
open_ref:   .byte 0
newline_p:  .byte 3
nl_ref:     .byte 0
            .byte $7F, $0D
read_p:     .byte 4
rd_ref:     .byte 0
            .word LINEBUF
            .word 255
rd_trans:   .word 0
write_p:    .byte 4
wr_ref:     .byte 0
            .word LINEBUF
wr_len:     .word 0
            .word 0
close_p:    .byte 1
cl_ref:     .byte 0
seteof_p:   .byte 2
se_ref:     .byte 0
            .byte 0, 0, 0
prefix_p:   .byte 1
            .word PREFIXBUF
online_p:   .byte 2
ol_unit:    .byte 0
            .word PREFIXBUF+1
s_hdr:      .byte "RETROINV3", 0
quit_parms: .byte 4, 0
            .word 0
            .byte 0
            .word 0

        .segment "CODE"

; fixprefix: work in the folder RetroInv was started from (ProDOS
; leaves its pathname at $0280), or if no prefix is set, the boot volume
fixprefix:
        ldx $0280               ; a path with a "/" in it?
        beq @gp
        cpx #64
        bcs @gp
@sl:    lda $0280,x
        and #$7F
        cmp #'/'
        beq @dir
        dex
        bne @sl
        beq @gp
@dir:   stx PREFIXBUF           ; its folder becomes the prefix
@cpy:   lda $0280,x
        and #$7F
        sta PREFIXBUF,x
        dex
        bne @cpy
        MLICALL $C6, prefix_p
@gp:    MLICALL $C7, prefix_p
        bcs @set
        lda PREFIXBUF
        bne @d
@set:   lda DEVNUM
        sta ol_unit
        MLICALL $C5, online_p
        bcs @d
        lda PREFIXBUF+1
        and #$0F
        beq @d
        tax
        lda #'/'
        sta PREFIXBUF+1
        sta PREFIXBUF+2,x
        inx
        inx
        stx PREFIXBUF
        MLICALL $C6, prefix_p
@d:     rts

setrefs:
        lda open_ref
        sta nl_ref
        sta rd_ref
        sta wr_ref
        sta cl_ref
        sta se_ref
        rts

; readline: next line into LINEBUF (zero-terminated, high bits cleared)
readline:
        MLICALL $CA, read_p
        bcs @e
        ldx rd_trans
        beq @z
        dex
        lda LINEBUF,x
        and #$7F
        cmp #$0D
        beq @z
        inx
@z:     lda #0
        sta LINEBUF,x
        ldx #0
@h:     lda LINEBUF,x
        beq @ok
        and #$7F
        sta LINEBUF,x
        inx
        bne @h
@ok:    clc
@e:     rts

; getstr: LINEBUF (quotes stripped) -> length-prefixed field at rp+Y, max X
getstr: sty gs_off
        stx gs_max
        ldx #0
        lda LINEBUF
        cmp #'"'
        bne @s
        inx
@s:     ldy gs_off
        iny
        lda #0
        sta gs_n
@l:     lda LINEBUF,x
        beq @d
        cmp #'"'
        beq @d
        pha
        lda gs_n
        cmp gs_max
        pla
        bcs @d
        sta (rp),y
        iny
        inx
        inc gs_n
        bne @l
@d:     ldy gs_off
        lda gs_n
        sta (rp),y
        rts

; getsmall: LINEBUF number 1..(gs_lim-1) -> 0-based at rp+Y, default A
getsmall:
        sty gs_off
        sta gs_def
        lda #<LINEBUF
        sta sptr
        lda #>LINEBUF
        sta sptr+1
        jsr parseint
        lda num+1
        ora num+2
        ora num+3
        ora num+4
        bne @def
        lda num
        beq @def
        cmp gs_lim
        bcs @def
        sec
        sbc #1
        jmp @st
@def:   lda gs_def
@st:    ldy gs_off
        sta (rp),y
        rts

; doload: carry set + A = error on failure; a missing file is not an error
doload: lda #0
        sta count
        sta ld_over
        sta ld_short
        sta ld_missing
        MLICALL $C8, open_p
        bcc @o
        cmp #$46
        beq @none
        cmp #$44
        beq @none
        sec
        rts
@none:  jsr fixlinks             ; empty: Item Nos start at 1
        lda #1
        sta ld_missing
        lda #0
        sta dirty
        clc
        rts
@o:     jsr setrefs
        MLICALL $C9, newline_p
        lda #1
        sta ld_v
        jsr readline
        jcs @close
        lda LINEBUF
        cmp #'R'
        bne @cnt
        lda #2                  ; "RETROINV2" or "RETROINV3" header
        ldx LINEBUF+8
        cpx #'3'
        bne @v2
        lda #3
@v2:    sta ld_v
        jsr readline
        jcs @close
@cnt:   lda #<LINEBUF
        sta sptr
        lda #>LINEBUF
        sta sptr+1
        jsr parseint
        lda num+1
        ora num+2
        ora num+3
        ora num+4
        bne @cap
        lda num
        cmp maxrec
        bcc @n
        beq @n
@cap:   lda #1
        sta ld_over
        lda maxrec
@n:     sta ld_n
        lda #0
        sta ld_i
@rec:   lda ld_i
        cmp ld_n
        bcc @more
        lda ld_over             ; all read: is there more than it said?
        jne @close
        jsr readline
        jcs @close
        lda LINEBUF
        jeq @close
        inc ld_short
        jmp @close
@more:  jsr recaddr
        jsr readline
        jcs @close
        ldy #F_NAME
        ldx #30
        jsr getstr
        jsr readline
        jcs @close
        ldy #F_MAKER
        ldx #20
        jsr getstr
        jsr readline
        jcs @close
        ldy #F_YEAR
        ldx #4
        jsr getstr
        jsr readline
        jcs @close
        ldy #F_TYPE
        lda #NTYPES+1
        sta gs_lim
        lda #5
        jsr getsmall
        jsr readline
        jcs @close
        ldy #F_COND
        lda #7
        sta gs_lim
        lda #2
        jsr getsmall
        jsr readline
        jcs @close
        ldy #F_LOC
        ldx #20
        jsr getstr
        jsr readline
        jcs @close
        lda #<LINEBUF
        sta sptr
        lda #>LINEBUF
        sta sptr+1
        jsr parsemoney
        ldy #F_VAL
        lda num
        sta (rp),y
        iny
        lda num+1
        sta (rp),y
        iny
        lda num+2
        sta (rp),y
        iny
        lda num+3
        sta (rp),y
        jsr readline
        jcs @close
        ldy #F_NOTES
        ldx #60
        jsr getstr
        ldy #F_SERIAL
        lda #0
        sta (rp),y
        lda ld_v
        cmp #2
        bcc @nos
        jsr readline
        jcs @close
        ldy #F_SERIAL
        ldx #20
        jsr getstr
@nos:   lda #0                  ; Item No., Part of, Slot (version 3)
        ldy #F_ITEMNO
@z:     sta (rp),y
        iny
        cpy #F_SLOT+1
        bne @z
        lda ld_v
        cmp #3
        bcc @next
        ldy #F_ITEMNO
        jsr getword
        bcs @close
        ldy #F_PARENT
        jsr getword
        bcs @close
        jsr readline
        bcs @close
        ldy #F_SLOT
        lda #NSLOTS
        sta gs_lim
        jsr getslot
@next:  inc ld_i
        lda ld_i
        sta count
        jmp @rec
@close: lda ld_i                 ; fewer items than the header says?
        cmp ld_n
        bcs @cl
        inc ld_short
@cl:    MLICALL $CC, close_p
        jsr fixlinks
        lda #0
        sta dirty
        clc
        rts

; getword: read a line, store its number as 16 bits at rp+Y
getword:
        sty gs_off
        jsr readline
        bcs @d
        lda #<LINEBUF
        sta sptr
        lda #>LINEBUF
        sta sptr+1
        jsr parseint
        jsr num16               ; over 65535: none (renumbered later)
        ldy gs_off
        lda num
        sta (rp),y
        iny
        lda num+1
        sta (rp),y
        clc
@d:     rts

; num16: num = 0 if it doesn't fit in 16 bits
num16:  lda num+2
        ora num+3
        ora num+4
        beq @d
        jmp zeronum
@d:     rts

; getslot: LINEBUF number 0..(gs_lim-1) at rp+Y (0 if out of range)
getslot:
        sty gs_off
        lda #<LINEBUF
        sta sptr
        lda #>LINEBUF
        sta sptr+1
        jsr parseint
        lda num
        ldx num+1
        bne @z
        cmp gs_lim
        bcc @st
@z:     lda #0
@st:    ldy gs_off
        sta (rp),y
        rts

; ---- writing ----
lb_reset:
        lda #0
        sta lblen
        rts
lb_char:
        ldx lblen
        sta LINEBUF,x
        inc lblen
        rts
lb_zstr:
        sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        beq @d
        jsr lb_char
        iny
        bne @l
@d:     rts
; lb_quoted: "length-prefixed field at rp+A"
lb_quoted:
        jsr fldptr
        lda #'"'
        jsr lb_char
        ldy #0
        lda (ptr1),y
        sta t1
@l:     cpy t1
        beq @d
        iny
        lda (ptr1),y
        jsr lb_char
        jmp @l
@d:     lda #'"'
        jmp lb_char
; lb_write: terminate with CR and write the line (carry set on error)
lb_write:
        lda #$0D
        jsr lb_char
        lda lblen
        sta wr_len
        lda #0
        sta wr_len+1
        MLICALL $CB, write_p
        php
        pha
        jsr lb_reset
        pla
        plp
        rts

; lb_word: the 16-bit number at rp+Y as a line.  lb_num: num as a line
lb_word:
        jsr zeronum
        lda (rp),y
        sta num
        iny
        lda (rp),y
        sta num+1
lb_num: jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr lb_zstr
        jmp lb_write

; lb_quotedw: one quoted field line
lb_qline:
        jsr lb_quoted
        jmp lb_write

; dosave: write the inventory to RETROINV.SAVING, then swap it in for
; the old file.  On any error the old file is left as it was.
dosave: lda #<tmpname           ; work on the temporary file
        sta dp_path
        sta create_p+1
        sta open_p+1
        lda #>tmpname
        sta dp_path+1
        sta create_p+2
        sta open_p+2
        MLICALL $C1, destroy_p  ; a leftover from an earlier try
        jsr @write
        php
        pha
        lda #<pathname          ; back to the real name
        sta create_p+1
        sta open_p+1
        lda #>pathname
        sta create_p+2
        sta open_p+2
        pla
        plp
        bcs @fail
        lda #<pathname          ; replace the old file with the new one
        sta dp_path
        lda #>pathname
        sta dp_path+1
        MLICALL $C1, destroy_p
        bcc @ren
        cmp #$46                ; there was no old file: fine
        bne @fail
@ren:   MLICALL $C2, rename_p
        bcs @fail2
        lda #0
        sta dirty
        clc
        rts
@fail:  pha                     ; throw the incomplete copy away
        MLICALL $C1, destroy_p
        pla
@fail2: sec
        rts

@write: MLICALL $C0, create_p
        bcc @c
        rts
@c:     MLICALL $C8, open_p
        bcc @o
        rts
@o:     jsr setrefs
        jsr lb_reset
        lda #<s_hdr
        ldy #>s_hdr
        jsr lb_zstr
        jsr lb_write
        jcs @err
        lda count
        jsr setnum8
        jsr lb_num
        jcs @err
        lda #0
        sta sv_i
@rec:   lda sv_i
        cmp count
        jcs @done
        jsr recaddr
        lda #F_NAME
        jsr lb_qline
        jcs @err
        lda #F_MAKER
        jsr lb_qline
        jcs @err
        lda #F_YEAR
        jsr lb_qline
        jcs @err
        ldy #F_TYPE
        lda (rp),y
        clc
        adc #'1'
        jsr lb_char
        jsr lb_write
        jcs @err
        ldy #F_COND
        lda (rp),y
        clc
        adc #'1'
        jsr lb_char
        jsr lb_write
        jcs @err
        lda #F_LOC
        jsr lb_qline
        jcs @err
        jsr zeronum
        lda #F_VAL
        jsr fldptr
        ldy #0
        jsr addrec32
        jsr fmtmoney0
        lda #<(moneybuf+1)
        ldy #>(moneybuf+1)
        jsr lb_zstr
        jsr lb_write
        jcs @err
        lda #F_NOTES
        jsr lb_qline
        jcs @err
        lda #F_SERIAL
        jsr lb_qline
        jcs @err
        ldy #F_ITEMNO
        jsr lb_word
        jcs @err
        ldy #F_PARENT
        jsr lb_word
        jcs @err
        ldy #F_SLOT
        lda (rp),y
        jsr setnum8
        jsr lb_num
        jcs @err
        inc sv_i
        jmp @rec
@done:  MLICALL $CC, close_p
        rts
@err:   pha
        MLICALL $CC, close_p
        pla
        sec
        rts

        .segment "BSS"
gs_off:   .res 1
gs_max:   .res 1
gs_n:     .res 1
gs_def:   .res 1
ld_n:     .res 1
ld_i:     .res 1
ld_over:  .res 1
ld_missing: .res 1
ld_short: .res 1
ld_v:     .res 1
gs_lim:   .res 1
sv_i:     .res 1
lblen:    .res 1
