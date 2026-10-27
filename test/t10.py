from common import *
import friend, os
friend.build('test/vol/RETROINV.DAT')
a=start()
print('== loaded, list as in file'); print(rows(a,2,10)); print(rows(a,22,23))
a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0B); a.key('\r'); a.run()   # Sort > By System (last item)
print('== by system'); print(rows(a,0,22))
a.png('/tmp/claude-0/-home-claude/4161c9de-27fa-5cd2-bffd-0c0cabd28634/scratchpad/sys.png')
