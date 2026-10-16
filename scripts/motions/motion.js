// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
// A JavaScript twin of FigureRig.swift and FigurePainter.swift, reading the same
// ExerciseMotions.json, so poses can be checked as pictures before they reach Xcode.
// A change to the figure or the painter needs the same change in both.
const fs = require('fs');

const v = (x, y) => ({ x, y });
const add = (a, b) => v(a.x + b.x, a.y + b.y);
const sub = (a, b) => v(a.x - b.x, a.y - b.y);
const mul = (a, k) => v(a.x * k, a.y * k);
const len = a => Math.hypot(a.x, a.y);
const unit = a => { const l = len(a); return l > 0 ? mul(a, 1 / l) : v(0, 0); };
const front = d => v(d.y, -d.x);
const rotate = (p, r) => v(p.x * Math.cos(r) - p.y * Math.sin(r), p.x * Math.sin(r) + p.y * Math.cos(r));
const dir = deg => { const r = deg * Math.PI / 180; return v(Math.sin(r), -Math.cos(r)); };
const lerp = (a, b, t) => a + (b - a) * t;
const lerpV = (a, b, t) => add(a, mul(sub(b, a), t));
const f = p => `${p.x.toFixed(2)} ${p.y.toFixed(2)}`;
const BODY = { thigh: 46.5, shin: 46.7, upperArm: 35.3, forearm: 27.7, ankle: 7.4, far: v(-3.6, -1.6) };

function joint(root, target, l1, l2, bend) {
  const d = sub(target, root);
  const dist = Math.min(Math.max(len(d), Math.abs(l1 - l2) + 0.01), l1 + l2 - 0.01);
  const cosA = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist);
  return add(root, mul(rotate(unit(d), bend * Math.acos(Math.min(1, Math.max(-1, cosA)))), l1));
}
const ease = x => 0.5 - 0.5 * Math.cos(Math.PI * Math.min(1, Math.max(0, x)));
function phase(t, k) {
  if (t < k[0]) return 0;
  if (t < k[1]) return ease((t - k[0]) / (k[1] - k[0]));
  if (t < k[2]) return 1;
  if (t < k[3]) return 1 - ease((t - k[2]) / (k[3] - k[2]));
  return 0;
}

// Shapes, as SVG path data. Capsules all wind the same way, as in Swift.
function capsule(p1, p2, r1, r2) {
  const d = sub(p2, p1), dist = len(d);
  if (dist < 0.01) return circle(p1, Math.max(r1, r2));
  const th = Math.atan2(d.y, d.x);
  const phi = Math.acos(Math.min(1, Math.max(-1, (r1 - r2) / dist)));
  const on = (c, r, a) => v(c.x + r * Math.cos(a), c.y + r * Math.sin(a));
  const large2 = 2 * phi > Math.PI ? 1 : 0, large1 = 2 * phi < Math.PI ? 1 : 0;
  return `M${f(on(p1, r1, th + phi))}L${f(on(p2, r2, th + phi))}` +
    `A${r2.toFixed(2)} ${r2.toFixed(2)} 0 ${large2} 0 ${f(on(p2, r2, th - phi))}` +
    `L${f(on(p1, r1, th - phi))}A${r1.toFixed(2)} ${r1.toFixed(2)} 0 ${large1} 0 ${f(on(p1, r1, th + phi))}Z`;
}
const circle = (c, r) => `M${(c.x - r).toFixed(2)} ${c.y.toFixed(2)}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0Z`;
function ellipse(c, rx, ry, deg) {
  const pts = [];
  for (let i = 0; i < 48; i++) {
    const a = i / 48 * 2 * Math.PI;
    pts.push(add(c, rotate(v(rx * Math.cos(a), ry * Math.sin(a)), deg * Math.PI / 180)));
  }
  return 'M' + pts.map(f).join('L') + 'Z';
}
function outline(pts) {
  const n = pts.length;
  let d = `M${f(pts[0])}`;
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    d += `C${f(add(p1, mul(sub(p2, p0), 1 / 6)))} ${f(sub(p2, mul(sub(p3, p1), 1 / 6)))} ${f(p2)}`;
  }
  return d + 'Z';
}
const polygon = pts => 'M' + pts.map(f).join('L') + 'Z';
const hexagon = (c, r, deg) => polygon([0, 1, 2, 3, 4, 5].map(i => add(c, mul(dir(deg + i * 60), r))));

// Data, as ExerciseMotion.swift decodes it.
const V = a => v(a[0], a[1]);
function arm(a) {
  return 'upper' in a ? { kind: 'swing', upper: a.upper, bend: a.bend ?? 0, upperLength: a.upperLength ?? 1 }
    : { kind: 'reach', hand: V(a.hand), onTorso: a.on === 'torso', scale: a.scale ?? 1, elbow: a.elbow ?? -1, upperLength: a.upperLength ?? 1 };
}
function pose(j) {
  return {
    hip: V(j.hip), lean: j.lean, head: j.head ?? null, ankle: j.ankle ? V(j.ankle) : v(0, -BODY.ankle),
    foot: j.foot ?? 0, farAnkle: j.farAnkle ? V(j.farAnkle) : null, farFoot: j.farFoot ?? null,
    knee: j.knee ?? -1, arm: arm(j.arm), farArm: j.farArm ? arm(j.farArm) : null,
    thigh: j.thigh ?? null, shin: j.shin ?? null, farThigh: j.farThigh ?? null, farShin: j.farShin ?? null,
    curl: j.curl ?? 0, shrug: j.shrug ?? 0,
  };
}
function motion(j) {
  return {
    id: j.id, name: j.name, gear: (j.gear || []).map(gearOf), shadowWidth: j.shadowWidth ?? 40,
    muscles: new Set(j.muscles || []), timing: j.timing || [0.08, 0.5, 0.58, 0.96],
    seconds: j.seconds ?? 2.4, shift: j.shift ?? 0, zoom: j.zoom ?? 1, shadow: j.shadow ? V(j.shadow) : v(4, 0),
    from: pose(j.from), to: pose(j.to),
  };
}
function lerpArm(a, b, t) {
  if (a.kind === 'swing' && b.kind === 'swing') return { kind: 'swing', upper: lerp(a.upper, b.upper, t), bend: lerp(a.bend, b.bend, t), upperLength: lerp(a.upperLength, b.upperLength, t) };
  if (a.kind === 'reach' && b.kind === 'reach') return { ...a, hand: lerpV(a.hand, b.hand, t), scale: lerp(a.scale, b.scale, t), upperLength: lerp(a.upperLength, b.upperLength, t) };
  return t < 0.5 ? a : b;
}
function lerpPose(a, b, t) {
  const mix = (x, y, fn) => (x == null || y == null) ? (x ?? y) : fn(x, y, t);
  return {
    hip: lerpV(a.hip, b.hip, t), lean: lerp(a.lean, b.lean, t), head: mix(a.head, b.head, lerp),
    ankle: lerpV(a.ankle, b.ankle, t), foot: lerp(a.foot, b.foot, t), farAnkle: mix(a.farAnkle, b.farAnkle, lerpV),
    farFoot: mix(a.farFoot, b.farFoot, lerp), knee: a.knee, arm: lerpArm(a.arm, b.arm, t),
    farArm: mix(a.farArm, b.farArm, lerpArm),
    thigh: mix(a.thigh, b.thigh, lerp), shin: mix(a.shin, b.shin, lerp),
    farThigh: mix(a.farThigh, b.farThigh, lerp), farShin: mix(a.farShin, b.farShin, lerp),
    curl: lerp(a.curl, b.curl, t), shrug: lerp(a.shrug, b.shrug, t),
  };
}

// The Figure struct.
const smooth01 = x => { const k = Math.min(1, Math.max(0, x)); return k * k * (3 - 2 * k); };
function figure(p) {
  const spine = dir(p.lean), fr = v(-spine.y, spine.x);
  const pivot = add(p.hip, mul(spine, 18));
  const torso = (a, b) => {
    const q = add(p.hip, add(mul(spine, a), mul(fr, b)));
    if (!p.curl) return q;
    return add(pivot, rotate(sub(q, pivot), p.curl * Math.PI / 180 * smooth01((a - 10) / 16)));
  };
  const hd = dir(p.head ?? (p.lean + p.curl)), hf = v(-hd.y, hd.x);
  const neckBase = torso(52, 1.5), neckTop = add(neckBase, mul(hd, 9));
  const leg = (ankle, foot, thigh, shin, o) => {
    const hip = add(p.hip, o);
    if (thigh != null && shin != null) {
      const knee = add(hip, mul(dir(thigh), BODY.thigh));
      return { hip, knee, ankle: add(knee, mul(dir(shin), BODY.shin)), foot };
    }
    const a = add(ankle, o);
    return { hip, knee: joint(hip, a, BODY.thigh, BODY.shin, p.knee), ankle: a, foot };
  };
  const shoulderAt = torso(48 + p.shrug, -0.5);
  const armOf = (ap, o) => {
    const shoulder = add(shoulderAt, o);
    if (ap.kind === 'swing') {
      const elbow = add(shoulder, mul(dir(180 - ap.upper), BODY.upperArm * ap.upperLength));
      return { shoulder, elbow, wrist: add(elbow, mul(dir(180 - ap.upper - ap.bend), BODY.forearm)), scale: 1 };
    }
    const target = add(ap.onTorso ? torso(ap.hand.x, ap.hand.y) : ap.hand, o);
    const elbow = joint(shoulder, target, BODY.upperArm * ap.scale * ap.upperLength, BODY.forearm * ap.scale, ap.elbow);
    return { shoulder, elbow, wrist: add(elbow, mul(unit(sub(target, elbow)), BODY.forearm * ap.scale)), scale: ap.scale };
  };
  return {
    pose: p, spine, front: fr, torso, headDirection: hd, neckBase, neckTop,
    head: add(neckTop, add(mul(hd, 9.5), mul(hf, 1.5))),
    nearLeg: leg(p.ankle, p.foot, p.thigh, p.shin, v(0, 0)),
    farLeg: leg(p.farAnkle ?? p.ankle, p.farFoot ?? p.foot, p.farThigh ?? p.thigh, p.farShin ?? p.shin, BODY.far),
    nearArm: armOf(p.arm, v(0, 0)), farArm: armOf(p.farArm ?? p.arm, BODY.far),
  };
}

function muscle(a, b, ra, rb, k, w, side) {
  const out = mul(front(unit(sub(b, a))), side);
  const pt = (t, wd) => { const r = lerp(ra, rb, t); return [add(lerpV(a, b, t), mul(out, r - r * wd - 0.1)), r * wd]; };
  const [p1, r1] = pt(k[0], w[0]), [p2, r2] = pt(k[1], w[1]), [p3, r3] = pt(k[2], w[2]);
  return capsule(p1, p2, r1, r2) + capsule(p2, p3, r2, r3);
}
function legShape(l) {
  const td = unit(sub(l.knee, l.hip)), sd = unit(sub(l.ankle, l.knee));
  const mid = add(lerpV(l.hip, l.knee, 0.42), mul(front(td), 1));
  const calf = add(lerpV(l.knee, l.ankle, 0.3), mul(front(sd), -1.8));
  const turn = l.foot * Math.PI / 180;
  const heel = add(l.ankle, rotate(v(-4.5, 2.9), turn)), toe = add(l.ankle, rotate(v(17, 4.2), turn));
  return {
    thigh: capsule(l.hip, mid, 10.4, 9.2) + capsule(mid, l.knee, 9.2, 6.6),
    shin: capsule(l.knee, calf, 6.6, 7.2) + capsule(calf, l.ankle, 7.2, 3.9),
    foot: capsule(heel, toe, 4.5, 3.2) + capsule(l.ankle, heel, 3.9, 4.5),
    quads: muscle(l.hip, l.knee, 10.4, 6.6, [0.12, 0.5, 0.9], [0.55, 0.72, 0.7], 1),
    hamstrings: muscle(l.hip, l.knee, 10.4, 6.6, [0.14, 0.5, 0.88], [0.5, 0.62, 0.55], -1),
    calves: muscle(l.knee, l.ankle, 7.0, 3.9, [0.08, 0.3, 0.62], [0.62, 0.78, 0.5], -1),
  };
}
function armShape(a) {
  const ud = unit(sub(a.elbow, a.shoulder)), fd = unit(sub(a.wrist, a.elbow));
  const fore = add(lerpV(a.elbow, a.wrist, 0.3), mul(front(fd), 0.4));
  const grip = add(a.wrist, mul(fd, 6.5 * Math.max(a.scale, 0.8)));
  const bent = Math.acos(Math.min(1, Math.max(-1, ud.x * fd.x + ud.y * fd.y))) * 180 / Math.PI;
  const k = Math.min(1, bent / 130);
  return {
    arm: a, grip,
    upper: capsule(a.shoulder, a.elbow, 6.8, 4.5),
    forearm: capsule(a.elbow, fore, 4.5, 5.0) + capsule(fore, a.wrist, 5.0, 3.3),
    hand: capsule(a.wrist, grip, 3.6, 3.9),
    biceps: muscle(a.shoulder, a.elbow, 6.8, 4.5, [0.2, 0.52, 0.86], [0.55, 0.8 + 0.15 * k, 0.6], 1),
    triceps: muscle(a.shoulder, a.elbow, 6.8, 4.5, [0.16, 0.5, 0.86], [0.55, 0.72, 0.58], -1),
    forearms: muscle(a.elbow, a.wrist, 5.0, 3.3, [0.1, 0.32, 0.75], [0.8, 0.85, 0.6], 1),
    delts: side => muscle(a.shoulder, a.elbow, 6.8, 4.5, [0, 0.17, 0.4], side === 0 ? [1, 1, 0.65] : [0.62, 0.62, 0.45], side),
  };
}

const THEMES = {
  light: { page: '#FDF9F0', card: '#F4F0E6', body: '#AAA696', far: '#CDC9BA', muscle: '#63611E',
    muscleFar: '#9C9A66', gear: '#34332B', gearFace: '#4B4940', prop: '#DDD8C8', shadow: 'rgba(28,28,22,0.10)' },
  dark: { page: '#14140E', card: '#1E1E18', body: '#6F6C5F', far: '#47463D', muscle: '#CECA75',
    muscleFar: '#88864F', gear: '#D8D4C7', gearFace: '#B9B5A8', prop: '#34332B', shadow: 'rgba(0,0,0,0.34)' },
};

function gearOf(j) {
  return {
    kind: j.kind, on: j.on ?? null, from: j.from ? V(j.from) : null, to: j.to ? V(j.to) : null,
    at: j.at ? V(j.at) : null, thick: j.thick ?? 8, legs: j.legs ?? [], width: j.width ?? 4,
    handle: j.handle ?? 'bar', stack: j.stack ?? false, profile: j.profile ?? false, one: j.one ?? false, hang: j.hang ?? false,
    radius: j.radius ?? null, front: j.front ?? false,
  };
}

let clipSeq = 0;
// The painter: returns { defs, body } for one figure, in the same order as FigurePainter.draw.
function paint(m, F, c) {
  const defs = [], out = [];
  const fill = (d, col) => out.push(`<path d="${d}" fill="${col}"/>`);
  const fillInside = (clip, d, col) => {
    const id = `k${++clipSeq}`;
    defs.push(`<clipPath id="${id}"><path d="${clip}"/></clipPath>`);
    out.push(`<path d="${d}" fill="${col}" clip-path="url(#${id})"/>`);
  };
  const has = x => m.muscles.has(x);
  const gears = kind => m.gear.filter(g => g.kind === kind);
  const plate = (at, r) => { fill(circle(at, r), c.gear); fill(circle(at, r * 0.735), c.gearFace); fill(circle(at, r * 0.21), c.body); };
  const leg = (l, body, mc) => {
    fill(l.thigh, body); fill(l.shin, body); fill(l.foot, body);
    if (has('quads')) fillInside(l.thigh, l.quads, mc);
    if (has('hamstrings')) fillInside(l.thigh, l.hamstrings, mc);
    if (has('calves')) fillInside(l.shin, l.calves, mc);
  };
  const armDraw = (a, body, mc) => {
    fill(a.upper, body); fill(a.forearm, body); fill(a.hand, body);
    const cap = a.upper + circle(a.arm.shoulder, 7.2);
    if (has('biceps')) fillInside(a.upper, a.biceps, mc);
    if (has('triceps')) fillInside(a.upper, a.triceps, mc);
    if (has('forearms')) fillInside(a.forearm, a.forearms, mc);
    if (has('sideDelts')) fillInside(cap, a.delts(0), mc);
    if (has('frontDelts')) fillInside(cap, a.delts(1), mc);
    if (has('rearDelts')) fillInside(cap, a.delts(-1), mc);
  };
  const farArm = armShape(F.farArm), nearArm = armShape(F.nearArm);
  const farLeg = legShape(F.farLeg), nearLeg = legShape(F.nearLeg);
  // Points on the body that gear follows.
  const bodyPoint = name => {
    const nl = F.nearLeg;
    switch (name) {
      case 'hands': return nearArm.grip;
      case 'ankle': return nl.ankle;
      case 'shin': return lerpV(nl.knee, nl.ankle, 0.78);
      case 'thigh': return add(lerpV(nl.hip, nl.knee, 0.62), mul(front(unit(sub(nl.knee, nl.hip))), 9));
      case 'hips': return F.torso(-2, 11);
      case 'chest': return F.torso(36, 15);
      default: return nearArm.grip;
    }
  };
  const dumbbell = (arm, near) => {
    const g = arm.grip;
    if (gears('dumbbells').some(d => d.hang)) {
      const top = add(g, v(0, 2));
      fill(capsule(top, add(top, v(0, 15)), 1.7, 1.7), near ? c.gear : c.body);
      for (const y of [0, 15]) fill(capsule(add(top, v(-7, y)), add(top, v(7, y)), 2.8, 2.8), near ? c.gear : c.body);
      return;
    }
    if (gears('dumbbells').some(d => d.profile)) {
      const fd = unit(sub(arm.arm.wrist, arm.arm.elbow)), axis = front(fd);
      const col = near ? c.gear : c.body;
      fill(capsule(add(g, mul(axis, -7)), add(g, mul(axis, 7)), 1.7, 1.7), col);
      for (const k of [-8, 8]) {
        const e = add(g, mul(axis, k));
        fill(capsule(add(e, mul(fd, -6.5)), add(e, mul(fd, 6.5)), 2.8, 2.8), col);
      }
      return;
    }
    if (!near) { fill(hexagon(add(g, v(-1, -1)), 8.6, 30), c.body); return; }
    const at = add(g, v(1, 1));
    fill(hexagon(at, 8.6, 30), c.gear); fill(hexagon(at, 6.0, 30), c.gearFace); fill(circle(at, 2.4), c.body);
  };

  fill(ellipse(m.shadow, m.shadowWidth ?? 40, 3.4, 0), c.shadow);

  // Behind everything: machine stacks and frame posts.
  for (const g of gears('cable')) if (g.stack) fill(capsule(v(g.from.x, -3), v(g.from.x, g.from.y), 6.5, 6.5), c.prop);
  for (const g of gears('post')) fill(capsule(g.from, g.to, g.width / 2, g.width / 2), c.prop);

  // The far side.
  leg(farLeg, c.far, c.muscleFar);
  armDraw(farArm, c.far, c.muscleFar);
  const hasDumbbells = gears('dumbbells').length > 0, oneDumbbell = gears('dumbbells').some(d => d.one);
  if (hasDumbbells && !oneDumbbell) dumbbell(farArm, false);

  // Benches, seats and pads, under the body.
  const pad = g => {
    const d = unit(sub(g.to, g.from)), right = v(-d.y, d.x), h = g.thick / 2;
    for (const x of g.legs) {
      const k = (x - g.from.x) / (g.to.x - g.from.x || 1), top = add(lerpV(g.from, g.to, k), mul(right, h));
      fill(capsule(top, v(x, -2), 1.9, 1.9), c.prop);
      fill(capsule(v(x - 8, -1.6), v(x + 8, -1.6), 1.6, 1.6), c.prop);
    }
    fill(capsule(add(g.from, mul(right, h)), add(g.to, mul(right, h)), h, h), c.prop);
  };
  for (const g of gears('pad')) if (!g.front) pad(g);

  // The body.
  const torsoPts = [[-7, 3], [2, 9], [16, 9], [29, 12.5], [41, 12.5], [50.5, 8],
    [54, -2], [51, -9.5], [39, -11.5], [24, -8.5], [11, -10.5], [0, -14.5], [-8.5, -9]];
  const torso = outline(torsoPts.map(([a, b]) => F.torso(a, b)));
  const lean = F.pose.lean, turnAt = a => lean + F.pose.curl * smooth01((a - 10) / 16);
  fill(torso, c.body);
  if (has('glutes')) fillInside(torso, ellipse(F.torso(-1.5, -8.5), 8.5, 10.5, turnAt(-1.5)), c.muscle);
  if (has('chest')) fillInside(torso, ellipse(F.torso(37, 8.5), 6.5, 9, turnAt(37)), c.muscle);
  if (has('abs')) fillInside(torso, capsule(F.torso(4, 5.8), F.torso(27, 8.5), 3.4, 3.4), c.muscle);
  if (has('obliques')) fillInside(torso, ellipse(F.torso(14, 2), 4.5, 9, turnAt(14)), c.muscle);
  if (has('lats')) fillInside(torso, ellipse(F.torso(33, -7.5), 4.5, 11, turnAt(33)), c.muscle);
  if (has('traps')) fillInside(torso, ellipse(F.torso(50, -6), 5, 7, turnAt(50)), c.muscle);
  if (has('lowerBack')) fillInside(torso, capsule(F.torso(6, -8), F.torso(26, -6.2), 2.8, 2.8), c.muscle);

  for (const g of gears('barbell')) if (g.on === 'back') {
    const bar = F.torso(50, -9), pl = add(bar, v(-9, 2.5));
    fill(capsule(pl, bar, 2.6, 2.6), c.gear);
    plate(pl, g.radius ?? 17);
  }

  const hf = v(-F.headDirection.y, F.headDirection.x), turn = F.pose.head ?? (F.pose.lean + F.pose.curl);
  fill(capsule(F.neckBase, F.neckTop, 5.6, 5.0), c.body);
  fill(ellipse(F.head, 10.2, 11.6, turn), c.body);
  fill(ellipse(sub(add(F.head, mul(hf, 3.2)), mul(F.headDirection, 5.5)), 7.4, 6.4, turn), c.body);

  // Pads in front of the body, such as a preacher bench's, under the near arm.
  for (const g of gears('pad')) if (g.front) pad(g);

  // Cables run to the middle of the body, behind the near arm; bars are gripped by it.
  for (const g of gears('cable')) {
    const end = bodyPoint(g.on ?? 'hands');
    fill(capsule(g.from, end, 0.8, 0.8), c.gear);
    fill(circle(g.from, 4.2), c.gear); fill(circle(g.from, 1.7), c.prop);
  }
  for (const g of gears('bar')) fill(circle(g.at, 3.6), c.gear);

  leg(nearLeg, c.body, c.muscle);
  armDraw(nearArm, c.body, c.muscle);

  for (const g of gears('barbell')) if (g.on === 'hands' || g.on == null) plate(nearArm.grip, g.radius ?? 17);
  for (const g of gears('ezbar')) plate(nearArm.grip, g.radius ?? 12.5);
  if (hasDumbbells) dumbbell(nearArm, true);
  for (const g of gears('cable')) {
    const end = bodyPoint(g.on ?? 'hands');
    if (g.handle === 'rope') {
      const d = unit(sub(end, g.from));
      fill(capsule(sub(end, mul(d, 9)), add(end, mul(d, 2)), 2.2, 2.4), c.gear);
    } else if (g.handle === 'bar') {
      fill(circle(end, 3.2), c.gear);
    } else if (g.handle === 'single') {
      fill(circle(end, 3.6), c.gear); fill(circle(end, 1.8), c.body);
    }
  }
  for (const g of gears('handle')) fill(circle(bodyPoint(g.on ?? 'hands'), 3.4), c.gear);
  for (const g of gears('roller')) {
    const at = g.at ?? bodyPoint(g.on);
    fill(circle(at, g.radius ?? 6.5), c.prop); fill(circle(at, 2.2), c.gear);
  }
  return { defs: defs.join(''), body: out.join('') };
}

// One card at (x, y) of size w × h, laid out like FigurePainter.place.
function card(m, t, theme, x, y, w, h, still = false) {
  const c = THEMES[theme];
  const scale = Math.min(1.15, (h - 34) / 190) * m.zoom;
  const g = `translate(${(x + w / 2 + m.shift * scale).toFixed(2)} ${(y + h - 20).toFixed(2)}) scale(${scale.toFixed(4)})`;
  let defs = '', body = '';
  if (still) {
    const a = paint(m, figure(m.from), c), b = paint(m, figure(m.to), c);
    defs = a.defs + b.defs;
    body = `<g opacity="0.4">${a.body}</g>${b.body}`;
  } else {
    const p = paint(m, figure(lerpPose(m.from, m.to, phase(t, m.timing))), c);
    defs = p.defs; body = p.body;
  }
  return { defs, body: `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="24" fill="${c.card}"/><g transform="${g}">${body}</g>` };
}

function load(file) { return JSON.parse(fs.readFileSync(file, 'utf8')).map(motion); }
function render(svg, file, scale = 1) {
  const { Resvg } = require('@resvg/resvg-js');
  fs.writeFileSync(file, new Resvg(svg, { fitTo: { mode: 'zoom', value: scale } }).render().asPng());
}

module.exports = { load, card, render, THEMES, motion, figure, pose, lerpPose, phase, v, add, sub, mul, dir, unit, rotate };
