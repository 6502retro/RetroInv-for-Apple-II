from common import *
import os
# a file in the Applesoft program's format (as BASIC.SYSTEM writes it)
open('test/vol/RETROINV.DAT','wb').write(b'3\r"Apple ][+"\r"Apple"\r"1979"\r1\r2\r"Den"\r1200\r""\r"Mockingboard"\r"Sweet Micro"\r""\r2\r1\r"Box B"\r.5\r"A, B: C"\r"ImageWriter II"\r"Apple"\r"1985"\r2\r5\r""\r75.25\r"needs ribbon"\r')
a = start()
print(rows(a,4,8)); print(rows(a,22,23))
# mouse: click row 2 (select), click again (open editor)
a.click(10,5); a.click(10,5)
print("== editor via double click:"); print(rows(a,2,21))
# click type right arrow twice, condition left arrow, click Value field and type, click OK
a.click(32,10); a.click(32,10); a.click(16,11)
a.click(20,14); a.key('\x18'+'149.95'); a.run()
print(rows(a,8,14))
a.click(61,18)
print(rows(a,4,8)); print(rows(a,22,23))
