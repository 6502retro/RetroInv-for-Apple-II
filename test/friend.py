"""Build a RETROINV3 inventory from the friend's card spreadsheet."""
CAT = {  # Card_ID: (name, maker, common slot)
 'DIIR':('Disk II Controller Ribbon','Apple'), 'DII19':('Disk II Controller DB19','Apple'),
 'SSC':('Super Serial Card',''), 'AMC':('Apple Mouse Card','Apple'), 'LEGO':('LEGO Interface','China'),
 'ROM':('RomCard670',''), 'IO16':('Generic 16ch I/O board','Mountain Computing'),
 'PRINTF':('Printerface Card','Practical Peripherals'), 'PROTOG':('Generic Prototyping board',''),
 'AIIE80COL':('80 Column card','Apple'), 'AIIE80COL64':('80 Column card with 64k','Apple'),
 'MINISAM':('Mini SAM Voice syntesizer','David Mutimer'), 'A2DVI':('HDMI Display adapter','Chris Auger'),
 'Uthernet':('Ethernet Adapter Uthernet II','Glenn Jones')}
CARDS = [  # id, card, cond, status, computer, slot, notes
 (1,'ROM','Good','Installed','COMP003',1,'Came in A2Plus'),(2,'DII19','Good','Installed','COMP007',6,''),
 (3,'SSC','Good','Installed','COMP001',2,''),(4,'DII19','Good','Installed','COMP001',6,''),
 (5,'IO16','Good','Installed','COMP002',1,''),(6,'SSC','Good','Installed','COMP002',2,'DB25'),
 (7,'LEGO','Good','Shelf','COMP002',3,'On loan, Evan'),(8,'DII19','Good','Installed','COMP002',5,''),
 (9,'DIIR','Good','Installed','COMP002',6,''),(10,'LEGO','Good','Installed','COMP006',7,''),
 (11,'PRINTF','Good','Shelf','',None,'Untested'),(12,'PROTOG','Good','Shelf','',None,'Untested'),
 (13,'AIIE80COL','Good','Shelf','',None,'Untested'),(14,'AIIE80COL64','Good','Shelf','',None,'Untested'),
 (15,'MINISAM','Good','Shelf','',None,'Untested'),(16,'DIIR','Good','Shelf','',None,''),
 (17,'DII19','Good','Shelf','COMP006',6,''),(18,'SSC','Good','Shelf','',None,'Non-typical cable. Need test.'),
 (19,'SSC','Good','Shelf','COMP006',2,''),(20,'AMC','Good','Shelf','',None,'Untested'),
 (21,'A2DVI','Excellent','Installed','COMP006',1,''),(22,'Uthernet','Excellent','Shelf','',None,''),
 (23,'Uthernet','Excellent','Installed','COMP006',3,'')]
COND = ['Mint','Excellent','Good','Fair','Poor','For Parts']
def q(s): return '"%s"' % s
def build(path):
    items = []
    comps = sorted({c[4] for c in CARDS if c[4]})
    cid = {}
    for n, c in enumerate(comps, 1):
        cid[c] = n
        items.append([q(c), q(''), q(''), '1', '3', q('Desk'), '0.00', q('Placeholder computer'), q(''), str(n), '0', '0'])
    for (i, card, cond, status, comp, slot, notes) in CARDS:
        name, maker = CAT[card]
        loc = 'Shelf' if status == 'Shelf' else ''
        # his CARD001 becomes Item No. 101, and so on
        items.append([q(name), q(maker), q(''), '7', str(COND.index(cond) + 1), q(loc), '0.00',
                      q(notes.replace('"', "'")), q(''), str(100 + i),
                      str(cid.get(comp, 0)), str(slot + 1 if slot is not None else 0)])
    out = ['RETROINV3', str(len(items))]
    for it in items:
        assert len(it) == 12
        out += it
    open(path, 'wb').write(('\r'.join(out) + '\r').encode())
if __name__ == '__main__':
    import sys; build(sys.argv[1])
