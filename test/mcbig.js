const M = require('./mclib.js'), fs = require('fs');
M.setTemplateHeader(fs.readFileSync('../tools/mcsamples/SAMPLE.BILL'));
const cells = [{ r: 1, c: 1, kind: 'text', text: 'Name' }, { r: 1, c: 2, kind: 'text', text: 'Value' }];
for (let i = 0; i < 250; i++) { cells.push({ r: i + 2, c: 1, kind: 'text', text: 'Item ' + (i + 1) }); cells.push({ r: i + 2, c: 2, kind: 'number', value: i + 0.25, fmt: 8 }); }
fs.writeFileSync(process.argv[2], M.buildFile({ cells }));
