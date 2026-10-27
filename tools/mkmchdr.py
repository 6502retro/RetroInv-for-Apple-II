"""Build the Mouse Calc sheet header RetroInv writes on export.

Takes the 0x883-byte program-state header from a real Mouse Calc 1.1 sheet
(SAMPLE.BILL), sets RetroInv's column widths and on-screen column
positions the same way the Mouse Calc Converter does, and PackBits-packs
it for embedding in RETROINV.SYSTEM."""
import sys

HEADER_LEN = 0x883
WIDTHS_A, WIDTHS_B, POS_A = 0x29, 0x68, 0xA7
DEFAULT_WIDTH, MAX_COL = 11, 62
# A Name, B Maker, C Serial, D Year, E Type, F Condition, G Location, H Value,
# I Notes, J Slot, K Part Of, L Item No.
WIDTHS = [24, 14, 14, 6, 12, 11, 14, 13, 40, 10, 9, 10]

src, out_bin, out_raw = sys.argv[1], sys.argv[2], sys.argv[3]
h = bytearray(open(src, 'rb').read()[:HEADER_LEN])
widths = {c + 1: w for c, w in enumerate(WIDTHS)}
for c in range(1, MAX_COL + 1):
    w = widths.get(c, DEFAULT_WIDTH)
    v = 0xFF if w == DEFAULT_WIDTH else w
    h[WIDTHS_A + c] = v
    h[WIDTHS_B + c] = v
x = 3
for c in range(1, MAX_COL + 1):
    w = widths.get(c, DEFAULT_WIDTH)
    if x is not None and x + w <= 0x4F:
        h[POS_A + c] = x
        x += w
    else:
        h[POS_A + c] = 0xFF
        x = None
open(out_raw, 'wb').write(h)

def packbits(d):
    out, i = bytearray(), 0
    while i < len(d):
        j = i
        while j < len(d) and j - i < 128 and d[j] == d[i]:
            j += 1
        if j - i >= 3:
            out += bytes([257 - (j - i), d[i]])
            i = j
            continue
        lit = bytearray()
        while i < len(d) and len(lit) < 128:
            if i + 2 < len(d) and d[i] == d[i + 1] == d[i + 2]:
                break
            lit.append(d[i])
            i += 1
        out += bytes([len(lit) - 1]) + lit
    return bytes(out)

def unpack(p):
    out, i = bytearray(), 0
    while i < len(p):
        n = p[i]; i += 1
        if n < 128:
            out += p[i:i + n + 1]; i += n + 1
        else:
            out += bytes([p[i]]) * (257 - n); i += 1
    return bytes(out)

pk = packbits(bytes(h))
assert unpack(pk) == bytes(h)
open(out_bin, 'wb').write(pk)
print('header', len(h), 'packed', len(pk))
