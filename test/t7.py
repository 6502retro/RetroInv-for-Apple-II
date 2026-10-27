from common import *
import os
TY={'INVENTORY':0xF8,'HANDMADE':0xF8,'SAMPLE.BILL':0xF8}
def boot2():
    a=start(); a.types.update(TY); return a
# 1. picker + round trip of the exported sheet
a=boot2()
a.key('I',oa=True); a.run(); print(rows(a,4,16))
a.key('\r'); a.run(); print(rows(a,6,17))
a.key('\r'); a.run(); print(rows(a,6,17))
a.key('\r'); a.run(); print(rows(a,4,11)); print(rows(a,22,23))
a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run(); print(rows(a,4,18)); a.key(0x1B); a.run()
# 2. the hand-made sheet (pick with the mouse: row 2 of the list, click twice)
a.key('I',oa=True); a.run()
a.click(30,10); a.click(30,10); a.run()
a.key('\r'); a.run(); print(rows(a,9,14)); a.key('\r'); a.run()
print(rows(a,4,12)); print(rows(a,22,23))
for i in range(3):
    a.key('\r'); a.run(); print(rows(a,4,18)); a.key(0x1B); a.key(0x0A); a.run()
# 3. a sheet that isn't an inventory
a.key('I',oa=True); a.run(); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run(); a.key('\r'); a.run(); print(rows(a,7,17))
