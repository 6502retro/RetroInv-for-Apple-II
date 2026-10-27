# RetroInv 2.5 — by 6502Retro

## Download
- `release/RETROINV-2.5.po` — bootable 140K ProDOS disk: ProDOS 8 2.4.3, RetroInv 2.5
  (mouse/MouseText, enhanced IIe/IIc/IIGS), BASIC.SYSTEM, Applesoft RetroInv 1.4
  and a SAMPLE inventory (also as a Mouse Calc sheet).
- `release/RETROINV-1.4.dsk` — Applesoft RetroInv 1.4 on a DOS 3.3 disk (any Apple II with 48K).
- `release/RetroInv Owners Manual.pdf` — the owner's manual.


A retro computer collection inventory for the Apple II, written in 6502
assembly as a ProDOS 8 system program. Hi-res 6502 Retro Computing splash,
80-column MouseText interface, pull-down menus, mouse and keyboard.

## Requirements
- Enhanced Apple IIe (with 80-column card), IIc, IIc Plus or IIgs
- ProDOS 8
- Mouse optional (AppleMouse card, or the built-in IIc/IIgs mouse port)

## Disk
`RETROINV2.po` holds `RETROINV.SYSTEM` (this program) and `RETROINV`
(the Applesoft version). Both read and write the same `RETROINV.DAT`.
Copy `PRODOS` (and `BASIC.SYSTEM` for the BASIC version) onto the disk
to make it boot straight into the splash screen.

## Keys
| Key | Action |
|---|---|
| ↑ ↓ | move selection |
| ← → | page up / down |
| RETURN | edit selected item |
| ESC | open the menus (arrows + RETURN) |
| ⌘N / ⌘E / ⌘D | new / edit / delete item (⌘ = Open-Apple; plain letters work too) |
| ⌘F / ⌘G | find / find next |
| ⌘R | collection report |
| ⌘O | open another inventory |
| ⌘S | save (asks for a name if the inventory is new) |
| ⌘I / ⌘X | import from / export to Mouse Calc |
| ⌘Q | quit (asks to save if needed) |

In the item form: TAB or ↑↓ moves between fields, ←→ (or a click) changes
Type and Condition, CTRL-X clears a field, RETURN = OK, ESC = Cancel.

Mouse: click a title to open a menu (or press and drag), click an item to
select it, click it again to edit, use the scroll bar arrows and track.

## Systems: computers and the things in them
Types: Computer, Card, Peripheral, Part, Software, Accessory, Documents,
Other. Every item has a permanent Item No. Any item that isn't a computer
can be Part of a computer, optionally in a Slot (0-7 or the IIe aux slot);
both are chosen with the arrows in the item window. Sort > By System lists
each computer followed by its parts in slot order, indented, with the slot
shown as [6] or [A], then the items that belong to no system. Deleting a
computer, or changing its type, keeps its parts but unattaches them. The
report counts the items in systems.

## Multiple inventories
File > New Inventory starts an empty, untitled inventory; Save As saves the
current one under a new name; Open lists the inventories in the RetroInv
folder (text files whose first line is RETROINV2 or RETROINV3, plus RETROINV.DAT). The
current name shows on the menu bar. RETROINV.LAST remembers the inventory
in use, and RetroInv reopens it at startup (falling back to RETROINV.DAT).
New, Open and Quit offer to save unsaved changes first. The Applesoft
version always uses RETROINV.DAT.

## Mouse Calc import / export
File > Export to Mouse Calc writes the inventory as a Mouse Calc 1.1 sheet
(ProDOS type $F8) in the RetroInv folder: row 1 holds the headings Name,
Maker, Serial #, Year, Type, Condition, Location, Value, Notes, Slot, Part Of,
Item No.; each item
is a row, Value uses the $X,XXX.XX format, and a Total row holds a live
+SUM() formula. Open it in Mouse Calc from that folder.

File > Import from Mouse Calc lists the Mouse Calc sheets in the RetroInv
folder and replaces the inventory in memory with the chosen one (Revert
to Saved undoes it). Columns are matched by the first three letters of
their row-1 headings, so they can be in any order and extra columns are
ignored. Rows without a Name are skipped, as is the Total row. Type and
Condition can be names or numbers (Type 1-8, Condition 1-6); Value can be a
number or text like $1,200; Part Of holds the computer's Item No.

The sheet header comes from a real Mouse Calc 1.1 sheet (tools/mcsamples),
set up the same way as the Mouse Calc Converter page, and exported sheets
are byte-identical to what the converter writes for the same cells.

## Building
Needs cc65 (ca65/ld65) and Python 3 with Pillow.

    python3 tools/mksplash.py art/6502retro-logo.png build/splash.bin build/splash.png
    python3 tools/mkmchdr.py tools/mcsamples/SAMPLE.BILL build/mchdr.pk build/mchdr.raw
    ./build.sh
    python3 tools/mkprodos.py --boot=prodos/BOOTBLOCKS build/RETROINV2.po RETROINV \
        prodos/PRODOS:PRODOS:0xFF:0x0000 \
        build/RETROINV.SYSTEM:RETROINV.SYSTEM:0xFF:0x2000 \
        prodos/BASIC.SYSTEM:BASIC.SYSTEM:0xFF:0x2000 \
        src/RETROINV.BAS:RETROINV:BAS:0 \
        build/SAMPLE:SAMPLE:0x04:0x0000 \
        build/SAMPLE.INV:SAMPLE.INV:0xF8:0x0000

`tools/mksample.py` writes the SAMPLE inventory; `test/basrun.js` runs the
Applesoft version under jsbasic (github.com/inexorabletash/jsbasic) with
scripted keys and DOS files in a folder.

`tools/sim.py` is a small Apple IIe test harness (py65) used to run the
program headless; `test/` has the scripted test sessions.

## Memory map
$0300-$03CF prefix/path/column-map buffers · $0800-$0913 record pointer
tables (138 entries) · $0914-$09F3 file-list names · $0A00 line/directory
buffers · $0C00-$3F6F item storage (77) · $3F70-$3FFF work buffers ·
end-of-program-$BAFF item storage (61) · $BB00 ProDOS file buffer.
build.sh checks that the pools still hold 138 items. The splash is
displayed from $2000 where ProDOS loads it, then that page becomes item
storage. Totals use 40-bit arithmetic; item values are capped at
$9,999,999.99.

## Saving
Saves go to RETROINV.SAVING, then the old file is destroyed and the new
one renamed, so a failed save never damages the saved file. A file with
more than 138 items, or whose item count doesn't match its contents, is
opened as Untitled so it can't be overwritten by a shortened copy.

## Tests
`test/t12.py` covers the fixes from the first beta report (disk full,
short and over-full files, value/total limits, item numbers, E notation,
years, Open-Apple commands, dialog focus, RETROINV.LAST, launch folder,
Mouse Calc headings, the Open list). `test/bt1.py` does the same for the
Applesoft version under jsbasic.

## Data file (RETROINV3)
Line 1 RETROINV3, line 2 the item count, then 12 lines per item: "name"
"maker" "year" type(1-8) condition(1-6) "location" value "notes" "serial"
item-no part-of(item no., 0 = none) slot(0 none, 1-8 = slot 0-7, 9 aux).
Types: 1 Computer 2 Peripheral 3 Software 4 Accessory 5 Documents 6 Other
7 Card 8 Part. RETROINV2 files (9 lines, no last three) and the original
header-less format (8 lines) are still read.
