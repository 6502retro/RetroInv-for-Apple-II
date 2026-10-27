# Drive Applesoft RetroInv under jsbasic: bt.run(files, keys) -> screens, files after
import json, os, shutil, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
def run(files, keys, prog=HERE + '/../src/RETROINV.BAS'):
    d = tempfile.mkdtemp()
    vol = d + '/vol'; os.makedirs(vol)
    for n, data in files.items(): open(vol + '/' + n, 'wb').write(data)
    json.dump(keys, open(d + '/k.json', 'w'))
    subprocess.run(['node', HERE + '/basrun.js', prog, vol, d + '/k.json', d + '/out.txt'], check=True, timeout=600)
    out = open(d + '/out.txt').read()
    after = {n: open(vol + '/' + n, 'rb').read() for n in os.listdir(vol)}
    shutil.rmtree(d)
    return out, after
