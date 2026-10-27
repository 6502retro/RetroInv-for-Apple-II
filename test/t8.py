from common import *
import os
def show(a, r0, r1): print('\n'.join(rows(a, r0, r1).split('\n')))
def ls(): print('  files:', sorted(os.listdir('test/vol')))
a=start()
print('== start:'); show(a,0,1)
add(a,'Apple IIe','Apple','1983',0,1,'Desk','300','','A2S2-1')
add(a,'Disk II','Apple','1978',1,0,'Shelf','100','','')
a.key('S',oa=True); a.run(); ls()
# Save As -> COMMODORE
a.key(0x1B); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.run()
show(a,0,12)
a.key('\r'); a.run(); show(a,9,17)
a.key('\x18commodore\r'); a.run(); show(a,0,1); ls()
print('  LAST =', open('test/vol/RETROINV.LAST','rb').read())
# New inventory (clean, no prompt)
a.key(0x1B); a.key("\r"); a.run(); show(a,0,1); show(a,22,23)
add(a,'C64','Commodore','1982',0,2,'Closet','150','','')
add(a,'1541','Commodore','1982',1,2,'Closet','60','','')
# Open while dirty+untitled -> prompt -> Save -> Save As dialog
a.key('O',oa=True); a.run(); show(a,9,16)
a.key('\r'); a.run(); show(a,9,17)       # Save chosen -> name dialog
a.key('\x18c64\r'); a.run(); show(a,4,16)   # now the Open picker
ls()
a.key(0x0A); a.key('\r'); a.run(); show(a,0,7)
print('  LAST =', open('test/vol/RETROINV.LAST','rb').read())
# Save As over another inventory -> replace prompt; over LAST / SYSTEM-like names -> refused
a.key(0x1B); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run()
a.key('\x18RETROINV.DAT\r'); a.run(); show(a,9,14); a.key(0x1B); a.run()
a.key('\x18RETROINV.LAST\r'); a.run(); show(a,9,14); a.key('\r'); a.run(); a.key(0x1B); a.run()
