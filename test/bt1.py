import sys; sys.path.insert(0, '.')
import bt
fails = []
def check(w, ok):
    print(('PASS ' if ok else 'FAIL ') + w)
    if not ok: fails.append(w)
def inv(items, hdr=None):
    out = ['RETROINV3', str(hdr if hdr is not None else len(items))]
    for it in items:
        d = dict(name='X', maker='', year='', type=1, cond=3, loc='', val='0', notes='', serial='', no=0, part=0, slot=0); d.update(it)
        out += ['"%s"' % d['name'], '"%s"' % d['maker'], '"%s"' % d['year'], str(d['type']), str(d['cond']), '"%s"' % d['loc'],
                str(d['val']), '"%s"' % d['notes'], '"%s"' % d['serial'], str(d['no']), str(d['part']), str(d['slot'])]
    return ('\r'.join(out) + '\r').encode()
apl = open('beta/T.APLSOFT', 'rb').read()
# A. values and years written by Applesoft
out, f = bt.run({'RETROINV.DAT': apl}, [' ', 'x', '6~x', '7x', '8'])
rep = out.split('=== snapshot')[1]
check('A report: oldest is not the 2-digit year', 'OLDEST' not in rep or 'YEAR 85' not in rep.upper())
check('A report: top value is 1E+09 capped', '9999999.99' in rep)
d = f['RETROINV.DAT'].split(b'\r')
vals = [d[2 + 12 * i + 6] for i in range(7)]
check('A saved values are fixed-point: %s' % vals, all(b'E' not in v for v in vals) and vals[1] == b'0.00' and vals[3] == b'9999999.99')
check('A no temp file left', 'RETROINV.SAVING' not in f)
# B. more than 138 items: save asks for a new name
big = inv([dict(name='ITEM %d' % i, no=i + 1) for i in range(200)])
out, f = bt.run({'RETROINV.DAT': big}, [' ', '~x', '7~', 'big2\r', 'x', '8'])
s = out.split('=== snapshot')
check('B load says only first 138', 'ONLY THE FIRST 138' in s[1])
check('B save asks for a new name', 'NEW FILE NAME' in s[2])
check('B original keeps 200', f['RETROINV.DAT'].split(b'\r')[1] == b'200')
check('B BIG2 has 138', f.get('BIG2', b'').split(b'\r')[1:2] == [b'138'])
# C. short file
out, f = bt.run({'RETROINV.DAT': open('beta/T.TRUNC', 'rb').read()}, [' ', '~x', '8'])
s = out.split('=== snapshot')[1]
check('C short file reported', 'SHORTER THAN IT SAYS' in s and 'NEW FILE NAME' in s)
# D. adding: value with comma, 2-digit year refused, lowercase search, item no wrap
ids = inv([dict(name='Apple IIe', no=65534, type=1), dict(name='Disk II', no=65535, type=2)])
keys = [' ', 'x', '1', 'mockingboard\r', 'Sweet Micro\r', '\r', '85\r', '1983\r', '7', '3', '\r', '1,200\r', '\r', '65534\r', '4', '~x',
        '4', 'MOCKING\r', '~', '\r', '3~x', '7x', '8']
out, f = bt.run({'RETROINV.DAT': ids}, keys)
s = out.split('=== snapshot')
check('D 2-digit year refused', 'FOUR DIGITS' in s[1])
check('D new item got Item No. 1 (after 65535)', 'ITEM NO. 1 ADDED' in s[1])
check('D lowercase name found by capital search', '1 MATCH' in s[2])
d = f['RETROINV.DAT'].split(b'\r')
check('D value 1,200 saved as 1200.00: %s' % d[2 + 24 + 6], d[2 + 24 + 6] == b'1200.00')
check('D year saved as 1983', d[2 + 24 + 2] == b'"1983"')
check('D part of 65534, slot 4 (code 5)', d[2 + 24 + 10:2 + 24 + 12] == [b'65534', b'5'])
print(s[1][-900:])
print('\n%d failed' % len(fails)); [print(' -', x) for x in fails]
