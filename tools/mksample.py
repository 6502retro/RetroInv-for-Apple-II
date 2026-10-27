"""Write the SAMPLE inventory (RETROINV3) shipped on the RetroInv disk:
two complete systems plus a few loose items."""
import sys
# type codes 1-8 and slot codes (0 none, 1-8 = slot 0-7, 9 = aux slot)
C, P, S, A, D, O, K, R = 1, 2, 3, 4, 5, 6, 7, 8
ITEMS = [
 # name, maker, year, type, cond, location, value, notes, serial, item no., part of, slot
 ('Apple IIe Enhanced', 'Apple', '1985', C, 2, 'Desk', '450.00', 'Platinum keyboard, 128K', 'A2S2-655123', 1, 0, 0),
 ('Extended 80-Column Card', 'Apple', '1983', K, 2, '', '35.00', '64K', '', 2, 1, 9),
 ('Super Serial Card', 'Apple', '1981', K, 3, '', '40.00', '', '', 3, 1, 3),
 ('AppleMouse II Card', 'Apple', '1984', K, 3, '', '45.00', 'Mouse in drawer', '', 4, 1, 5),
 ('Disk II Controller', 'Apple', '1978', K, 3, '', '60.00', '', '', 5, 1, 7),
 ('Disk II Drive', 'Apple', '1978', P, 3, 'Desk', '125.50', 'Cleaned heads', '', 6, 1, 0),
 ('IIe Power Supply', 'Apple', '1983', R, 3, '', '30.00', 'Recapped', '', 7, 1, 0),
 ('Apple IIGS ROM 3', 'Apple', '1989', C, 2, 'Den', '600.00', '4 MB', '', 8, 0, 0),
 ('AppleColor RGB Monitor', 'Apple', '1986', P, 3, 'Den', '150.00', '', '', 9, 8, 0),
 ('Apple 3.5 Drive', 'Apple', '1986', P, 4, 'Den', '80.00', 'Slow eject', '', 10, 8, 0),
 ('Oregon Trail', 'MECC', '1985', S, 6, 'Box A', '20.00', "Original 5.25' disk", '', 11, 0, 0),
 ('Kraft Joystick', 'Kraft', '1982', A, 5, 'Drawer', '5.00', '', '', 12, 0, 0),
 ('AppleWorks 3.0 Manual', 'Claris', '1989', D, 2, 'Shelf', '15.00', '', '', 13, 0, 0),
]
out = ['RETROINV3', str(len(ITEMS))]
q = lambda s: '"%s"' % s
for (n, m, y, t, c, l, v, no, sn, num, par, sl) in ITEMS:
    out += [q(n), q(m), q(y), str(t), str(c), q(l), v, q(no), q(sn), str(num), str(par), str(sl)]
open(sys.argv[1], 'wb').write(('\r'.join(out) + '\r').encode())
