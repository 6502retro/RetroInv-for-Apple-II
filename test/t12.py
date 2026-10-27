# RetroInv 2.5: checks for the fixes from Scott's beta test report
import sys, os, shutil
sys.path.insert(0, 'test'); sys.path.insert(0, 'tools')
from common import *
from sim import boot
V = 'test/vb'
fails = []
def check(what, ok):
    print(('PASS ' if ok else 'FAIL ') + what)
    if not ok: fails.append(what)
def fresh(*names):
    shutil.rmtree(V, ignore_errors=True); os.makedirs(V)
    for n in names: shutil.copy('test/beta/' + n, V + '/' + n)
def go(last=None, cap=None, **kw):
    if last: open(V + '/RETROINV.LAST', 'wb').write(last.encode() + b'\r')
    a = boot('build/RETROINV.SYSTEM', V, **kw)
    for n in os.listdir(V):
        if n.startswith('S.'): a.types[n] = 0xF8
    a.capacity = cap
    a.run(); a.key(' '); a.run(); return a
def add2(a, name, val='', year='', notes='', loc=''):
    a.key('N', oa=True); a.run()
    a.key(name + '\t\t\t' + year + '\t\t\t\t\t' + loc + '\t' + val + '\t' + notes + '\r'); a.run()
def scr(a): return plain(a)
def inv(items, hdr=None):
    out = ['RETROINV3', str(hdr if hdr is not None else len(items))]
    for it in items:
        d = dict(name='X', maker='', year='', type=1, cond=3, loc='', val='0', notes='', serial='', no=0, part=0, slot=0); d.update(it)
        out += ['"%s"' % d['name'], '"%s"' % d['maker'], '"%s"' % d['year'], str(d['type']), str(d['cond']), '"%s"' % d['loc'],
                str(d['val']), '"%s"' % d['notes'], '"%s"' % d['serial'], str(d['no']), str(d['part']), str(d['slot'])]
    return ('\r'.join(out) + '\r').encode()
def lines(n): return open(V + '/' + n, 'rb').read().split(b'\r')

# 1. failed save leaves the file alone
fresh('SAMPLE'); a = go('SAMPLE'); a.capacity = a.used() + 512
for i in range(12): add2(a, 'Filler item number %d' % i, '12', '1990', 'A long note to use up space on the disk, quite long', 'Somewhere far')
a.key('S', oa=True); a.run(); s = scr(a)
check('1 disk full: message says file not changed', 'The disk is full.' in s and 'was not changed' in s)
check('1 disk full: Saving... cleared', 'Saving' not in rows(a, 22, 23))
check('1 disk full: SAMPLE still has 13 items', lines('SAMPLE')[1] == b'13' and len(lines('SAMPLE')) == 2 + 13 * 12 + 1)
check('1 disk full: no temporary file left', not os.path.exists(V + '/RETROINV.SAVING'))
a.key('\r'); a.run(); a.capacity = None
a.key('S', oa=True); a.run()
check('1 save with room works', lines('SAMPLE')[1] == b'25' and not os.path.exists(V + '/RETROINV.SAVING'))

# 2. short file
fresh('T.TRUNC'); a = go('T.TRUNC'); s = scr(a)
check('2 short file warns', "doesn't hold the number" in s)
check('2 short file opens Untitled', 'Untitled' in rows(a, 0, 1))
open(V + '/LONG', 'wb').write(inv([dict(name='A', no=1), dict(name='B', no=2), dict(name='C', no=3)], hdr=2))
a = go('LONG'); check('2 file with extra items warns', "doesn't hold the number" in scr(a))

# 3. more than 138 items
fresh(); open(V + '/BIG', 'wb').write(inv([dict(name='Item %d' % i, no=i + 1) for i in range(200)]))
a = go('BIG'); s = scr(a)
check('3 over-full file warns and opens Untitled', 'more than 138' in s and 'Untitled' in s)
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
check('3 Save goes to Save As', 'Save this inventory under a new' in scr(a))
a.key(0x1B); a.run()
check('3 BIG still has 200', lines('BIG')[1] == b'200')
check('3 status shows "138 of 138 items"', '138 of 138 items' in rows(a, 22, 23))

# 4/5. value limit and totals
fresh(); a = go(); add2(a, 'Big', '999999999', '1985'); s = scr(a)
check('4 value over the limit refused', 'largest value' in s)
a.key('\r'); a.run(); a.key(0x18 + 0); a.key('9999999.99\r'); a.run()
check('4 $9,999,999.99 accepted and shown in full', '$9999999.99' in rows(a, 4, 5))
fresh('T.OVERFLOW'); a = go('T.OVERFLOW')
check('5 status total $49999999.95', '$49999999.95' in rows(a, 22, 23))
a.key('R', oa=True); a.run(); s = scr(a)
check('5 report total $49999999.95', s.count('$49999999.95') >= 2)

# 6. item numbers
fresh(); open(V + '/IDS', 'wb').write(inv([dict(name='A', no=65534), dict(name='B', no=65535), dict(name='C', no=1)]))
a = go('IDS'); add2(a, 'New 1'); add2(a, 'New 2')
a.key('S', oa=True); a.run(); L = lines('IDS'); nos = [L[2 + 12 * i + 9] for i in range(5)]
check('6 new numbers skip 0 and used ones: %s' % nos, nos[3:] == [b'2', b'3'])
check('6 five-digit numbers line up', rows(a, 4, 5)[:6] == '65534 ' or rows(a, 5, 6)[:6] == '65534 ')
open(V + '/IDS', 'wb').write(inv([dict(name='A', no=70000, part=0), dict(name='B', no=5)]))
a = go('IDS'); a.key('S', oa=True); a.run(); L = lines('IDS')
check('6 Item No. over 65535 is renumbered: %s' % L[11], L[11] not in (b'4464', b'0'))

# 7. Applesoft numbers and years
fresh('T.APLSOFT'); a = go('T.APLSOFT'); s = scr(a)
r = {l.split()[2] if len(l.split()) > 2 else '': l for l in s.split('\n')}
check('7 1E-03 is $0.00 (blank)', '$' not in [l for l in s.split('\n') if 'Val 1E-03' in l][0])
check('7 1E+09 is capped at $9999999.99', '$9999999.99' in [l for l in s.split('\n') if 'Val 1E+09' in l][0])
open(V + '/E', 'wb').write(inv([dict(name='E1', val='1.5E+03'), dict(name='E2', val='1234.567'), dict(name='E3', val='2.5E-02')]))
a2 = go('E'); s2 = scr(a2)
check('7 1.5E+03 -> $1500.00', '$1500.00' in s2)
check('7 1234.567 rounds to $1234.57', '$1234.57' in s2)
check('7 2.5E-02 -> $0.03', '$0.03' in s2)
a.key('R', oa=True); a.run(); s = scr(a)
check('7 two-digit year is not the oldest', 'Year 85' not in s)
a.key('\r'); a.run(); add2(a, 'Two digit', '', '85'); s = scr(a)
check('7 typing a 2-digit year is refused', 'four' in s and 'digits' in s)

# smaller issues
fresh('SAMPLE'); a = go('SAMPLE')
a.key('Q'); r_ = a.run(); check('plain Q does nothing', not a.quit and 'Save changes' not in scr(a))
add2(a, 'Thing'); a.key('Q', oa=True); a.run()
a.key('\t'); a.run(); s = scr(a)
check('Tab moves the default button', 'don\'t save' in s.lower() and 'Don\'t Save' not in s)
a.key('\r'); r_ = a.run(); check('RETURN on Don\'t Save quits', a.quit)

# RETROINV.LAST naming a Mouse Calc sheet
fresh('S.HOSTILE', 'SAMPLE'); shutil.copy(V + '/SAMPLE', V + '/RETROINV.DAT')
a = go('S.HOSTILE'); check('LAST -> Mouse Calc sheet is ignored', 'RETROINV.DAT' in rows(a, 0, 1))

# launched by path from another folder
fresh(); os.makedirs(V + '/SUB'); shutil.copy('test/beta/SAMPLE', V + '/SUB/RETROINV.DAT')
a = go(prefix='/RETROINV/', startpath='/RETROINV/SUB/RETROINV.SYSTEM')
check('uses its own folder when launched by pathname', '13 of 138' in rows(a, 22, 23))

# Mouse Calc import headings
fresh('S.COLLIDE'); a = go()
a.key('I', oa=True); a.run(); a.key('\r'); a.run(); a.key('\r'); a.run(); a.key('\r'); a.run()
a.key('E', oa=True); a.run(); s = scr(a)
check('import: Notes from "Notes", not "Not for sale"', 'real note A' in s)
check('import: Year from "Year", not "Year bought"', '1983' in s and '2019' not in s)
check('import: "Part No." is not Part Of', 'None' in s)
a.key(0x1B); a.run()

# Open list: other text files don't take places; more than 14; buttons on screen
fresh()
for i in range(10): open(V + '/NOTE%d' % i, 'wb').write(b'just text\r')
for i in range(3): open(V + '/INV%d' % i, 'wb').write(inv([dict(name='I%d' % i, no=1)]))
a = go(); a.key('O', oa=True); a.run(); s = scr(a)
check('Open lists all 3 inventories among 10 text files', all('INV%d' % i in s.upper() for i in range(3)) and 'NOTE' not in s.upper())
a.key(0x1B); a.run()
for i in range(3, 18): open(V + '/INV%d' % i, 'wb').write(inv([dict(name='I%d' % i, no=1)]))
a = go(); a.key('O', oa=True); a.run(); s = scr(a)
check('Open with 18 inventories says only 14 listed', 'Only the first 14' in s)
check('Open buttons on screen', 'open' in rows(a, 21, 22).lower() and 'Cancel' in rows(a, 21, 22))
a.png('test/vb_open.png')
print('\n%d failed' % len(fails)); [print(' -', f) for f in fails]
