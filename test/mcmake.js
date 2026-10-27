// build a Mouse Calc sheet like one a user might edit by hand in Mouse Calc
const M = require('./mclib.js'), fs = require('fs');
M.setTemplateHeader(fs.readFileSync('../tools/mcsamples/SAMPLE.BILL'));
const T = (r, c, text) => ({ r, c, kind: 'text', text });
const N = (r, c, value, fmt = 0) => ({ r, c, kind: 'number', value, fmt });
const cells = [
  // columns deliberately in a different order, with an extra column
  T(1, 1, 'VALUE'), T(1, 2, 'NAME'), T(1, 3, 'notes'), T(1, 4, '  Year'), T(1, 5, 'COND.'), T(1, 6, 'Serial number'), T(1, 7, 'Bought from'), T(1, 8, 'Type'),
  N(2, 1, 1200, 8), T(2, 2, 'Apple ][ "Woz" board'), T(2, 3, 'Rev 0, needs PSU'), N(2, 4, 1977, 2), T(2, 5, 'excellent'), N(2, 6, 31234), T(2, 7, 'eBay'), N(2, 8, 1),
  T(3, 1, '$1,050.25'), T(3, 2, 'Lisa 2/10'), N(3, 4, 1984), T(3, 5, '5'), T(3, 6, 'A6S-123'), T(3, 8, 'computer'),
  N(4, 1, 0.5), T(4, 2, 'Floppy labels'), N(4, 4, 1983.6), N(4, 5, 9), T(4, 8, 'Doc'),
  // a blank row, then a row without a name, then a totals row
  N(6, 1, 999), T(7, 1, 'TOTAL'), N(8, 2, 3.14159), N(9, 2, -42), N(10, 2, 0.000123), N(11, 2, 12345678901234),
];
fs.writeFileSync(process.argv[2], M.buildFile({ cells }));
