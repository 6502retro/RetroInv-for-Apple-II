# Reproduce Scott's beta bugs in the simulator (run from the retroinv folder)
import sys, os, shutil
sys.path.insert(0, 'test'); sys.path.insert(0, 'tools')
from common import *
from sim import boot
V = 'test/vb'
def fresh(*names):
    shutil.rmtree(V, ignore_errors=True); os.makedirs(V)
    for n in names: shutil.copy('test/beta/' + n, V + '/' + n)
def go(last=None, cap=None, binp='build/RETROINV.SYSTEM', **kw):
    if last: open(V + '/RETROINV.LAST', 'wb').write(last.encode() + b'\r')
    a = boot(binp, V, **kw)
    for n in os.listdir(V):
        if n.startswith('S.'): a.types[n] = 0xF8
    a.capacity = cap
    a.run(); a.key(' '); a.run(); return a
def add2(a, name, val='', year='', notes='', loc=''):
    a.key('N', oa=True); a.run()
    a.key(name + '\t\t\t' + year + '\t\t\t\t\t' + loc + '\t' + val + '\t' + notes + '\r'); a.run()
def show(a, r0, r1): print(rows(a, r0, r1))
which = sys.argv[1:] or ['2', '3', '4', '5', '6', '7', '1']
if '2' in which:
    print('--- bug 2: short file'); fresh('T.TRUNC'); a = go('T.TRUNC'); show(a, 0, 1); show(a, 7, 16); show(a, 22, 23)
if '3' in which:
    print('--- bug 3: 200 items, save'); fresh('T.200')
    # rebuild a 200-item file from the 138-item one
    L = open(V + '/T.200', 'rb').read().split(b'\r')
    items = [L[2 + 12 * i:14 + 12 * i] for i in range(138)]
    for i in range(62):
        it = list(items[i]); it[0] = b'"Extra %d"' % (i + 1); it[9] = str(1000 + i).encode(); it[10] = b'0'; items.append(it)
    open(V + '/T.200', 'wb').write(b'\r'.join([b'RETROINV3', b'200'] + [x for it in items for x in it]) + b'\r')
    a = go('T.200'); show(a, 7, 16); a.key('\r'); a.run(); a.key('S', oa=True); a.run(); show(a, 0, 1); show(a, 22, 23)
    print('saved count line:', open(V + '/T.200', 'rb').read().split(b'\r')[1])
if '4' in which:
    print('--- bug 4: value 999999999'); fresh(); a = go()
    add2(a, 'Big', '999999999', '1985'); show(a, 4, 5); show(a, 7, 16); show(a,22,23)
if '5' in which:
    print('--- bug 5: totals'); fresh('T.OVERFLOW'); a = go('T.OVERFLOW'); show(a, 4, 9); show(a, 22, 23)
    a.key('R', oa=True); a.run(); show(a, 5, 20)
if '6' in which:
    print('--- bug 6: item no wrap'); fresh('T.MAXID'); a = go('T.MAXID'); show(a, 4, 10)
    add2(a, 'New A'); add2(a, 'New B'); show(a, 4, 12)
if '7' in which:
    print('--- bug 7: applesoft values/years'); fresh('T.APLSOFT'); a = go('T.APLSOFT'); show(a, 4, 12)
    a.key('R', oa=True); a.run(); show(a, 16, 20)
if '1' in which:
    print('--- bug 1: failed save'); fresh('SAMPLE')
    a = go('SAMPLE')
    used = a.used(); print('used', used)
    a.capacity = used + 512          # room for a little growth only
    for i in range(12): add2(a, 'Filler item number %d' % i, '12', '1990', 'A long note to use up space on the disk, quite long', 'Somewhere far')
    a.key('S', oa=True); a.run(); show(a, 7, 16); a.key('\r'); a.run(); show(a, 22, 23)
    L = open(V + '/SAMPLE', 'rb').read().split(b'\r'); print('file now says', L[1], 'items; lines', len(L))
    a.key('Q', oa=True); a.run(); show(a, 7, 16); a.key('D'); a.run(); print('quit', a.quit)
    a = go(cap=None); show(a, 0, 1); show(a, 22, 23)
