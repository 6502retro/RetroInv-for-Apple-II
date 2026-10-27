import sys, re
sys.path.insert(0, 'tools')
from sim import boot
def plain(a): return re.sub(r'\x1b\[7m(.)\x1b\[0m', r'\1', a.screen())
def rows(a, r0, r1): return '\n'.join(plain(a).split('\n')[r0:r1])
def start(vol='test/vol'):
    a = boot('build/RETROINV.SYSTEM', vol); a.run(); a.key(' '); a.run(); return a
def add(a, name, maker, year, typ_right, cond_moves, loc, val, notes, serial=''):
    a.key('N', oa=True); a.run()
    a.key(name+'\t'+maker+'\t'+serial+'\t'+year+'\t')
    for _ in range(typ_right): a.key(0x15)
    a.key('\t')
    for _ in range(cond_moves): a.key(0x15)
    a.key('\t\t\t'+loc+'\t'+val+'\t'+notes+'\r'); a.run()   # (Part of, Slot)
def seed(a):
    add(a, 'Apple IIe Enhanced', 'Apple', '1985', 0, 1, 'Desk', '450', 'Platinum keyboard, 128K')
    add(a, 'Disk II', 'Apple', '1978', 1, 0, 'Shelf 2', '125.5', 'Works, cleaned heads')
    add(a, 'Oregon Trail', 'MECC', '1985', 2, 3, 'Box A', '$20', 'Original 5.25" disk')
    add(a, 'AppleMouse II', 'Apple', '1984', 1, 4, 'Drawer', '89.99', 'With card')
    add(a, 'Commodore 64', 'Commodore', '1982', 0, 3, 'Closet', '150', 'Breadbin')
