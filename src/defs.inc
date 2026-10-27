; ---------------------------------------------------------------
; RetroInv 2.5 - definitions
; ---------------------------------------------------------------

MLI       = $BF00
DEVNUM    = $BF30

KBD       = $C000
CLR80STORE= $C000
SET80STORE= $C001
CLR80COL  = $C00C
SET80COL  = $C00D
CLRALTCHAR= $C00E
SETALTCHAR= $C00F
KBDSTRB   = $C010
TXTCLR    = $C050
TXTSET    = $C051
MIXCLR    = $C052
LOWSCR    = $C054
HISCR     = $C055
LORES     = $C056
HIRES     = $C057
DHIRESOFF = $C05F
BUTN0     = $C061
BUTN1     = $C062

; mouse firmware entry-table offsets
SETMOUSE  = $12
READMOUSE = $14
POSMOUSE  = $16
CLAMPMOUSE= $17
INITMOUSE = $19

; zero page
ptr1      = $60
ptr2      = $62
ptr3      = $64
sptr      = $66
cx        = $68
cy        = $69
inv       = $6A
t0        = $6B
t1        = $6C
t2        = $6D
t3        = $6E
t4        = $6F
rp        = $70
rp2       = $72
num       = $84         ; 5 bytes (40-bit)
num2      = $89         ; 5 bytes
mrom      = $7C         ; 2 bytes ($Cn00)
mjmp      = $7E         ; 2 bytes
fptr      = $80         ; 2 bytes, finditem result

; record layout (length-prefixed strings)
F_NAME    = 0           ; 1+30
F_MAKER   = 31          ; 1+20
F_YEAR    = 52          ; 1+4
F_TYPE    = 57          ; 0-5
F_COND    = 58          ; 0-5
F_LOC     = 59          ; 1+20
F_VAL     = 80          ; 4 bytes, cents
F_NOTES   = 84          ; 1+60
F_SERIAL  = 145         ; 1+20
F_ITEMNO  = 166         ; 2 bytes, permanent Item No.
F_PARENT  = 168         ; 2 bytes, Item No. of the computer (0 = none)
F_SLOT    = 170         ; 0 none, 1-8 = slot 0-7, 9 = aux slot
RECSIZE   = 171

T_COMPUTER = 0          ; type codes: 0 Computer 1 Peripheral 2 Software
NTYPES     = 8          ; 3 Accessory 4 Documents 5 Other 6 Card 7 Part
NSLOTS     = 10

MAXREC    = 138         ; the same limit as Applesoft RetroInv
MAXCENTS  = 999999999   ; largest value: $9,999,999.99
PTRLO     = $0800       ; MAXREC bytes
PTRHI     = $0800+MAXREC
DIRNAMES  = $0914       ; 14 names of 16 bytes, to $09F3
LINEBUF   = $0A00
PREFIXBUF = $0300       ; page 3 ($0300-$03CF) is free under ProDOS:
mc_path   = $0342       ; 66 bytes each
colmap    = $0384       ; 64 bytes
POOLA     = $0C00
POOLA_END = $3F70       ; pool A covers the splash page once it is gone
SCRATCH   = $3F70       ; 144 bytes after pool A's last record (after the splash)
TMPSTR    = SCRATCH     ; 64
DIGITS    = SCRATCH+64  ; 52
ENBUF     = SCRATCH+116 ; 24
FILEBUF   = $BB00       ; ProDOS file buffer, $BB00-$BEFF
POOLB_END = $BB00

LISTTOP   = 4
LISTROWS  = 17

EV_KEY    = 1
EV_MOUSE  = 2

; glyph codes understood by putch (MouseText)
G_OA      = $01
G_CA      = $02
G_RET     = $03
G_UP      = $04
G_DOWN    = $05
G_LEFT    = $06
G_RIGHT   = $07
G_CHECK   = $08
G_DOTS    = $09
G_PTR     = $0A
G_BLOCK   = $0B
G_OVER    = $0C
G_RBAR    = $0D       ; line on right edge of cell (left window border)
G_LBAR    = $0E       ; line on left edge of cell (right window border)
G_CHECKER = $0F
G_DIAMOND = $10
G_SCRUP   = $11
G_SCRDN   = $12

; commands
CMD_ABOUT    = 0
CMD_NEWINV   = 1
CMD_OPEN     = 2
CMD_SAVE     = 3
CMD_SAVEAS   = 4
CMD_REVERT   = 5
CMD_IMPORT   = 6
CMD_EXPORT   = 7
CMD_QUIT     = 8
CMD_NEW      = 9
CMD_EDIT     = 10
CMD_DELETE   = 11
CMD_FIND     = 12
CMD_FINDNEXT = 13
CMD_SORTNAME = 14
CMD_SORTMAKER= 15
CMD_SORTYEAR = 16
CMD_SORTTYPE = 17
CMD_SORTVALUE= 18
CMD_SORTSYSTEM= 19
CMD_REPORT   = 20

.macro POS xx, yy
        lda #xx
        sta cx
        lda #yy
        sta cy
.endmacro

.macro PRT str
        lda #<str
        ldy #>str
        jsr prt
.endmacro

.macro PRTS s
        jsr prti
        .byte s, 0
.endmacro

.macro MLICALL cmd, parms
        jsr MLI
        .byte cmd
        .word parms
.endmacro
