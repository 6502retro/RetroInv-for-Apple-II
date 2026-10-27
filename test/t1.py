import sys, time
sys.path.insert(0, 'tools')
from sim import boot
a = boot('build/RETROINV.SYSTEM', 'test/vol')
t=time.time()
print(a.run(), 'hires' if a.hires and not a.text else 'text', round(time.time()-t,1),'s')
a.key(' ')
print(a.run(), round(time.time()-t,1),'s', 'mli', a.mlilog, 'prefix', a.prefix)
print(a.screen())
