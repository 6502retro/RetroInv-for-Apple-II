from common import *
import random, time
random.seed(2)
names=['Apple IIe','Apple IIc','Apple IIgs','Disk II','Duodisk','Mockingboard','Z-80 SoftCard','Super Serial','Grappler+','Thunderclock','Choplifter','Karateka','Lode Runner','AppleWorks','Print Shop','TRS-80 Model I','Atari 800XL','VIC-20','Commodore 64','BBC Micro']
n=240
lines=[str(n)]
for i in range(n):
    lines += ['"%s #%d"'%(random.choice(names),i), '"%s"'%random.choice(['Apple','Commodore','Atari','Broderbund','Tandy']), '"%d"'%random.randint(1977,1990), str(random.randint(1,6)), str(random.randint(1,6)), '"Shelf %d"'%random.randint(1,9), '%d.%02d'%(random.randint(0,900),random.randint(0,99)), '"note %d"'%i]
open('test/vol/RETROINV.DAT','wb').write(('\r'.join(lines)+'\r').encode())
def mhz(a, i0): return (a.cycles-i0)*3.2/1_020_000
a = boot('build/RETROINV.SYSTEM','test/vol'); a.run(); a.key(' ')
i0=a.cycles; a.run(); print('load ~%.1fs on a 1MHz IIe'%mhz(a,i0))
a.key('\r'); a.run(); print(rows(a,22,23))
for k in range(3): a.key(0x15)       # page down x3
a.run(); print(rows(a,4,6)); print(rows(a,19,21))
a.click(79,20); a.click(79,4); a.click(79,6)  # scroll down, up, page up
print('sel row visible:', [r for r in range(4,21) if a.inverse_spans(r)[5]=='#'])
i0=a.cycles; a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0D); a.run(); print('sort by name ~%.1fs'%mhz(a,i0))
print(rows(a,4,8))
i0=a.cycles; a.key('S', oa=True); a.run(); print('save ~%.1fs'%mhz(a,i0), rows(a,22,23))
a.key('N', oa=True); a.run(); print(rows(a,9,14))
a.key('\r'); a.run()
d=open('test/vol/RETROINV.DAT','rb').read().split(b'\r'); print('saved count line', d[0], 'lines', len(d))
