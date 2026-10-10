---
title: 画像生成用プロンプト(迷宮のマップチップ)
audience: 画像を作る人、開発用
pair: godot/assets/OVERRIDE.md(差し替えのしかた)、tools/make-tiles.py(同梱のチップを描くコード)
---

# マップチップ用プロンプト

迷宮の床・通路・壁・扉・記号を、画像生成の AI で作るためのプロンプト。**共通の形式**に、**舞台ごとの案**を添えて渡す。
できた PNG は、下の表のファイル名で `assets/` に置くと差し替わる(F6 で読み込み直す)。同梱の仮のドット絵は `godot/assets/tiles/`(`tools/make-tiles.py` が描く)。

## 1. 共通の形式

```
Create a production-oriented 2D pixel art dungeon tile for a top-down Godot RPG.

VISUAL STYLE

- Consistent dark fantasy pixel art in a polished 16-bit-inspired style.
- Match the visual style of the provided reference image, image_2.png.
- Crisp pixel clusters, deliberate pixel placement, controlled shading, and a limited color palette.
- Dark, atmospheric, low-key lighting. The tile is lit from the upper left. No strong highlights; this tile will be dimmed by distance from a torch.
- No anti-aliased edges, no vector graphics, no painterly textures, and no smooth gradients.
- Strictly top-down view. No perspective, no horizon, no cast shadows that cross the tile edge.

TECHNICAL LAYOUT

- Exactly one tile, exactly 32x32 pixels (or 64x64 if the pixels are drawn at 2x). Square, opaque, no transparency.
- The tile must repeat seamlessly: the left edge continues into the right edge, and the top edge into the bottom edge.
- No border, no frame, no grid line, no drop shadow, no text.
- Keep the detail fine and low-contrast. No single large feature in the center that would look repeated when tiled.

TILE TO CREATE

[タイルの種類と舞台の案をここに入れる(下の表)]
```

扉と記号だけは、透明な背景にする(下の 4. を参照)。

## 2. タイルの種類

| ファイル名(例は舞台 `fuyou`) | 内容 | 追加の指示 |
|---|---|---|
| `floor_fuyou` | 部屋の床 | 一番ふつうの床。目立つ模様は入れない |
| `floor_fuyou_2` `floor_fuyou_3` | 部屋の床の変種 | `floor_fuyou` と同じ地。小さな特徴(割れ、苔、水たまり)を足す。つなぎ目が合うこと |
| `corr_fuyou` | 通路の床 | 部屋の床より暗く、細かく、踏み固められた感じ |
| `wall_fuyou` | 壁の**正面**(南側が床のマスに使う) | 手前から見た、高さのある壁の面。**上端に明るい縁(天端)、下端に暗い接地の影**を描く。床より少し暗い |
| `wall_fuyou_2` | 壁の正面の変種 | 梁、壁龕、鉱脈など、舞台らしい特徴を1つ入れる。縁と接地の影は同じ |
| `walltop_fuyou` | 壁の**天面**(それ以外の岩のマス) | 真上から見た、平らな石積みの上面。**床よりずっと暗く**、継ぎ目と小さな明るい縁取りで、床と見分けがつくこと。舞台の色は薄く |
| `door_fuyou` | 閉じた扉 | 縦長の板が、通路をふさぐ。左右は透明。南北の扉は、ゲームが90度回す |
| `door_open_fuyou` | 開いた扉 | 左端に寄せた、細い開き戸。残りは透明 |

**壁が壁に見えるための決まり**: 壁は2枚で1組。上から見ると、壁は床と同じ平らな絵になって見分けがつかない。そこで、床のすぐ北にある壁は「正面」(高さがある)、それ以外は「天面」(暗い屋根)として描き分ける。ゲームは、正面の真下の床に影も落とす。

舞台の名前(`fuyou` `sabi` `kagami` `hone` `soko` `generic`)に替えて、同じ形で作る。変種は `_2`〜`_4` まで使える。

## 3. 舞台ごとの案

### fuyou 腐葉の回廊(第1〜2層)
- 共通: damp mossy cave, rotting leaf litter, pale glowing mushrooms, a muted green-brown palette (#414d38 floor, #121812 rock, glow #a7cf86).
- floor: packed dark earth with scattered decayed leaves and small moss patches.
- floor_2: a few tiny pale-blue glowing mushrooms. floor_3: a patch of bright moss.
- corr: trodden dirt path with small pebbles.
- wall: rough wet rock with dripping moss hanging from the top edge and hairline cracks.
- wall_2: the same rock with thicker moss and two or three glowing mushrooms low on the face.
- door: rotting wooden planks with moss, rusty iron straps.

### sabi 錆鉄の坑道(第3〜4層)
- 共通: abandoned mine tunnel, rusted rails, rotten timber supports, brown-orange palette (#4d4137 floor, #17120f rock, glow #d39a5b).
- floor: gravel and packed soil with iron flakes.
- floor_2: a pair of rusty rails crossing the tile horizontally on wooden sleepers, aligned to the tile edges so they connect. floor_3: a rust-stained puddle of ore dust.
- corr: worn wooden plank flooring running horizontally.
- wall: dark rock with thin white exhausted ore veins and rust spots.
- wall_2: a horizontal timber beam across the top and a vertical support post.
- door: heavy iron-banded timber hatch.

### kagami 鏡の水廊(第5〜6層)
- 共通: flooded stone corridor with polished mirror walls, cold teal palette (#334852 floor, #0c1419 rock, glow #86d0e2).
- floor: wet blue-grey flagstones with faint specular dots.
- floor_2: the same stones under a thin sheet of still water, with a few small ripple lines. floor_3: water with a diagonal light reflection.
- corr: narrow wet flagstones, darker.
- wall: a polished dark glass-like mirror surface with diagonal reflected light streaks and a thin dark frame.
- wall_2: the same mirror with the streaks offset.
- door: pale silvery slab with rivets, like a mirror panel.

### hone 骨の大聖堂(第7〜9層)
- 共通: a cathedral built from giant bones, pale ivory against near-black violet, cold and silent (#4c4852 floor, #131116 rock, glow #e3d8b2).
- floor: flat polished bone plates laid like paving, thin black seams, a few tiny cracks.
- floor_2: plates with scratched prayer marks. floor_3: plates with a dark stain in the seams.
- corr: worn pale slabs, darker than the room floor.
- wall: two huge curved ribs rising side by side from the bottom of the tile, between dark gaps.
- wall_2: a niche holding a skull, framed by bone.
- door: a slab of bone with iron bands.

### soko 第10層以降
- 共通: the inside of an unnatural stomach-like space, seamless soft indigo surfaces that seem to breathe, faint lilac rings, nothing recognizable (#3a3c52 floor, #0c0d14 rock, glow #b9b4ff).
- floor: smooth dark indigo with slow rings. corr: the same, darker.
- wall: a seamless smooth dark membrane with a faint diagonal sheen and two tiny lilac lights.
- door: a slit-like pale violet slab.

### generic 汎用
- 共通: plain grey stone dungeon (#4a4a52).
- floor: large flagstones. corr: smaller flagstones, darker. wall: stone bricks in a running bond, dark mortar. door: oak planks with iron straps.

## 4. 扉と記号(透明な背景)

```
Create a single 32x32 pixel art sprite for a top-down dark fantasy dungeon, on a fully transparent background.
Same style rules as above. One dark 1-pixel outline around the object. The object stays inside the tile and does not touch the edge.
Intended to be drawn on top of a floor tile.
```

| ファイル名 | 内容 |
|---|---|
| `door_<舞台>` | 閉じた扉。縦長の板が、中央の12ピクセルほどの幅を占める |
| `door_open_<舞台>` | 開いた扉。左端の4ピクセルほどの細い板 |
| `icon_stairs_up` | 上りの階段。上に矢印 |
| `icon_stairs_down` | 下りの階段。下に矢印 |
| `icon_chest` | 宝箱。鉄の帯と金の錠前 |
| `icon_trap` | 気づいた罠。床の剣山 |

鍵のかかった扉は赤く、隠し扉は青白く、ゲームが色を変えて描く。絵は、ふつうの扉のままでよい。

## 5. 置き方

- `assets/` に、上の表のファイル名で置く(拡張子は png、webp、jpg)。実行ファイルと同じフォルダの `assets/`、または `user://assets/`。
- 32×32 の絵は、ぼかさずにそのまま拡大して描く。64×64 より大きい絵は、縮めて描く。
- `floor` `corr` `wall` `door` のように舞台名を付けないファイルは、全舞台に使われる。置いたものは、同梱の絵より優先される。
- 変種(`_2` から)は、置いた数だけ使われる。無ければ、1枚だけで敷く。
