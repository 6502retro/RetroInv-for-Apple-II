"""Screenshots for the manual, taken from the simulator with the SAMPLE inventory."""
import sys, os, shutil
sys.path.insert(0, 'test'); sys.path.insert(0, 'tools')
from common import *
from sim import boot
from PIL import Image, ImageDraw
V = 'test/vs'; OUT = sys.argv[1] if len(sys.argv) > 1 else 'manual'
def bezel(src, dst):
    im = Image.open(src).convert('RGBA'); w, h = im.size
    c = Image.new('RGBA', (w + 44, h + 44), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle([10, 10, w + 33, h + 33], radius=16, fill=(42, 42, 42, 255))
    c.paste(im, (22, 22)); c.save(dst)
def fresh():
    shutil.rmtree(V, ignore_errors=True); os.makedirs(V)
    shutil.copy('build/SAMPLE', V + '/SAMPLE'); shutil.copy('build/SAMPLE.INV', V + '/SAMPLE.INV')
    shutil.copy('build/SAMPLE', V + '/COMMODORE'); shutil.copy('build/SAMPLE', V + '/RETROINV.DAT')
    open(V + '/RETROINV.LAST', 'wb').write(b'SAMPLE\r')
def go():
    a = boot('build/RETROINV.SYSTEM', V, prefix='/RETROINV/', startpath='/RETROINV/RETROINV.SYSTEM')
    a.types['SAMPLE.INV'] = 0xF8
    a.run(); a.key(' '); a.run(); return a
def shot(a, name):
    a.png(OUT + '/' + name + '.png'); bezel(OUT + '/' + name + '.png', OUT + '/fig-' + name + '.png')
os.makedirs(OUT, exist_ok=True)
fresh(); a = go()
a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0B); a.key('\r'); a.run()      # Sort > By System
a.key('S', oa=True); a.run()
a.key(0x0A); a.key(0x0A); a.run(); a.mouse_to(70, 21); a.run(); shot(a, 'systems')
a.key(0x1B); a.key(0x15); a.key(0x0A); a.key(0x0A); a.run(); shot(a, 'menu')   # Item menu, Delete Item
a.key(0x1B); a.run()
a.key(0x0A); a.key('\r'); a.run(); shot(a, 'edit')
a.key(0x1B); a.run()
a.key('R', oa=True); a.run(); shot(a, 'report'); a.key('\r'); a.run()
a.key('O', oa=True); a.run(); shot(a, 'open'); a.key(0x1B); a.run()
a.key('X', oa=True); a.run(); shot(a, 'export'); a.key(0x1B); a.run()
a.key('I', oa=True); a.run(); shot(a, 'import'); a.key(0x1B); a.run()
add2 = lambda n: (a.key('N', oa=True), a.run())
a.key(0x1B); a.key(0x15); a.key(0x15); a.key('\r'); a.run()     # Sort > By Name: a change
a.key('Q', oa=True); a.run(); shot(a, 'savech')
shutil.copy('build/splash.png', OUT + '/splash.png'); bezel(OUT + '/splash.png', OUT + '/fig-splash.png')
print('ok')
