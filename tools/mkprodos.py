import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from applesoft import tokenize

TOTAL = 280
img = bytearray(TOTAL * 512)
used = set(range(0, 7))  # boot 0-1, volume dir 2-5, bitmap 6
nxt = 7

def blk(n):
    return n * 512

def alloc():
    global nxt
    b = nxt
    nxt += 1
    used.add(b)
    return b

def pdate(y, m, d, hh, mm):
    w = ((y % 100) << 9) | (m << 5) | d
    return bytes([w & 0xFF, w >> 8, mm, hh])

DT = pdate(2026, 10, 21, 7, 0)

def name_bytes(n):
    return n.encode('ascii').ljust(15, b'\x00')

files = []

def add_file(name, ftype, aux, data):
    nblocks = (len(data) + 511) // 512 or 1
    if nblocks == 1:
        key = alloc()
        img[blk(key):blk(key) + len(data)] = data
        files.append((1, name, ftype, key, 1, len(data), aux))
    else:
        assert nblocks <= 256
        key = alloc()
        for i in range(nblocks):
            b = alloc()
            chunk = data[i * 512:(i + 1) * 512]
            img[blk(b):blk(b) + len(chunk)] = chunk
            img[blk(key) + i] = b & 0xFF
            img[blk(key) + 256 + i] = b >> 8
        files.append((2, name, ftype, key, nblocks + 1, len(data), aux))

def build(volname, out, boot=None):
    assert len(files) <= 12, 'only the first volume directory block is written'
    if boot:                        # ProDOS boot loader, blocks 0-1
        img[0:1024] = boot[:1024].ljust(1024, b'\x00')
    # volume directory chain 2..5
    for b in range(2, 6):
        o = blk(b)
        prev = b - 1 if b > 2 else 0
        nx = b + 1 if b < 5 else 0
        img[o:o + 2] = prev.to_bytes(2, 'little')
        img[o + 2:o + 4] = nx.to_bytes(2, 'little')
    h = blk(2) + 4
    img[h] = 0xF0 | len(volname)
    img[h + 1:h + 16] = name_bytes(volname)
    img[h + 24:h + 28] = DT
    img[h + 28] = 0
    img[h + 29] = 0
    img[h + 30] = 0xC3
    img[h + 31] = 0x27
    img[h + 32] = 0x0D
    img[h + 33:h + 35] = len(files).to_bytes(2, 'little')
    img[h + 35:h + 37] = (6).to_bytes(2, 'little')
    img[h + 37:h + 39] = TOTAL.to_bytes(2, 'little')
    for i, (st, name, ft, key, bu, eof, aux) in enumerate(files):
        e = h + 39 * (i + 1)
        img[e] = (st << 4) | len(name)
        img[e + 1:e + 16] = name_bytes(name)
        img[e + 16] = ft
        img[e + 17:e + 19] = key.to_bytes(2, 'little')
        img[e + 19:e + 21] = bu.to_bytes(2, 'little')
        img[e + 21:e + 24] = eof.to_bytes(3, 'little')
        img[e + 24:e + 28] = DT
        img[e + 28] = 0
        img[e + 29] = 0
        img[e + 30] = 0xE3
        img[e + 31:e + 33] = aux.to_bytes(2, 'little')
        img[e + 33:e + 37] = DT
        img[e + 37:e + 39] = (2).to_bytes(2, 'little')
    bm = blk(6)
    for b in range(TOTAL):
        if b not in used:
            img[bm + b // 8] |= 0x80 >> (b % 8)
    open(out, 'wb').write(img)

if __name__ == '__main__':
    # usage: mkprodos.py [--boot=blocks.bin] out.po VOLNAME file:NAME:TYPE:AUX ...
    args = sys.argv[1:]
    boot = None
    if args[0].startswith('--boot='):
        boot = open(args.pop(0)[7:], 'rb').read()
    out, vol = args[0], args[1]
    for spec in args[2:]:
        path, name, ft, aux = spec.split(':')
        data = open(path, 'rb').read()
        if ft == 'BAS':
            data = bytes(tokenize(data.decode()))
            ft, aux = '0xFC', '0x0801'
        add_file(name, int(ft, 16), int(aux, 16), data)
    build(vol, out, boot)
    print('blocks used', len(used), 'of', TOTAL)
