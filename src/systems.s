; ---------------------------------------------------------------
; Systems: item numbers, "Part of" links to a computer, slots,
; and the By System ordering.
;
; Every item has a permanent Item No. (F_ITEMNO, 16 bits, never 0).
; F_PARENT is the Item No. of the computer an item belongs to (0 = none).
; Rules kept by fixlinks: item numbers are unique, a Computer is never
; part of anything, and a link always points at an existing Computer.
; F_SLOT: 0 = none, 1-8 = slot 0-7, 9 = the IIe auxiliary slot.
; ---------------------------------------------------------------

        .segment "RODATA"
; type codes in display order, and each code's place in that order
tord:   .byte 0, 6, 1, 7, 2, 3, 4, 5
trank:  .byte 0, 2, 4, 5, 6, 7, 1, 3
s_none:    .byte "None", 0
s_auxslot: .byte "Aux slot", 0
s_slotw:   .byte "Slot ", 0
; slot visiting order for By System: slots 0-7, aux, then no slot
sysslot: .byte 1, 2, 3, 4, 5, 6, 7, 8, 9, 0

        .segment "CODE"

; getid: (rp)+F_ITEMNO -> fi_a ; getpar: (rp)+F_PARENT -> fi_a
getid:  ldy #F_ITEMNO
        bne getw
getpar: ldy #F_PARENT
getw:   lda (rp),y
        sta fi_a
        iny
        lda (rp),y
        sta fi_a+1
        rts

; finditem: find the item whose Item No. is fi_id.
; carry clear = found: fptr -> record, fi_x = index
finditem:
        lda fi_id
        ora fi_id+1
        beq @no
        ldx #0
@l:     cpx count
        bcs @no
        lda PTRLO,x
        sta fptr
        lda PTRHI,x
        sta fptr+1
        ldy #F_ITEMNO
        lda (fptr),y
        cmp fi_id
        bne @n
        iny
        lda (fptr),y
        cmp fi_id+1
        bne @n
        stx fi_x
        clc
        rts
@n:     inx
        bne @l
@no:    sec
        rts

; freeid: fi_a = an Item No. no item uses yet (never 0), counting up
; from nextid and wrapping after 65535.  nextid moves past it.
freeid: lda nextid
        sta fi_id
        lda nextid+1
        sta fi_id+1
@t:     lda fi_id
        ora fi_id+1
        bne @c
        inc fi_id               ; skip 0, which means "none"
@c:     jsr finditem
        bcs @free
        inc fi_id
        bne @t
        inc fi_id+1
        jmp @t
@free:  lda fi_id
        sta fi_a
        clc
        adc #1
        sta nextid
        lda fi_id+1
        sta fi_a+1
        adc #0
        sta nextid+1
        rts

; newid: give record (rp) a free Item No.
newid:  jsr freeid
        ldy #F_ITEMNO
        lda fi_a
        sta (rp),y
        iny
        lda fi_a+1
        sta (rp),y
        rts

; ---------------------------------------------------------------
; fixlinks: make item numbers unique and links valid; set nextid.
; ---------------------------------------------------------------
fixlinks:
        ; nextid = highest Item No. + 1
        lda #1
        sta nextid
        lda #0
        sta nextid+1
        sta fl_i
@mx:    lda fl_i
        cmp count
        bcs @uniq
        jsr recaddr
        jsr getid
        lda fi_a
        cmp nextid
        lda fi_a+1
        sbc nextid+1
        bcc @mn
        lda fi_a                ; fi_a >= nextid: nextid = fi_a + 1
        clc
        adc #1
        sta nextid
        lda fi_a+1
        adc #0
        sta nextid+1
@mn:    inc fl_i
        jmp @mx
        ; give a new number to items with none, or a repeated one
@uniq:  lda #0
        sta fl_i
@u:     lda fl_i
        cmp count
        bcs @links
        jsr recaddr
        jsr getid
        lda fi_a
        ora fi_a+1
        beq @renum
        lda fi_a
        sta fi_id
        lda fi_a+1
        sta fi_id+1
        jsr finditem            ; the first item with this number
        lda fi_x
        cmp fl_i
        beq @un
@renum: lda fl_i
        jsr recaddr
        jsr newid
@un:    inc fl_i
        jmp @u
        ; links must point at an existing Computer; Computers have none
@links: lda #0
        sta fl_i
@k:     lda fl_i
        cmp count
        bcs @d
        jsr recaddr
        jsr getpar
        lda fi_a
        ora fi_a+1
        beq @kn
        ldy #F_TYPE
        lda (rp),y
        cmp #T_COMPUTER
        beq @clr
        lda fi_a
        sta fi_id
        lda fi_a+1
        sta fi_id+1
        jsr finditem
        bcs @clr
        ldy #F_TYPE
        lda (fptr),y
        cmp #T_COMPUTER
        beq @kn
@clr:   lda fl_i
        jsr recaddr
        ldy #F_PARENT
        lda #0
        sta (rp),y
        iny
        sta (rp),y
@kn:    inc fl_i
        jmp @k
@d:     rts

; ---------------------------------------------------------------
; countparts: fi_id = a computer's Item No. -> A = items that are part
; of it.  detach: unlink every item that is part of fi_id.
; ---------------------------------------------------------------
countparts:
        lda #0
        sta cp_n
        clc
        bcc partwalk
detach: lda #$80
        sta cp_n
partwalk:
        lda fi_id
        ora fi_id+1
        beq @d
        ldx #0
@l:     cpx count
        bcs @d
        lda PTRLO,x
        sta fptr
        lda PTRHI,x
        sta fptr+1
        ldy #F_PARENT
        lda (fptr),y
        cmp fi_id
        bne @n
        iny
        lda (fptr),y
        cmp fi_id+1
        bne @n
        bit cp_n
        bmi @un
        inc cp_n
        bne @n
@un:    lda #0
        sta (fptr),y
        dey
        sta (fptr),y
@n:     inx
        bne @l
@d:     lda cp_n
        and #$7F
        rts

; ---------------------------------------------------------------
; Part of: step to the next / previous computer for the item in EDITREC
; ---------------------------------------------------------------
; pcstep: A = +1 / $FF.  Updates EDITREC+F_PARENT.
pcstep: sta pc_dir
        lda EDITREC+F_TYPE
        cmp #T_COMPUTER
        bne @go
        rts
@go:    lda EDITREC+F_PARENT
        sta fi_id
        lda EDITREC+F_PARENT+1
        sta fi_id+1
        jsr finditem
        bcc @at
        ; from None: next starts at 0, previous starts at the end
        lda #$FF
        ldx pc_dir
        bpl @st
        lda count
@st:    sta fi_x
@at:    lda fi_x
@step:  clc
        adc pc_dir
        sta fi_x
        cmp count
        bcs @none               ; ran off either end
        tax
        lda PTRLO,x
        sta fptr
        lda PTRHI,x
        sta fptr+1
        ldy #F_TYPE
        lda (fptr),y
        cmp #T_COMPUTER
        bne @nx
        ldy #F_ITEMNO           ; never part of itself
        lda (fptr),y
        cmp EDITREC+F_ITEMNO
        bne @take
        iny
        lda (fptr),y
        cmp EDITREC+F_ITEMNO+1
        beq @nx
@take:  ldy #F_ITEMNO
        lda (fptr),y
        sta EDITREC+F_PARENT
        iny
        lda (fptr),y
        sta EDITREC+F_PARENT+1
        rts
@nx:    lda fi_x
        jmp @step
@none:  lda #0
        sta EDITREC+F_PARENT
        sta EDITREC+F_PARENT+1
        rts

; rankof: A = type code -> A = its place in display order (uses X)
rankof: cmp #NTYPES
        bcc @ok
        lda #5
@ok:    tax
        lda trank,x
        rts

; slotname: A = slot code -> A/Y zero-terminated name
slotname:
        cmp #NSLOTS
        bcs @no
        tax
        bne @s
@no:    lda #<s_none
        ldy #>s_none
        rts
@s:     cpx #9
        bne @n
        lda #<s_auxslot
        ldy #>s_auxslot
        rts
@n:     ldy #0
@c:     lda s_slotw,y
        beq @dg
        sta SLOTBUF,y
        iny
        bne @c
@dg:    txa
        clc
        adc #'0'-1
        sta SLOTBUF,y
        lda #0
        sta SLOTBUF+1,y
        lda #<SLOTBUF
        ldy #>SLOTBUF
        rts

; ---------------------------------------------------------------
; In the list: is row dr_i shown indented under its computer?
; Yes when the rows above it, back to its computer, are all its siblings.
; carry set = indent
; ---------------------------------------------------------------
indented:
        jsr getpar
        lda fi_a
        ora fi_a+1
        beq @no
        ldx dr_i
@up:    dex
        cpx #$FF
        beq @no
        lda PTRLO,x
        sta fptr
        lda PTRHI,x
        sta fptr+1
        ldy #F_ITEMNO           ; reached the computer?
        lda (fptr),y
        cmp fi_a
        bne @sib
        iny
        lda (fptr),y
        cmp fi_a+1
        beq @yes
@sib:   ldy #F_PARENT           ; a sibling: keep looking up
        lda (fptr),y
        cmp fi_a
        bne @no
        iny
        lda (fptr),y
        cmp fi_a+1
        beq @up
@no:    clc
        rts
@yes:   sec
        rts

; ---------------------------------------------------------------
; Sort By System: computers (and loose items) by name, each computer
; followed by its parts in slot order.
; ---------------------------------------------------------------
SYSLO = $0A00
SYSHI = $0B00

cmd_sortsystem:
        lda #2
        sta redraw
        lda count
        cmp #2
        bcs @go
        rts
@go:    lda #<s_sorting
        ldy #>s_sorting
        jsr statusmsg
        jsr fixlinks
        lda #0
        sta skey
        jsr dosort              ; by name first
        lda #0
        sta ss_out
        sta ss_pass             ; pass 0: computers, pass 1: loose items
@pass:  lda #0
        sta ss_i
@root:  lda ss_i
        cmp count
        jcs @endp
        jsr recaddr
        jsr getpar
        lda fi_a
        ora fi_a+1
        jne @nr                 ; parts come with their computer
        ldy #F_TYPE
        lda (rp),y
        cmp #T_COMPUTER
        beq @isc
        lda ss_pass             ; not a computer: only in pass 1
        jeq @nr
        lda ss_i
        jsr ss_put
        jmp @nr
@isc:   lda ss_pass
        jne @nr
        lda ss_i
        jsr ss_put
        jsr getid
        lda #0
        sta ss_s
@slot:  ldx ss_s
        lda sysslot,x
        sta ss_want
        lda #0
        sta ss_j
@kid:   lda ss_j
        cmp count
        bcs @ns
        tax
        lda PTRLO,x
        sta fptr
        lda PTRHI,x
        sta fptr+1
        ldy #F_PARENT
        lda (fptr),y
        cmp fi_a
        bne @nk
        iny
        lda (fptr),y
        cmp fi_a+1
        bne @nk
        ldy #F_SLOT
        lda (fptr),y
        cmp #NSLOTS
        bcc @sv
        lda #0
@sv:    cmp ss_want
        bne @nk
        lda ss_j
        jsr ss_put
@nk:    inc ss_j
        jmp @kid
@ns:    inc ss_s
        lda ss_s
        cmp #NSLOTS
        bne @slot
@nr:    inc ss_i
        jmp @root
@endp:  lda ss_pass
        bne @copy
        inc ss_pass
        jmp @pass
@copy:  lda ss_out              ; every item placed exactly once?
        cmp count
        bne @done
        ldx #0
@cp:    lda SYSLO,x
        sta PTRLO,x
        lda SYSHI,x
        sta PTRHI,x
        inx
        cpx count
        bne @cp
@done:  lda #0
        sta sel
        sta top
        lda #1
        sta dirty
        rts

; ss_put: append item A to the new order
ss_put: tax
        ldy ss_out
        lda PTRLO,x
        sta SYSLO,y
        lda PTRHI,x
        sta SYSHI,y
        inc ss_out
        rts

        .segment "BSS"
nextid:  .res 2
fi_id:   .res 2
fi_a:    .res 2
fi_x:    .res 1
fl_i:    .res 1
cp_n:    .res 1
pc_dir:  .res 1
ss_out:  .res 1
ss_i:    .res 1
ss_j:    .res 1
ss_s:    .res 1
ss_want: .res 1
ss_pass: .res 1
SLOTBUF: .res 10
