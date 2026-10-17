#!/usr/bin/env node
/* Urbs Labyrinthi の生成器(docs/urbs-labyrinthi.html の Core)を Node で動かし、
   Godot が読む階ごとの JSON を書き出す。
   使い方: node tools/export-floors.mjs [出力フォルダ] [種] [夜の数]
   既定:   godot/data  vergha  7(層と階の数は Core.WIRE。docs/dungeon-model.md)
   人数 1〜4 のそれぞれについて書き出す(遭遇の予算は人数に比例するため)。
   書き出したら node tools/check-floors.mjs で確かめ、python3 tools/export-bestiary.py で日記帳の一覧を作り直す。 */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.resolve(process.argv[2] || path.join(root, 'godot/data'));
const seed = process.argv[3] || 'vergha';
const NIGHTS = +(process.argv[4] || 7);
// Godot が使う項目だけ残す(地図と魔物の説明文は、ゲームでは使わない)
const KEEP_MON = ['index', 'name', 'name_ja', 'count', 'cr', 'xp', 'ac', 'hp', 'size', 'type', 'speed', 'attacks', 'multiattack', 'legendary', 'world_name'];

const html = fs.readFileSync(path.join(root, 'docs/urbs-labyrinthi.html'), 'utf8');
const lines = html.split('\n');
const mons = JSON.parse(/>(\[.*\])<\/script>/.exec(lines.find(l => l.includes('id="mon2014"')))[1]);
const a = lines.findIndex(l => l.startsWith('const Core = (() => {'));
const b = lines.findIndex((l, i) => i > a && l === '})();');
const Core = vm.runInNewContext(lines.slice(a, b + 1).join('\n') + '\nCore;', {});

/* 層(第N層)は、複数の階(ゲームの1マップ)のグループ。階の数、1階の広さ、高さ、魔物の密度は、生成器のワイヤフレーム
   Core.WIRE が持つ(数理モデル tools/dungeon-model.mjs の目安つき。docs/dungeon-scale.md、docs/dungeon-model.md)。
   density … 巣のある部屋の割合にかける係数(1 で生成器の標準) */
const LAYERS = Core.WIRE.layers.map(L => ({ layer: L.layer, theme: L.theme, floors: L.floors, size: L.size, density: L.density, h_m: L.h_m, top_m: L.top_m, mon_floor: L.mon_floor, kg_floor: L.kg_floor, bodies_floor: L.bodies_floor, drop_kg: L.drop_kg, lair: !!L.lair }));
const DEPTHS = Core.DEPTHS; // 階の通し番号(1〜)ごとの { layer, sub, subs, size, density, ... }
const FLOORS = DEPTHS.length;

const monById = new Map(mons.map(m => [m.i, m]));
fs.mkdirSync(path.join(out, 'floors'), { recursive: true });
for (const f of fs.readdirSync(path.join(out, 'floors'))) if (/^f\d\d_n\d\d_p\d\.json(\.gz)?$/.test(f)) fs.unlinkSync(path.join(out, 'floors', f));   // 古い階(階数が減ったとき用)
let total = 0;
const t0 = Date.now();
for (let night = 0; night < NIGHTS; night++) {
  for (let party = 1; party <= 4; party++) for (let depth = 1; depth <= FLOORS; depth++) {
    const D0 = DEPTHS[depth - 1];
    const theme = Core.themeForFloor(D0.layer);
    const th = Core.THEMES[theme];
    // 同じ層の2階め以降は、sub で別の地図になる(骨組みの種が変わる。縦穴と候補地は同じ位置)
    const D = Core.generate({ seed, theme, floor: D0.layer, sub: D0.sub, subs: D0.subs, night, size: D0.size, level: th.level, party, edition: '2014', ecology: true, density: D0.density }, mons);
    const j = Core.exportJSON(D);
    j.style = { col: th.col, short: th.short, env: th.env, see: th.see, hear: th.hear, smell: th.smell, level: th.level, water: !!th.water };
    j.meta.depth = depth; j.meta.layer = D0.layer; j.meta.sub = D0.sub; j.meta.subs = D0.subs;
    j.meta.floor_label = Core.floorLabel(th, D0.layer, D0.sub, D0.subs);
    j.meta.night_label = D.night.label;
    for (const e of j.encounters) for (const m of e.monsters) {   // monLine が落とす項目を足す
      const src = monById.get(m.index);
      if (src) { if (src.mu) m.multiattack = true; if (src.la) m.legendary = true; if (src.sp) m.speed = src.sp; }
      for (const k of Object.keys(m)) if (!KEEP_MON.includes(k)) delete m[k];
    }
    for (const r of j.rooms) { delete r.exits; delete r.flavor; delete r.traps; }
    delete j.walls;               // Godot は grid から壁を扱う
    const f = path.join(out, 'floors', `f${String(depth).padStart(2, '0')}_n${String(night).padStart(2, '0')}_p${party}.json.gz`);
    const s = zlib.gzipSync(Buffer.from(JSON.stringify(j)), { level: 9 });     // gzip(Godot が読む。pck を小さくするため)
    fs.writeFileSync(f, s); total += s.length;
  }
  process.stdout.write(`night ${night}: ${FLOORS * 4} files, ${((Date.now() - t0) / 1000).toFixed(0)}s\n`);
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
const { layers: _l, ...wire } = Core.WIRE;
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify({ seed, nights: NIGHTS, floors: FLOORS, layers: LAYERS, wire, schema: Core.SCHEMA, generator: Core.GENERATOR }));
console.log(`wrote ${NIGHTS * FLOORS * 4} floors (${FLOORS} 階), ${(total / 1024).toFixed(0)} KB →`, out);
