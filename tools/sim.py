"""Minimal enhanced Apple IIe for testing RETROINV.SYSTEM.

Emulates: 6502 (py65), 64K main + aux text page, 80STORE/PAGE2 banking,
ALTCHARSET MouseText, keyboard + Open-Apple, an AppleMouse in slot 4,
and the ProDOS MLI calls RetroInv uses, backed by a host directory.
"""
import os
from py65.devices.mpu6502 import MPU

MT = {0x40: '◉', 0x41: '◎', 0x42: '↖', 0x43: '⌛', 0x44: '✓', 0x45: '✔',
      0x46: '↵', 0x47: '⚇', 0x48: '←', 0x49: '…', 0x4A: '↓', 0x4B: '↑',
      0x4C: '▔', 0x4D: '↵', 0x4E: '█', 0x4F: '◀', 0x50: '▶', 0x51: '▼',
      0x52: '▲', 0x53: '─', 0x54: '└', 0x55: '→', 0x56: '▒', 0x57: '▒',
      0x58: '▛', 0x59: '▜', 0x5A: '▕', 0x5B: '◆', 0x5C: '═', 0x5D: '✚',
      0x5E: '▯', 0x5F: '▏'}

MSLOT = 4
ENTRY = {0x12: 'SET', 0x13: 'SERVE', 0x14: 'READ', 0x15: 'CLEAR',
         0x16: 'POS', 0x17: 'CLAMP', 0x18: 'HOME', 0x19: 'INIT'}


class Mem:
    def __init__(self, m):
        self.m = m

    def __getitem__(self, a):
        if isinstance(a, slice):
            return [self[i] for i in range(*a.indices(65536))]
        return self.m.read(a)

    def __setitem__(self, a, v):
        if isinstance(a, slice):
            for i, x in zip(range(*a.indices(65536)), v):
                self.m.write(i, x)
            return
        self.m.write(a, v)

    def __len__(self):
        return 65536


class Apple:
    def __init__(self, voldir, volname='RETROINV', mouse=True):
        self.main = bytearray(65536)
        self.aux = bytearray(65536)
        self.store80 = self.page2 = self.col80 = self.alt = False
        self.text = True
        self.hires = False
        self.keys = []          # pending (ascii, oa)
        self.latch = 0
        self.oa = False
        self.kbd_idle = 0
        self.mouse = mouse
        self.mx = self.my = 0
        self.mbtn = False
        self.clamp = [(0, 1023), (0, 1023)]
        self.voldir = voldir
        self.volname = volname
        self.prefix = ''
        self.files = {}
        self.types = {}         # file name -> ProDOS file type (default $04)
        self.quit = False
        self.mlilog = []
        self.capacity = None    # bytes of free space on the volume (None = plenty)
        self.startpath = ''     # pathname ProDOS leaves at $0280
        self.main[0xFBB3] = 0x06
        self.main[0xFBC0] = 0xE0
        self.cycles = 0
        self.mpu = MPU(memory=Mem(self))

    # ---- memory ---------------------------------------------------------
    def read(self, a):
        if 0x400 <= a < 0x800 and self.store80 and self.page2:
            return self.aux[a]
        if 0xC000 <= a < 0xC100:
            return self.io(a, None)
        if 0xC100 <= a < 0xD000:
            hi = a >> 8
            if self.mouse and hi == 0xC0 + MSLOT:
                lo = a & 0xFF
                if lo == 0x0C:
                    return 0x20
                if lo == 0xFB:
                    return 0xD6
                if 0x12 <= lo <= 0x19:
                    return 0x80 + lo        # entry points at $C492.. etc.
                return 0x60                 # RTS everywhere else
            return 0xFF
        return self.main[a]

    def write(self, a, v):
        if 0x400 <= a < 0x800 and self.store80 and self.page2:
            self.aux[a] = v
            return
        if 0xC000 <= a < 0xC100:
            self.io(a, v)
            return
        if a >= 0xC000:
            return
        self.main[a] = v

    def io(self, a, v):
        if a == 0xC000:
            if v is None:
                if self.latch == 0 and self.keys:
                    ch, oa = self.keys.pop(0)
                    self.latch = ch | 0x80
                    self.oa = oa
                if self.latch == 0:
                    self.kbd_idle += 1
                else:
                    self.kbd_idle = 0
                return self.latch
            self.store80 = False
        elif a == 0xC001 and v is not None:
            self.store80 = True
        elif a == 0xC00C and v is not None:
            self.col80 = False
        elif a == 0xC00D and v is not None:
            self.col80 = True
        elif a == 0xC00E and v is not None:
            self.alt = False
        elif a == 0xC00F and v is not None:
            self.alt = True
        elif a == 0xC010:
            self.latch &= 0x7F
            if self.latch:
                self.latch = 0
        elif a == 0xC050:
            self.text = False
        elif a == 0xC051:
            self.text = True
        elif a == 0xC054:
            self.page2 = False
        elif a == 0xC055:
            self.page2 = True
        elif a == 0xC056:
            self.hires = False
        elif a == 0xC057:
            self.hires = True
        elif a in (0xC061, 0xC062):
            return 0x80 if self.oa else 0
        return 0

    # ---- CPU loop with traps -------------------------------------------
    def rts(self):
        m = self.mpu
        lo = self.main[0x100 + ((m.sp + 1) & 0xFF)]
        hi = self.main[0x100 + ((m.sp + 2) & 0xFF)]
        m.sp = (m.sp + 2) & 0xFF
        return (hi << 8 | lo) + 1

    def step(self):
        m = self.mpu
        pc = m.pc
        if pc == 0xBF00:
            self.mli()
            return
        if self.mouse and (pc >> 8) == 0xC0 + MSLOT:
            self.mousefw(pc & 0xFF)
            m.pc = self.rts()
            return
        if self.read(pc) == 0x00:
            raise RuntimeError('BRK at %04X' % pc)
        m.step()
        self.cycles += 1

    def run(self, maxsteps=5_000_000, until_idle=600):
        """Run until the program waits on the keyboard (or quits)."""
        self.kbd_idle = 0
        for _ in range(maxsteps):
            if self.quit:
                return 'quit'
            self.step()
            if self.kbd_idle >= until_idle and not self.keys:
                return 'idle'
        raise RuntimeError('did not go idle; pc=%04X' % self.mpu.pc)

    # ---- mouse firmware ----------------------------------------------
    def mousefw(self, lo):
        name = ENTRY.get(lo - 0x80)
        n = MSLOT
        if name == 'READ':
            self.main[0x478 + n] = self.mx & 0xFF
            self.main[0x578 + n] = self.mx >> 8
            self.main[0x4F8 + n] = self.my & 0xFF
            self.main[0x5F8 + n] = self.my >> 8
            self.main[0x778 + n] = 0x80 if self.mbtn else 0
        elif name == 'CLAMP':
            axis = self.mpu.a
            lo_ = self.main[0x478] | self.main[0x578] << 8
            hi_ = self.main[0x4F8] | self.main[0x5F8] << 8
            self.clamp[axis] = (lo_, hi_)
        elif name == 'POS':
            self.mx = self.main[0x478 + n] | self.main[0x578 + n] << 8
            self.my = self.main[0x4F8 + n] | self.main[0x5F8 + n] << 8
        self.mpu.p &= ~1

    # ---- ProDOS MLI ----------------------------------------------------
    def mli(self):
        m = self.mpu
        ret = self.rts()
        cmd = self.main[ret]
        pb = self.main[ret + 1] | self.main[ret + 2] << 8
        err = self.mlicall(cmd, pb)
        self.mlilog.append((cmd, err))
        m.a = err
        if err:
            m.p |= 1
            m.p &= ~2
        else:
            m.p &= ~1
            m.p |= 2
        m.pc = ret + 3

    def rd16(self, a):
        return self.main[a] | self.main[a + 1] << 8

    def path(self, pb):
        p = self.rd16(pb + 1)
        n = self.main[p]
        name = bytes(self.main[p + 1:p + 1 + n]).decode()
        if not name.startswith('/'):
            name = self.prefix + name
        parts = name.strip('/').split('/')
        if not parts or parts[0] != self.volname:
            return None
        return os.path.join(self.voldir, *parts[1:])

    def used(self, extra_path=None, extra_len=0):
        tot = 0
        names = set(os.listdir(self.voldir))
        for n in names:
            fp = os.path.join(self.voldir, n)
            ln = os.path.getsize(fp)
            for f in self.files.values():
                if f['p'] == fp and not f.get('dir'):
                    ln = len(f['d'])
            if fp == extra_path:
                ln = max(ln, extra_len)
            tot += (ln + 511) // 512 + 1
        return tot * 512

    def mlicall(self, cmd, pb):
        mm = self.main
        if cmd == 0x65:
            self.quit = True
            return 0
        if cmd == 0xC7:                 # GET_PREFIX
            buf = self.rd16(pb + 1)
            p = self.prefix.encode()
            mm[buf] = len(p)
            mm[buf + 1:buf + 1 + len(p)] = p
            return 0
        if cmd == 0xC6:                 # SET_PREFIX
            buf = self.rd16(pb + 1)
            n = mm[buf]
            np = bytes(mm[buf + 1:buf + 1 + n]).decode()
            if not np.startswith('/'):
                np = self.prefix + np
            if not np.endswith('/'):
                np += '/'
            self.prefix = np
            return 0
        if cmd == 0xC5:                 # ON_LINE
            buf = self.rd16(pb + 2)
            v = self.volname.encode()
            mm[buf] = 0x60 | len(v)
            mm[buf + 1:buf + 1 + len(v)] = v
            return 0
        if cmd == 0xC0:                 # CREATE
            p = self.path(pb)
            if p is None:
                return 0x45
            if os.path.exists(p):
                return 0x47
            open(p, 'wb').close()
            self.types[os.path.basename(p)] = mm[pb + 4]
            return 0
        if cmd == 0xC1:                 # DESTROY
            p = self.path(pb)
            if p is None or not os.path.exists(p):
                return 0x46
            os.remove(p)
            self.types.pop(os.path.basename(p), None)
            return 0
        if cmd == 0xC2:                 # RENAME
            p = self.path(pb)
            q = self.path(pb + 2)
            if p is None or q is None:
                return 0x40
            if not os.path.exists(p):
                return 0x46
            if os.path.exists(q):
                return 0x47
            os.rename(p, q)
            t = self.types.pop(os.path.basename(p), None)
            if t is not None:
                self.types[os.path.basename(q)] = t
            return 0
        if cmd == 0xC4:                 # GET_FILE_INFO
            p = self.path(pb)
            if p is None or not os.path.exists(p):
                return 0x46
            mm[pb + 4] = self.types.get(os.path.basename(p), 0x04)
            return 0
        if cmd == 0xCE:                 # SET_MARK
            f = self.files.get(mm[pb + 1])
            f['pos'] = mm[pb + 2] | mm[pb + 3] << 8 | mm[pb + 4] << 16
            return 0
        if cmd == 0xC8:                 # OPEN
            p = self.path(pb)
            if p is None:
                return 0x45
            if not os.path.exists(p):
                return 0x46
            if os.path.isdir(p):
                d = self.dirfile(p)
            else:
                d = bytearray(open(p, 'rb').read())
            self.files[1] = {'p': p, 'd': d, 'pos': 0, 'nl': None,
                             'dir': os.path.isdir(p)}
            mm[pb + 5] = 1
            return 0
        f = self.files.get(mm[pb + 1])
        if cmd in (0xC9, 0xCA, 0xCB, 0xCC, 0xD0) and f is None:
            return 0x43
        if cmd == 0xC9:                 # NEWLINE
            f['nl'] = (mm[pb + 2], mm[pb + 3])
            return 0
        if cmd == 0xCA:                 # READ
            buf, req = self.rd16(pb + 2), self.rd16(pb + 4)
            d, pos = f['d'], f['pos']
            if pos >= len(d):
                mm[pb + 6] = mm[pb + 7] = 0
                return 0x4C
            out = bytearray()
            while pos < len(d) and len(out) < req:
                b = d[pos]
                out.append(b)
                pos += 1
                if f['nl'] and (b & f['nl'][0]) == f['nl'][1]:
                    break
            f['pos'] = pos
            mm[buf:buf + len(out)] = out
            mm[pb + 6] = len(out) & 0xFF
            mm[pb + 7] = len(out) >> 8
            return 0
        if cmd == 0xCB:                 # WRITE
            buf, req = self.rd16(pb + 2), self.rd16(pb + 4)
            d, pos = f['d'], f['pos']
            data = bytes(mm[buf:buf + req])
            if self.capacity is not None and \
                    self.used(f['p'], pos + req) > self.capacity:
                room = len(d)
                while self.used(f['p'], room + 1) <= self.capacity:
                    room += 1
                if room > pos:
                    d[pos:room] = data[:room - pos]
                f['pos'] = max(pos, room)
                mm[pb + 6] = mm[pb + 7] = 0
                return 0x48
            d[pos:pos + req] = data
            f['pos'] = pos + req
            mm[pb + 6] = req & 0xFF
            mm[pb + 7] = req >> 8
            return 0
        if cmd == 0xD0:                 # SET_EOF
            eof = mm[pb + 2] | mm[pb + 3] << 8 | mm[pb + 4] << 16
            del f['d'][eof:]
            f['pos'] = min(f['pos'], eof)
            return 0
        if cmd == 0xCC:                 # CLOSE
            if not f.get('dir'):
                open(f['p'], 'wb').write(f['d'])
            del self.files[mm[pb + 1]]
            return 0
        return 0x01

    def dirfile(self, p):
        names = sorted(n for n in os.listdir(p)
                       if not n.startswith('.') and os.path.isfile(os.path.join(p, n)))
        ents = []
        for n in names:
            e = bytearray(39)
            e[0] = 0x10 | len(n)
            e[1:1 + len(n)] = n.encode()
            e[16] = self.types.get(n, 0x04)
            ents.append(bytes(e))
        hdr = bytearray(39)
        hdr[0] = 0xF0 | len(self.volname)
        hdr[1:1 + len(self.volname)] = self.volname.encode()
        slots = [bytes(hdr)] + ents
        out = bytearray()
        while slots:
            blk = bytearray(512)
            for i in range(13):
                if not slots:
                    break
                blk[4 + 39 * i:4 + 39 * (i + 1)] = slots.pop(0)
            out += blk
        return out

    # ---- input helpers -----------------------------------------------
    def key(self, ch, oa=False):
        if isinstance(ch, str):
            for c in ch:
                self.keys.append((ord(c), oa))
        else:
            self.keys.append((ch, oa))

    def mouse_to(self, col, row):
        self.mx = col * 4 + 1
        self.my = row * 8 + 3

    def click(self, col, row):
        """move, press, let the program see it, release"""
        self.mouse_to(col, row)
        self.run()
        self.mbtn = True
        self.run()
        self.mbtn = False
        self.run()

    # ---- screen ----------------------------------------------------------
    def cells(self):
        rows = []
        for y in range(24):
            base = 0x400 + (y % 8) * 0x80 + (y // 8) * 0x28
            row = []
            for x in range(80):
                mem = self.aux if x % 2 == 0 else self.main
                row.append(mem[base + x // 2])
            rows.append(row)
        return rows

    @staticmethod
    def decode(c):
        """screen code -> (char, inverse)"""
        if c >= 0x80:
            return chr(c & 0x7F) if (c & 0x7F) >= 0x20 else '?', False
        if c < 0x20:
            return chr(c + 0x40), True
        if c < 0x40:
            return chr(c), True
        if c < 0x60:
            return MT.get(c, '?'), False
        return chr(c), True

    def screen(self, mark_inverse=True):
        out = []
        for row in self.cells():
            s = ''
            for c in row:
                ch, iv = self.decode(c)
                if iv and mark_inverse:
                    ch = ch.lower() if ch.isalpha() and ch.isupper() else ch
                    ch = '\x1b[7m' + ch + '\x1b[0m'
                s += ch
            out.append(s)
        return '\n'.join(out)

    def plain(self):
        lines = []
        for row in self.cells():
            lines.append(''.join(self.decode(c)[0] for c in row))
        return '\n'.join(lines)

    def inverse_spans(self, y):
        row = self.cells()[y]
        return ''.join('#' if self.decode(c)[1] else '.' for c in row)

    def png(self, path, scale=2):
        from PIL import Image, ImageDraw, ImageFont
        font = ImageFont.truetype(
            '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 14)
        cw, chh = 9, 18
        img = Image.new('RGB', (80 * cw + 16, 24 * chh + 16), (0, 0, 0))
        d = ImageDraw.Draw(img)
        fg = (235, 235, 235)
        for y, row in enumerate(self.cells()):
            for x, c in enumerate(row):
                ch, iv = self.decode(c)
                px, py = 8 + x * cw, 8 + y * chh
                if iv:
                    d.rectangle([px, py, px + cw - 1, py + chh - 1], fill=fg)
                col = (0, 0, 0) if iv else fg
                if ch == '▔':
                    d.rectangle([px, py, px + cw - 1, py + 1], fill=col)
                elif ch == '▕':
                    d.rectangle([px + cw - 2, py, px + cw - 1, py + chh - 1], fill=col)
                elif ch == '▏':
                    d.rectangle([px, py, px + 1, py + chh - 1], fill=col)
                elif ch == '_':
                    d.rectangle([px, py + chh - 2, px + cw - 1, py + chh - 1], fill=col)
                elif ch == '▒':
                    for yy in range(py, py + chh, 2):
                        for xx in range(px + (yy // 2) % 2, px + cw, 2):
                            d.point((xx, yy), fill=col)
                elif ch == '█':
                    d.rectangle([px, py, px + cw - 1, py + chh - 1], fill=col)
                elif ch != ' ':
                    d.text((px, py + 1), ch, font=font, fill=col)
        img = img.resize((img.width * scale // 2 * 2 // 2, img.height), Image.NEAREST)
        img.save(path)


def boot(binpath, voldir, mouse=True, prefix='', startpath=''):
    a = Apple(voldir, mouse=mouse)
    a.prefix = prefix
    sp = startpath.encode()
    a.main[0x280] = len(sp)
    a.main[0x281:0x281 + len(sp)] = sp
    data = open(binpath, 'rb').read()
    a.main[0x2000:0x2000 + len(data)] = data
    a.mpu.pc = 0x2000
    a.mpu.sp = 0xFF
    return a
