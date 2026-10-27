from common import *
import os, shutil
V='test/vol'
def show(a, r0, r1): print(rows(a, r0, r1))
# state left by t8: C64, COMMODORE, RETROINV.DAT, RETROINV.LAST(=COMMODORE)
print('1. startup reopens the last inventory'); a=start(); show(a,0,1); show(a,22,23)
# 2. remembered file deleted -> falls back to RETROINV.DAT
open(V+'/RETROINV.LAST','wb').write(b'GONE\r')
print('2. remembered file missing'); a=start(); show(a,0,1); show(a,22,23)
# 3. garbage in RETROINV.LAST
open(V+'/RETROINV.LAST','wb').write(b'2bad/name\r')
print('3. bad RETROINV.LAST'); a=start(); show(a,0,1)
# 4. old-format RETROINV.DAT listed; a plain text file and a Mouse Calc sheet are not
open(V+'/RETROINV.DAT','wb').write(b'1\r"Apple ][+"\r"Apple"\r"1979"\r1\r2\r"Den"\r1200\r""\r')
open(V+'/NOTES','wb').write(b'shopping list\rcables\r')
shutil.copy('tools/mcsamples/SAMPLE.BILL', V+'/SAMPLE.BILL')
a=start(); a.types['SAMPLE.BILL']=0xF8
a.key('O',oa=True); a.run(); print('4. open list'); show(a,8,14)
a.key(0x0A); a.key(0x0A); a.key('\r'); a.run(); show(a,0,1); show(a,4,5)   # RETROINV.DAT (old format)
# 5. revert on untitled does nothing; quit prompt names the file
a.key(0x1B); a.key('\r'); a.run()                        # New Inventory
add(a,'Test','X','2000',0,0,'','1','','')
a.key(0x1B); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run()   # Revert
print('5. revert untitled:'); show(a,4,5); show(a,22,23)
a.key('Q',oa=True); a.run(); show(a,10,12)
a.key(0x1B); a.run()   # cancel quit
# 6. Save As onto a write-protected disk keeps the old name
orig=a.mlicall
def wp(cmd,pb):
    if cmd in (0xC0,0xCB,0xD0): return 0x2B
    return orig(cmd,pb)
a.mlicall=wp
a.key(0x1B); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run(); a.key('\x18NEWONE\r'); a.run()
print('6. write-protected save as:'); show(a,9,14); a.key('\r'); a.run(); show(a,0,1); show(a,22,23)
a.mlicall=orig
print('   files:', sorted(os.listdir(V)))
# 7. quit -> Don't Save
a.key('Q',oa=True); a.run(); a.key('D'); print('7. quit:', a.run(), a.quit)
