"""Build the RetroInv hi-res splash (280x192 Apple II hi-res, 8192 bytes)
from the 6502 Retro Computing logo, plus a PNG preview."""
import sys
from PIL import Image

SRC, OUT_BIN, OUT_PNG = sys.argv[1], sys.argv[2], sys.argv[3]

BLACK, WHITE, GREEN, VIOLET, ORANGE, BLUE = range(6)
W, H = 280, 192
pix = [[BLACK] * W for _ in range(H)]

src = Image.open(SRC).convert('RGB')
sw, sh = src.size
k = sw / 2538.0                      # measurements below are for a 2538 px logo

# ---- logo geometry (source px) -> screen --------------------------------
BOX_X0, BOX_X1 = 140 * k, 2398 * k   # white box / stripe band
TOP = 276 * k                         # top of the green "6502"
STR_Y0, STR_Y1 = 1180 * k, 1319 * k  # stripe band
BOX_Y1 = 2397 * k
X0, XW = 56, 168                      # byte-aligned target (bytes 8..31)
sx = XW / (BOX_X1 - BOX_X0)
sy = sx / 1.094                       # Apple II pixels are taller than wide
Y0 = 5

def to_src(x, y):
    return BOX_X0 + (x - X0 + 0.5) / sx, TOP + (y - Y0 + 0.5) / sy

def classify(rgb):
    r, g, b = rgb
    if r > 200 and g > 200 and b > 200:
        return WHITE
    if g > r + 25 and g > b + 25 and g > 110:
        return GREEN
    return BLACK

stripe_top = Y0 + round((STR_Y0 - TOP) * sy)
stripe_bot = Y0 + round((STR_Y1 - TOP) * sy)
box_bot = Y0 + round((BOX_Y1 - TOP) * sy)

for y in range(Y0, box_bot):
    for x in range(X0, X0 + XW):
        if stripe_top <= y < stripe_bot:
            continue
        fx, fy = to_src(x, y)
        if 0 <= fx < sw and 0 <= fy < sh:
            pix[y][x] = classify(src.getpixel((int(fx), int(fy))))

# stripes: green, yellow, orange, red, violet, blue (byte aligned, 28 px each)
for i in range(6):
    for y in range(stripe_top, stripe_bot):
        odd_row = (y - stripe_top) % 2
        c = [GREEN, (ORANGE if odd_row == 0 else WHITE), ORANGE,
             (ORANGE if odd_row == 0 else VIOLET), VIOLET, BLUE][i]
        for x in range(X0 + 28 * i, X0 + 28 * (i + 1)):
            pix[y][x] = c

# ---- small blocky font for the caption lines -----------------------------
FONT = {
 'A': [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
 'C': [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
 'E': ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
 'I': ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
 'K': ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
 'L': ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
 'N': ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
 'O': [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
 'P': ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
 'R': ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
 'S': [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
 'T': ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
 'V': ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
 'Y': ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
 'B': ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
 '0': [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
 '1': ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
 '2': [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
 '3': ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
 '4': ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
 '5': ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
 '6': ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
 '.': [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
 '-': [".....", ".....", ".....", "#####", ".....", ".....", "....."],
 ' ': ["....."] * 7,
}

def text(s, y, color=WHITE):
    pitch = 12
    x = (W - (len(s) * pitch - 2)) // 2
    for ch in s:
        g = FONT[ch]
        for r in range(7):
            for c in range(5):
                if g[r][c] == '#':
                    for d in range(2):
                        pix[y + r][x + 2 * c + d] = color
        x += pitch

text("RETROINV 2.5", 156)
text("COLLECTION INVENTORY", 169)
text("PRESS ANY KEY OR CLICK", 183)

# ---- encode as Apple II hi-res ------------------------------------------
def rowaddr(y):
    return (y % 8) * 0x400 + ((y // 8) % 8) * 0x80 + (y // 64) * 0x28

mem = bytearray(8192)
for y in range(H):
    base = rowaddr(y)
    for bx in range(40):
        cells = pix[y][bx * 7:bx * 7 + 7]
        pal = 0x80 if any(c in (ORANGE, BLUE) for c in cells) else 0
        b = 0
        for i, c in enumerate(cells):
            x = bx * 7 + i
            on = (c == WHITE or
                  (c in (GREEN, ORANGE) and x % 2 == 1) or
                  (c in (VIOLET, BLUE) and x % 2 == 0))
            if on:
                b |= 1 << i
        mem[base + bx] = b | pal
open(OUT_BIN, 'wb').write(mem)

# ---- simple colour preview of what the bytes produce --------------------
RGB = {0: (0, 0, 0), 'w': (255, 255, 255), (0, 0): (199, 52, 255),
       (0, 1): (20, 245, 60), (1, 0): (20, 207, 253), (1, 1): (255, 106, 60)}
prev = Image.new('RGB', (W * 2, H * 2))
for y in range(H):
    base = rowaddr(y)
    bits = []
    for bx in range(40):
        b = mem[base + bx]
        for i in range(7):
            bits.append(((b >> i) & 1, b >> 7))
    for x in range(W):
        on, pal = bits[x]
        if not on:
            c = RGB[0]
            if 0 < x < W - 1 and bits[x - 1][0] and bits[x + 1][0]:
                c = RGB[(bits[x - 1][1], (x - 1) % 2)]   # NTSC colour fill
        elif (x > 0 and bits[x - 1][0]) or (x < W - 1 and bits[x + 1][0]):
            c = RGB['w']
        else:
            c = RGB[(pal, x % 2)]
        for dx in range(2):
            for dy in range(2):
                prev.putpixel((x * 2 + dx, y * 2 + dy), c)
prev.save(OUT_PNG)
print("stripes", stripe_top, stripe_bot, "box bottom", box_bot)
