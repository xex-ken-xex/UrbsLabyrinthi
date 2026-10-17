#!/usr/bin/env node
/* 書き出した階(godot/data/floors/*.json.gz)が、設計(design/2026-10-17-generator-design.md §8)と
   数理モデル(docs/dungeon-model.md §7)の決まりを守っているかを確かめる。
   使い方: node tools/check-floors.mjs [データフォルダ]   既定: godot/data
   守れていなければ、何がどう違うかを出して、終了コード 1。 */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.resolve(process.argv[2] || path.join(root, 'godot/data'));
const html = fs.readFileSync(path.join(root, 'docs/urbs-labyrinthi.html'), 'utf8');
const lines = html.split('\n');
const a = lines.findIndex(l => l.startsWith('const Core = (() => {'));
const b = lines.findIndex((l, i) => i > a && l === '})();');
const Core = vm.runInNewContext(lines.slice(a, b + 1).join('\n') + '\nCore;', {});

const man = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const NIGHTS = man.nights, FLOORS = man.floors;
const fails = [], notes = [];
const fail = (s) => { fails.push(s); };
const load = (d, n, p) => {
  const f = path.join(dir, 'floors', `f${String(d).padStart(2, '0')}_n${String(n).padStart(2, '0')}_p${p}.json.gz`);
  if (!fs.existsSync(f)) return null;
  return JSON.parse(zlib.gunzipSync(fs.readFileSync(f)).toString());
};

/* 1. 形と数 */
if (man.schema !== Core.SCHEMA) fail(`manifest の schema が ${man.schema}(生成器は ${Core.SCHEMA})`);
if (man.generator !== Core.GENERATOR) fail(`manifest の generator が ${man.generator}(生成器は ${Core.GENERATOR})`);
if (FLOORS !== Core.DEPTHS.length) fail(`階の数が ${FLOORS}(WIRE は ${Core.DEPTHS.length})`);
let missing = 0;
for (let d = 1; d <= FLOORS; d++) for (let n = 0; n < NIGHTS; n++) for (let p = 1; p <= 4; p++) if (!fs.existsSync(path.join(dir, 'floors', `f${String(d).padStart(2, '0')}_n${String(n).padStart(2, '0')}_p${p}.json.gz`))) missing++;
if (missing) fail(`階のファイルが ${missing} 個ない`);

/* 2. 一階ずつ(人数4で見る) */
const offset = (j, pt) => [pt.x - j.shaft.center[0], pt.y - j.shaft.center[1]];
const key = (x, y) => `${x},${y}`;
const reachAll = j => {
  const W = j.meta.grid.width, H = j.meta.grid.height, g = j.grid;
  const open = (x, y) => x >= 0 && y >= 0 && x < W && y < H && g[y][x] !== '#' && g[y][x] !== 'O';
  const seen = new Uint8Array(W * H), st = [[j.stairs.up.x, j.stairs.up.y]]; seen[j.stairs.up.y * W + j.stairs.up.x] = 1;
  while (st.length) { const [x, y] = st.pop(); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (open(X, Y) && !seen[Y * W + X]) { seen[Y * W + X] = 1; st.push([X, Y]); } } }
  return j.rooms.filter(r => !seen[r.center[1] * W + r.center[0]]).map(r => r.no);
};
const mons = {}, kg = {}, changedQuiet = { c: 0, n: 0 }, changedExhale = { c: 0, n: 0 };
const prevNight = new Map();   // depth → 前の夜の JSON
const byDepthNight = new Map();
for (let n = 0; n < NIGHTS; n++) for (let d = 1; d <= FLOORS; d++) {
  const j = load(d, n, 4); if (!j) continue;
  byDepthNight.set(`${d}|${n}`, j);
  const D0 = Core.DEPTHS[d - 1], W = j.meta.grid.width, H = j.meta.grid.height, tag = `f${d}(第${D0.layer}層 ${D0.sub + 1}/${D0.subs}) n${n}`;
  if (j.schema !== Core.SCHEMA) fail(`${tag}: schema ${j.schema}`);
  if (j.meta.depth !== d || j.meta.layer !== D0.layer || j.meta.sub !== D0.sub) fail(`${tag}: meta の depth/layer/sub が合わない`);
  const [sw, sh] = Core.SIZES[D0.size]; if (W !== sw || H !== sh) fail(`${tag}: 広さ ${W}×${H}(WIRE は ${sw}×${sh})`);
  /* 縦穴: 中央に 13×13 の O、まわりに通路の輪 */
  const cx = W >> 1, cy = H >> 1;
  if (j.shaft.center[0] !== cx || j.shaft.center[1] !== cy || j.shaft.w !== Core.WIRE.shaft.w) fail(`${tag}: 縦穴が中央にない、または大きさが違う`);
  let voidOk = true, ringOk = true;
  for (let y = j.shaft.y - 1; y <= j.shaft.y + j.shaft.h; y++) for (let x = j.shaft.x - 1; x <= j.shaft.x + j.shaft.w; x++) {
    const edge = x < j.shaft.x || y < j.shaft.y || x >= j.shaft.x + j.shaft.w || y >= j.shaft.y + j.shaft.h;
    const ch = j.grid[y][x];
    if (edge) { if (ch !== ',' && ch !== '+') ringOk = false; } else if (ch !== 'O') voidOk = false;
  }
  if (!voidOk) fail(`${tag}: 縦穴の中に虚空でないマスがある`);
  if (!ringOk) fail(`${tag}: 縦穴の縁の回廊が切れている`);
  /* 候補地7つは、縦穴の中心からの差が全階で同じ(七角形) */
  if (j.stair_sites.length !== 7) fail(`${tag}: 候補地が ${j.stair_sites.length} 個`);
  for (const s of j.stair_sites) {
    const ang = -Math.PI / 2 + s.k * 2 * Math.PI / 7, ex = Math.round(Core.WIRE.site_r * Math.cos(ang)), ey = Math.round(Core.WIRE.site_r * Math.sin(ang));
    const [ox, oy] = offset(j, s);
    if (Math.abs(ox - ex) > 1 || Math.abs(oy - ey) > 1) fail(`${tag}: 候補地 ${s.k} が (${ox},${oy})、決まりは (${ex},${ey})`);
  }
  /* 階段の決まり: 上り = 候補地 mirror(夜 + 階 − 1)、下り = mirror(夜 + 階) */
  const up = j.stair_sites.find(s => s.k === Core.mirrorRoom((n + d - 1) % 49)), dn = j.stair_sites.find(s => s.k === Core.mirrorRoom((n + d) % 49));
  if (!up || j.stairs.up.x !== up.x || j.stairs.up.y !== up.y) fail(`${tag}: 上り階段が候補地 ${up && up.k} にない`);
  if (!dn || j.stairs.down.room !== dn.room) fail(`${tag}: 下り階段が候補地 ${dn && dn.k} の部屋にない`);
  if (up && dn && up !== dn && (j.stairs.down.x !== dn.x || j.stairs.down.y !== dn.y)) fail(`${tag}: 下り階段の位置が候補地の中心でない`);
  /* 全部屋へ行ける */
  const bad = reachAll(j); if (bad.length) fail(`${tag}: 上り階段から行けない部屋 ${bad.join(',')}`);
  /* 竪坑: 第1〜6層に4つ。いちばん下の階だけ穴がない */
  const want = Core.WIRE.verticals.filter(v => D0.layer >= v.layers[0] && D0.layer <= v.layers[1]);
  if (j.verticals.length !== want.length) fail(`${tag}: 縦の構造が ${j.verticals.length} 個(決まりは ${want.length})`);
  for (const v of j.verticals) {
    const [ox, oy] = offset(j, { x: v.x + 1, y: v.y + 1 });
    const w = want.find(w => w.dx === ox && w.dy === oy);
    if (!w) fail(`${tag}: 竪坑が決まりにない位置 (${ox},${oy})`);
    const last = w && D0.layer === w.layers[1] && D0.sub === D0.subs - 1;
    if (v.hole === last) fail(`${tag}: 竪坑の穴の有無が逆(hole=${v.hole})`);
    for (let y = v.y; y < v.y + v.h; y++) for (let x = v.x; x < v.x + v.w; x++) if ((j.grid[y][x] === 'O') !== v.hole) fail(`${tag}: 竪坑のマス (${x},${y}) が ${j.grid[y][x]}`);
  }
  /* 夜をまたぐ不変: 骨組み、候補地、縦の構造、大部屋。組み替わらなかった一画は前の夜と同じ */
  const pv = prevNight.get(d);
  if (pv) {
    if (pv.meta.skeleton_hash !== j.meta.skeleton_hash) fail(`${tag}: 骨組みが前の夜と違う`);
    if (JSON.stringify(pv.stair_sites) !== JSON.stringify(j.stair_sites)) fail(`${tag}: 候補地が前の夜と違う`);
    if (JSON.stringify(pv.verticals) !== JSON.stringify(j.verticals)) fail(`${tag}: 縦の構造が前の夜と違う`);
    const bigs = x => x.rooms.filter(r => r.big).map(r => `${r.name}@${r.x},${r.y}`).sort().join('|');
    if (bigs(pv) !== bigs(j)) fail(`${tag}: 大部屋の位置か名前が前の夜と違う`);
    const exhale = Core.nightInfo(n).exhale; let kept = 0, chg = 0;
    for (const dd of j.districts) {
      const pd = pv.districts[dd.id];
      if (dd.changed < n) { kept++; if (!pd || pd.hash !== dd.hash) fail(`${tag}: 一画 ${dd.id} は組み替わっていないのに、前の夜と違う`); if (pd && pd.changed !== dd.changed) fail(`${tag}: 一画 ${dd.id} の changed が前の夜と合わない`); }
      else chg++;
    }
    const acc = exhale ? changedExhale : changedQuiet; acc.c += chg; acc.n += chg + kept;
    if (exhale && kept) fail(`${tag}: 吐く夜なのに、組み替わらない一画が ${kept} ある`);
  } else if (n === 0 && j.districts.some(dd => dd.changed !== 0)) fail(`${tag}: 夜0なのに changed が 0 でない一画がある`);
  prevNight.set(d, j);
  /* 数理モデルの目安 */
  const nm = j.encounters.reduce((s, e) => s + e.monsters.reduce((a, m) => a + m.count, 0), 0);
  (mons[D0.layer] = mons[D0.layer] || []).push(nm);
  let kgs = 0; for (const r of j.rooms) if (r.treasure) { const m = /([\d.]+)kg/.exec(r.treasure.items[0] || ''); if (m) kgs += +m[1]; }
  (kg[D0.layer] = kg[D0.layer] || []).push(kgs);
}
/* 3. 階をまたぐ: この階の下りの真下に、下の階の上り(同じ夜) */
for (let n = 0; n < NIGHTS; n++) for (let d = 1; d < FLOORS; d++) {
  const A = byDepthNight.get(`${d}|${n}`), B = byDepthNight.get(`${d + 1}|${n}`); if (!A || !B) continue;
  const [ax, ay] = offset(A, A.stairs.down), [bx, by] = offset(B, B.stairs.up);
  const sameRoom = A.stairs.down.room === A.stairs.up.room;   // 息継ぎ7の夜は同じ部屋の中の別のマス
  if (!sameRoom && (ax !== bx || ay !== by)) fail(`f${d} n${n}: 下り (${ax},${ay}) の真下に f${d + 1} の上り (${bx},${by}) がない`);
  if (sameRoom && (Math.abs(ax - bx) > 5 || Math.abs(ay - by) > 5)) fail(`f${d} n${n}: 下り (${ax},${ay}) と f${d + 1} の上り (${bx},${by}) が同じ候補地にない`);
}
/* 4. 組み替えの法則 */
const q = changedQuiet.n ? changedQuiet.c / changedQuiet.n : 0, e = changedExhale.n ? changedExhale.c / changedExhale.n : 0;
notes.push(`一画の組み替え: 静かな夜 ${(q * 100).toFixed(0)}%(決まり ${Core.WIRE.p_quiet * 100}%)、吐く夜 ${(e * 100).toFixed(0)}%`);
if (changedQuiet.n && Math.abs(q - Core.WIRE.p_quiet) > .08) fail(`静かな夜の組み替えが ${(q * 100).toFixed(0)}%(決まりは ${Core.WIRE.p_quiet * 100}% ± 8)`);
/* 5. 数理モデルの目安(層ごと、7夜の平均) */
const avg = a => a.reduce((s, v) => s + v, 0) / (a.length || 1);
notes.push('| 層 | 階 | 魔物/階 目安 | 平均 | 最少〜最多 | 燐晶 kg/階 目安 | 平均(生成器の宝) |', '|---|---|---|---|---|---|---|');
for (const L of Core.WIRE.layers) {
  const m = mons[L.layer] || [0], k = kg[L.layer] || [0], av = avg(m);
  notes.push(`| 第${L.layer}層 | ${L.floors} | ${L.mon_floor} | ${av.toFixed(0)} | ${Math.min(...m)}〜${Math.max(...m)} | ${L.kg_floor} | ${avg(k).toFixed(0)} |`);
  if (Math.abs(av - L.mon_floor) > L.mon_floor * .4) fail(`第${L.layer}層: 魔物の数の平均 ${av.toFixed(0)} が目安 ${L.mon_floor} の ±40% に入らない(density を直す)`);
}
console.log(notes.join('\n'));
if (fails.length) { console.log(`\n守れていない: ${fails.length}`); for (const f of fails.slice(0, 60)) console.log(' - ' + f); if (fails.length > 60) console.log(` …ほか ${fails.length - 60}`); process.exit(1); }
console.log(`\nすべて守れている(${FLOORS}階 × ${NIGHTS}夜)。`);
