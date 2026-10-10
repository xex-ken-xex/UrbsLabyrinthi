#!/usr/bin/env python3
"""tools/item-catalog.py から、docs/items-and-forage.md と docs/item-prompts.md の表を作り直す。
  python3 tools/make-item-docs.py
文章の部分は、tools/item-docs-text/ ではなく、このファイルの中にある。"""
import importlib.util
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


cat = load("cat", "item-catalog.py")
icons = json.load(open(os.path.join(ROOT, "godot", "data", "item-icons.json")))["icons"]
THEME_JP = {"fuyou": "腐葉", "sabi": "錆鉄", "kagami": "鏡", "hone": "骨", "soko": "底", "generic": "汎用", "all": "全"}
SPOT_JP = {"floor": "床", "wall": "壁ぎわ", "water": "水ぎわ", "corr": "通路"}
SELL = 0.4

# 絵の指示(英語。画像生成の AI に渡す)
LOOKS = {
    "kuro_take": "two small charcoal-black mushrooms with grey stems and faint grey speckles",
    "no_hai_imo": "a lumpy ash-grey tuber (wild potato) with a tiny green sprout on top",
    "yakusou": "a small cave herb plant with green leaves and a tiny pale yellow flower",
    "koke_mitsu": "a small glass-like jar of golden moss honey with a brown wooden lid",
    "mekura_uo": "a pale white blind cave fish, no visible eye, side view",
    "kotsufun_take": "a tall ivory-white mushroom with a smooth cap, like bone powder",
    "reimu_no_hana": "a single pale blue flower with white center on a green stem, cold mist feel",
    "zui_mitsu": "a jar of translucent pale-gold marrow honey, with a soft golden glow and sparkles",
    "nanashi_no_mi": "a round violet fruit with a small dark leaf, faintly sparkling, unnaturally smooth",
    "kemono_niku": "a raw cut of red meat on a pale bone",
    "hikari_goke": "a mound of teal glowing moss with tiny luminous specks",
    "shizuku_goke": "a mound of blue-green wet moss with a dripping drop of glowing water",
    "sabi_mizu": "a clear glass flask of grey, metallic-tasting mineral water",
    "mizukagami_so": "a round mirror-like silvery-cyan floating leaf plant with a white flower",
    "tomoshi_take": "two pale-blue mushrooms glowing from within, light cyan stems",
    "yawaraka_hikari": "a soft lilac glowing jelly blob, translucent, with sparkles",
    "kodo_nira": "a bunch of green chive-like blades tied with a pale cloth",
    "tetsu_take": "a hard reddish-brown mushroom with a metallic sheen",
    "kagami_goke": "a mound of silvery-white moss that reflects light, with sparkles",
    "inori_goke": "a mound of pale ivory moss with a soft warm glow",
    "iki_take": "a tall lavender mushroom that looks like it is breathing, soft violet glow",
    "nemuri_take": "two purple mushrooms with lighter spores floating, sleepy look",
    "sakebi_take": "a tall red mushroom with a cream stem, shaped like an open screaming mouth",
    "doku_take": "two magenta-pink mushrooms with pale spots, clearly poisonous",
    "sabi_goke": "a mound of orange-rust coloured moss",
    "iwa_jio": "three white rock-salt crystals stacked like cubes",
    "komori_fun": "a small pile of dark brown bat droppings",
    "mizu_hiru": "a dark purple-brown leech, curled, with a tiny red mark",
    "shinju_gai": "a large lavender-white clam shell, slightly open, with a pearl-white inside",
    "shinju": "a single glossy white pearl with a soft highlight and a sparkle",
    "sui_sho_mo": "a mound of pale cyan seaweed covered in tiny glass crystals",
    "hone_no_hana": "a white flower with bone-coloured petals and a dark centre",
    "furui_ko": "a lump of amber-orange hardened incense resin with a glossy highlight",
    "byakuro": "a cream-white wax block with a candle wick and a tiny flame",
    "zugai_take": "a pale mushroom shaped like a tiny skull, dark eye holes",
    "kemono_kawa": "a flat folded brown animal pelt with fur edges",
    "kiba": "two curved ivory beast fangs",
    "nenneki": "a green blob of slime with a wet highlight",
    "honekuzu": "a crossed pair of bone fragments, ivory",
    "hakatsuchi": "a dark clump of grave soil",
    "tetsukuzu": "a pile of grey-blue scrap iron plates, jagged",
    "ma_ha": "a leafy green magical herb sprig, darker and richer than the cave herb",
    "yakeishi": "a charcoal-black stone with glowing orange cracks and a tiny flame",
    "uroko": "a cluster of four teal-green scales, glossy",
    "doku_sen": "a lime-green venom gland sac with a small tube and a brown cap",
    "hane": "a single long off-white feather",
    "relic_gear": "a small bundle of old armour pieces (a breastplate and two pauldrons), steel grey",
    "relic_tools": "a bundle of old tools: a small pick and a leather satchel",
    "relic_tag": "a grey metal guild identification tag on a thin chain",
    "relic_coins": "a small pile of four old silver coins",
    "potion": "a corked round glass bottle of red healing potion",
    "hi_potion": "a larger bottle of bright pink high potion with sparkles",
    "ether": "a corked round glass bottle of blue mana water",
    "revive_charm": "a round golden charm with a red cross, tied with a short cord",
    "lamp_oil": "a flat glass flask of yellow glowing lamp oil",
    "return_scroll": "a rolled cream parchment scroll with a red wax seal",
    "corpse": "(drawn on the ground) the body of a fallen adventurer lying sideways, blue tunic, brown boots",
}
CRYSTAL_LOOK = {
    "low": "dull grey-blue, cloudy, faint glints",
    "mid": "clear teal-blue, steady glow",
    "high": "bright cyan-white, strong glow and sparkles",
    "pure": "violet-white prism with rainbow facets and rays",
    "unk": "near-black violet with unstable white sparkles (the glow never settles)",
}
SIZE_LOOK = {"s": "a single small shard", "m": "a cluster of three shards", "l": "a large cluster of five shards on a rock base"}


def sell_price(p):
    return int(p * SELL)


def effect_text(it):
    if it.get("kind", "consumable") == "material":
        return "素材(売るだけ)"
    u = it["use"]
    if u == "heal_pct":
        return f"HP {int(it['v'] * 100)}%回復"
    if u == "mp_pct":
        return f"MP {int(it['v'] * 100)}%回復"
    if u == "light":
        return f"灯り +2マス・{int(it['t'])}秒"
    if u == "buff":
        b = it["buff"]
        if b == "power":
            return f"体当たり +{int(round((it['v'] - 1) * 100))}%・{int(it['t'])}秒"
        if b == "guard":
            return f"被ダメージ −{int(round((1 - it['v']) * 100))}%・{int(it['t'])}秒"
        if b == "speed":
            return f"移動 +{int(round((it['v'] - 1) * 100))}%・{int(it['t'])}秒"
        if b == "regen":
            return f"最大HPの{int(it['v'] * 100)}%を{int(it['t'])}秒で回復"
    return u


def where_text(it):
    sp = it.get("spots")
    if not sp:
        return "魔物・遺体"
    return "、".join(f"{THEME_JP[t]}{'(' + SPOT_JP[s] + ')'}" + (f"・第{f}層〜" if f > 1 else "") for (t, w, s, f) in sp)


def rarity(it):
    ws = [w for (_t, w, _s, _f) in it.get("spots", [])]
    if not ws:
        return "—"
    m = max(ws)
    return "多い" if m >= 2.5 else ("ふつう" if m >= 1.5 else ("少ない" if m >= 0.8 else "稀"))


def table_items():
    rows = ["| 名前 | 効果 | 売値(銀貨) | 出る所 | 多さ |", "|---|---|---|---|---|"]
    groups = [("食べ物・回復", lambda i: i.get("use") == "heal_pct" and i["id"] != "kemono_niku"),
              ("魔力・灯り", lambda i: i.get("use") in ("mp_pct", "light")),
              ("一時の強化", lambda i: i.get("use") == "buff"),
              ]
    out = []
    used = set()
    for title, f in groups:
        its = [i for i in cat.FORAGE if f(i) and i["id"] not in used]
        used.update(i["id"] for i in its)
        out += [f"### {title}", "", *rows]
        for i in its:
            out.append(f"| {i['name']} | {effect_text(i)} | {sell_price(i['price'])} | {where_text(i)} | {rarity(i)} |")
        out.append("")
    mats = [i for i in cat.FORAGE if i.get("kind") == "material" and i.get("spots")]
    out += ["### 素材(自生。薬師組・鍛冶組・神殿などが買う)", "", *rows]
    for i in mats:
        out.append(f"| {i['name']} | {i['desc'].split('。')[0]} | {sell_price(i['price'])} | {where_text(i)} | {rarity(i)} |")
    out.append("")
    return "\n".join(out)


def table_drops():
    out = ["| 倒した魔物 | 落とすもの(確率) |", "|---|---|"]
    by = {}
    names = {i["id"]: i["name"] for i in cat.FORAGE}
    for (tgt, iid, p, _c) in cat.DROPS:
        by.setdefault(tgt, []).append(f"{names[iid]} {int(p * 100)}%")
    jp = {"type:beast": "獣", "type:ooze": "ウーズ", "type:undead": "アンデッド", "type:construct": "構造体", "type:plant": "植物",
          "type:fey": "妖精", "type:elemental": "精霊", "type:dragon": "竜", "type:monstrosity": "怪物", "type:fiend": "悪魔",
          "idx:spider": "蜘蛛", "idx:snake": "蛇", "idx:bat": "蝙蝠", "idx:eagle": "鷲", "idx:owl": "梟", "idx:raven": "鴉", "idx:hawk": "鷹", "idx:harpy": "ハーピー"}
    for k, v in by.items():
        out.append(f"| {jp.get(k, k)} | {'、'.join(v)} |")
    return "\n".join(out)


def table_purity():
    colors = {"low": "鈍い灰青", "mid": "澄んだ青緑", "high": "明るい水色〜白", "pure": "白紫、虹色の面", "unk": "黒紫、定まらない白い光"}
    base = {"low": "腐葉の回廊(第1〜2層)", "mid": "錆鉄の坑道(第3〜4層)、汎用", "high": "鏡の水廊(第5〜6層)", "pure": "骨の大聖堂(第7〜9層)", "unk": "第10層以降"}
    out = ["| 純度 | 銀貨/kg | 光り方 | その層の基本の純度 |", "|---|---|---|---|"]
    for (pid, jp, price) in cat.PURITIES:
        out.append(f"| {jp} | {price} | {colors[pid]} | {base[pid]} |")
    return "\n".join(out)


def write_items_doc():
    n_for = len([i for i in cat.FORAGE if i.get("spots")])
    n_all = len(cat.FORAGE)
    txt = f"""---
title: 税のかからないもの(迷宮の自生物、魔物の素材、遺品)と、燐晶の光る石
audience: 設計、開発
pair: tools/item-catalog.py(一覧の元)、tools/make-items.py(絵とゲームのデータを作る)、docs/item-prompts.md(絵のプロンプト)
---

# 税のかからないものと、光る燐晶

この表は `python3 tools/make-item-docs.py` で、一覧(`tools/item-catalog.py`)から作り直す。

## 1. 考え方

- **課税されるのは燐晶だけ**(都市資料: 「持ち帰った燐晶の3割を納める。査定は、ギルドの査定所」)。茸や苔、魔物の素材、遺品は、燐晶ではないので、査定所を通らない。税が、かからない。
- 都市の食は、迷宮の自生物に支えられている(「燐晶の副産物の灰で育てる黒い茸、灰芋、胃袋スープ」)。壁下区の貧民や運び屋は、迷宮で採った茸や芋で食いつなぐ。冒険者にとっても、**燐晶の稼ぎの3割が税に消える**一方、自生物は丸ごと手に入る。
- ゲームでは、自生物は、薬代を浮かせ(食べて回復、短い強化)、余りを売って小銭になる。**稼ぎの本筋は燐晶**のままにするため、自生物の売値は、燐晶より小さい(1つ数銀貨〜数十銀貨。燐晶は、1kg で30〜200銀貨)。
- 自生物は、**舞台ごとに違う**。層を替えると、拾うものが変わり、薬師組や鍛冶組が欲しがる素材も変わる。

## 2. 燐晶(光る石)

宝箱は、やめた。燐晶は、床に落ちている**きらきら光る石**。近づくと吸い寄せられて、拾える。拾った燐晶は袋に入り、地上へ戻るときに、純度ごとに査定され、**3割が燐晶税**になる。迷宮で全滅すると、袋は失う。

{table_purity()}

| 手に入る所 | 内容 |
|---|---|
| 宝のある部屋 | 光る石の山(2〜6個)と、そばの持ち物(治療薬、灯具、遺品、まれに装備) |
| 露頭 | 壁ぎわの小さな光る石。宝の量に比例して、層じゅうに散らばる |
| 遺体 | 先に来て戻らなかった冒険者。触れると、燐晶(1〜3個)と遺品がこぼれる。**燐晶は、死骸と血を養分に育つ**(都市資料)ので、良い純度が出やすい |
| 倒した魔物 | 確率で燐晶を落とす。強いほど、大きいほど、良い純度ほど多い。竜、精霊、構造体、アンデッドは落としやすい |

純度は、層の基本の純度を中心に、一つ上が15%、二つ上が3%、一つ下が25%の割合で出る(遺体と強い魔物は、上が出やすい)。
石の大きさは、重さで決まり、絵が変わる(欠片 〜0.08kg、かたまり 〜0.3kg、大きな塊)。量の全体は、`Balance.CRYSTAL_SCALE`(いま 0.3)で、一括して変えられる。

## 3. 迷宮の自生物({n_for}種)と素材・遺品(全{n_all}種)

売値は、値段の4割(`ItemDB.SELL_RATE`)。「多さ」は、出現表の重みの目安。

{table_items()}

## 4. 魔物の素材(倒すと落ちる)

{table_drops()}

## 5. 遺品(遺体から)

| 名前 | 売値 | 内容 |
|---|---|---|
""" + "\n".join(
        f"| {i['name']} | {sell_price(i['price'])} | {i['desc']} |" for i in cat.FORAGE if i["id"].startswith("relic_")
    ) + f"""

遺体は、上の層ほど多い(広さに比例し、深いほど減る)。遺体からは、燐晶(1〜3個)のほか、認識票60%、古い銀貨45%、遺品の道具25%、遺品の装備15%、治療薬12%、装備12%、自生物20% が出る。

## 6. ゲームでの扱い

- 拾うと、自生物と素材は**持ち物**(Tab)に入る。燐晶は**袋**に入り、画面左の表示に、純度ごとの重さと見積もりが出る。
- 持ち物では、食べ物と強化・灯りの品は使える。素材は、店で売るだけ(街の「店」で売る。値段の4割)。
- 灯り茸や軟光は、光の半径を広げる。鉄茸、鏡苔、坑道韮は、一時的に防御、足、体当たりを強くする。息茸は、最大HPをじわじわ回復する。

## 7. 【未確定】今後

- 調合(薬師組が、素材から薬を作る)。眠り茸+水→眠り薬、毒茸→毒消し、など。
- 鮮度(茸や魚は、日が経つと傷む。街へ戻ると腐っている)。
- 採集のスキル(野伏が、茸や草を見つけやすい)。見つけにくいものを、見つけやすくする。
- 闇市(自生物を、税のかからない値段で、運び屋や貧民に売る)。
- 毒茸を食べると、体に障る(状態異常が入ったとき)。
- 自生物の再生(夜が明けると、また生える)。いまは、夜ごとに層ごと組み直されるので、置き直されている。
- 密輸(燐晶を、自生物の袋に隠して、税を逃れる)。都市資料の「約2割が密輸」と結びつける。
"""
    open(os.path.join(ROOT, "docs", "items-and-forage.md"), "w").write(txt)


def write_prompts_doc():
    names = {i["id"]: i["name"] for i in cat.FORAGE}
    names.update({"potion": "治療薬", "hi_potion": "上級治療薬", "ether": "魔力水", "revive_charm": "蘇生の護符", "lamp_oil": "燐晶の灯油",
                  "return_scroll": "帰還の札", "corpse": "遺体(地面に置く絵)"})
    rows = ["| マス | id | 名前 | 絵の指示(英語) |", "|---|---|---|---|"]
    for iid, n in sorted(icons.items(), key=lambda kv: kv[1]):
        if iid.startswith("crystal_"):
            _c, pid, sz = iid.split("_")
            look = f"{SIZE_LOOK[sz]} of luminous crystal (phosphor crystal), {CRYSTAL_LOOK[pid]}"
            name = f"燐晶 {[p[1] for p in cat.PURITIES if p[0] == pid][0]}・{ {'s': '欠片', 'm': 'かたまり', 'l': '大きな塊'}[sz] }"
        else:
            look = LOOKS.get(iid, "")
            name = names.get(iid, iid)
        rows.append(f"| {n} | `{iid}` | {name} | {look} |")
    total = len(icons)
    nrows = (total + 15) // 16
    txt = f"""---
title: 画像生成用プロンプト(アイテムのアイコンシート)
audience: 画像を作る人、開発用
pair: godot/assets/OVERRIDE.md(差し替えのしかた)、tools/make-items.py(同梱のシートを描くコード)、docs/items-and-forage.md(品物の説明)
---

# アイテムのアイコンシート

燐晶、迷宮の自生物、魔物の素材、遺品、消耗品のアイコンを、1枚のシートで作る。同梱の仮の絵は `godot/assets/items/items_sheet.png`(`tools/make-items.py` が描く)。

## 1. シートの形

- **16列 × {nrows}行**(全{total}マス)。1マス 32×32。シート全体は **512×{nrows * 32} ピクセル**。透明な背景。
- マスの並びは、下の表の「マス」の番号(0から。左上が0、右へ数え、行が替わる)。**この並びは変えない**(ゲームが、`data/item-icons.json` の番号で切り出す)。
- 解像度を上げたいときは、同じ並びのまま、横幅を 16 の倍数にする(例: 1マス 64×64 なら 1024×{nrows * 64})。ゲームは、横幅÷16 を1マスの大きさとして切る。
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

- One sprite sheet with exactly 16 columns and {nrows} rows of 32x32 cells: exactly 512x{nrows * 32} pixels.
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

{chr(10).join(rows)}
"""
    open(os.path.join(ROOT, "docs", "item-prompts.md"), "w").write(txt)


if __name__ == "__main__":
    write_items_doc()
    write_prompts_doc()
    print("docs/items-and-forage.md, docs/item-prompts.md")
