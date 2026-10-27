; ---------------------------------------------------------------
; Multiple inventories: New Inventory, Open, Save As, the shared
; "save changes?" prompt, and remembering the last inventory used.
;
; Inventories are text files in the RetroInv folder whose first line
; is RETROINV2 (RETROINV.DAT is also accepted in the older format).
; RETROINV.LAST holds the name of the inventory to open at startup.
; ---------------------------------------------------------------
        .segment "RODATA"
t_open:    .byte "Open Inventory", 0
s_openh:   .byte "Inventories in this folder:", 0
b_open:    .byte "Open", 0
pk_open:   .word t_open, s_openh, b_open
t_saveas:  .byte "Save As", 0
s_sal1:    .byte "Save this inventory under a new", 0
s_sal2:    .byte "name in the RetroInv folder:", 0
nd_saveas: .word t_saveas, s_sal1, s_sal2, b_save, NEWNAME
s_noinv:   .byte "There are no inventories in this|"
           .byte "folder yet. Choose Save As to|"
           .byte "start one.", 0
al_noinv:  .word t_open, s_noinv
           .byte 1
           .word b_ok
s_badinv:  .byte "That name belongs to a file that|"
           .byte "is not an inventory. Please|"
           .byte "choose another name.", 0
al_badinv: .word t_saveas, s_badinv
           .byte 1
           .word b_ok
al_badnm2: .word t_saveas, s_badname
           .byte 1
           .word b_ok
s_invex:   .byte "An inventory with that name|"
           .byte "already exists. Replace it?", 0
al_invex:  .word t_saveas, s_invex
           .byte 2
           .word b_replace, b_cancel
s_savq1:   .byte "Save changes to ", 0
s_savq2:   .byte "|before closing it?", 0
al_savech: .word t_alert, MSGBUF
           .byte 3
           .word b_save, b_dont, b_cancel
s_untitled: .byte "Untitled", 0
s_invlbl:  .byte "Inventory: ", 0
s_lastnm:  .byte 13, "RETROINV.LAST"
s_defnm:   .byte 12, "RETROINV.DAT"

        .segment "DATA"
NEWNAME:   .byte 0
           .res 15
OLDNAME:   .res 16
nfi_p:     .byte $0A
           .word NEWNAME
           .byte 0
nfi_type:  .byte 0
           .res 13
lopen_p:   .byte 3
lo_path:   .word s_lastnm
           .word FILEBUF
lo_ref:    .byte 0
lcreate_p: .byte 7
           .word s_lastnm
           .byte $C3, $04
           .word $0000
           .byte $01
           .word 0, 0

        .segment "CODE"

; copy16: copy the 16-byte name at ptr1 to ptr2
copy16: ldy #15
@l:     lda (ptr1),y
        sta (ptr2),y
        dey
        bpl @l
        rts

; namecmp: Z set if length-prefixed names at ptr1 and ptr2 match
namecmp:
        ldy #0
        lda (ptr1),y
        cmp (ptr2),y
        bne @d
        tay
@l:     lda (ptr1),y
        cmp (ptr2),y
        bne @d
        dey
        bne @l
@d:     rts

; ---------------------------------------------------------------
; the inventory name on the menu bar
; ---------------------------------------------------------------
drawinvname:
        lda #0
        sta cy
        sta inv
        lda #30
        sta cx
        PRT s_invlbl
        lda named
        bne @n
        PRT s_untitled
        rts
@n:     lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        jmp prtlen

; ---------------------------------------------------------------
; askdirty: if there are unsaved changes, offer to save them.
; Carry clear = go ahead, carry set = the user cancelled.
; ---------------------------------------------------------------
askdirty:
        lda dirty
        beq @ok
        jsr mb_reset
        lda #<s_savq1
        ldy #>s_savq1
        jsr mb_str
        lda named
        bne @nm
        lda #<s_untitled
        ldy #>s_untitled
        jsr mb_str
        jmp @q
@nm:    lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        jsr mb_fld
@q:     lda #<s_savq2
        ldy #>s_savq2
        jsr mb_str
        lda #<al_savech
        ldy #>al_savech
        jsr alert
        cmp #1
        beq @ok                 ; Don't Save
        cmp #0
        bne @no                 ; Cancel
        jsr save_any
        bcs @no
@ok:    clc
        rts
@no:    sec
        rts

; save_any: Save, or Save As when the inventory has no name yet.
; Carry clear = saved.
save_any:
        lda named
        bne save_cur
        jmp saveas_flow
save_cur:
        lda #<s_saving
        ldy #>s_saving
        jsr statusmsg
        jsr dosave
        bcc @ok
        jsr saveerror
        sec
        rts
@ok:    clc
        rts

; ---------------------------------------------------------------
; commands
; ---------------------------------------------------------------
cmd_save:
        lda #2
        sta redraw
        jmp save_any

cmd_saveas:
        lda #2
        sta redraw
        jmp saveas_flow

cmd_newinv:
        lda #2
        sta redraw
        jsr askdirty
        bcs @x
        lda #0
        sta count
        sta sel
        sta top
        sta dirty
        sta named
        jsr fixlinks            ; Item Nos start again at 1
@x:     rts

cmd_quit:
        lda #2
        sta redraw
        jsr askdirty
        bcs @x
        jmp doquit
@x:     rts

cmd_revert:
        lda #2
        sta redraw
        lda named
        beq @x
        lda dirty
        beq @x
        lda #<al_revert
        ldy #>al_revert
        jsr alert
        cmp #0
        bne @x
        jsr doload
        bcc @ok
        jsr loaderror
@ok:    jsr overwarn
        lda #0
        sta sel
        sta top
@x:     rts

cmd_open:
        lda #2
        sta redraw
        jsr askdirty
        bcc @scan
        rts
@scan:  jsr drawall
        jsr scaninv
        bcc @sc
        jmp loaderror
@sc:    lda ndir
        bne @pick
        lda #<al_noinv
        ldy #>al_noinv
        jmp alert
@pick:  lda #<pk_open
        ldy #>pk_open
        jsr setpick
        jsr pickdialog
        bcc @chosen
        rts
@chosen:
        ; keep the current name, then switch to the chosen file
        lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        lda #<OLDNAME
        sta ptr2
        lda #>OLDNAME
        sta ptr2+1
        jsr copy16
        jsr dselptr
        lda #<pathname
        sta ptr2
        lda #>pathname
        sta ptr2+1
        jsr copy16
        lda #<s_opening
        ldy #>s_opening
        jsr statusmsg
        jsr doload
        bcc @ok
        ; couldn't open it: go back to the previous inventory
        pha
        lda #<OLDNAME
        sta ptr1
        lda #>OLDNAME
        sta ptr1+1
        lda #<pathname
        sta ptr2
        lda #>pathname
        sta ptr2+1
        jsr copy16
        lda named
        beq @nr
        jsr doload
@nr:    pla
        jmp loaderror
@ok:    lda #1
        sta named
        lda #0
        sta sel
        sta top
        jsr writelast
        jsr drawall
        jmp overwarn

        .segment "RODATA"
s_opening: .byte "Opening", G_DOTS, 0
        .segment "CODE"

; dselptr: ptr1 = DIRNAMES entry dsel
dselptr:
        lda dsel
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
        rts

; ---------------------------------------------------------------
; Save As
; ---------------------------------------------------------------
saveas_flow:
        ; suggest the current name
        lda named
        beq @blank
        lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        lda #<NEWNAME
        sta ptr2
        lda #>NEWNAME
        sta ptr2+1
        jsr copy16
        jmp @dlg
@blank: lda #0
        sta NEWNAME
@dlg:   lda #<nd_saveas
        ldy #>nd_saveas
        jsr namedialog
        bcc @chk
        lda #2
        sta redraw
        sec
        rts
@chk:   lda #2
        sta redraw
        lda NEWNAME
        beq @bad
        lda NEWNAME+1
        cmp #'A'
        bcc @bad
        cmp #'Z'+1
        bcc @nlast
@bad:   lda #<al_badnm2
        ldy #>al_badnm2
        jsr alert
        jmp @dlg
@nlast: lda #<NEWNAME
        sta ptr1
        lda #>NEWNAME
        sta ptr1+1
        lda #<s_lastnm
        sta ptr2
        lda #>s_lastnm
        sta ptr2+1
        jsr namecmp
        beq @notinv
        ; does a file with this name exist already?
        MLICALL $C4, nfi_p
        bcs @free               ; no: fine
        lda nfi_type
        cmp #$04
        bne @notinv
        ; the inventory that is already open: just save over it
        lda named
        beq @ask
        lda #<NEWNAME
        sta ptr1
        lda #>NEWNAME
        sta ptr1+1
        lda #<pathname
        sta ptr2
        lda #>pathname
        sta ptr2+1
        jsr namecmp
        beq @free
@ask:   lda #<al_invex
        ldy #>al_invex
        jsr alert
        cmp #0
        beq @free
        jmp @dlg
@notinv:
        lda #<al_badinv
        ldy #>al_badinv
        jsr alert
        jmp @dlg
@free:  ; save under the new name; on failure keep the old one
        lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        lda #<OLDNAME
        sta ptr2
        lda #>OLDNAME
        sta ptr2+1
        jsr copy16
        lda #<NEWNAME
        sta ptr1
        lda #>NEWNAME
        sta ptr1+1
        lda #<pathname
        sta ptr2
        lda #>pathname
        sta ptr2+1
        jsr copy16
        lda #<s_saving
        ldy #>s_saving
        jsr statusmsg
        jsr dosave
        bcc @saved
        pha
        lda #<OLDNAME
        sta ptr1
        lda #>OLDNAME
        sta ptr1+1
        lda #<pathname
        sta ptr2
        lda #>pathname
        sta ptr2+1
        jsr copy16
        pla
        jsr saveerror
        sec
        rts
@saved: lda #1
        sta named
        jsr writelast
        clc
        rts

; ---------------------------------------------------------------
; scaninv: DIRNAMES = the inventories in the RetroInv folder
; ---------------------------------------------------------------
scaninv:
        lda #$04
        sta sd_type
        jmp scandir

; invfilter: keep only the inventories among DIRNAMES sd_start..ndir-1
invfilter:
        lda sd_start
        sta si_i
        sta si_o
@l:     lda si_i
        cmp ndir
        bcs @done
        sta dsel
        jsr dselptr
        lda #<s_lastnm          ; never list RETROINV.LAST
        sta ptr2
        lda #>s_lastnm
        sta ptr2+1
        jsr namecmp
        beq @skip
        lda #<s_defnm           ; RETROINV.DAT may be in the old format
        sta ptr2
        lda #>s_defnm
        sta ptr2+1
        jsr namecmp
        beq @keep
        jsr isinv
        bcs @skip
@keep:  ; move entry si_i down to si_o
        jsr dselptr
        lda si_o
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<DIRNAMES
        sta ptr2
        lda #>DIRNAMES
        adc #0
        sta ptr2+1
        jsr copy16
        inc si_o
@skip:  inc si_i
        jmp @l
@done:  lda si_o
        sta ndir
        rts

; isinv: does the file named at ptr1 start with RETROINV2?  carry clear = yes
isinv:  lda ptr1
        sta lo_path
        lda ptr1+1
        sta lo_path+1
        MLICALL $C8, lopen_p
        bcs @no
        lda lo_ref
        sta open_ref
        jsr setrefs
        MLICALL $C9, newline_p
        jsr readline
        php
        MLICALL $CC, close_p
        plp
        bcs @no
        ldx #0                  ; "RETROINV" then 2 or 3
@c:     lda s_hdr,x
        cmp LINEBUF,x
        bne @no
        inx
        cpx #8
        bne @c
        lda LINEBUF+9
        bne @no
        lda LINEBUF+8
        cmp #'2'
        beq @yes
        cmp #'3'
        bne @no
@yes:   clc
        rts
@no:    sec
        rts

; ---------------------------------------------------------------
; RETROINV.LAST: remember the inventory in use
; ---------------------------------------------------------------
; writelast: errors (such as a write-protected disk) are ignored
writelast:
        lda #<s_lastnm
        sta lo_path
        lda #>s_lastnm
        sta lo_path+1
        MLICALL $C0, lcreate_p
        MLICALL $C8, lopen_p
        bcs @d
        lda lo_ref
        sta open_ref
        jsr setrefs
        MLICALL $D0, seteof_p
        jsr lb_reset
        lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        ldy #0
        lda (ptr1),y
        sta t1
@l:     cpy t1
        beq @w
        iny
        lda (ptr1),y
        jsr lb_char
        jmp @l
@w:     jsr lb_write
        MLICALL $CC, close_p
@d:     rts

; readlast: if RETROINV.LAST names an inventory, put it in pathname
readlast:
        lda #<s_lastnm
        sta lo_path
        lda #>s_lastnm
        sta lo_path+1
        MLICALL $C8, lopen_p
        bcs @d
        lda lo_ref
        sta open_ref
        jsr setrefs
        MLICALL $C9, newline_p
        jsr readline
        php
        MLICALL $CC, close_p
        plp
        bcs @d
        ; check: 1-15 characters, starting with a letter
        lda LINEBUF
        cmp #'A'
        bcc @d
        cmp #'Z'+1
        bcs @d
        ldx #0
@n:     lda LINEBUF,x
        beq @len
        inx
        cpx #16
        bcc @n
        rts
@len:   stx pathname
@cp:    lda LINEBUF-1,x
        sta pathname,x
        dex
        bne @cp
        ; only follow it to an inventory (never to a Mouse Calc sheet)
        lda #<pathname
        sta ptr1
        lda #>pathname
        sta ptr1+1
        lda #<s_defnm
        sta ptr2
        lda #>s_defnm
        sta ptr2+1
        jsr namecmp
        beq @d
        jsr isinv
        bcc @d
        jmp usedefault
@d:     rts

; usedefault: pathname = RETROINV.DAT
usedefault:
        lda #<s_defnm
        sta ptr1
        lda #>s_defnm
        sta ptr1+1
        lda #<pathname
        sta ptr2
        lda #>pathname
        sta ptr2+1
        ldy #12
@l:     lda (ptr1),y
        sta (ptr2),y
        dey
        bpl @l
        rts

        .segment "BSS"
named:  .res 1
si_i:   .res 1
si_o:   .res 1
