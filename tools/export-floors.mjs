#!/usr/bin/env node
/* Urbs Labyrinthi の生成器(docs/urbs-labyrinthi.html の Core)を Node で動かし、
   Godot が読む層ごとの JSON を書き出す。
   使い方: node tools/export-floors.mjs [出力フォルダ] [種] [夜の数] [層の数]
   既定:   godot/data  vergha  7  10
   人数 1〜4 のそれぞれについて書き出す(遭遇の予算は人数に比例するため)。 */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.resolve(process.argv[2] || path.join(root, 'godot/data'));
const seed = process.argv[3] || 'vergha';
const NIGHTS = +(process.argv[4] || 7), FLOORS = +(process.argv[5] || 10);
/* 層の広さ。上の層ほど、潜る冒険者が多く、広い(docs/dungeon-scale.md)。 */
const FLOOR_SIZE = floor => (floor <= 2 ? 'XXL' : floor <= 4 ? 'XL' : floor <= 6 ? 'L' : 'M');

const html = fs.readFileSync(path.join(root, 'docs/urbs-labyrinthi.html'), 'utf8');
const lines = html.split('\n');
const mons = JSON.parse(/>(\[.*\])<\/script>/.exec(lines.find(l => l.includes('id="mon2014"')))[1]);
const a = lines.findIndex(l => l.startsWith('const Core = (() => {'));
const b = lines.findIndex((l, i) => i > a && l === '})();');
const Core = vm.runInNewContext(lines.slice(a, b + 1).join('\n') + '\nCore;', {});

const monById = new Map(mons.map(m => [m.i, m]));
fs.mkdirSync(path.join(out, 'floors'), { recursive: true });
let total = 0;
for (let night = 0; night < NIGHTS; night++) {
  for (let party = 1; party <= 4; party++) for (let floor = 1; floor <= FLOORS; floor++) {
    const theme = Core.themeForFloor(floor);
    const th = Core.THEMES[theme];
    const D = Core.generate({ seed, theme, floor, night, size: FLOOR_SIZE(floor), level: th.level, party, edition: '2014' }, mons);
    const j = Core.exportJSON(D);
    j.style = { col: th.col, short: th.short, env: th.env, see: th.see, hear: th.hear, smell: th.smell, level: th.level, water: !!th.water };
    j.meta.floor_label = Core.floorLabel(th, floor);
    j.meta.night_label = D.night.label;
    for (const e of j.encounters) for (const m of e.monsters) {   // monLine が落とす項目を足す
      const src = monById.get(m.index);
      if (src) { if (src.mu) m.multiattack = true; if (src.la) m.legendary = true; if (src.sp) m.speed = src.sp; }
    }
    delete j.walls;               // Godot は grid から壁を扱う
    const f = path.join(out, 'floors', `f${String(floor).padStart(2, '0')}_n${String(night).padStart(2, '0')}_p${party}.json`);
    const s = JSON.stringify(j);
    fs.writeFileSync(f, s); total += s.length;
  }
}
/* 闘技場が、遭遇を作るためのデータ(魔物の一覧、舞台ごとの重み、経験点の予算)。
   Core.buildPool / genEncounter を GDScript へ写したもの(scripts/encounter_gen.gd)が読む */
const themes = {};
for (const [id, th] of Object.entries(Core.THEMES)) {
  themes[id] = { name: th.name, short: th.short, level: th.level, water: !!th.water, types: th.types,
    beastRe: th.beastRe ? th.beastRe.source : '', humanoidRe: th.humanoidRe ? th.humanoidRe.source : '', elementalRe: th.elementalRe ? th.elementalRe.source : '',
    sig: th.sig, floors: th.floors };
}
fs.writeFileSync(path.join(out, 'encounter-data.json'), JSON.stringify({ monsters: mons, themes, xp_budget: Core.XP_BUDGET }));
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify({ seed, nights: NIGHTS, floors: FLOORS, schema: Core.SCHEMA }));
console.log(`wrote ${NIGHTS * FLOORS * 4} floors, ${(total / 1024).toFixed(0)} KB →`, out);
