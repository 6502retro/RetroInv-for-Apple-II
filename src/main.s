; ---------------------------------------------------------------
; RetroInv 2.5 - Apple II retro computer collection inventory
; by 6502Retro.  ProDOS 8 system program, 80-column MouseText UI.
; ---------------------------------------------------------------
        .setcpu "6502"
        .macpack longbranch
        .include "defs.inc"

; The first 8K of the file is the hi-res splash, displayed straight from
; where ProDOS loads it ($2000).  Its first three bytes are a JMP; the real
; picture bytes are put back before graphics are switched on.
        .segment "SPLASH"
        jmp start
        .incbin "../build/splash.bin", 3

        .segment "CODE"
start:  cld
        lda #SPL0
        sta $2000
        lda #SPL1
        sta $2001
        lda #SPL2
        sta $2002
        sta KBDSTRB
        ; need an enhanced IIe, IIc or IIgs (MouseText + 80 columns)
        lda $FBB3
        cmp #$06
        jne badmachine
        lda $FBC0
        cmp #$EA
        jeq badmachine
        ; show the splash
        sta CLR80STORE
        sta CLR80COL
        sta DHIRESOFF
        sta MIXCLR
        sta HIRES
        sta LOWSCR
        sta TXTCLR
        lda #0
        sta curon
        sta hasmouse
        sta inv
        lda #$FF
        sta mopen
        jsr initmouse
        jsr splashwait
        ; switch to 80-column MouseText text
        sta TXTSET
        sta LORES
        sta SET80COL
        sta SET80STORE
        sta SETALTCHAR
        sta LOWSCR
        jsr clrscr
        POS 33, 11
        PRTS "Loading"
        lda #G_DOTS
        jsr putch
        jsr initpool
        jsr fixprefix
        lda #0
        sta count
        sta sel
        sta top
        sta dirty
        sta redraw
        sta FINDSTR
        lda #1
        sta named
        jsr readlast            ; the inventory used last time
        jsr doload
        bcs @err
        lda ld_missing
        beq @ok
        lda pathname            ; remembered file is gone: use RETROINV.DAT
        cmp #12
        beq @ok
        jsr usedefault
        jsr doload
        bcc @ok
@err:   jsr loaderror
@ok:    jsr overwarn
        jmp mainloop

; overwarn: after loading, if the file had more items than fit, or
; doesn't hold the number of items it says, open it as Untitled so a
; Save can't overwrite the file with a shortened copy.
overwarn:
        lda #<al_over
        ldy #>al_over
        ldx ld_over
        bne @w
        lda #<al_short
        ldy #>al_short
        ldx ld_short
        beq @d
@w:     sta ow_p
        sty ow_p+1
        lda #0
        sta named
        jsr drawall
        lda ow_p
        ldy ow_p+1
        jmp alert
@d:     rts

badmachine:
        sta TXTSET
        sta CLR80COL
        sta CLRALTCHAR
        sta CLR80STORE
        sta LOWSCR
        ldx #0
@cl:    lda #$A0
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne @cl
        ldx #0
@m:     lda badmsg,x
        beq @w
        ora #$80
        sta $0528,x
        inx
        bne @m
@w:     lda KBD
        bpl @w
        sta KBDSTRB
        jmp doquit

        .segment "RODATA"
badmsg: .byte "NEEDS ENHANCED IIE/IIC/IIGS - PRESS KEY", 0
        .segment "CODE"

; splashwait: until a key, a click, or about five seconds
splashwait:
        lda #0
        sta t0
        sta t1
        lda #5
        sta t2
@l:     lda KBD
        bmi @key
        inc t0
        bne @l
        jsr pollmouse
        lda mpress
        bne @d
        inc t1
        bne @l
        dec t2
        bne @l
@d:     rts
@key:   sta KBDSTRB
        rts

; initpool: assign record slots in [POOLA,POOLA_END) and [bss_end,POOLB_END)
initpool:
        lda #0
        sta maxrec
        lda #<POOLA
        sta ptr1
        lda #>POOLA
        sta ptr1+1
        lda #<POOLA_END
        sta ip_lim
        lda #>POOLA_END
        sta ip_lim+1
        jsr @fill
        lda #<bss_end
        sta ptr1
        lda #>bss_end
        sta ptr1+1
        lda #<POOLB_END
        sta ip_lim
        lda #>POOLB_END
        sta ip_lim+1
@fill:  lda maxrec
        cmp #MAXREC
        bcs @done
        clc                     ; room for one more record below ip_lim?
        lda ptr1
        adc #RECSIZE
        tax
        lda ptr1+1
        adc #0
        cmp ip_lim+1
        bcc @ok
        bne @done
        cpx ip_lim
        beq @ok
        bcs @done
@ok:    ldx maxrec
        lda ptr1
        sta PTRLO,x
        lda ptr1+1
        sta PTRHI,x
        inc maxrec
        clc
        lda ptr1
        adc #RECSIZE
        sta ptr1
        bcc @fill
        inc ptr1+1
        bne @fill
@done:  rts

; recaddr: A = index -> rp
recaddr:
        tax
        lda PTRLO,x
        sta rp
        lda PTRHI,x
        sta rp+1
        rts

; fldptr: ptr1 = rp + A
fldptr: clc
        adc rp
        sta ptr1
        lda rp+1
        adc #0
        sta ptr1+1
        rts

; typename: A = type code 0..7 -> A/Y string.  condname: A = 0..5
typename:
        cmp #NTYPES
        bcc @ok
        lda #5
@ok:    tax
        lda tnlo,x
        ldy tnhi,x
        rts
condname:
        cmp #6
        bcc @ok
        lda #2
@ok:    tax
        lda cnlo,x
        ldy cnhi,x
        rts

        .segment "RODATA"
tn0:    .byte "Computer", 0
tn1:    .byte "Peripheral", 0
tn2:    .byte "Software", 0
tn3:    .byte "Accessory", 0
tn4:    .byte "Documents", 0
tn5:    .byte "Other", 0
tn6:    .byte "Card", 0
tn7:    .byte "Part", 0
tnlo:   .byte <tn0, <tn1, <tn2, <tn3, <tn4, <tn5, <tn6, <tn7
tnhi:   .byte >tn0, >tn1, >tn2, >tn3, >tn4, >tn5, >tn6, >tn7
cn0:    .byte "Mint", 0
cn1:    .byte "Excellent", 0
cn2:    .byte "Good", 0
cn3:    .byte "Fair", 0
cn4:    .byte "Poor", 0
cn5:    .byte "For Parts", 0
cnlo:   .byte <cn0, <cn1, <cn2, <cn3, <cn4, <cn5
cnhi:   .byte >cn0, >cn1, >cn2, >cn3, >cn4, >cn5
        .segment "CODE"

; ---------------------------------------------------------------
; main screen
; ---------------------------------------------------------------
drawall:
        jsr clrscr
        jsr drawmenubar
        jsr drawheaders
        jsr drawlist
        jsr drawstatus
        jmp drawhints

drawheaders:
        lda #0
        sta inv
        POS 2, 2
        PRTS "No."
        POS 6, 2
        PRTS "Name"
        POS 27, 2
        PRTS "Maker"
        POS 42, 2
        PRTS "Year"
        POS 47, 2
        PRTS "Type"
        POS 58, 2
        PRTS "Condition"
        POS 74, 2
        PRTS "Value"
        POS 0, 3
        lda #G_OVER
        ldx #79
        jsr rep
        POS 0, 21
        lda #G_OVER
        ldx #80
        jmp rep

drawlist:
        jsr ensurevis
        lda #0
        sta dl_r
@r:     lda dl_r
        clc
        adc #LISTTOP
        sta cy
        lda #0
        sta cx
        sta inv
        lda dl_r
        clc
        adc top
        bcs @blank
        cmp count
        bcs @blank
        jsr drawrow
        jmp @n
@blank: ldx #79
        jsr spaces
@n:     inc dl_r
        lda dl_r
        cmp #LISTROWS
        bne @r
        jmp drawscroll

; drawrow: A = index, cy = row
drawrow:
        sta dr_i
        jsr recaddr
        lda #0
        sta cx
        lda dr_i
        cmp sel
        bne @n
        lda #1
        sta inv
@n:     jsr getid
        lda fi_a
        sta num
        lda fi_a+1
        sta num+1
        lda #0
        sta num+2
        sta num+3
        sta num+4
        ldx #5
        jsr prnum
        jsr space
        ; parts listed under their computer are indented, with the slot
        lda #20
        sta dr_w
        jsr indented
        bcc @nm
        ldx #2
        jsr spaces
        dec dr_w
        dec dr_w
        ldy #F_SLOT
        lda (rp),y
        beq @nm
        cmp #NSLOTS
        bcs @nm
        pha
        lda #'['
        jsr putch
        pla
        cmp #9
        bne @dg
        lda #'A'
        bne @pc
@dg:    clc
        adc #'0'-1
@pc:    jsr putch
        lda #']'
        jsr putch
        jsr space
        lda dr_w
        sec
        sbc #4
        sta dr_w
@nm:    lda #F_NAME
        jsr fldptr
        ldx dr_w
        jsr prtfld
        jsr space
        lda #F_MAKER
        jsr fldptr
        ldx #14
        jsr prtfld
        jsr space
        lda #F_YEAR
        jsr fldptr
        ldx #4
        jsr prtfld
        jsr space
        ldy #F_TYPE
        lda (rp),y
        jsr typename
        ldx #10
        jsr prtw
        jsr space
        ldy #F_COND
        lda (rp),y
        jsr condname
        ldx #9
        jsr prtw
        jsr space
        jsr zeronum
        lda #F_VAL
        jsr fldptr
        ldy #0
        jsr addrec32
        jsr fmtmoney
        ldx #11
        lda #<moneybuf
        ldy #>moneybuf
        jsr prtr
        lda #0
        sta inv
        rts

drawscroll:
        lda #0
        sta inv
        POS 79, LISTTOP
        lda #G_SCRUP
        jsr putch
        lda #LISTTOP+1
        sta cy
@t:     lda #79
        sta cx
        lda #G_CHECKER
        jsr putch
        inc cy
        lda cy
        cmp #LISTTOP+LISTROWS-1
        bne @t
        lda #79
        sta cx
        lda #G_SCRDN
        jsr putch
        lda #$FF
        sta thumbrow
        lda count
        cmp #2
        bcc @d
        ; thumb = 5 + sel*14/(count-1)
        lda #0
        sta t2
        sta t3
        ldx #LISTROWS-3
@m:     clc
        lda t2
        adc sel
        sta t2
        bcc @m2
        inc t3
@m2:    dex
        bne @m
        ldx count
        dex
        stx t4
        ldx #0
@dv:    lda t2
        sec
        sbc t4
        tay
        lda t3
        sbc #0
        bcc @dd
        sta t3
        sty t2
        inx
        bne @dv
@dd:    txa
        clc
        adc #LISTTOP+1
        sta cy
        sta thumbrow
        lda #79
        sta cx
        lda #$20
        jsr putsc
@d:     rts

drawstatus:
        lda #22
        sta cy
        jsr clrrow
        lda #1
        sta cx
        lda count
        jsr setnum8
        ldx #0
        jsr prnum
        PRTS " of "
        lda maxrec
        jsr setnum8
        ldx #0
        jsr prnum
        PRTS " items     Total value: "
        jsr totalvalue
        ldx #0
        jsr prmoney
        lda dirty
        beq @d
        lda #70
        sta cx
        lda #G_DIAMOND
        jsr putch
        PRTS " Modified"
@d:     rts

; statusmsg: show A/Y on the status line
statusmsg:
        pha
        tya
        pha
        lda #22
        sta cy
        jsr clrrow
        lda #1
        sta cx
        pla
        tay
        pla
        jmp prt

totalvalue:
        jsr zeronum
        lda #0
        sta tv_i
@l:     lda tv_i
        cmp count
        bcs @d
        jsr recaddr
        lda #F_VAL
        jsr fldptr
        ldy #0
        jsr addrec32
        inc tv_i
        bne @l
@d:     rts

drawhints:
        POS 0, 23
        lda #0
        sta inv
        PRTS {" ",G_OA,"N New  RETURN Edit  ",G_OA,"D Delete  ",G_OA,"F Find  ",G_OA,"R Report  ",G_OA,"S Save  ",G_OA,"Q Quit  ESC Menus"}
        rts

; ensurevis: keep sel valid and visible
ensurevis:
        lda count
        bne @a
        lda #0
        sta sel
        sta top
        rts
@a:     lda sel
        cmp count
        bcc @b
        ldx count
        dex
        stx sel
@b:     lda sel
        cmp top
        bcs @c
        sta top
@c:     lda sel
        sec
        sbc top
        cmp #LISTROWS
        bcc @e
        lda sel
        sec
        sbc #LISTROWS-1
        sta top
@e:     lda count
        sec
        sbc #LISTROWS
        bcs @f
        lda #0
@f:     cmp top
        bcs @g
        sta top
@g:     rts

; ---------------------------------------------------------------
; main loop
; ---------------------------------------------------------------
mainloop:
        jsr drawall
        lda #0
        sta redraw
@ev:    jsr getevent
        cmp #EV_KEY
        beq @key
        jsr mainclick
        jmp @after
@key:   jsr mainkey
@after: lda redraw
        beq @ev
        cmp #2
        beq mainloop
        jsr drawlist
        jsr drawstatus
        lda #0
        sta redraw
        jmp @ev

mainkey:
        lda keych
        jsr toupper
        sta keych
        cmp #$0B
        beq @up
        cmp #$0A
        beq @down
        cmp #$08
        beq @pgup
        cmp #$15
        beq @pgdn
        cmp #$0D
        bne @k1
        lda #CMD_EDIT
        jmp docmd
@k1:    cmp #$1B
        bne @k2
        lda #1
        ldx #1
        jsr menuloop
        jmp domenucmd
@k2:    lda keyoa               ; commands need Open-Apple (or Solid-Apple)
        beq @d
        ldx #0
@kl:    lda keytab,x
        beq @d
        cmp keych
        beq @kf
        inx
        inx
        bne @kl
@kf:    lda keytab+1,x
        jmp docmd
@d:     rts
@up:    lda sel
        beq @d
        dec sel
        jmp @mv
@down:  ldx sel
        inx
        cpx count
        bcs @d
        stx sel
        jmp @mv
@pgup:  lda sel
        sec
        sbc #LISTROWS
        bcs @pu
        lda #0
@pu:    sta sel
        jmp @mv
@pgdn:  lda sel
        clc
        adc #LISTROWS
        bcs @pd1
        cmp count
        bcc @pd
@pd1:   ldx count
        beq @d
        dex
        txa
@pd:    sta sel
@mv:    lda #1
        sta redraw
        rts

        .segment "RODATA"
keytab: .byte 'N', CMD_NEW, 'E', CMD_EDIT, 'D', CMD_DELETE
        .byte 'F', CMD_FIND, 'G', CMD_FINDNEXT, 'S', CMD_SAVE
        .byte 'R', CMD_REPORT, 'Q', CMD_QUIT, '?', CMD_ABOUT
        .byte 'I', CMD_IMPORT, 'X', CMD_EXPORT, 'O', CMD_OPEN, 0
        .segment "CODE"

mainclick:
        lda mrow
        bne @nm
        lda mcol
        jsr menuhit
        cmp #$FF
        beq @d
        ldx #0
        jsr menuloop
        jmp domenucmd
@nm:    cmp #LISTTOP
        bcc @d
        cmp #LISTTOP+LISTROWS
        bcs @d
        lda mcol
        cmp #79
        beq @scroll
        lda mrow
        sec
        sbc #LISTTOP
        clc
        adc top
        bcs @d
        cmp count
        bcs @d
        cmp sel
        beq @open
        sta sel
        lda #1
        sta redraw
@d:     rts
@open:  lda #CMD_EDIT
        jmp docmd
@scroll:
        lda mrow
        cmp #LISTTOP
        bne @s1
        lda #$0B
        bne @sk
@s1:    cmp #LISTTOP+LISTROWS-1
        bne @s2
        lda #$0A
        bne @sk
@s2:    cmp thumbrow
        bcc @s3
        lda #$15
        bne @sk
@s3:    lda #$08
@sk:    sta keych
        jmp mainkey

domenucmd:
        cmp #$FF
        bne @cmd
        lda #2
        sta redraw
        rts
@cmd:   pha                     ; clear the pull-down before the command
        jsr drawall
        pla
        ; fall through

; docmd: A = command
docmd:  asl a
        tax
        lda #2
        sta redraw
        lda cmdtab+1,x
        pha
        lda cmdtab,x
        pha
        rts

        .segment "RODATA"
cmdtab: .word cmd_about-1, cmd_newinv-1, cmd_open-1, cmd_save-1
        .word cmd_saveas-1, cmd_revert-1, cmd_import-1, cmd_export-1
        .word cmd_quit-1, cmd_new-1, cmd_edit-1, cmd_delete-1
        .word cmd_find-1, cmd_findnext-1, cmd_sortname-1
        .word cmd_sortmaker-1, cmd_sortyear-1, cmd_sorttype-1
        .word cmd_sortvalue-1, cmd_sortsystem-1, cmd_report-1
        .segment "CODE"

; ---------------------------------------------------------------
; commands
; ---------------------------------------------------------------
cmd_about:
        lda #<al_about
        ldy #>al_about
        jmp alert

cmd_new:
        lda count
        cmp maxrec
        bcc @ok
        lda #<al_full
        ldy #>al_full
        jmp alert
@ok:    jsr clearedit
        jsr freeid
        lda fi_a
        sta EDITREC+F_ITEMNO
        lda fi_a+1
        sta EDITREC+F_ITEMNO+1
        lda #<t_new
        ldy #>t_new
        jsr edititem
        bcs @x
        lda count
        jsr recaddr
        jsr edit2rec
        lda count
        sta sel
        inc count
        lda #1
        sta dirty
@x:     lda #2
        sta redraw
        rts

cmd_edit:
        lda count
        beq @x
        lda sel
        jsr recaddr
        jsr rec2edit
        lda #<t_edit
        ldy #>t_edit
        jsr edititem
        bcs @x
        lda sel
        jsr recaddr
        ldy #F_TYPE             ; was a computer, isn't any more:
        lda (rp),y              ; its parts no longer belong to it
        cmp #T_COMPUTER
        bne @cp
        lda EDITREC+F_TYPE
        cmp #T_COMPUTER
        beq @cp
        jsr getid
        lda fi_a
        sta fi_id
        lda fi_a+1
        sta fi_id+1
        jsr detach
@cp:    lda sel
        jsr recaddr
        jsr edit2rec
        lda #1
        sta dirty
@x:     lda #2
        sta redraw
        rts

cmd_delete:
        lda count
        jeq @x
        jsr mb_reset
        lda #<s_delq
        ldy #>s_delq
        jsr mb_str
        lda sel
        jsr recaddr
        lda #F_NAME
        jsr fldptr
        jsr mb_fld
        jsr getid
        lda fi_a
        sta fi_id
        lda fi_a+1
        sta fi_id+1
        jsr countparts
        beq @ask
        sta num
        lda #0
        sta num+1
        sta num+2
        sta num+3
        sta num+4
        lda #<s_delp1
        ldy #>s_delp1
        jsr mb_str
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr mb_str
        lda #<s_delp2
        ldy #>s_delp2
        jsr mb_str
@ask:   lda #<al_delete
        ldy #>al_delete
        jsr alert
        cmp #0
        bne @x
        jsr detach              ; its parts stay, unattached
        ; remove slot sel, recycle its record at the end of the table
        ldx sel
        lda PTRLO,x
        sta t2
        lda PTRHI,x
        sta t3
@sh:    inx
        cpx count
        bcs @last
        lda PTRLO,x
        sta PTRLO-1,x
        lda PTRHI,x
        sta PTRHI-1,x
        jmp @sh
@last:  dex
        lda t2
        sta PTRLO,x
        lda t3
        sta PTRHI,x
        dec count
        lda #1
        sta dirty
@x:     lda #2
        sta redraw
        rts

doquit: jsr clrscr
        sta TXTSET
        sta CLRALTCHAR
        sta CLR80STORE
        sta CLR80COL
        sta LOWSCR
        MLICALL $65, quit_parms
        brk

loaderror:
        pha
        jsr drawall
        jsr mb_reset
        lda #<s_loaderr
        ldy #>s_loaderr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<al_error
        ldy #>al_error
        jmp alert

saveerror:
        pha
        jsr drawstatus          ; clear "Saving..."
        jsr mb_reset
        lda #<s_saveerr
        ldy #>s_saveerr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<s_kept
        ldy #>s_kept
        jsr mb_str
        lda #<al_error
        ldy #>al_error
        jmp alert

; mb_errtext: A = ProDOS error code
mb_errtext:
        cmp #$2B
        bne @e1
        lda #<s_wp
        ldy #>s_wp
        jmp mb_str
@e1:    cmp #$48
        bne @e2
        lda #<s_full
        ldy #>s_full
        jmp mb_str
@e2:    cmp #$27
        bne @e3
        lda #<s_io
        ldy #>s_io
        jmp mb_str
@e3:    pha
        lda #<s_perr
        ldy #>s_perr
        jsr mb_str
        pla
        jmp mb_hex

        .segment "RODATA"
t_new:     .byte "New Item", 0
t_edit:    .byte "Edit Item", 0
t_alert:   .byte "RetroInv", 0
s_saving:  .byte "Saving", G_DOTS, 0
s_delq:    .byte "Delete this item?||", 0
s_delp1:   .byte "|Its ", 0
s_delp2:   .byte " parts will stay, unattached.", 0
s_loaderr: .byte "Could not open the inventory.||", 0
s_saveerr: .byte "Could not save the inventory.||", 0
s_kept:    .byte "|The file on disk was not changed.", 0
s_wp:      .byte "The disk is write-protected.", 0
s_full:    .byte "The disk is full.", 0
s_io:      .byte "Disk I/O error.", 0
s_perr:    .byte "ProDOS error $", 0
s_about:   .byte "RetroInv 2.5 for the Apple II||"
           .byte "Retro computer collection inventory|"
           .byte "by 6502Retro", 0
s_fullm:   .byte "The inventory is full.", 0
s_revq:    .byte "Discard your changes and reload|"
           .byte "the inventory from disk?", 0
b_ok:      .byte "OK", 0
b_cancel:  .byte "Cancel", 0
b_delete:  .byte "Delete", 0
b_revert:  .byte "Revert", 0
b_save:    .byte "Save", 0
b_dont:    .byte "Don't Save", 0

al_about:  .word t_alert, s_about
           .byte 1
           .word b_ok
al_full:   .word t_alert, s_fullm
           .byte 1
           .word b_ok
al_delete: .word t_delitem, MSGBUF
           .byte 2
           .word b_delete, b_cancel
al_revert: .word t_alert, s_revq
           .byte 2
           .word b_revert, b_cancel
al_over:   .word t_alert, s_over
           .byte 1
           .word b_ok
s_over:    .byte "This inventory has more than 138|"
           .byte "items, so only the first 138 were|"
           .byte "loaded. It is open as Untitled, so|"
           .byte "saving can't shorten the file.", 0
al_short:  .word t_alert, s_short
           .byte 1
           .word b_ok
s_short:   .byte "This file doesn't hold the number|"
           .byte "of items it says, so it may be|"
           .byte "damaged. It is open as Untitled,|"
           .byte "so the file is left as it is.", 0
al_error:  .word t_alert, MSGBUF
           .byte 1
           .word b_ok
t_delitem: .byte "Delete Item", 0

        .segment "BSS"
count:    .res 1
sel:      .res 1
top:      .res 1
dirty:    .res 1
redraw:   .res 1
maxrec:   .res 1
thumbrow: .res 1
ip_lim:   .res 2
dl_r:     .res 1
dr_i:     .res 1
dr_w:     .res 1
tv_i:     .res 1
ow_p:     .res 2
FINDSTR:  .res 22

        .include "screen.s"
        .include "num.s"
        .include "mouse.s"
        .include "ui.s"
        .include "menu.s"
        .include "form.s"
        .include "file.s"
        .include "report.s"
        .include "mcalc.s"
        .include "invfile.s"
        .include "systems.s"

        .segment "BSS"
bss_end:
