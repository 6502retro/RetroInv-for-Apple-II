; ---------------------------------------------------------------
; Mouse Calc import / export
;
; Mouse Calc 1.1 (Version Soft) sheets are ProDOS files of type $F8:
;   $883-byte program-state header, max row, max column, then cell
;   records sorted by column then row:  row, col, type, body..., $FF
;   type: $80 = number, $40 = formula, low nibble = display format
;   text body = ASCII | $80;  number = exponent byte then BCD pairs,
;   value = 0.pairs * 100^((e & $3F) - $1F), e bit $40 = negative
;   formula = type $C0+fmt, cached value, $FE, tokens
;
; Export writes: row 1 headings, one row per item, a Total row with
; a live SUM.  Import maps columns by their row-1 headings.
; ---------------------------------------------------------------
OBUF     = $0B00          ; export output buffer (255 bytes used)
INBUF    = $0A00          ; import input buffer
CELLBUF  = $0B00          ; import cell body
DIRBUF   = $0A00          ; directory block buffer ($0A00-$0BFF)
MC_COLS  = 12
MC_HDRLEN= $883
MAXDIR   = 14           ; DIRNAMES at $0914-$09F3

        .segment "RODATA"
mchdr:  .incbin "../build/mchdr.pk"
mchdr_end:

; column order: A Name, B Maker, C Serial, D Year, E Type, F Condition,
;               G Location, H Value, I Notes, J Slot, K Part Of, L Item No.
mch0:   .byte "Name", 0
mch1:   .byte "Maker", 0
mch2:   .byte "Serial #", 0
mch3:   .byte "Year", 0
mch4:   .byte "Type", 0
mch5:   .byte "Condition", 0
mch6:   .byte "Location", 0
mch7:   .byte "Value", 0
mch8:   .byte "Notes", 0
mch9:   .byte "Slot", 0
mch10:  .byte "Part Of", 0
mch11:  .byte "Item No.", 0
mchlo:  .byte <mch0,<mch1,<mch2,<mch3,<mch4,<mch5,<mch6,<mch7,<mch8,<mch9,<mch10,<mch11
mchhi:  .byte >mch0,>mch1,>mch2,>mch3,>mch4,>mch5,>mch6,>mch7,>mch8,>mch9,>mch10,>mch11
; each heading's letters and digits, for import matching: a column is
; used only if its heading is one of these (ignoring case, spaces and
; punctuation), so "Serial #" and "SERIAL" match but "Part No." doesn't
mckey:  .byte "NAME", 0, "MAKER", 0, "SERIAL", 0, "YEAR", 0, "TYPE", 0
        .byte "CONDITION", 0, "LOCATION", 0, "VALUE", 0, "NOTES", 0
        .byte "SLOT", 0, "PARTOF", 0, "ITEMNO", 0
mcoff:  .byte F_NAME, F_MAKER, F_SERIAL, F_YEAR, F_TYPE, F_COND, F_LOC, F_VAL, F_NOTES
        .byte F_SLOT, F_PARENT, F_ITEMNO
mcmax:  .byte 30, 20, 20, 4, 0, 0, 20, 0, 60, 0, 0, 0
s_total: .byte "Total", 0

t_export:  .byte "Export to Mouse Calc", 0
t_import:  .byte "Import from Mouse Calc", 0
s_expl1:   .byte "Save the inventory as a Mouse Calc", 0
s_expl2:   .byte "sheet in this folder, named:", 0
s_expname: .byte "Name:", 0
nd_export: .word t_export, s_expl1, s_expl2, b_export, EXPNAME
b_export:  .byte "Export", 0
b_import:  .byte "Import", 0
b_replace: .byte "Replace", 0
s_badname: .byte "A ProDOS name starts with a letter|"
           .byte "and has up to 15 letters, digits|"
           .byte "and periods.", 0
s_notmc:   .byte "That name belongs to a file that|"
           .byte "is not a Mouse Calc sheet. Please|"
           .byte "choose another name.", 0
s_exists:  .byte "A Mouse Calc sheet with that name|"
           .byte "already exists. Replace it?", 0
s_expok1:  .byte "Exported ", 0
s_expok2:  .byte " items to|", 0
s_expok3:  .byte "||Open it in Mouse Calc.", 0
s_nofiles: .byte "There are no Mouse Calc sheets in|"
           .byte "this folder. Copy one next to|"
           .byte "RETROINV.SYSTEM and try again.", 0
s_impq:    .byte "Replace the inventory in memory|"
           .byte "with this sheet? (Revert to Saved|"
           .byte "brings back the saved one.)", 0
s_impok1:  .byte "Imported ", 0
s_impok2:  .byte " items.", 0
s_impover: .byte "|Some rows did not fit in memory.", 0
s_impok3:  .byte "||Choose Save to keep them.", 0
s_own1:    .byte 12, "RETROINV.DAT"
s_own2:    .byte 15, "RETROINV.SYSTEM"
s_nonamecol:  .byte "Row 1 of that sheet has no Name|"
           .byte "column, so it doesn't look like an|"
           .byte "inventory. Nothing was changed.", 0
s_imperr:  .byte "Could not read the sheet.||", 0
s_experr:  .byte "Could not export the sheet.||", 0
s_pickh:   .byte "Mouse Calc sheets in this folder:", 0
pk_import: .word t_import, s_pickh, b_import

al_badname: .word t_export, s_badname
            .byte 1
            .word b_ok
al_notmc:   .word t_export, s_notmc
            .byte 1
            .word b_ok
al_exists:  .word t_export, s_exists
            .byte 2
            .word b_replace, b_cancel
al_expmsg:  .word t_export, MSGBUF
            .byte 1
            .word b_ok
al_nofiles: .word t_import, s_nofiles
            .byte 1
            .word b_ok
al_impq:    .word t_import, s_impq
            .byte 2
            .word b_import, b_cancel
al_impmsg:  .word t_import, MSGBUF
            .byte 1
            .word b_ok
al_nonamecol:  .word t_import, s_nonamecol
            .byte 1
            .word b_ok

        .segment "DATA"
EXPNAME:   .byte 9, "INVENTORY"
           .res 7
mcreate_p: .byte 7
           .word mc_path
           .byte $C3, $F8
           .word $0000
           .byte $01
           .word 0, 0
mopen_p:   .byte 3
           .word mc_path
           .word FILEBUF
mo_ref:    .byte 0
mgfi_p:    .byte $0A
           .word mc_path
           .byte 0
mgfi_type: .byte 0
           .res 13
mwrite_p:  .byte 4
mw_ref:    .byte 0
           .word OBUF
mw_len:    .word 0
           .word 0
mread_p:   .byte 4
mr_ref:    .byte 0
mr_buf:    .word INBUF
mr_req:    .word 255
mr_trans:  .word 0
mclose_p:  .byte 1
mc_ref:    .byte 0
mseteof_p: .byte 2
mse_ref:   .byte 0
           .byte 0, 0, 0
msetmark_p: .byte 2
msm_ref:   .byte 0
msm_pos:   .byte 0, 0, 0

        .segment "CODE"

msetrefs:
        lda mo_ref
        sta mw_ref
        sta mr_ref
        sta mc_ref
        sta mse_ref
        rts

; ---------------------------------------------------------------
; output buffer
; ---------------------------------------------------------------
ob_put: stx ob_x
        ldx oblen
        sta OBUF,x
        inx
        stx oblen
        cpx #255
        bne @r
        pha
        jsr ob_flush
        pla
@r:     ldx ob_x
        rts

ob_flush:
        lda oblen
        beq @d
        sta mw_len
        lda #0
        sta mw_len+1
        sta oblen
        lda ob_err
        bne @d
        MLICALL $CB, mwrite_p
        bcc @d
        sta ob_err
@d:     rts

; ---------------------------------------------------------------
; export
; ---------------------------------------------------------------
cmd_export:
        lda #2
        sta redraw
@dlg:   lda #<nd_export
        ldy #>nd_export
        jsr namedialog
        bcc @go
        rts
@go:    ; validate the name: letter first, then letters, digits, periods
        lda EXPNAME
        beq @bad
        lda EXPNAME+1
        cmp #'A'
        bcc @bad
        cmp #'Z'+1
        bcs @bad
        jmp @named
@bad:   lda #<al_badname
        ldy #>al_badname
        jsr alert
        jmp @dlg
@named: ; never let an export take RetroInv's own file names
        lda #<s_own1
        ldy #>s_own1
        jsr samename
        beq @nmc0
        lda #<s_own2
        ldy #>s_own2
        jsr samename
        bne @cpn
@nmc0:  jmp @nmc
@cpn:   ; mc_path = EXPNAME (relative to the RetroInv folder)
        ldx EXPNAME
@cp:    lda EXPNAME,x
        sta mc_path,x
        dex
        bpl @cp
        MLICALL $C0, mcreate_p
        bcc @open
        cmp #$47
        beq @dup
        jmp experror
@dup:   MLICALL $C4, mgfi_p
        bcs @nmc
        lda mgfi_type
        cmp #$F8
        beq @ask
@nmc:   lda #<al_notmc
        ldy #>al_notmc
        jsr alert
        jmp @dlg
@ask:   lda #<al_exists
        ldy #>al_exists
        jsr alert
        cmp #0
        beq @open
        rts
@open:  lda #<s_exporting
        ldy #>s_exporting
        jsr statusmsg
        MLICALL $C8, mopen_p
        bcc @o2
        jmp experror
@o2:    jsr msetrefs
        MLICALL $D0, mseteof_p
        bcc @o3
        pha
        MLICALL $CC, mclose_p
        pla
        jmp experror
@o3:    lda #0
        sta oblen
        sta ob_err
        jsr wr_mchdr
        ; max row, max column
        lda count
        beq @mr1
        clc
        adc #3
        bne @mr
@mr1:   lda #1
@mr:    jsr ob_put
        lda #MC_COLS
        jsr ob_put
        ; cells, column by column
        lda #0
        sta ex_col
@col:   lda #1
        sta c_row
        ldx ex_col
        lda mchlo,x
        ldy mchhi,x
        jsr wr_textz
        lda #0
        sta ex_i
@row:   lda ex_i
        cmp count
        bcs @tot
        jsr recaddr
        lda ex_i
        clc
        adc #2
        sta c_row
        jsr wr_field
        inc ex_i
        jmp @row
@tot:   lda count
        beq @ncol
        clc
        adc #3
        sta c_row
        lda ex_col
        cmp #6
        bne @t8
        lda #<s_total
        ldy #>s_total
        jsr wr_textz
        jmp @ncol
@t8:    cmp #7
        bne @ncol
        jsr wr_sum
@ncol:  inc ex_col
        lda ex_col
        cmp #MC_COLS
        bne @col
        jsr ob_flush
        MLICALL $CC, mclose_p
        bcs @cerr
        lda ob_err
        beq @ok
@cerr:  lda ob_err
        jmp experror
@ok:    jsr mb_reset
        lda #<s_expok1
        ldy #>s_expok1
        jsr mb_str
        lda count
        jsr setnum8
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr mb_str
        lda #<s_expok2
        ldy #>s_expok2
        jsr mb_str
        jsr mb_prefix
        ldx #0
@nm:    cpx EXPNAME
        beq @nmd
        lda EXPNAME+1,x
        stx ex_i
        jsr mb_char
        ldx ex_i
        inx
        bne @nm
@nmd:   lda #<s_expok3
        ldy #>s_expok3
        jsr mb_str
        lda #<al_expmsg
        ldy #>al_expmsg
        jmp alert

; samename: Z set if EXPNAME equals the length-prefixed name at A/Y
samename:
        sta ptr3
        sty ptr3+1
        ldy #0
        lda (ptr3),y
        cmp EXPNAME
        bne @d
        tay
@l:     lda (ptr3),y
        cmp EXPNAME,y
        bne @d
        dey
        bne @l
@d:     rts

experror:
        pha
        jsr mb_reset
        lda #<s_experr
        ldy #>s_experr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<al_expmsg
        ldy #>al_expmsg
        jmp alert

; mb_prefix: append the current prefix (folder) to MSGBUF
mb_prefix:
        ldx #0
@l:     cpx PREFIXBUF
        beq @d
        lda PREFIXBUF+1,x
        stx mp_x
        jsr mb_char
        ldx mp_x
        inx
        bne @l
@d:     rts

        .segment "RODATA"
s_exporting: .byte "Exporting to Mouse Calc", G_DOTS, 0
        .segment "CODE"

; wr_mchdr: unpack the PackBits header into the output
wr_mchdr:
        lda #<mchdr
        sta ptr2
        lda #>mchdr
        sta ptr2+1
@n:     lda ptr2
        cmp #<mchdr_end
        lda ptr2+1
        sbc #>mchdr_end
        bcs @d
        ldy #0
        lda (ptr2),y
        jsr @inc
        cmp #$80
        bcs @rep
        tax
        inx
        stx wh_n
@lit:   ldy #0
        lda (ptr2),y
        jsr @inc
        jsr ob_put
        dec wh_n
        bne @lit
        beq @n
@rep:   eor #$FF
        clc
        adc #2
        sta wh_n
        ldy #0
        lda (ptr2),y
        jsr @inc
@r:     jsr ob_put
        dec wh_n
        bne @r
        beq @n
@d:     rts
@inc:   inc ptr2
        bne @i
        inc ptr2+1
@i:     rts

; cell_begin: A = type byte; row c_row, column ex_col+1
cell_begin:
        pha
        lda c_row
        jsr ob_put
        ldx ex_col
        inx
        txa
        jsr ob_put
        pla
        jmp ob_put
cell_end:
        lda #$FF
        jmp ob_put

; wr_textz: text cell from zero-terminated string A/Y
wr_textz:
        sta ptr3
        sty ptr3+1
        lda #0
        jsr cell_begin
        ldy #0
@l:     lda (ptr3),y
        beq @d
        ora #$80
        jsr ob_put
        iny
        bne @l
@d:     jmp cell_end

; wr_textfld: text cell from length-prefixed field at ptr1 (skips empty)
wr_textfld:
        ldy #0
        lda (ptr1),y
        beq @d
        sta wt_n
        lda #0
        jsr cell_begin
        ldy #0
@l:     iny
        lda (ptr1),y
        ora #$80
        jsr ob_put
        cpy wt_n
        bne @l
        jmp cell_end
@d:     rts

; wr_field: column ex_col of record rp
wr_field:
        ldx ex_col
        cpx #9
        bcc @f
        jmp wr_sys
@f:     cpx #3
        beq @year
        cpx #4
        beq @type
        cpx #5
        beq @cond
        cpx #7
        beq @val
        lda mcoff,x
        jsr fldptr
        jmp wr_textfld
@type:  ldy #F_TYPE
        lda (rp),y
        jsr typename
        jmp wr_textz
@cond:  ldy #F_COND
        lda (rp),y
        jsr condname
        jmp wr_textz
@val:   lda #$88                ; number, $X,XXX.XX
        jsr cell_begin
        jsr zeronum
        lda #F_VAL
        jsr fldptr
        ldy #0
        jsr addrec32
        jsr enc_cents
        jmp cell_end
@year:  ; all digits -> number cell (format XXXX), otherwise text
        lda #F_YEAR
        jsr fldptr
        ldy #0
        lda (ptr1),y
        beq @yd
        sta wt_n
        ldy #0
@yc:    iny
        lda (ptr1),y
        cmp #'0'
        bcc @ytext
        cmp #'9'+1
        bcs @ytext
        sta numbuf-1,y
        cpy wt_n
        bne @yc
        lda #0
        sta numbuf,y
        lda #$82
        jsr cell_begin
        lda #0
        sta en_frac
        jsr enc_dec
        jmp cell_end
@ytext: jmp wr_textfld
@yd:    rts

; wr_sys: Slot (text), Part Of and Item No. (numbers); blanks are skipped
wr_sys: cpx #9
        bne @po
        ldy #F_SLOT
        lda (rp),y
        beq wr_none
        cmp #NSLOTS
        bcs wr_none
        jsr slotname
        jmp wr_textz
@po:    cpx #10
        bne @no
        jsr getpar
        jmp wr_n16
@no:    jsr getid
; wr_n16: number cell from fi_a (nothing when zero)
wr_n16: lda fi_a
        ora fi_a+1
        beq @d
        lda fi_a
        sta num
        lda fi_a+1
        sta num+1
        lda #0
        sta num+2
        sta num+3
        sta num+4
        jsr fmtnum
        lda #$80
        jsr cell_begin
        lda #0
        sta en_frac
        jsr enc_dec
        jmp cell_end
@d:
wr_none:
        rts

; wr_sum: formula cell  +SUM(H2...Hn) with the cached total
wr_sum: lda #$C8
        jsr cell_begin
        jsr totalvalue
        jsr enc_cents
        lda #$FE
        jsr ob_put
        lda #$E0                ; +
        jsr ob_put
        lda #$C1                ; SUM
        jsr ob_put
        lda #$ED                ; (
        jsr ob_put
        lda #$88                ; H
        jsr ob_put
        lda #2
        jsr ob_put
        lda #$EC                ; ...
        jsr ob_put
        lda #$88
        jsr ob_put
        lda count
        clc
        adc #1
        jsr ob_put
        lda #$EE                ; )
        jsr ob_put
        jmp cell_end

; enc_cents: write num (cents) as a Mouse Calc number
enc_cents:
        jsr fmtnum
        lda #2
        sta en_frac
        ; fall through

; enc_dec: numbuf = decimal digits (zero-terminated); the last en_frac
; of them are the fraction.  Writes exponent byte + BCD pairs.
enc_dec:
        ldx #0
@sk:    lda numbuf,x            ; skip leading zeros
        cmp #'0'
        bne @nz
        inx
        bne @sk
@nz:    stx en_s
        lda numbuf,x
        bne @len
        lda #0                  ; zero
        jmp ob_put
@len:   ldy #0
@l:     lda numbuf,x
        beq @gl
        inx
        iny
        bne @l
@gl:    ; Y = significant digit count; integer digits = Y - en_frac
        tya
        sec
        sbc en_frac
        bcs @ip
        ; fewer digits than the fraction: pad with leading zeros
        eor #$FF
        clc
        adc #1                  ; A = zeros needed
        sta en_pad
        lda #0
        sta en_int
        jmp @build
@ip:    sta en_int
        lda #0
        sta en_pad
        lda en_int
        lsr a
        bcc @build
        inc en_pad              ; odd integer part: one leading zero
        inc en_int
@build: ldy #0
@pz:    cpy en_pad
        beq @cpd
        lda #'0'
        sta ENBUF,y
        iny
        bne @pz
@cpd:   ldx en_s
@cp:    lda numbuf,x
        beq @cpe
        sta ENBUF,y
        inx
        iny
        bne @cp
@cpe:   tya                     ; make the digit count even
        lsr a
        bcc @ev
        lda #'0'
        sta ENBUF,y
        iny
@ev:    sty en_n
        ; drop trailing "00" pairs
@tr:    lda en_n
        cmp #2
        bcc @emit
        tax
        lda ENBUF-1,x
        cmp #'0'
        bne @emit
        lda ENBUF-2,x
        cmp #'0'
        bne @emit
        dec en_n
        dec en_n
        jmp @tr
@emit:  lda en_int
        lsr a
        clc
        adc #$1F
        jsr ob_put
        ldy #0
@ep:    cpy en_n
        bcs @ed
        lda ENBUF,y
        and #$0F
        asl a
        asl a
        asl a
        asl a
        sta en_b
        lda ENBUF+1,y
        and #$0F
        ora en_b
        jsr ob_put
        iny
        iny
        bne @ep
@ed:    rts

; namedialog: A/Y -> spec (.word title, line1, line2, button, buffer)
; asks for a ProDOS name.  Carry clear = OK.
namedialog:
        sta ptr1
        sty ptr1+1
        ldy #9
@cp:    lda (ptr1),y
        sta nd_title,y
        dey
        bpl @cp
        jsr hidecursor
        lda #20
        sta wx
        lda #7
        sta wy
        lda #40
        sta ww
        lda #8
        sta wh
        lda nd_title
        ldy nd_title+1
        jsr drawwin
        POS 22, 10
        lda nd_l1
        ldy nd_l1+1
        jsr prt
        POS 22, 11
        lda nd_l2
        ldy nd_l2+1
        jsr prt
        POS 22, 13
        PRT s_expname
        POS 42, 15
        lda nd_btn
        ldy nd_btn+1
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
        beq @ok
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
        cmp #42
        bcc @loop
        cmp #50
        bcc @ok
        cmp #51
        bcc @loop
        cmp #59
        bcs @loop
@x:     sec
        rts
@ok:    clc
        rts
@setf:  lda nd_buf
        sta ptr2
        lda nd_buf+1
        sta ptr2+1
        lda #15
        sta tf_max
        lda #3
        sta tf_filt
        lda #28
        sta tf_col
        lda #13
        sta tf_row
        rts

; ---------------------------------------------------------------
; import
; ---------------------------------------------------------------
cmd_import:
        lda #2
        sta redraw
        lda #$F8
        sta sd_type
        jsr scandir
        bcc @sc
        jmp imperror
@sc:    lda ndir
        bne @pick
        lda #<al_nofiles
        ldy #>al_nofiles
        jmp alert
@pick:  lda #<pk_import
        ldy #>pk_import
        jsr setpick
        jsr pickdialog
        bcc @chosen
        rts
@chosen:
        lda #<al_impq
        ldy #>al_impq
        jsr alert
        cmp #0
        beq @go
        rts
@go:    ; mc_path = chosen name
        lda dsel
        asl a
        asl a
        asl a
        asl a
        tax
        ldy #0
        lda DIRNAMES,x
        sta mc_path
        sta t0
@cn:    inx
        iny
        lda DIRNAMES,x
        sta mc_path,y
        cpy t0
        bne @cn
        lda #<s_importing
        ldy #>s_importing
        jsr statusmsg
        MLICALL $C8, mopen_p
        bcc @o
        jmp imperror
@o:     jsr msetrefs
        lda #<INBUF
        sta mr_buf
        lda #>INBUF
        sta mr_buf+1
        lda #255
        sta mr_req
        lda #0
        sta mr_req+1
        sta ib_len
        sta ib_pos
        ; check the sheet before touching the inventory: pass 1 looks
        ; for a Name heading
        jsr skiphdr
        bcs @rderr
        lda #$FF
        ldx #63
@cm:    sta colmap,x
        dex
        bpl @cm
        lda #0
        sta im_pass
@p1:    jsr readcell
        bcs @p1d
        jsr maphead
        jmp @p1
@p1d:   ldx #63
@fn:    lda colmap,x
        beq @hasname
        dex
        bpl @fn
        MLICALL $CC, mclose_p
        lda #<al_nonamecol
        ldy #>al_nonamecol
        jmp alert
@rderr: pha
        MLICALL $CC, mclose_p
        pla
        jmp imperror
@hasname:
        ; rewind and read the data
        lda #0
        sta mark_p+2
        sta mark_p+3
        sta mark_p+4
        lda mo_ref
        sta mark_p+1
        MLICALL $CE, mark_p
        bcs @rderr
        lda #0
        sta ib_len
        sta ib_pos
        jsr skiphdr
        bcs @rderr
        jsr clearall
        lda #0
        sta im_rows
        sta ld_over
@p2:    jsr readcell
        bcs @p2d
        jsr storecell
        jmp @p2
@p2d:   MLICALL $CC, mclose_p
        jsr compact
        jsr fixlinks
        lda #0
        sta sel
        sta top
        lda #1
        sta dirty
        ; report
        jsr mb_reset
        lda #<s_impok1
        ldy #>s_impok1
        jsr mb_str
        lda count
        jsr setnum8
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr mb_str
        lda #<s_impok2
        ldy #>s_impok2
        jsr mb_str
        lda ld_over
        beq @rep
        lda #<s_impover
        ldy #>s_impover
        jsr mb_str
@rep:   lda #<s_impok3
        ldy #>s_impok3
        jsr mb_str
        jsr drawall
        lda #<al_impmsg
        ldy #>al_impmsg
        jmp alert

imperror:
        pha
        jsr mb_reset
        lda #<s_imperr
        ldy #>s_imperr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<al_impmsg
        ldy #>al_impmsg
        jmp alert

        .segment "RODATA"
s_importing: .byte "Importing from Mouse Calc", G_DOTS, 0
        .segment "DATA"
mark_p: .byte 2, 0, 0, 0, 0
        .segment "CODE"

; getbyte: next file byte in A; carry set at end of file / error
getbyte:
        ldx ib_pos
        cpx ib_len
        bcc @have
        MLICALL $CA, mread_p
        bcs @e
        lda mr_trans
        beq @eof
        sta ib_len
        ldx #0
        stx ib_pos
@have:  lda INBUF,x
        inc ib_pos
        clc
        rts
@eof:   lda #$4C
@e:     sec
        rts

; skiphdr: skip the $883-byte header and the max row/column bytes
skiphdr:
        lda #<(MC_HDRLEN+2)
        sta sh_n
        lda #>(MC_HDRLEN+2)
        sta sh_n+1
@l:     jsr getbyte
        bcs @d
        lda sh_n
        bne @dl
        dec sh_n+1
@dl:    dec sh_n
        lda sh_n
        ora sh_n+1
        bne @l
        clc
@d:     rts

; readcell: next cell into c_r, c_c, c_t and CELLBUF (c_len bytes).
; carry set at end of file.
readcell:
        jsr getbyte
        bcs @d
        sta c_r
        jsr getbyte
        bcs @d
        sta c_c
        jsr getbyte
        bcs @d
        sta c_t
        lda #0
        sta c_len
@b:     jsr getbyte
        bcs @end
        cmp #$FF
        beq @end
        ldx c_len
        cpx #255
        beq @b
        sta CELLBUF,x
        inc c_len
        jmp @b
@end:   clc
@d:     rts

; maphead: if the cell is a row-1 heading, record which field it is
maphead:
        lda c_r
        cmp #1
        bne @d
        lda c_c
        cmp #64
        bcs @d
        lda c_t
        bmi @d                  ; headings are text
        jsr cell2tmp
        ldx #0                  ; keep only letters and digits, in capitals
        ldy #0
@n:     lda TMPSTR,x
        beq @nz
        jsr toupper
        cmp #'0'
        bcc @nn
        cmp #'9'+1
        bcc @nk
        cmp #'A'
        bcc @nn
        cmp #'Z'+1
        bcs @nn
@nk:    sta TMPSTR,y
        iny
@nn:    inx
        bne @n
@nz:    sta TMPSTR,y
        ldy #0
        sty mh_f
@f:     ldx #0
@c:     lda mckey,y
        cmp TMPSTR,x
        bne @sk
        cmp #0
        beq @hit
        inx
        iny
        bne @c
@sk:    lda mckey,y             ; on to the next heading
        beq @nx
        iny
        bne @sk
@nx:    iny
        inc mh_f
        lda mh_f
        cmp #MC_COLS
        bne @f
@d:     rts
@hit:   ldx c_c
        lda mh_f
        sta colmap,x
        rts

; cell2tmp: cell contents as text in TMPSTR (zero-terminated)
cell2tmp:
        lda c_t
        bmi bcd2text
        ldx #0
        ldy #0
@l:     cpx c_len
        beq @d
        cpy #62
        bcs @d
        lda CELLBUF,x
        and #$7F
        cmp #$20
        bcc @n
        cmp #'"'
        bne @s
        lda #$27                ; keep quotes out of RETROINV.DAT
@s:     sta TMPSTR,y
        iny
@n:     inx
        bne @l
@d:     lda #0
        sta TMPSTR,y
        rts

; bcd2text: number cell -> decimal text in TMPSTR
bcd2text:
        lda #0
        sta bt_o
        lda c_len
        jeq @out
        lda CELLBUF
        cmp #$80
        jeq @out                ; ERROR / NA / TRUE / FALSE
        sta bt_e
        and #$40
        beq @pos
        lda #'-'
        jsr @put
@pos:   jsr bcdpairs            ; DIGITS = digit pairs, bt_nd digits
        lda bt_e
        and #$3F
        sec
        sbc #$1F                ; integer pairs (signed)
        beq @small
        bmi @small
        cmp #11
        jcs @big
        asl a
        sta bt_ki               ; integer digits
@pad:   ldx bt_nd               ; pad stored digits out to the integer part
        cpx bt_ki
        bcs @ip
        lda #'0'
        sta DIGITS,x
        inc bt_nd
        bne @pad
@ip:    ldx #0                  ; skip leading zeros, keep at least one digit
@lz:    inx
        cpx bt_ki
        bcs @lz1
        lda DIGITS-1,x
        cmp #'0'
        beq @lz
@lz1:   dex
@ic:    cpx bt_ki
        bcs @ie
        lda DIGITS,x
        jsr @put
        inx
        bne @ic
@ie:    lda bt_ki
        sta bt_fs
        jmp @frac
@small: ; value below 1: "0", fraction = (-2k) zeros + digits
        eor #$FF
        clc
        adc #1
        asl a
        cmp #20
        bcs @zero
        sta bt_pad
        jsr padfrac
        lda #'0'
        jsr @put
        lda #0
        sta bt_fs
@frac:  lda bt_nd
        sta bt_fe
@tz:    lda bt_fe               ; drop trailing zeros
        cmp bt_fs
        beq @out
        bcc @out
        tax
        lda DIGITS-1,x
        cmp #'0'
        bne @dot
        dec bt_fe
        jmp @tz
@dot:   lda #'.'
        jsr @put
        ldx bt_fs
@fc:    cpx bt_fe
        bcs @out
        lda DIGITS,x
        jsr @put
        inx
        bne @fc
@zero:  lda #'0'
        jsr @put
@out:   ldy bt_o
        lda #0
        sta TMPSTR,y
        rts
@big:   lda #0
        sta bt_o
        jmp @zero
@put:   ldy bt_o
        cpy #40
        bcs @pd
        sta TMPSTR,y
        inc bt_o
@pd:    rts

; bcdpairs: CELLBUF[1..] BCD pairs -> DIGITS (ASCII), bt_nd = count
bcdpairs:
        ldx #1
        lda #0
        sta bt_nd
@l:     cpx c_len
        bcs @d
        lda CELLBUF,x
        cmp #$FE
        beq @d
        cmp #$A0
        bcs @d
        and #$0F
        cmp #10
        bcs @d
        lda CELLBUF,x
        lsr a
        lsr a
        lsr a
        lsr a
        ora #'0'
        stx bp_x
        ldx bt_nd
        cpx #30
        bcs @d
        sta DIGITS,x
        inx
        ldy bp_x
        lda CELLBUF,y
        and #$0F
        ora #'0'
        sta DIGITS,x
        inx
        stx bt_nd
        ldx bp_x
        inx
        bne @l
@d:     rts

; padfrac: shift DIGITS right by bt_pad, filling with '0'
padfrac:
        lda bt_pad
        beq @d
        ldx bt_nd
@s:     dex
        bmi @f
        lda DIGITS,x
        pha
        txa
        clc
        adc bt_pad
        tay
        pla
        sta DIGITS,y
        jmp @s
@f:     ldx #0
        lda #'0'
@z:     cpx bt_pad
        beq @n
        sta DIGITS,x
        inx
        bne @z
@n:     lda bt_nd
        clc
        adc bt_pad
        sta bt_nd
@d:     rts

; bcd2cents: number cell -> num (cents); negatives and specials -> 0
bcd2cents:
        jsr zeronum
        lda c_len
        beq @d
        lda CELLBUF
        cmp #$80
        beq @d
        and #$40
        bne @d
        lda CELLBUF
        and #$3F
        sec
        sbc #$1F
        bmi @d                  ; below one cent
        cmp #5
        bcc @ok
        lda #$FF                ; huge: capval clamps it
        sta num+4
@d:     rts
@ok:    sta bc_k
        ldx #0
@l:     stx bc_i
        jsr mul10
        jsr mul10
        ldx bc_i
        inx
        cpx c_len
        bcs @nx
        lda CELLBUF,x
        cmp #$A0
        bcs @nx
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        sta bc_t
        asl a
        asl a
        adc bc_t
        asl a                   ; high digit * 10
        sta bc_t
        pla
        and #$0F
        clc
        adc bc_t
        jsr addnum8
@nx:    ldx bc_i
        inx
        cpx bc_k
        bcc @l
        beq @l
        rts

; clearall: empty every record slot, with default type and condition
clearall:
        lda #0
        sta ca_i
@r:     lda ca_i
        cmp maxrec
        bcs @d
        jsr recaddr
        ldy #RECSIZE-1
        lda #0
@z:     sta (rp),y
        dey
        cpy #$FF
        bne @z
        ldy #F_TYPE
        lda #5
        sta (rp),y
        ldy #F_COND
        lda #2
        sta (rp),y
        inc ca_i
        bne @r
@d:     rts

; storecell: put a data cell into its record
storecell:
        lda c_r
        cmp #2
        bcc @d
        lda c_c
        cmp #64
        bcs @d
        tax
        lda colmap,x
        cmp #$FF
        beq @d
        sta sc_f
        lda c_r
        sec
        sbc #2
        cmp maxrec
        bcc @in
        lda #1
        sta ld_over
@d:     rts
@in:    sta sc_i
        cmp im_rows
        bcc @nr
        tax
        inx
        stx im_rows
@nr:    lda sc_i
        jsr recaddr
        ldx sc_f
        cpx #9
        bcc @nsys
        jmp storesys
@nsys:  cpx #4
        beq @tc
        cpx #5
        beq @tc
        cpx #7
        beq @val
        ; text field
        jsr cell2tmp
        ldx sc_f
        lda mcoff,x
        jsr fldptr
        ldx sc_f
        lda mcmax,x
        sta sc_max
        ldx #0
@sp:    lda TMPSTR,x            ; drop leading spaces
        cmp #' '
        bne @cp0
        inx
        bne @sp
@cp0:   ldy #0
@cp:    lda TMPSTR,x
        beq @cpd
        cpy sc_max
        bcs @cpd
        iny
        sta (ptr1),y
        inx
        bne @cp
@cpd:   tya
        ldy #0
        sta (ptr1),y
        rts
@val:   lda c_t
        bpl @vt
        jsr bcd2cents
        jmp @vs
@vt:    jsr cell2tmp
        lda #<TMPSTR
        sta sptr
        lda #>TMPSTR
        sta sptr+1
        jsr parsemoney
@vs:    jsr capval              ; no more than $9,999,999.99
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
        rts
@tc:    ; Type or Condition: a number 1-6, or a name
        jsr cell2tmp
        lda TMPSTR
        cmp #'0'
        bcc @name
        cmp #'9'+1
        bcs @name
        lda #<TMPSTR
        sta sptr
        lda #>TMPSTR
        sta sptr+1
        jsr parseint
        ldx #NTYPES+1           ; types 1-8, conditions 1-6
        lda sc_f
        cmp #4
        beq @lim
        ldx #7
@lim:   stx sc_t
        lda num
        beq @dd
        cmp sc_t
        bcs @dd
        sec
        sbc #1
        jmp @set
@name:  lda #0
        sta sc_n
@nl:    lda sc_n
        ldx sc_f
        cpx #4
        bne @cn
        jsr typename
        jmp @cmp
@cn:    jsr condname
@cmp:   sta ptr2
        sty ptr2+1
        ldy #0
@cc:    lda (ptr2),y
        jsr toupper
        sta sc_t
        lda TMPSTR,y
        jsr toupper
        cmp sc_t
        bne @nm
        iny
        cpy #3
        bne @cc
        lda sc_n
        jmp @set
@nm:    inc sc_n
        lda sc_n
        ldx sc_f
        cpx #4
        bne @n6
        cmp #NTYPES
        bne @nl
        rts
@n6:    cmp #6
        bne @nl
@dd:    rts                     ; unknown: keep the default
@set:   pha
        ldx sc_f
        lda mcoff,x
        tay
        pla
        sta (rp),y
        rts

; storesys: Slot ("Slot 6", "6", "Aux"), Part Of and Item No. (numbers)
storesys:
        jsr cell2tmp
        lda sc_f
        cmp #9
        bne @num
        lda TMPSTR
        jsr toupper
        cmp #'A'
        bne @dig
        lda #9
        bne @slot
@dig:   ldx #0
@sc:    lda TMPSTR,x
        beq @d
        cmp #'0'
        bcc @sn
        cmp #'7'+1
        bcs @sn
        sec
        sbc #'0'-1
@slot:  ldy #F_SLOT
        sta (rp),y
@d:     rts
@sn:    inx
        bne @sc
        rts
@num:   lda #<TMPSTR
        sta sptr
        lda #>TMPSTR
        sta sptr+1
        jsr parseint
        jsr num16
        ldx sc_f
        lda mcoff,x
        tay
        lda num
        sta (rp),y
        iny
        lda num+1
        sta (rp),y
        rts

; compact: keep rows that have a name, in sheet order
compact:
        lda #0
        sta cp_o
        sta cp_i
@l:     lda cp_i
        cmp im_rows
        bcs @d
        jsr recaddr
        ldy #F_NAME
        lda (rp),y
        beq @n
        ; swap slot cp_i into position cp_o
        ldx cp_i
        ldy cp_o
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
        inc cp_o
@n:     inc cp_i
        bne @l
@d:     lda cp_o
        sta count
        rts

; ---------------------------------------------------------------
; scandir: DIRNAMES = the files of type sd_type in the current folder.
; For inventories ($04) the folder is read a block at a time and each
; block's text files are checked (invfilter) with the folder closed, so
; other text files never take up places in the list.  sd_more is set
; if there were more than MAXDIR.
; ---------------------------------------------------------------
scandir:
        lda #0
        sta ndir
        sta sd_more
        sta sd_blk
        lda #1                  ; block 0 starts with the folder's header
        sta sd_ent
        ; mc_path = prefix without its trailing slash
        ldx PREFIXBUF
        dex
        stx mc_path
@cp:    lda PREFIXBUF,x
        sta mc_path,x
        dex
        bne @cp
@open:  MLICALL $C8, mopen_p
        bcc @o
        rts
@o:     jsr msetrefs
        lda mo_ref
        sta msm_ref
        lda sd_blk              ; mark = block * 512
        asl a
        sta msm_pos+1
        MLICALL $CE, msetmark_p
        lda #<DIRBUF
        sta mr_buf
        lda #>DIRBUF
        sta mr_buf+1
        lda #0
        sta mr_req
        lda #2
        sta mr_req+1
        lda ndir
        sta sd_start
@blk:   MLICALL $CA, mread_p
        jcs @end
        lda #<(DIRBUF+4)        ; ptr1 = entry sd_ent
        sta ptr1
        lda #>(DIRBUF+4)
        sta ptr1+1
        ldx sd_ent
        beq @ent
@sk:    clc
        lda ptr1
        adc #$27
        sta ptr1
        bcc @sk1
        inc ptr1+1
@sk1:   dex
        bne @sk
@ent:   ldy #0
        lda (ptr1),y
        and #$F0
        beq @next
        cmp #$40
        bcs @next               ; only seedling/sapling/tree files
        ldy #16
        lda (ptr1),y
        cmp sd_type
        bne @next
        lda ndir
        cmp #MAXDIR
        bcs @full
        asl a
        asl a
        asl a
        asl a
        tax
        ldy #0
        lda (ptr1),y
        and #$0F
        sta DIRNAMES,x
        sta t0
@nc:    inx
        iny
        lda (ptr1),y
        sta DIRNAMES,x
        cpy t0
        bne @nc
        inc ndir
@next:  clc
        lda ptr1
        adc #$27
        sta ptr1
        bcc @nn
        inc ptr1+1
@nn:    inc sd_ent
        lda sd_ent
        cmp #13
        jne @ent
        lda #0                  ; on to the next block
        sta sd_ent
        inc sd_blk
        lda sd_type
        cmp #$04
        jne @blk
        jsr @close              ; inventories: check this block's files
        jsr invfilter
        jmp @open
@full:  jsr @close              ; the list is full
        lda sd_type
        cmp #$04
        bne @more
        jsr invfilter           ; room again once non-inventories go?
        lda ndir
        cmp #MAXDIR
        jcc @open
@more:  inc sd_more
        clc
        rts
@end:   jsr @close
        clc
        rts
@close: MLICALL $CC, mclose_p
        lda #<INBUF
        sta mr_buf
        lda #>INBUF
        sta mr_buf+1
        rts

; setpick: A/Y -> spec (.word title, heading, button) for pickdialog
setpick:
        sta ptr1
        sty ptr1+1
        ldy #5
@cp:    lda (ptr1),y
        sta pk_title,y
        dey
        bpl @cp
        rts

; pickdialog: choose one of DIRNAMES.  Carry clear = chosen (dsel).
PK_TOP = 6
pickdialog:
        lda #0
        sta dsel
@full:  jsr hidecursor
        lda #20
        sta wx
        lda #1
        sta wy
        lda #40
        sta ww
        lda ndir
        clc
        adc #6
        sta wh
        lda pk_title
        ldy pk_title+1
        jsr drawwin
        POS 22, 4
        lda pk_head
        ldy pk_head+1
        jsr prt
        jsr @list
        lda sd_more             ; more than fit in the list?
        beq @nm
        lda ndir
        clc
        adc #PK_TOP
        sta cy
        lda #22
        sta cx
        PRTS "Only the first 14 are listed."
@nm:    lda ndir
        clc
        adc #PK_TOP+1
        sta pk_btn
        sta cy
        lda #42
        sta cx
        lda pk_btnl
        ldy pk_btnl+1
        ldx #1
        jsr drawbtn
        lda #51
        sta cx
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jsr drawbtn
@loop:  jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        beq @ok
        cmp #$1B
        beq @x
        cmp #$0B
        beq @up
        cmp #$0A
        beq @dn
        jmp @loop
@up:    lda dsel
        beq @loop
        dec dsel
        jsr @list
        jmp @loop
@dn:    ldx dsel
        inx
        cpx ndir
        bcs @loop
        stx dsel
        jsr @list
        jmp @loop
@mouse: lda mrow
        cmp pk_btn
        bne @mrow
        lda mcol
        cmp #42
        bcc @loop
        cmp #50
        bcc @ok
        cmp #51
        bcc @loop
        cmp #59
        bcs @loop
@x:     sec
        rts
@ok:    clc
        rts
@mrow:  sec
        sbc #PK_TOP
        bcc @loop
        cmp ndir
        bcs @loop
        cmp dsel
        beq @ok                 ; click the selected sheet again to import
        sta dsel
        jsr @list
        jmp @loop
@list:  lda #0
        sta pk_i
@lr:    lda pk_i
        cmp ndir
        bcs @ld
        clc
        adc #PK_TOP
        sta cy
        lda #24
        sta cx
        lda #0
        ldx pk_i
        cpx dsel
        bne @li
        lda #1
@li:    sta inv
        jsr space
        lda pk_i
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<DIRNAMES
        sta ptr1
        lda #>DIRNAMES
        adc #0
        sta ptr1+1
        ldx #16
        jsr prtfld
        jsr space
        lda #0
        sta inv
        inc pk_i
        jmp @lr
@ld:    rts

        .segment "BSS"
oblen:   .res 1
ob_err:  .res 1
ob_x:    .res 1
ex_col:  .res 1
ex_i:    .res 1
c_row:   .res 1
wt_n:    .res 1
wh_n:    .res 1
mp_x:    .res 1
en_frac: .res 1
en_s:    .res 1
en_int:  .res 1
en_pad:  .res 1
en_n:    .res 1
en_b:    .res 1
ib_len:  .res 1
ib_pos:  .res 1
sh_n:    .res 2
c_r:     .res 1
c_c:     .res 1
c_t:     .res 1
c_len:   .res 1
im_pass: .res 1
im_rows: .res 1
mh_f:    .res 1
bt_e:    .res 1
bt_k:    .res 1
bt_ki:   .res 1
bt_nd:   .res 1
bt_o:    .res 1
bt_pad:  .res 1
bt_fs:   .res 1
bt_fe:   .res 1
bp_x:    .res 1
bc_k:    .res 1
bc_i:    .res 1
bc_t:    .res 1
ca_i:    .res 1
sc_f:    .res 1
sc_i:    .res 1
sc_max:  .res 1
sc_n:    .res 1
sc_t:    .res 1
cp_o:    .res 1
cp_i:    .res 1
ndir:    .res 1
dsel:    .res 1
sd_n:    .res 1
pk_btn:  .res 1
pk_i:    .res 1
pk_title: .res 2
pk_head: .res 2
pk_btnl: .res 2
sd_type: .res 1
sd_more: .res 1
sd_blk:  .res 1
sd_ent:  .res 1
sd_start: .res 1
nd_title: .res 2
nd_l1:   .res 2
nd_l2:   .res 2
nd_btn:  .res 2
nd_buf:  .res 2
