#!/usr/bin/env node
/* 層ごとの魔物の密度と、縄張りの足りなさを調べる。docs/dungeon-ecology.md の表の元。
   使い方: node tools/analyze-ecology.mjs            新しい設定(縄張りと密度を使う)と、旧い設定(使わない)を並べる */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const html = fs.readFileSync(path.join(root, 'docs/urbs-labyrinthi.html'), 'utf8');
const lines = html.split('\n');
const mons = JSON.parse(/>(\[.*\])<\/script>/.exec(lines.find(l => l.includes('id="mon2014"')))[1]);
const a = lines.findIndex(l => l.startsWith('const Core = (() => {'));
const b = lines.findIndex((l, i) => i > a && l === '})();');
const Core = vm.runInNewContext(lines.slice(a, b + 1).join('\n') + '\nCore;', {});
const monById = new Map(mons.map(m => [m.i, m]));
const M2_PER_CELL = 1.524 * 1.524;      // 1マス 5フィート
// 縄張り(歩ける床の広さ、m²)。1体あたり。群れは n^0.6 で、分け合う
const TERR = { T: 150, S: 250, M: 600, L: 1500, H: 4000, G: 10000 };
const terrOf = e => { const n = e.groups.reduce((s, g) => s + g.n, 0); return Math.max(...e.groups.map(g => TERR[(monById.get(g.i) || {}).z || 'M'])) * Math.pow(n, 0.6); };
const LAYERS = process.env.LAYERS_JSON ? JSON.parse(process.env.LAYERS_JSON) : JSON.parse(fs.readFileSync(path.join(root, 'godot/data/manifest.json'), 'utf8')).layers;
function run(label, eco) {
  const rows = [];
  for (const L of LAYERS) {
    const theme = Core.themeForFloor(L.layer), th = Core.THEMES[theme];
    let acc = { cells: 0, open: 0, mon: 0, enc: 0, dens: 0, terr: 0, treasure: 0, n: 0, minGap: 1e9 };
    for (let sub = 0; sub < L.floors; sub++) for (let night = 0; night < 7; night++) {
      const D = Core.generate({ seed: sub ? `vergha#${sub + 1}` : 'vergha', theme, floor: L.layer, night, size: L.size, level: th.level, party: 4, edition: '2014', ecology: eco, density: eco ? L.density : 1 }, mons);
      const open = D.tiles.reduce((s, t) => s + (t !== 0 ? 1 : 0), 0);
      acc.cells += D.W * D.H; acc.open += open; acc.n++;
      acc.enc += D.encs.length; acc.dens += D.encs.filter(e => e.roomId >= 0).length;
      for (const e of D.encs) { acc.mon += e.tokens.length; acc.terr += terrOf(e); }
      acc.treasure += D.rooms.filter(r => r.treasure).length;
      const ds = D.encs.filter(e => e.roomId >= 0).map(e => D.rooms.find(r => r.id === e.roomId));
      for (let i = 0; i < ds.length; i++) for (let j = i + 1; j < ds.length; j++) acc.minGap = Math.min(acc.minGap, Math.hypot(ds[i].cx - ds[j].cx, ds[i].cy - ds[j].cy));
    }
    const n = acc.n, ha = acc.cells / n * M2_PER_CELL / 1e4, openM2 = acc.open / n * M2_PER_CELL;
    rows.push({ layer: L.layer, size: L.size, floors: L.floors, ha: ha, openHa: openM2 / 1e4, mon: acc.mon / n, groups: acc.enc / n, dens: acc.dens / n, perHa: acc.mon / n / ha, terrIdx: (acc.terr / n) / openM2, treasure: acc.treasure / n, minGap: acc.minGap });
  }
  return rows;
}
const fmt = r => `| 第${r.layer}層 | ${r.size} | ${r.floors} | ${r.ha.toFixed(2)} | ${r.openHa.toFixed(2)} | ${r.groups.toFixed(1)} | ${r.mon.toFixed(0)} | ${r.perHa.toFixed(0)} | ${r.terrIdx.toFixed(2)} | ${r.treasure.toFixed(1)} |`;
const head = '| 層 | 1階の広さ | 階数 | 1階の面積(ha) | 歩ける床(ha) | 魔物の群れ | 魔物 | 魔物/ha | 縄張りの混み具合 | 宝の部屋 |\n|---|---|---|---|---|---|---|---|---|---|';
const old = process.env.SKIP_OLD ? [] : run('old', false), neu = run('new', true);
if (old.length) console.log('## 旧い設定(密度1、縄張りなし)\n' + head + '\n' + old.map(fmt).join('\n'));
console.log('\n## 新しい設定(密度と縄張りあり)\n' + head + '\n' + neu.map(fmt).join('\n'));
const sum = (rows, f) => rows.reduce((s, r) => s + f(r) * r.floors, 0);
console.log('\n合計(階ぶん): 魔物', sum(neu, r => r.mon).toFixed(0), ' 階 ', LAYERS.reduce((s, l) => s + l.floors, 0), ' 面積(ha) ', sum(neu, r => r.ha).toFixed(1), ' 歩ける床(ha) ', sum(neu, r => r.openHa).toFixed(1));
