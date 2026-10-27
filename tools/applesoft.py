import sys

KW = """END FOR NEXT DATA INPUT DEL DIM READ GR TEXT PR# IN# CALL PLOT HLIN VLIN
HGR2 HGR HCOLOR= HPLOT DRAW XDRAW HTAB HOME ROT= SCALE= SHLOAD TRACE NOTRACE
NORMAL INVERSE FLASH COLOR= POP VTAB HIMEM: LOMEM: ONERR RESUME RECALL STORE
SPEED= LET GOTO RUN IF RESTORE & GOSUB RETURN REM STOP ON WAIT LOAD SAVE DEF
POKE PRINT CONT LIST CLEAR GET NEW TAB( TO FN SPC( THEN AT NOT STEP + - * / ^
AND OR > = < SGN INT ABS USR FRE SCRN( PDL POS SQR RND LOG EXP COS SIN TAN ATN
PEEK LEN STR$ VAL ASC CHR$ LEFT$ RIGHT$ MID$""".split()
assert 0x80 + len(KW) - 1 == 0xEA, len(KW)

def tokenize_line(text):
    out = bytearray()
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == ' ':
            i += 1
            continue
        if c == '"':
            j = text.find('"', i + 1)
            j = n if j < 0 else j + 1
            out += text[i:j].encode('ascii')
            i = j
            continue
        matched = None
        for t, kw in enumerate(KW):
            # match ignoring spaces, as Applesoft does
            k, m = i, 0
            while m < len(kw) and k < n:
                if text[k] == ' ':
                    k += 1
                    continue
                if text[k] != kw[m]:
                    break
                k += 1
                m += 1
            if m == len(kw):
                matched = (t, kw, k)
                break
        if matched:
            t, kw, k = matched
            out.append(0x80 + t)
            i = k
            if kw == 'REM':
                out += text[i:].encode('ascii')
                break
            if kw == 'DATA':
                j = i
                q = False
                while j < n and (q or text[j] != ':'):
                    if text[j] == '"':
                        q = not q
                    j += 1
                out += text[i:j].strip().encode('ascii')
                i = j
            continue
        out.append(ord(c))
        i += 1
    return out

def tokenize(src):
    prog = bytearray()
    addr = 0x0801
    for line in src.splitlines():
        line = line.rstrip()
        if not line:
            continue
        num, rest = line.split(' ', 1)
        body = tokenize_line(rest)
        rec_len = 4 + len(body) + 1
        nxt = addr + rec_len
        prog += nxt.to_bytes(2, 'little') + int(num).to_bytes(2, 'little') + body + b'\x00'
        addr = nxt
    prog += b'\x00\x00'
    return prog

def detok(prog):
    i = 0
    lines = []
    while True:
        nxt = int.from_bytes(prog[i:i+2], 'little')
        if nxt == 0:
            break
        num = int.from_bytes(prog[i+2:i+4], 'little')
        j = i + 4
        s = ''
        while prog[j] != 0:
            b = prog[j]
            s += (' ' + KW[b - 0x80] + ' ') if b >= 0x80 else chr(b)
            j += 1
        lines.append(f"{num} {s}")
        i = j + 1
    return lines

def hi(name):
    return bytes((ord(c) | 0x80) for c in name.ljust(30))

def make_dos33(files, volume=254):
    img = bytearray(35 * 16 * 256)
    used = set((t, s) for t in range(3) for s in range(16))
    used |= set((17, s) for s in range(16))
    def sec(t, s):
        o = (t * 16 + s) * 256
        return o
    alloc_t, alloc_s = 18, 15
    def alloc():
        nonlocal alloc_t, alloc_s
        while (alloc_t, alloc_s) in used:
            alloc_s -= 1
            if alloc_s < 0:
                alloc_s = 15
                alloc_t += 1
        used.add((alloc_t, alloc_s))
        return alloc_t, alloc_s
    # catalog chain T17 S15..S1
    for s in range(15, 0, -1):
        o = sec(17, s)
        if s > 1:
            img[o + 1], img[o + 2] = 17, s - 1
    entries = []
    for name, ftype, data in files:
        chunks = [data[k:k+256] for k in range(0, len(data), 256)] or [b'']
        tsl = alloc()
        pairs = []
        for ch in chunks:
            t, s = alloc()
            o = sec(t, s)
            img[o:o+len(ch)] = ch
            pairs.append((t, s))
        o = sec(*tsl)
        for k, (t, s) in enumerate(pairs):
            img[o + 0x0C + 2*k] = t
            img[o + 0x0D + 2*k] = s
        entries.append((tsl, ftype, name, len(pairs) + 1))
    o = sec(17, 15)
    for k, (tsl, ftype, name, cnt) in enumerate(entries):
        e = o + 0x0B + 35 * k
        img[e], img[e+1], img[e+2] = tsl[0], tsl[1], ftype
        img[e+3:e+33] = hi(name)
        img[e+33:e+35] = cnt.to_bytes(2, 'little')
    v = sec(17, 0)
    img[v+0] = 4
    img[v+1], img[v+2], img[v+3] = 17, 15, 3
    img[v+6] = volume
    img[v+0x27] = 122
    img[v+0x30], img[v+0x31] = 18, 1
    img[v+0x34], img[v+0x35] = 35, 16
    img[v+0x36], img[v+0x37] = 0x00, 0x01
    for t in range(35):
        bits = 0
        for s in range(16):
            if (t, s) not in used:
                bits |= 1 << s
        b = v + 0x38 + 4 * t
        img[b] = (bits >> 8) & 0xFF
        img[b+1] = bits & 0xFF
    return img

if __name__ == '__main__':
    src = open(sys.argv[1]).read()
    prog = tokenize(src)
    if '--list' in sys.argv:
        print('\n'.join(detok(prog)))
    data = len(prog).to_bytes(2, 'little') + prog
    img = make_dos33([('RETROINV', 0x02, data)])
    open(sys.argv[2], 'wb').write(img)
    print("program bytes:", len(prog))
