from common import *
import os
if os.path.exists("test/vol/RETROINV.DAT"): os.remove("test/vol/RETROINV.DAT")
a = start(); seed(a)
print("== loaded:"); print('\n'.join(plain(a).split('\n')[4:8])); print(plain(a).split('\n')[22])
# mouse: press on 'Sort' title, drag to 'By Value', release
a.mouse_to(17,0); a.run(); a.mbtn=True; a.run()
a.mouse_to(17,6); a.run()
print("== sort menu open, hovering By Value:"); print('\n'.join(a.screen().split('\n')[0:9]))
a.mbtn=False; a.run()
print("== after sort by value:"); print('\n'.join(plain(a).split('\n')[4:8]))
# keyboard menu: ESC -> File, right x2 -> Sort, down to By Name, RETURN
a.key(0x1B); a.run(); a.key(0x15); a.key(0x15); a.run()
print("== ESC menu moved to Sort:"); print('\n'.join(a.screen().split('\n')[0:9]))
a.key(0x0D); a.run()
print("== sorted by name:"); print('\n'.join(plain(a).split('\n')[4:8]))
# find 'mecc'
a.key('F', oa=True); a.run(); a.key('mecc'); a.run()
print("== find dialog:"); print('\n'.join(plain(a).split('\n')[8:18]))
a.key(0x0D); a.run()
print("== found row:"); print(a.inverse_spans(4)[:10], a.inverse_spans(5)[:10], a.inverse_spans(6)[:10])
# report
a.key('R', oa=True); a.run()
print("== report:"); print('\n'.join(plain(a).split('\n')[2:22]))
a.key(' '); a.run()
# save
a.key('S', oa=True); a.run()
print("== status after save:", plain(a).split('\n')[22])
print(open('test/vol/RETROINV.DAT','rb').read())
# delete item 1 via click on menu Item > Delete (sticky click mode)
a.click(11,0)
print("== Item menu after click:"); print('\n'.join(plain(a).split('\n')[0:9]))
a.click(12,4)
print("== delete alert:"); print('\n'.join(plain(a).split('\n')[7:17]))
a.key(0x0D); a.run()
print('\n'.join(plain(a).split('\n')[4:8])); print(plain(a).split('\n')[22])
# quit -> prompt -> Don't save
a.key('Q', oa=True); a.run()
print("== quit prompt:"); print('\n'.join(plain(a).split('\n')[7:17]))
a.key('D'); r=a.run(); print('result', r, a.quit)
