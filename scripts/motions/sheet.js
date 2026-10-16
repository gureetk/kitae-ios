// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
// Contact sheet: one row per motion, five moments of the loop and the Reduce Motion still.
const { load, card, render, THEMES } = require('./motion');
const [file, out, theme = 'light', only] = process.argv.slice(2);
let motions = load(file);
if (only) { const ids = only.split(',').map(Number); motions = motions.filter(m => ids.includes(m.id)); }
const ts = [0, 0.25, 0.55, 0.78, 'still'];
const W = 200, H = 200, G = 8;
const width = G + ts.length * (W + G), height = G + motions.length * (H + G);
let defs = '', body = `<rect width="${width}" height="${height}" fill="${THEMES[theme].page}"/>`;
motions.forEach((m, r) => ts.forEach((t, c) => {
  const k = card(m, t === 'still' ? 0 : t, theme, G + c * (W + G), G + r * (H + G), W, H, t === 'still');
  defs += k.defs; body += k.body;
}));
render(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><defs>${defs}</defs>${body}</svg>`, out);
