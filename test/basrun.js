// Run the Applesoft RetroInv under jsbasic (node), with a 40x24 screen,
// scripted keystrokes and DOS text files kept in a host folder.
// usage: node basrun.js program.bas voldir keys.json out.txt
const fs = require('fs'), path = require('path'), vm = require('vm');
const [, , PROG, VOL, KEYS, OUT] = process.argv;
const JS = '/home/claude/ext/jsbasic';

// localStorage backed by files in VOL (key "/" + filename)
global.window = { localStorage: {
  getItem(k) { const f = path.join(VOL, k.split('/').pop()); return fs.existsSync(f) ? encodeURIComponent(fs.readFileSync(f, 'latin1').replace(/\r/g, '\r')) : null; },
  setItem(k, v) { fs.writeFileSync(path.join(VOL, k.split('/').pop()), decodeURIComponent(v), 'latin1'); },
  removeItem(k) { const f = path.join(VOL, k.split('/').pop()); if (fs.existsSync(f)) fs.unlinkSync(f); },
}};
// a missing file: behave like an empty, new file (as DOS OPEN does)
function XMLHttpRequest() { this.status = 404; this.responseText = ''; }
XMLHttpRequest.prototype.open = function () {}; XMLHttpRequest.prototype.send = function () {};
const ctx = { window: global.window, setTimeout, console, Math, Date, XMLHttpRequest };
vm.createContext(ctx);
// zero-page string pointers for PEEK(109..112): about 20K free by default
vm.runInContext(fs.readFileSync(JS + '/basic.js', 'utf8').replace('// Last error code',
  "0x006d: function(){return 0}, 0x006e: function(){return 0x40}, 0x006f: function(){return 0}, 0x0070: function(){return 0x90},\n      // Last error code"), ctx);
vm.runInContext(fs.readFileSync(JS + '/dos.js', 'utf8'), ctx);

// --- tty
const W = 40, H = 24;
let scr = [], cx = 0, cy = 0, inv = false;
const blank = () => { scr = []; for (let y = 0; y < H; y++) scr.push(Array(W).fill(' ')); };
blank();
const transcript = [];
function scroll() { scr.shift(); scr.push(Array(W).fill(' ')); }
function put(c) {
  if (c === '\r' || c === '\n') { cx = 0; cy++; if (cy >= H) { scroll(); cy = H - 1; } return; }
  if (c === '\b') { if (cx > 0) cx--; return; }
  if (c.charCodeAt(0) < 32) return;
  scr[cy][cx] = inv ? c.toLowerCase() : c;
  cx++;
  if (cx >= W) { cx = 0; cy++; if (cy >= H) { scroll(); cy = H - 1; } }
}
const keys = JSON.parse(fs.readFileSync(KEYS, 'utf8')).join('').split('');
let snapshots = [];
function snap(tag) { snapshots.push('=== ' + tag + '\n' + scr.map(r => r.join('').replace(/\s+$/, '')).join('\n')); }
const tty = {
  TEXT_STYLE_NORMAL: 0, TEXT_STYLE_INVERSE: 1, TEXT_STYLE_FLASH: 2,
  textWindow: { left: 0, top: 0, width: W, height: H },
  writeChar(c) { put(c); }, writeString(s) { for (const c of s) tty.writeChar(c); },
  getScreenSize() { return { width: W, height: H }; },
  getCursorPosition() { return { x: cx, y: cy }; },
  setCursorPosition(x, y) { if (x !== undefined) cx = x; if (y !== undefined) cy = y; },
  clearScreen() { blank(); cx = 0; cy = 0; },
  clearEOL() { for (let x = cx; x < W; x++) scr[cy][x] = ' '; },
  clearEOS() { tty.clearEOL(); for (let y = cy + 1; y < H; y++) scr[y].fill(' '); },
  setTextStyle(s) { inv = s === 1; },
  cursorUp() {}, cursorDown() {}, cursorLeft() {}, cursorRight() {},
  setFirmwareActive() {}, isFirmwareActive() { return false; }, isAltCharset() { return false; },
  getKeyboardRegister() { return 0; }, clearKeyboardStrobe() { return 0; }, getButtonState() { return 0; },
  readChar(cb) {
    if (!keys.length) { snap('END (out of keys)'); throw new Error('OUT_OF_KEYS'); }
    const k = keys.shift();
    if (k === '~') { snap('snapshot'); return tty.readChar(cb); }      // ~ = take a snapshot
    setTimeout(() => cb(k), 0);
  },
  readLine(cb, prompt) {
    tty.writeString(prompt || '');
    let s = '';
    while (keys.length && keys[0] !== '\r') s += keys.shift();
    keys.shift();
    tty.writeString(s + '\r');
    setTimeout(() => cb(s), 0);
  },
};
const dos = new ctx.DOS(tty);
const basic = ctx.basic;
let src = fs.readFileSync(PROG, 'utf8');
const program = basic.compile(src);
program.init({ tty, dos });
let steps = 0, done = false;
function finish(why) {
  if (done) return; done = true;
  snap('FINAL: ' + why);
  fs.writeFileSync(OUT, snapshots.join('\n\n') + '\n');
}
function driver() {
  try {
    let state;
    do { state = program.step(driver); steps++; if (steps > 5e7) { finish('too many steps'); return; } }
    while (state === basic.STATE_RUNNING);
    if (state === basic.STATE_STOPPED) finish('program ended');
  } catch (e) { finish(e.message === 'OUT_OF_KEYS' ? 'out of keys' : 'ERROR ' + e.message + ' line ' + e.line); }
}
driver();
