---
title: 画像生成用プロンプト(アイテムのアイコンシート)
audience: 画像を作る人、開発用
pair: godot/assets/OVERRIDE.md(差し替えのしかた)、tools/make-items.py(同梱のシートを描くコード)、docs/items-and-forage.md(品物の説明)
---

# アイテムのアイコンシート

燐晶、迷宮の自生物、魔物の素材、遺品、消耗品のアイコンを、1枚のシートで作る。同梱の仮の絵は `godot/assets/items/items_sheet.png`(`tools/make-items.py` が描く)。

## 1. シートの形

- **16列 × 5行**(全72マス)。1マス 32×32。シート全体は **512×160 ピクセル**。透明な背景。
- マスの並びは、下の表の「マス」の番号(0から。左上が0、右へ数え、行が替わる)。**この並びは変えない**(ゲームが、`data/item-icons.json` の番号で切り出す)。
- 解像度を上げたいときは、同じ並びのまま、横幅を 16 の倍数にする(例: 1マス 64×64 なら 1024×320)。ゲームは、横幅÷16 を1マスの大きさとして切る。
- 1つだけ差し替えたいときは、`item_<id>.png`(例: `item_kuro_take.png`)を `assets/` に置く。シートより優先される。

## 2. 共通の形式

```
Create a production-oriented 2D pixel art item icon sheet for a Godot game.

VISUAL STYLE

- Consistent dark fantasy pixel art in a polished 16-bit-inspired style.
- Match the visual style of the provided reference image, image_2.png.
- Crisp pixel clusters, deliberate pixel placement, clean silhouettes with a 1-pixel dark outline, controlled shading, a limited colour palette.
- Each item is readable at 32x32 and also when drawn at 20x20 on a dark mossy cave floor.
- No anti-aliased edges, no vector graphics, no painterly textures, no smooth gradients, no text.

TECHNICAL LAYOUT

- One sprite sheet with exactly 16 columns and 5 rows of 32x32 cells: exactly 512x160 pixels.
- Transparent background. No spacing, padding, gutters or gaps between cells.
- Each icon is one object, centred in its cell, resting near the bottom of the cell, entirely inside it.
- Lit from the upper left.
- Place the icons exactly in the cell order of the list below (cell 0 is the top-left; cells run left to right, then the next row). Leave unused cells empty.

ICON LIST (cell number: id — description)

[下の表の「マス」「id」「絵の指示」を、1行ずつ貼る]
```

## 3. 絵の方針

- **燐晶**は、すべて「光る石」。純度が上がるほど、明るく、きらめきが増える。ゲームが、周りに光の輪ときらめきを足すので、絵の中に光の輪は描かない。
- **茸と苔**は、舞台の色を思わせる(腐葉=緑・青白、錆鉄=橙・鉄色、鏡=銀・水色、骨=象牙色、底=紫)。
- **光る自生物**(灯り茸、光苔、軟光など)は、自分で光って見えるようにする(明るい点を足す)。
- 遺体は、地面に置く絵。横たわった冒険者。血を描かない(穏やかな絵にする)。

## 4. 一覧

| マス | id | 名前 | 絵の指示(英語) |
|---|---|---|---|
| 0 | `crystal_low_s` | 燐晶 低・欠片 | a single small shard of luminous crystal (phosphor crystal), dull grey-blue, cloudy, faint glints |
| 1 | `crystal_low_m` | 燐晶 低・かたまり | a cluster of three shards of luminous crystal (phosphor crystal), dull grey-blue, cloudy, faint glints |
| 2 | `crystal_low_l` | 燐晶 低・大きな塊 | a large cluster of five shards on a rock base of luminous crystal (phosphor crystal), dull grey-blue, cloudy, faint glints |
| 3 | `crystal_mid_s` | 燐晶 並・欠片 | a single small shard of luminous crystal (phosphor crystal), clear teal-blue, steady glow |
| 4 | `crystal_mid_m` | 燐晶 並・かたまり | a cluster of three shards of luminous crystal (phosphor crystal), clear teal-blue, steady glow |
| 5 | `crystal_mid_l` | 燐晶 並・大きな塊 | a large cluster of five shards on a rock base of luminous crystal (phosphor crystal), clear teal-blue, steady glow |
| 6 | `crystal_high_s` | 燐晶 高・欠片 | a single small shard of luminous crystal (phosphor crystal), bright cyan-white, strong glow and sparkles |
| 7 | `crystal_high_m` | 燐晶 高・かたまり | a cluster of three shards of luminous crystal (phosphor crystal), bright cyan-white, strong glow and sparkles |
| 8 | `crystal_high_l` | 燐晶 高・大きな塊 | a large cluster of five shards on a rock base of luminous crystal (phosphor crystal), bright cyan-white, strong glow and sparkles |
| 9 | `crystal_pure_s` | 燐晶 極・欠片 | a single small shard of luminous crystal (phosphor crystal), violet-white prism with rainbow facets and rays |
| 10 | `crystal_pure_m` | 燐晶 極・かたまり | a cluster of three shards of luminous crystal (phosphor crystal), violet-white prism with rainbow facets and rays |
| 11 | `crystal_pure_l` | 燐晶 極・大きな塊 | a large cluster of five shards on a rock base of luminous crystal (phosphor crystal), violet-white prism with rainbow facets and rays |
| 12 | `crystal_unk_s` | 燐晶 不明・欠片 | a single small shard of luminous crystal (phosphor crystal), near-black violet with unstable white sparkles (the glow never settles) |
| 13 | `crystal_unk_m` | 燐晶 不明・かたまり | a cluster of three shards of luminous crystal (phosphor crystal), near-black violet with unstable white sparkles (the glow never settles) |
| 14 | `crystal_unk_l` | 燐晶 不明・大きな塊 | a large cluster of five shards on a rock base of luminous crystal (phosphor crystal), near-black violet with unstable white sparkles (the glow never settles) |
| 15 | `potion` | 治療薬 | a corked round glass bottle of red healing potion |
| 16 | `hi_potion` | 上級治療薬 | a larger bottle of bright pink high potion with sparkles |
| 17 | `ether` | 魔力水 | a corked round glass bottle of blue mana water |
| 18 | `revive_charm` | 蘇生の護符 | a round golden charm with a red cross, tied with a short cord |
| 19 | `lamp_oil` | 燐晶の灯油 | a flat glass flask of yellow glowing lamp oil |
| 20 | `return_scroll` | 帰還の札 | a rolled cream parchment scroll with a red wax seal |
| 21 | `kuro_take` | 黒茸 | two small charcoal-black mushrooms with grey stems and faint grey speckles |
| 22 | `no_hai_imo` | 野灰芋 | a lumpy ash-grey tuber (wild potato) with a tiny green sprout on top |
| 23 | `yakusou` | 洞窟薬草 | a small cave herb plant with green leaves and a tiny pale yellow flower |
| 24 | `koke_mitsu` | 苔蜜 | a small glass-like jar of golden moss honey with a brown wooden lid |
| 25 | `mekura_uo` | 目なし魚 | a pale white blind cave fish, no visible eye, side view |
| 26 | `kotsufun_take` | 骨粉茸 | a tall ivory-white mushroom with a smooth cap, like bone powder |
| 27 | `reimu_no_hana` | 冷霧の花 | a single pale blue flower with white center on a green stem, cold mist feel |
| 28 | `zui_mitsu` | 髄蜜 | a jar of translucent pale-gold marrow honey, with a soft golden glow and sparkles |
| 29 | `nanashi_no_mi` | 名なしの実 | a round violet fruit with a small dark leaf, faintly sparkling, unnaturally smooth |
| 30 | `kemono_niku` | 獣肉 | a raw cut of red meat on a pale bone |
| 31 | `hikari_goke` | 光苔 | a mound of teal glowing moss with tiny luminous specks |
| 32 | `shizuku_goke` | 雫苔 | a mound of blue-green wet moss with a dripping drop of glowing water |
| 33 | `sabi_mizu` | 鉱水 | a clear glass flask of grey, metallic-tasting mineral water |
| 34 | `mizukagami_so` | 水鏡草 | a round mirror-like silvery-cyan floating leaf plant with a white flower |
| 35 | `tomoshi_take` | 灯り茸 | two pale-blue mushrooms glowing from within, light cyan stems |
| 36 | `yawaraka_hikari` | 軟光 | a soft lilac glowing jelly blob, translucent, with sparkles |
| 37 | `kodo_nira` | 坑道韮 | a bunch of green chive-like blades tied with a pale cloth |
| 38 | `tetsu_take` | 鉄茸 | a hard reddish-brown mushroom with a metallic sheen |
| 39 | `kagami_goke` | 鏡苔 | a mound of silvery-white moss that reflects light, with sparkles |
| 40 | `inori_goke` | 祈りの苔 | a mound of pale ivory moss with a soft warm glow |
| 41 | `iki_take` | 息茸 | a tall lavender mushroom that looks like it is breathing, soft violet glow |
| 42 | `nemuri_take` | 眠り茸 | two purple mushrooms with lighter spores floating, sleepy look |
| 43 | `sakebi_take` | 叫び茸 | a tall red mushroom with a cream stem, shaped like an open screaming mouth |
| 44 | `doku_take` | 毒茸 | two magenta-pink mushrooms with pale spots, clearly poisonous |
| 45 | `sabi_goke` | 錆苔 | a mound of orange-rust coloured moss |
| 46 | `iwa_jio` | 岩塩 | three white rock-salt crystals stacked like cubes |
| 47 | `komori_fun` | 蝙蝠糞 | a small pile of dark brown bat droppings |
| 48 | `mizu_hiru` | 水蛭 | a dark purple-brown leech, curled, with a tiny red mark |
| 49 | `shinju_gai` | 真珠貝 | a large lavender-white clam shell, slightly open, with a pearl-white inside |
| 50 | `shinju` | 真珠 | a single glossy white pearl with a soft highlight and a sparkle |
| 51 | `sui_sho_mo` | 水晶藻 | a mound of pale cyan seaweed covered in tiny glass crystals |
| 52 | `hone_no_hana` | 骨の花 | a white flower with bone-coloured petals and a dark centre |
| 53 | `furui_ko` | 古い香 | a lump of amber-orange hardened incense resin with a glossy highlight |
| 54 | `byakuro` | 白蝋 | a cream-white wax block with a candle wick and a tiny flame |
| 55 | `zugai_take` | 頭蓋茸 | a pale mushroom shaped like a tiny skull, dark eye holes |
| 56 | `kemono_kawa` | 獣皮 | a flat folded brown animal pelt with fur edges |
| 57 | `kiba` | 牙と爪 | two curved ivory beast fangs |
| 58 | `nenneki` | 粘液 | a green blob of slime with a wet highlight |
| 59 | `honekuzu` | 骨片 | a crossed pair of bone fragments, ivory |
| 60 | `hakatsuchi` | 墓土 | a dark clump of grave soil |
| 61 | `tetsukuzu` | 鉄屑 | a pile of grey-blue scrap iron plates, jagged |
| 62 | `ma_ha` | 魔草の葉 | a leafy green magical herb sprig, darker and richer than the cave herb |
| 63 | `yakeishi` | 焼け石 | a charcoal-black stone with glowing orange cracks and a tiny flame |
| 64 | `uroko` | 魔物の鱗 | a cluster of four teal-green scales, glossy |
| 65 | `doku_sen` | 毒腺 | a lime-green venom gland sac with a small tube and a brown cap |
| 66 | `hane` | 羽 | a single long off-white feather |
| 67 | `relic_gear` | 遺品の装備 | a small bundle of old armour pieces (a breastplate and two pauldrons), steel grey |
| 68 | `relic_tools` | 遺品の道具 | a bundle of old tools: a small pick and a leather satchel |
| 69 | `relic_tag` | 認識票 | a grey metal guild identification tag on a thin chain |
| 70 | `relic_coins` | 古い銀貨 | a small pile of four old silver coins |
| 71 | `corpse` | 遺体(地面に置く絵) | (drawn on the ground) the body of a fallen adventurer lying sideways, blue tunic, brown boots |
