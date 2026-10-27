const M = require('./mclib.js'), fs = require('fs');
const f = fs.readFileSync(process.argv[2]);
M.setTemplateHeader(fs.readFileSync('../tools/mcsamples/SAMPLE.BILL'));
const s = M.parseFile(f);
console.log('maxRow', s.maxRow, 'maxCol', s.maxCol, 'cells', s.cells.length);
console.log('widths A-J', s.widths.slice(1, 11).join(','));
const grid = {};
for (const c of s.cells) {
  const v = c.kind === 'text' ? JSON.stringify(c.text) : c.kind === 'formula' ? `${c.mc} = ${c.value} (excel ${c.excel})` : c.value;
  grid[M.cellName(c.r, c.c)] = v;
  if (c.parseError) console.log('PARSE ERROR', c.r, c.c, c.parseError);
}
for (const r of [1, 2, 3, 6, 7, 8, 9]) console.log(r, ['A','B','C','D','E','F','G','H','I','J','K','L'].map(c => grid[c + r] ?? '').join(' | '));
// rebuild with the converter's own writer and compare
const rebuilt = M.buildFile({ widths: s.widths, cells: s.cells, maxRow: s.maxRow, maxCol: s.maxCol });
console.log('rebuilt identical:', Buffer.compare(Buffer.from(rebuilt), f) === 0, rebuilt.length, f.length);
// evaluate formulas with Mouse Calc semantics
const get = (r, c) => { const x = s.cells.find(k => k.r === r && k.c === c); return x ? (x.kind === 'text' ? x.text : x.value) : undefined; };
for (const c of s.cells.filter(k => k.kind === 'formula')) console.log('eval', M.cellName(c.r, c.c), M.evaluate(c.ast, get), 'cached', c.value);
