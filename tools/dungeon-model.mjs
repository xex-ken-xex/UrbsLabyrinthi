#!/usr/bin/env node
/* 迷宮の燐の循環の数理モデル(docs/dungeon-model.md の表の元)。
   都市資料の数字(冒険者の数、燐晶の取引額、輸出量、死者の数、魔物の数)から、
   層ごとの燐の生産・採取・蓄えと、ゲームの1階に置く魔物・燐晶・遺体の目安を出し、
   数百年つづく迷宮としてつじつまが合うか(枯れないか、底にいくら溜まるか)を確かめる。
   使い方: node tools/dungeon-model.mjs          表を出す
           node tools/dungeon-model.mjs --json   生成器が読む層ごとの目安を JSON で出す */

/* ---------- 1. 入力(都市資料と、決めたこと) ---------- */
const DEPTH_M = 200;            // 迷宮の深さ(ken 2026-10-17)
const LAMBDA_M = 100;           // 燐の気の濃さが e 倍になる深さ。純度と値段の元
const PRICE_BOTTOM = 200;       // 底の燐晶の値段(銀貨/kg)。生成器の「不明 200」
const CELL_M = 1.524;           // 1マス 5フィート
const SHAFT_M = 20;             // 迷宮の中の大穴(縦穴)の一辺

/* 層。floors は階数(ken: 第1〜2層 5、第3〜6層 4、第7層以降 1)。h_m は1階の高さ。
   area_km2 は層の広がり(docs/dungeon-ecology.md §3。層の全階ぶん)。monsters はその層の魔物の総数(同 §3)。
   q_kg は魔物1体の体に含まれる燐(死ぬと燐晶になる量)。深いほど大きく強い魔物なので多い。 */
const LAYERS = [
  { layer: 1, theme: 'fuyou', floors: 5, h_m: 5, size: 'XXXL', area_km2: 14, monsters: 15000, q_kg: 0.5 },
  { layer: 2, theme: 'fuyou', floors: 5, h_m: 5, size: 'XXXL', area_km2: 14, monsters: 15000, q_kg: 0.5 },
  { layer: 3, theme: 'sabi', floors: 4, h_m: 5.5, size: 'XXL', area_km2: 10, monsters: 9000, q_kg: 1.0 },
  { layer: 4, theme: 'sabi', floors: 4, h_m: 5.5, size: 'XXL', area_km2: 10, monsters: 9000, q_kg: 1.0 },
  { layer: 5, theme: 'kagami', floors: 4, h_m: 5.5, size: 'XXL', area_km2: 6.5, monsters: 4500, q_kg: 2.0 },
  { layer: 6, theme: 'kagami', floors: 4, h_m: 5.5, size: 'XXL', area_km2: 6.5, monsters: 4500, q_kg: 2.0 },
  { layer: 7, theme: 'hone', floors: 1, h_m: 15, size: 'XL', area_km2: 1.5, monsters: 1000, q_kg: 6 },
  { layer: 8, theme: 'hone', floors: 1, h_m: 15, size: 'XL', area_km2: 1.5, monsters: 1000, q_kg: 6 },
  { layer: 9, theme: 'hone', floors: 1, h_m: 15, size: 'XL', area_km2: 1.5, monsters: 1000, q_kg: 6 },
  { layer: 10, theme: 'soko', floors: 1, h_m: 17, size: 'XL', area_km2: 1.1, monsters: 500, q_kg: 20 },
];
const SIZES = { XL: [96, 64], XXL: [128, 86], XXXL: [192, 128] };
const WALK = { XL: 0.288, XXL: 0.306, XXXL: 0.245 };   // 歩ける床の割合(docs/dungeon-scale.md の表から)

/* 冒険者(都市 GM 資料 §14.5)。n 在籍、deaths 年の死者、dives 1人の年の潜行回数、kg 1パーティ1回の持ち帰り、kills 1回に倒す魔物 */
const RANKS = {
  '灰': { n: 1360, deaths: 950, dives: 100, kg: 2.0, kills: 3, layers: [1, 2] },
  '青銅': { n: 1360, deaths: 120, dives: 100, kg: 2.5, kills: 3, layers: [3, 4] },
  '銀': { n: 245, deaths: 17, dives: 80, kg: 2.0, kills: 2.5, layers: [5, 6] },
  '黒鉄': { n: 33, deaths: 2, dives: 40, kg: 1.5, kills: 2, layers: [7, 8, 9] },
};
const PARTY = 4;
const RAW_VALUE_OFFICIAL = 6.0e6;   // 燐晶(原料)の取引額、年(GM §14.2)
const EXPORT_T = 110, NEBASHIRA_T = 12, REFINE_YIELD = 0.95;   // 輸出 110t、根柱 12t(GM §14.1、§16.4)。精錬の歩留まり
const SMUGGLE = 0.2;                // 約2割が密輸(GM §14.5)
const NATURAL_DEATH = 0.5;          // 魔物の自然死、年あたり(息から生まれた体は長くもたない。平均2年)
const CRYSTAL_YIELD = 0.8;          // 死骸の燐のうち、燐晶になる割合
const BODY_STAY_YR = 15, BODY_LEFT = 0.7;   // 遺体が残る年数、持ち帰られずに残る割合
const RHO = 1 / 1000;               // 鉱脈が1年に下の層へ流れる割合(燐は下へ流れる)
const AGE_BEFORE = 2000;            // 大穴が開く前に、迷宮が燐を溜めていた年数
const HUMAN_YEARS = 400;            // 人が掘り始めてからの年数
const BREATH = [3, 1, 4, 5, 6, 5, 7];   // 子守唄の息継ぎ。偶数の節の夜が吐く夜
const P_CHANGE = { quiet: 0.4, exhale: 1.0 };   // 一画が組み替わる確率

/* ---------- 2. 層の深さと値段 ---------- */
let z = 0;
for (const L of LAYERS) { L.top_m = z; z += L.floors * L.h_m; L.bottom_m = z; L.mid_m = (L.top_m + L.bottom_m) / 2; }
const price = zm => PRICE_BOTTOM * Math.exp(-(DEPTH_M - zm) / LAMBDA_M);
const PURITY = { fuyou: ['低', 30], sabi: ['並', 50], kagami: ['高', 80], hone: ['極', 140], soko: ['不明', 200] };
for (const L of LAYERS) { L.price = price(L.mid_m); L.purity = PURITY[L.theme][0]; L.price_table = PURITY[L.theme][1]; }

/* ---------- 3. 冒険者の潜行、殺し、採取 ---------- */
for (const L of LAYERS) { L.dives = 0; L.kills = 0; L.harvest_t = 0; L.deaths = 0; }
const econ = {};
for (const [name, r] of Object.entries(RANKS)) {
  const parties = r.n / PARTY, dives = parties * r.dives;
  const mass_t = dives * r.kg / 1000;
  const ls = r.layers.map(i => LAYERS[i - 1]);
  const value = mass_t * 1000 * ls.reduce((s, L) => s + L.price, 0) / ls.length;
  econ[name] = { parties, dives, mass_t, value, per_person: value / r.n };
  for (const L of ls) { L.dives += dives / ls.length; L.kills += dives * r.kills / ls.length; L.harvest_t += mass_t / ls.length; L.deaths += r.deaths / ls.length; }
}
const totalMass = Object.values(econ).reduce((s, e) => s + e.mass_t, 0);
const totalValue = Object.values(econ).reduce((s, e) => s + e.value, 0);

/* ---------- 4. 燐の生産(魔物の死 → 燐晶)と、息 ---------- */
for (const L of LAYERS) {
  L.births = NATURAL_DEATH * L.monsters + L.kills;        // 定常では、生まれる数 = 死ぬ数
  L.turnover = L.births / L.monsters;
  L.production_t = L.births * L.q_kg * CRYSTAL_YIELD / 1000;
  L.breath_t = L.births * L.q_kg / 1000;                  // 魔物の体になる燐 = 息の取り分
  L.pressure = L.harvest_t / L.production_t;
  L.sustainable_t = Math.min(L.harvest_t, L.production_t);
  L.vein_mining_t = L.harvest_t - L.sustainable_t;        // 生産を超えるぶんは、鉱脈(溜まった燐晶)を削っている
  L.burial_t = L.production_t - L.sustainable_t;          // 拾われずに埋まり、鉱脈になるぶん
  L.tau_pick = 1 / (1 + L.pressure);                      // 燐晶ができてから拾われる(埋まる)までの年数
  L.loose_t = L.production_t * L.tau_pick;                // 床と壁ぎわにある、拾える燐晶
}
const breath_t = LAYERS.reduce((s, L) => s + L.breath_t, 0);

/* ---------- 5. 鉱脈の400年(人が来る前の溜めと、掘られ方) ---------- */
/* 人の推移(年 → [魔物を殺す量の係数, 浅層の鉱脈を掘る量の係数])。いまを 1 とする。
   採掘者の時代(-400〜-300)と大採掘(-300〜-200)は、魔物を殺すより鉱脈を掘った(掘りすぎ → 大海嘯)。
   大海嘯(-200)で人口が3分の1減り、-150 に戻る。深層の探索が抑えられ、空振りの年(-50)からは浅層に人が集まって、いまの採取量になった */
const HISTORY = [[-400, 0.25, 0.3], [-300, 0.5, 0.6], [-200, 0.35, 0.35], [-150, 0.5, 0.5], [-50, 0.5, 0.5], [0, 1, 1]];
const lerp = (t, col) => { if (t < HISTORY[0][0]) return 0; for (let i = 1; i < HISTORY.length; i++) if (t <= HISTORY[i][0]) { const [a, b] = [HISTORY[i - 1], HISTORY[i]]; return a[col] + (b[col] - a[col]) * (t - a[0]) / (b[0] - a[0]); } return 1; };
const humanFactor = t => lerp(t, 1), mineFactor = t => lerp(t, 2);
const V = LAYERS.map(() => 0); let hoard = 0;
const history = [];
for (let t = -(AGE_BEFORE + HUMAN_YEARS); t < 0; t++) {
  const f = humanFactor(t), g = mineFactor(t);
  const flow = LAYERS.map((L, i) => {
    const kills = L.kills * f, births = NATURAL_DEATH * L.monsters + kills;
    const prod = births * L.q_kg * CRYSTAL_YIELD / 1000, harv = L.harvest_t * (L.layer <= 2 ? g : f);
    const sus = Math.min(harv, prod);
    return { burial: prod - sus, mining: harv - sus };
  });
  const down = V.map(v => v * RHO);
  for (let i = 0; i < LAYERS.length; i++) {
    const mined = Math.min(flow[i].mining, V[i] + flow[i].burial + (i ? down[i - 1] : 0));
    LAYERS[i].shortfall = flow[i].mining - mined;     // 鉱脈が尽きて、採れなかったぶん(今年)
    V[i] += flow[i].burial + (i ? down[i - 1] : 0) - mined - down[i];
  }
  hoard += down[LAYERS.length - 1];
  if (t === -HUMAN_YEARS) LAYERS.forEach((L, i) => { L.vein_virgin_t = V[i]; });
  if (t % 100 === -1 || t === -1) history.push({ t: t + 1, V: V.slice(), hoard });
}
LAYERS.forEach((L, i) => { L.vein_t = V[i]; L.years_left = L.vein_mining_t > 0 ? V[i] / L.vein_mining_t : Infinity; });
const hoard_m3 = hoard / 2.2 / 0.6, hoard_h = hoard_m3 / (SHAFT_M * SHAFT_M);

/* ---------- 6. 遺体 ---------- */
for (const L of LAYERS) L.bodies = L.deaths * BODY_LEFT * BODY_STAY_YR;

/* ---------- 7. ゲームの1階(区画)の目安 ---------- */
const NEST = 2.0;      // ギルドが案内する一帯は、巣が平均の2倍集まっている(docs/dungeon-ecology.md §5)
const REACH = 0.6;     // 区画の中の燐晶のうち、壁ぎわや部屋で見つけられる割合
const VEIN_FACE = 0.005;   // 鉱脈のうち、露頭として壁に顔を出している割合
for (const L of LAYERS) {
  const [W, H] = SIZES[L.size];
  L.floor_ha = W * H * CELL_M * CELL_M / 1e4;
  L.floor_walk_ha = L.floor_ha * WALK[L.size];
  L.layer_walk_ha = L.area_km2 * 100 * WALK[L.size];
  L.share = L.floor_walk_ha * L.floors / L.layer_walk_ha;             // 区画(全階)が層に占める割合
  L.mon_per_walk_ha = L.monsters / L.layer_walk_ha;
  L.mon_floor = L.mon_per_walk_ha * L.floor_walk_ha * NEST;
  L.kg_floor = (L.loose_t + L.vein_t * VEIN_FACE) * 1000 / L.layer_walk_ha * L.floor_walk_ha * REACH;   // 露頭と宝。鉱脈のうち露頭として顔を出している割合が VEIN_FACE
  L.drop_kg = L.q_kg * CRYSTAL_YIELD;                                   // 倒した魔物1体が落とす燐晶(平均)
  L.bodies_floor = L.bodies / L.layer_walk_ha * L.floor_walk_ha;
  L.renew_kg_night = L.production_t * 1000 * L.share / 365;            // 区画(全階)で1夜に新しくできる燐晶
}

/* ---------- 8. 夜の決まり ---------- */
const mirrorRoom = n => { let r = 0; for (let p = 0; p < n; p++) r = (r + BREATH[p % 7]) % 7; return r; };
const seq = Array.from({ length: 49 }, (_, n) => mirrorRoom(n));
const visited = new Set(seq).size, period = (() => { for (let p = 1; p <= 49; p++) if (mirrorRoom(p) === 0 && mirrorRoom(p + 1) === mirrorRoom(1)) return p; return -1; })();
const exhaleNights = [0, 1, 2, 3, 4, 5, 6].filter(s => BREATH[s] % 2 === 0);
let lifeNights = 0;   // 一画の地形が、何夜もつか(期待値。どの夜に組み替わったかで平均)。吐く夜で必ず替わる
for (let s = 0; s < 7; s++) { let keep = 1, life = 0; for (let n = s; n < s + 7; n++) { const p = exhaleNights.includes(n % 7) ? P_CHANGE.exhale : P_CHANGE.quiet; life += keep; keep *= 1 - p; } lifeNights += life / 7; }

/* 舞台ごとの値段(舞台の真ん中の深さで) */
const THEME_PRICE = [];
for (const th of ['fuyou', 'sabi', 'kagami', 'hone', 'soko']) { const ls = LAYERS.filter(L => L.theme === th); const mid = (ls[0].top_m + ls[ls.length - 1].bottom_m) / 2; THEME_PRICE.push({ purity: PURITY[th][0], table: PURITY[th][1], price: price(mid), mid }); }

/* ---------- 9. 確かめ ---------- */
const officialMass = totalMass * (1 - SMUGGLE), officialValue = totalValue * (1 - SMUGGLE);
const needRaw = (EXPORT_T + NEBASHIRA_T) / REFINE_YIELD;
const prodTotal = LAYERS.reduce((s, L) => s + L.production_t, 0);
const checks = [
  ['燐晶(原料)の公の取引額が 600万銀貨(±20%)', Math.abs(officialValue / RAW_VALUE_OFFICIAL - 1) < 0.2, `${(officialValue / 1e6).toFixed(2)}M(密輸を除く)`],
  ['公の原料の量が、輸出110t + 根柱12t を精錬の歩留まりで割った量を満たす', officialMass >= needRaw * 0.9, `${officialMass.toFixed(0)}t ≥ ${needRaw.toFixed(0)}t`],
  ['採取の合計が、魔物の生産の合計を超えない(迷宮全体で枯れない)', totalMass <= prodTotal * 1.05, `採取 ${totalMass.toFixed(0)}t / 生産 ${prodTotal.toFixed(0)}t`],
  ['浅層(第1〜2層)は生産を超えて採っていて、第1層の鉱脈は尽きかけ(残り 5〜60年)、第2層も減っている(300年未満)', LAYERS.slice(0, 2).every(L => L.pressure > 1) && LAYERS[0].years_left > 5 && LAYERS[0].years_left < 60 && LAYERS[1].years_left < 300, LAYERS.slice(0, 2).map(L => `第${L.layer}層 あと${L.years_left.toFixed(0)}年`).join('、')],
  ['第3層より下は、鉱脈が残っている(採っても400年もつ)', LAYERS.slice(2).every(L => L.years_left > 400), LAYERS.slice(2).map(L => `第${L.layer}層 ${L.vein_t.toFixed(0)}t`).join('、')],
  ['底の蓄えが、縦穴(20m四方)の底に収まる高さ(5〜30m)', hoard_h > 5 && hoard_h < 30, `${hoard.toFixed(0)}t、高さ ${hoard_h.toFixed(1)}m`],
  ['一人あたりの燐晶の年収(公の取引)が、約2,000銀貨(±20%)', Math.abs(officialValue / 3000 / 2000 - 1) < 0.2, `${(officialValue / 3000).toFixed(0)}銀貨(密輸を入れると ${(totalValue / 3000).toFixed(0)})`],
  ['値段の式(底200 × e^(-(200-z)/100))が、舞台ごとの純度の表(30/50/80/140/200)と合う(±20%)', THEME_PRICE.every(t => Math.abs(t.price / t.table - 1) < 0.2), THEME_PRICE.map(t => `${t.purity} ${t.price.toFixed(0)}(表 ${t.table})`).join('、')],
  ['大海嘯(5万体)が、息の数か月ぶんで足りる', 50000 * 0.5 / 1000 < breath_t * 0.5, `海嘯 ${(50000 * 0.5 / 1000).toFixed(0)}t / 息 年${breath_t.toFixed(0)}t`],
  ['階段の候補地は、49夜で7つ全部を巡って元に戻る', visited === 7 && period === 49, `巡る数 ${visited}、周期 ${period}`],
  ['一画の地形は、数夜で替わる(期待 1.5〜5夜)', lifeNights >= 1.5 && lifeNights <= 5, `${lifeNights.toFixed(1)}夜`],
  ['ゲームの1階の魔物が、いまの生成器の目安(第1層 約110体)と大きく違わない', LAYERS[0].mon_floor > 80 && LAYERS[0].mon_floor < 150, `${LAYERS[0].mon_floor.toFixed(0)}体`],
];

/* ---------- 出力 ---------- */
if (process.argv.includes('--json')) {
  console.log(JSON.stringify({
    depth_m: DEPTH_M, lambda_m: LAMBDA_M, shaft_m: SHAFT_M, breath_t_per_year: +breath_t.toFixed(1), hoard_t: +hoard.toFixed(0),
    layers: LAYERS.map(L => ({ layer: L.layer, theme: L.theme, floors: L.floors, h_m: L.h_m, top_m: L.top_m, size: L.size, price: +L.price.toFixed(0), purity: L.purity,
      mon_floor: +L.mon_floor.toFixed(0), kg_floor: +L.kg_floor.toFixed(1), drop_kg: +L.drop_kg.toFixed(2), bodies_floor: +L.bodies_floor.toFixed(1), renew_kg_night: +L.renew_kg_night.toFixed(2) })),
    p_change: P_CHANGE, exhale_nights: exhaleNights, ok: checks.every(c => c[1]),
  }, null, 1));
  process.exit(0);
}
const f = (v, d = 0) => (typeof v === 'number' && isFinite(v)) ? v.toFixed(d) : '—';
console.log('## 層ごとの燐の流れ(年)\n');
console.log('| 層 | 深さ(m) | 純度・値段(表 / 式) | 魔物 | 1体の燐(kg) | 潜行 | 殺し | 生まれる | 入れ替わり | 生産(t) | 採取(t) | 採取/生産 | 拾える燐晶(t) | 鉱脈 いま(t) | 鉱脈 400年前(t) | 鉱脈の残り(年) |');
console.log('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
for (const L of LAYERS) console.log(`| 第${L.layer}層 | ${f(L.top_m)}〜${f(L.bottom_m)} | ${L.purity} ${L.price_table} / ${f(L.price)} | ${L.monsters} | ${L.q_kg} | ${f(L.dives)} | ${f(L.kills)} | ${f(L.births)} | ${f(L.turnover, 1)}/年 | ${f(L.production_t, 1)} | ${f(L.harvest_t, 1)} | ${f(L.pressure, 2)} | ${f(L.loose_t, 1)} | ${f(L.vein_t)} | ${f(L.vein_virgin_t)} | ${isFinite(L.years_left) ? f(L.years_left) : '減らない'} |`);
console.log(`\n息(魔物の体になる燐): 年 ${f(breath_t)}t。生産の合計 ${f(prodTotal)}t、採取の合計 ${f(totalMass)}t。底の蓄え ${f(hoard)}t(縦穴の底に高さ ${f(hoard_h, 1)}m)。`);
console.log('\n## 冒険者の採取(年)\n');
console.log('| 等級 | 在籍 | パーティ | 潜行 | 持ち帰り(t) | 値(銀貨) | 1人の年収(銀貨) |\n|---|---|---|---|---|---|---|');
for (const [n, e] of Object.entries(econ)) console.log(`| ${n} | ${RANKS[n].n} | ${f(e.parties)} | ${f(e.dives)} | ${f(e.mass_t, 1)} | ${f(e.value)} | ${f(e.per_person)} |`);
console.log(`\n合計 ${f(totalMass)}t、${f(totalValue)}銀貨。密輸 ${SMUGGLE * 100}% を除いた公の取引 ${f(officialMass)}t、${f(officialValue)}銀貨。輸出と根柱に要る原料 ${f(needRaw)}t。`);
console.log('\n## 鉱脈の推移(t)\n');
console.log('| 年 | ' + LAYERS.map(L => `第${L.layer}層`).join(' | ') + ' | 底の蓄え |\n|---|' + LAYERS.map(() => '---').join('|') + '|---|');
for (const h of history) console.log(`| ${h.t} | ${h.V.map(v => f(v)).join(' | ')} | ${f(h.hoard)} |`);
console.log('\n## ゲームの1階(区画)の目安\n');
console.log('| 層 | 広さ | 歩ける床(ha) | 区画が層に占める割合 | 魔物 | 燐晶(露頭と宝、kg) | 1体が落とす(kg) | 遺体 | 区画で1夜に育つ燐晶(kg) |\n|---|---|---|---|---|---|---|---|---|');
for (const L of LAYERS) console.log(`| 第${L.layer}層 | ${L.size} | ${f(L.floor_walk_ha, 2)} | ${f(L.share * 100, 1)}% | ${f(L.mon_floor)} | ${f(L.kg_floor, 1)} | ${f(L.drop_kg, 2)} | ${f(L.bodies_floor, 1)} | ${f(L.renew_kg_night, 2)} |`);
console.log(`\n## 夜の決まり\n\n吐く夜は節 ${exhaleNights.map(s => s + 1).join('・')}(夜の番号 mod 7 = ${exhaleNights.join('・')})。一画の地形は期待 ${f(lifeNights, 1)}夜でかわる。階段の候補地は ${visited} か所を周期 ${period} 夜で巡る。`);
console.log('\n## 確かめ\n');
for (const [name, ok, detail] of checks) console.log(`- ${ok ? 'OK' : 'NG'} ${name}: ${detail}`);
process.exitCode = checks.every(c => c[1]) ? 0 : 1;
