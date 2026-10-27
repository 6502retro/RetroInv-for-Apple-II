from common import *
import friend, os
friend.build('test/vol/RETROINV.DAT')
S='/tmp/claude-0/-home-claude/4161c9de-27fa-5cd2-bffd-0c0cabd28634/scratchpad/'
a=start()
a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0B); a.key('\r'); a.run()      # By System
# go to the loose "80 column card" (after the systems): Find it
a.key('F',oa=True); a.run(); a.key('80 column\r'); a.run()
a.key('\r'); a.run()
print('== edit window'); print(rows(a,2,20))
# TAB to Part of (Name,Maker,Serial,Year,Type,Condition -> 6 tabs)
for _ in range(6): a.key('\t')
a.key(0x15); a.run()                 # -> first computer
print('== part of after one ->'); print(rows(a,9,12))
a.key('\t'); a.key(0x08); a.run()    # slot: back from None -> Aux slot
print(rows(a,9,12))
a.png(S+'edit.png')
a.key('\r'); a.run()
a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0B); a.key('\r'); a.run()      # By System again
print('== after move'); print(rows(a,4,8))
# mouse: open COMP003, click its Type right arrow -> Card (from Computer): Part-of resets; cancel
a.key('F',oa=True); a.run(); a.key('\x18COMP003\r'); a.run(); a.key('\r'); a.run()
a.click(20,10); a.run(); print('== comp003 type stepped by mouse:'); print(rows(a,10,12)); a.key(0x1B); a.run()
# delete COMP002 (5 parts)
a.key('F',oa=True); a.run(); a.key('\x18COMP002\r'); a.run()
a.key('D',oa=True); a.run(); print('== delete computer'); print(rows(a,9,16)); a.key('\r'); a.run()
a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0B); a.key('\r'); a.run()
print('== after delete'); print(rows(a,4,21)); print(rows(a,22,23))
# report
a.key('R',oa=True); a.run(); print('== report'); print(rows(a,2,23)); a.png(S+'report.png'); a.key(' '); a.run()
# save, reload
a.key('S',oa=True); a.run()
d=open('test/vol/RETROINV.DAT','rb').read().split(b'\r'); print('saved header', d[0], 'count', d[1], 'first item', d[2:14])
b=start(); b.key(0x1B); b.key(0x15); b.key(0x15); b.key(0x0B); b.key('\r'); b.run()
print('== reloaded'); print(rows(b,4,9)); print(rows(b,22,23))
