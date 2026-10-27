#!/bin/sh
# Build RETROINV.SYSTEM from source
set -e
cd "$(dirname "$0")"
CC65=${CC65:-/home/claude/cc65/bin}
mkdir -p build
B=$(python3 -c "d=open('build/splash.bin','rb').read(3); print(' '.join('-D SPL%d=\$%02X'%(i,b) for i,b in enumerate(d)))")
$CC65/ca65 -t none -I src $B -l build/retroinv.lst -o build/retroinv.o src/main.s
$CC65/ld65 -C src/retroinv.cfg -m build/retroinv.map -Ln build/retroinv.lbl -o build/RETROINV.SYSTEM build/retroinv.o
ls -l build/RETROINV.SYSTEM
# the item pools must hold MAXREC (138) records
python3 - <<'PY'
import re
m = open("build/retroinv.map").read()
end = int(re.search(r"^BSS +\w+ +(\w+)", m, re.M).group(1), 16) + 1
a = (0x3F70 - 0x0C00) // 171
b = (0xBB00 - end) // 171
print('pool A %d + pool B %d = %d records; %d bytes spare' % (a, b, a + b, (0xBB00 - end) - (138 - a) * 171))
assert a + b >= 138, 'not enough memory for 138 items'
PY
