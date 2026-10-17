---
title: 画像生成用プロンプト(アイテムのアイコンシート)
audience: 画像を作る人、開発用
pair: godot/assets/OVERRIDE.md(差し替えのしかた)、tools/make-items.py(同梱のシートを描くコード)、docs/items-and-forage.md(品物の説明)
---

# アイテムのアイコンシート

燐晶、迷宮の自生物、魔物の素材、遺品、消耗品のアイコンを、1枚のシートで作る。同梱の仮の絵は `godot/assets/items/items_sheet.png`(`tools/make-items.py` が描く)。

## 1. シートの形

- **16列 × 10行**(全147マス)。1マス 32×32。シート全体は **512×320 ピクセル**。透明な背景。
- マスの並びは、下の表の「マス」の番号(0から。左上が0、右へ数え、行が替わる)。**この並びは変えない**(ゲームが、`data/item-icons.json` の番号で切り出す)。
- 解像度を上げたいときは、同じ並びのまま、横幅を 16 の倍数にする(例: 1マス 64×64 なら 1024×640)。ゲームは、横幅÷16 を1マスの大きさとして切る。
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

- One sprite sheet with exactly 16 columns and 10 rows of 32x32 cells: exactly 512x320 pixels.
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
| 21 | `antidote` | antidote |  |
| 22 | `sleep_bottle` | sleep_bottle |  |
| 23 | `shriek_bottle` | shriek_bottle |  |
| 24 | `power_draught` | power_draught |  |
| 25 | `stone_draught` | stone_draught |  |
| 26 | `wind_draught` | wind_draught |  |
| 27 | `hi_ether` | hi_ether |  |
| 28 | `regen_elixir` | regen_elixir |  |
| 29 | `marrow_elixir` | marrow_elixir |  |
| 30 | `murky` | murky |  |
| 31 | `tetsukai` | tetsukai |  |
| 32 | `sumi` | sumi |  |
| 33 | `yumizai` | yumizai |  |
| 34 | `kuro_take` | 黒茸 | two small charcoal-black mushrooms with grey stems and faint grey speckles |
| 35 | `no_hai_imo` | 野灰芋 | a lumpy ash-grey tuber (wild potato) with a tiny green sprout on top |
| 36 | `yakusou` | 洞窟薬草 | a small cave herb plant with green leaves and a tiny pale yellow flower |
| 37 | `koke_mitsu` | 苔蜜 | a small glass-like jar of golden moss honey with a brown wooden lid |
| 38 | `mekura_uo` | 目なし魚 | a pale white blind cave fish, no visible eye, side view |
| 39 | `kotsufun_take` | 骨粉茸 | a tall ivory-white mushroom with a smooth cap, like bone powder |
| 40 | `reimu_no_hana` | 冷霧の花 | a single pale blue flower with white center on a green stem, cold mist feel |
| 41 | `zui_mitsu` | 髄蜜 | a jar of translucent pale-gold marrow honey, with a soft golden glow and sparkles |
| 42 | `nanashi_no_mi` | 名なしの実 | a round violet fruit with a small dark leaf, faintly sparkling, unnaturally smooth |
| 43 | `kemono_niku` | 獣肉 | a raw cut of red meat on a pale bone |
| 44 | `hikari_goke` | 光苔 | a mound of teal glowing moss with tiny luminous specks |
| 45 | `shizuku_goke` | 雫苔 | a mound of blue-green wet moss with a dripping drop of glowing water |
| 46 | `sabi_mizu` | 鉱水 | a clear glass flask of grey, metallic-tasting mineral water |
| 47 | `mizukagami_so` | 水鏡草 | a round mirror-like silvery-cyan floating leaf plant with a white flower |
| 48 | `tomoshi_take` | 灯り茸 | two pale-blue mushrooms glowing from within, light cyan stems |
| 49 | `yawaraka_hikari` | 軟光 | a soft lilac glowing jelly blob, translucent, with sparkles |
| 50 | `kodo_nira` | 坑道韮 | a bunch of green chive-like blades tied with a pale cloth |
| 51 | `tetsu_take` | 鉄茸 | a hard reddish-brown mushroom with a metallic sheen |
| 52 | `kagami_goke` | 鏡苔 | a mound of silvery-white moss that reflects light, with sparkles |
| 53 | `inori_goke` | 祈りの苔 | a mound of pale ivory moss with a soft warm glow |
| 54 | `iki_take` | 息茸 | a tall lavender mushroom that looks like it is breathing, soft violet glow |
| 55 | `nemuri_take` | 眠り茸 | two purple mushrooms with lighter spores floating, sleepy look |
| 56 | `sakebi_take` | 叫び茸 | a tall red mushroom with a cream stem, shaped like an open screaming mouth |
| 57 | `doku_take` | 毒茸 | two magenta-pink mushrooms with pale spots, clearly poisonous |
| 58 | `sabi_goke` | 錆苔 | a mound of orange-rust coloured moss |
| 59 | `iwa_jio` | 岩塩 | three white rock-salt crystals stacked like cubes |
| 60 | `komori_fun` | 蝙蝠糞 | a small pile of dark brown bat droppings |
| 61 | `mizu_hiru` | 水蛭 | a dark purple-brown leech, curled, with a tiny red mark |
| 62 | `shinju_gai` | 真珠貝 | a large lavender-white clam shell, slightly open, with a pearl-white inside |
| 63 | `shinju` | 真珠 | a single glossy white pearl with a soft highlight and a sparkle |
| 64 | `sui_sho_mo` | 水晶藻 | a mound of pale cyan seaweed covered in tiny glass crystals |
| 65 | `hone_no_hana` | 骨の花 | a white flower with bone-coloured petals and a dark centre |
| 66 | `furui_ko` | 古い香 | a lump of amber-orange hardened incense resin with a glossy highlight |
| 67 | `byakuro` | 白蝋 | a cream-white wax block with a candle wick and a tiny flame |
| 68 | `zugai_take` | 頭蓋茸 | a pale mushroom shaped like a tiny skull, dark eye holes |
| 69 | `kemono_kawa` | 獣皮 | a flat folded brown animal pelt with fur edges |
| 70 | `kiba` | 牙と爪 | two curved ivory beast fangs |
| 71 | `nenneki` | 粘液 | a green blob of slime with a wet highlight |
| 72 | `honekuzu` | 骨片 | a crossed pair of bone fragments, ivory |
| 73 | `hakatsuchi` | 墓土 | a dark clump of grave soil |
| 74 | `tetsukuzu` | 鉄屑 | a pile of grey-blue scrap iron plates, jagged |
| 75 | `ma_ha` | 魔草の葉 | a leafy green magical herb sprig, darker and richer than the cave herb |
| 76 | `yakeishi` | 焼け石 | a charcoal-black stone with glowing orange cracks and a tiny flame |
| 77 | `iou_hana` | 硫黄の華 | a cluster of bright yellow sulfur crystals on a dark scorched stone |
| 78 | `uroko` | 魔物の鱗 | a cluster of four teal-green scales, glossy |
| 79 | `doku_sen` | 毒腺 | a lime-green venom gland sac with a small tube and a brown cap |
| 80 | `hane` | 羽 | a single long off-white feather |
| 81 | `relic_gear` | 遺品の装備 | a small bundle of old armour pieces (a breastplate and two pauldrons), steel grey |
| 82 | `relic_tools` | 遺品の道具 | a bundle of old tools: a small pick and a leather satchel |
| 83 | `relic_tag` | 認識票 | a grey metal guild identification tag on a thin chain |
| 84 | `relic_coins` | 古い銀貨 | a small pile of four old silver coins |
| 85 | `haimugi` | haimugi |  |
| 86 | `suzumame` | suzumame |  |
| 87 | `chikabu` | chikabu |  |
| 88 | `makina` | makina |  |
| 89 | `hai_imo` | hai_imo |  |
| 90 | `sunauo` | sunauo |  |
| 91 | `yagi_raku` | yagi_raku |  |
| 92 | `iwadori_tamago` | iwadori_tamago |  |
| 93 | `shirokona` | shirokona |  |
| 94 | `kuromugishu` | kuromugishu |  |
| 95 | `jushi` | jushi |  |
| 96 | `koushin` | koushin |  |
| 97 | `takigi` | takigi |  |
| 98 | `dish_kuro_yaki` | dish_kuro_yaki |  |
| 99 | `dish_niku_kushi` | dish_niku_kushi |  |
| 100 | `dish_ibukuro` | dish_ibukuro |  |
| 101 | `dish_imo_uzumi` | dish_imo_uzumi |  |
| 102 | `dish_uo_shio` | dish_uo_shio |  |
| 103 | `dish_koke_kayu` | dish_koke_kayu |  |
| 104 | `dish_nira_itame` | dish_nira_itame |  |
| 105 | `dish_tetsu_nabe` | dish_tetsu_nabe |  |
| 106 | `dish_kagami_cha` | dish_kagami_cha |  |
| 107 | `dish_yakusou_cha` | dish_yakusou_cha |  |
| 108 | `dish_hikari_shiru` | dish_hikari_shiru |  |
| 109 | `dish_tomoshi_kushi` | dish_tomoshi_kushi |  |
| 110 | `dish_mame_shio` | dish_mame_shio |  |
| 111 | `dish_sunauo_aburi` | dish_sunauo_aburi |  |
| 112 | `dish_hira_yaki` | dish_hira_yaki |  |
| 113 | `dish_mitsu_mochi` | dish_mitsu_mochi |  |
| 114 | `dish_kousui_soup` | dish_kousui_soup |  |
| 115 | `dish_ibushi_niku` | dish_ibushi_niku |  |
| 116 | `dish_raku_aburi` | dish_raku_aburi |  |
| 117 | `dish_kuromugi_ni` | dish_kuromugi_ni |  |
| 118 | `dish_kotsufun_dashi` | dish_kotsufun_dashi |  |
| 119 | `dish_reimu_hyouka` | dish_reimu_hyouka |  |
| 120 | `dish_doku_nuki` | dish_doku_nuki |  |
| 121 | `dish_maha_ae` | dish_maha_ae |  |
| 122 | `dish_ikitake_sui` | dish_ikitake_sui |  |
| 123 | `dish_tamago_yaki` | dish_tamago_yaki |  |
| 124 | `dish_haimugi_pan` | dish_haimugi_pan |  |
| 125 | `dish_shiro_pan` | dish_shiro_pan |  |
| 126 | `dish_imo_raku_yaki` | dish_imo_raku_yaki |  |
| 127 | `dish_tsubo_tsutsumi` | dish_tsubo_tsutsumi |  |
| 128 | `dish_nanashi_mitsu` | dish_nanashi_mitsu |  |
| 129 | `dish_uo_shiozuke` | dish_uo_shiozuke |  |
| 130 | `dish_zui_kashi` | dish_zui_kashi |  |
| 131 | `dish_honenohana_zuke` | dish_honenohana_zuke |  |
| 132 | `dish_kuromugi_zuke` | dish_kuromugi_zuke |  |
| 133 | `dish_mame_himono_ni` | dish_mame_himono_ni |  |
| 134 | `dish_karani` | dish_karani |  |
| 135 | `dish_chikabu_su` | dish_chikabu_su |  |
| 136 | `dish_raku_ibushi` | dish_raku_ibushi |  |
| 137 | `dish_hoshi_imo` | dish_hoshi_imo |  |
| 138 | `dish_nemuri_yacha` | dish_nemuri_yacha |  |
| 139 | `dish_inori_kayu` | dish_inori_kayu |  |
| 140 | `dish_makina_tsutsumi` | dish_makina_tsutsumi |  |
| 141 | `dish_mizukagami_hiyajiru` | dish_mizukagami_hiyajiru |  |
| 142 | `dish_tomoshi_abura` | dish_tomoshi_abura |  |
| 143 | `corpse` | 遺体(地面に置く絵) | (drawn on the ground) the body of a fallen adventurer lying sideways, blue tunic, brown boots |
| 144 | `corpse_bones` | 遺体: 食い荒らされた骨 | (drawn on the ground) gnawed remains: scattered bones, a skull, ribs and torn blue cloth in a dark blood stain |
| 145 | `corpse_sit` | 遺体: 座って息絶えた | (drawn on the ground) an adventurer who died sitting against the wall, head drooped, legs stretched out, a dropped dagger |
| 146 | `corpse_hang` | 遺体: 吊るされた | (drawn on the ground, tall) a body hanged from a wooden beam by a rope, dark red clothes, a stain on the floor below |
