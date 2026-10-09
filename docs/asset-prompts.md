---
title: 画像生成用プロンプト(キャラクター、魔物のスプライトシート)
audience: 画像を作る人、開発用
pair: godot/assets/OVERRIDE.md(差し替えのしかた)、tools/make-sprites.py(同梱のシートを描くコード)
---

# 画像生成用プロンプト

Urbs Labyrinthi のキャラクターと魔物のスプライトシートを、画像生成の AI で作るためのプロンプト。
**共通の形式**に、**キャラクター案**を添えて渡す。できた PNG は、下の表のファイル名で `assets/` に置くと、ゲームの絵が差し替わる(ゲーム中に F6 で読み込み直す)。

## 1. 共通の形式(キャラクター用)

```
Create a production-oriented 2D pixel art RPG character sprite sheet for a Godot game.

VISUAL STYLE

- Consistent dark fantasy pixel art in a polished 16-bit-inspired style.
- Match the visual style of the provided reference image, image_2.png.
- Crisp pixel clusters, deliberate pixel placement, clean silhouettes, controlled shading, and a limited color palette.
- Dark, atmospheric fantasy aesthetic with readable character details.
- No anti-aliased edges, no vector graphics, no painterly textures, and no smooth gradients.
- Keep the character design consistent across all animation frames.

TECHNICAL LAYOUT

- Exactly one character.
- Exactly 12 animation frames.
- Each frame represents a 64x64 pixel cell.
- Arrange all 12 frames in a single horizontal row, with 12 columns and 1 row.
- Intended final sprite sheet dimensions: exactly 768x64 pixels.
- No spacing, padding, gutters, or gaps between frames.
- Every frame occupies one 64x64 pixel cell.
- The character must remain entirely inside its frame.
- Maintain a consistent character scale, body proportions, equipment size, and visual center across all frames.
- Use a consistent ground-contact point and baseline in every frame.
- Keep all equipment, weapons, hair, hats, cloaks, and effects inside the frame boundaries.
- Do not crop any part of the character.

FRAME ORDER

Arrange the frames in exactly this order:

Frames 1-3: DOWN, facing toward the camera.
Frames 4-6: LEFT, facing left.
Frames 7-9: RIGHT, facing right.
Frames 10-12: UP, facing away from the camera.

Each direction contains exactly three consecutive walking animation frames.

WALKING ANIMATION

- Create a coherent three-frame looping walk cycle for each direction.
- Frame 1: first walking pose.
- Frame 2: passing pose with a different leg and arm position.
- Frame 3: opposite walking pose, returning naturally toward the first pose.
- Use clear alternating leg movement and corresponding arm movement.
- Include subtle body bobbing where appropriate.
- Keep the torso, head, armor, clothing, and equipment consistent.
- Preserve the exact character design across all 12 frames.
- Ensure the walk cycle can loop without an obvious visual jump.
- All four directions must represent the same character.

BACKGROUND AND TRANSPARENCY

- Fully transparent background with a clean RGBA alpha channel.
- No background color.
- No checkerboard pattern.
- No floor, ground shadow, environment, scenery, or decorative elements.
- No gridlines, cell borders, separators, or frame outlines.

STRICT EXCLUSIONS

- No text, labels, captions, numbers, headings, logos, or watermarks.
- No character name printed inside the image.
- No multiple characters.
- No contact sheet layout.
- No additional frames.
- No reference poses outside the sprite sheet.
- No UI elements or decorative borders.

OUTPUT PRIORITY

Prioritize a clean, consistent, game-ready character design and a clearly organized sprite sheet over decorative presentation.

The image must function as a character animation asset, not as a sprite sheet preview or infographic.
```

## 2. キャラクター案(男女 × 5種)

共通の形式の末尾に、1人ぶんを添える。出力のファイル名は、見出しの ID を使う(`sheet_<ID>.png`)。

| ID(ファイル名) | ゲームのクラス | 概要 |
|---|---|---|
| `M_WARRIOR` `F_WARRIOR` | 戦士 | 重い板金鎧、剣と盾 |
| `M_CLERIC` `F_CLERIC` | 僧侶 | 儀式のローブ、メイスと聖典 / 聖なる杖 |
| `M_FIGHTER` `F_FIGHTER` | 蛮族、野伏 | 軽装の革鎧、短剣の二刀流 |
| `M_THIEF` `F_THIEF` | 盗賊 | 頭巾、覆面、短剣 |
| `M_MAGE` `F_MAGE` | 魔術師 | とんがり帽子とローブ、杖 |

### M_WARRIOR — Male Warrior
A bulky male knight wearing heavy steel plate armor, a closed steel helmet, layered metal pauldrons, gauntlets, steel greaves, and dark leather underlayers. Carries a sword and a large heater shield with a simple golden heraldic cross. Heavy, sturdy silhouette. Steel, charcoal, and muted gold palette.

### F_WARRIOR — Female Warrior
A female knight wearing fitted steel plate armor, a visible brown ponytail emerging from the helmet, metal pauldrons, gauntlets, and armored boots. Carries a sword and a heater shield. Strong, practical silhouette. Steel, brown, and muted gold palette.

### M_CLERIC — Male Cleric
A male priest wearing layered blue and white ceremonial robes, a blue hood, gold trim, leather belt, and sturdy boots. Carries a small mace and a closed holy book. Calm, dignified silhouette. Deep blue, ivory, and gold palette.

### F_CLERIC — Female Cleric
A female priest wearing flowing white and gold ceremonial robes, a modest veil, layered fabric, gold embroidery, and a waist sash. Carries a holy staff topped with a small golden sacred symbol. Elegant but practical silhouette. Ivory, white, and muted gold palette.

### M_FIGHTER — Male Light Warrior
An agile male fighter wearing dark leather armor, chainmail accents, bracers, fitted trousers, and light boots. Dual-wields two short swords. Athletic silhouette with a low, active combat stance. Charcoal, dark steel, and muted blue palette.

### F_FIGHTER — Female Light Warrior
An agile female fighter wearing lightweight leather armor, arm guards, fitted trousers, and a practical brown ponytail. Dual-wields two short blades. Athletic silhouette with a nimble, balanced stance. Dark leather, muted red, and steel palette.

### M_THIEF — Male Thief
A male rogue wearing a dark hooded cloak, a face-covering mask, layered leather armor, belts, pouches, and soft boots. Carries a single dagger in his right hand. Compact, stealthy silhouette. Charcoal, dark violet, and muted steel palette.

### F_THIEF — Female Thief
A female rogue wearing a dark hood, a face-covering scarf, fitted leather armor, belts, small pouches, and soft boots. Carries two small daggers. Agile silhouette with a low, cautious stance. Charcoal, dark red, and muted violet palette.

### M_MAGE — Male Mage
A male wizard wearing traditional purple and blue robes, a tall pointed hat, a long white beard, and gold-trimmed sleeves. Carries a wooden magic staff topped with a small blue crystal. Long-robed silhouette. Deep purple, midnight blue, and muted gold palette.

### F_MAGE — Female Mage
A female wizard wearing dark purple robes, a pointed wizard hat, long flowing hair, and subtle gold trim. Carries a magical wand or slender staff topped with a purple crystal. Elegant silhouette with layered robes. Dark purple, violet, and muted gold palette.

## 3. 魔物用(共通の形式を、魔物向けに直したもの)

共通の形式の「Exactly one character」を「Exactly one monster」に、「character」を「creature」に替え、`WALKING ANIMATION` の腕と脚の記述を、その魔物の動き(這う、跳ねる、飛ぶなど)に替える。ほかは同じ(12コマ、768×64、下・左・右・上の各3コマ、透過)。
出力のファイル名は `esheet_<SRDのindex>.png`(例: `esheet_giant-rat.png`)。種別ぜんぶに使いたい絵は `esheet_type_<種別>.png`。
大きな魔物(大型、超大型、巨大)も、**同じ64×64のコマに収める**(ゲームが、体の大きさに応じて拡大して描く)。

### 魔物案(同梱のシートと同じ11種)

| index | 日本語名 | 概要 |
|---|---|---|
| `giant-rat` `rat` | 洞窟鼠 | 灰褐色の大きな鼠。四つ足。這うように走る |
| `giant-bat` `bat` | 蝙蝠 | 紫の羽。はばたきの3コマ |
| `giant-spider` | 巨大蜘蛛 | 黒い体に赤い斑。八本の脚 |
| `gray-ooze` `green-slime` | 粘泥 | 半透明の粘体。縮んで伸びる3コマ |
| `skeleton` | 骨亡者 | 骨の戦士。短剣 |
| `zombie` | ゾンビ | 緑の肌、ぼろ服。腕を垂らして歩く |
| `bandit` | 盗掘者 | 頭巾と覆面。短剣 |
| `goblin` | ゴブリン | 緑の肌、小柄。短剣 |

### 例: giant-rat
A large gray-brown giant rat with a pink nose, small round ears, a long pink tail, and sturdy paws. Low four-legged silhouette. Scurrying walk cycle with a visible tail sway. Warm gray, brown, and muted pink palette.

## 4. 置き方

1. 作った PNG を、`assets/` フォルダに置く(実行ファイルと同じフォルダ。詳しくは `godot/assets/OVERRIDE.md`)。
2. ゲーム中に F6 で、読み込み直す。
3. 大きさが違う(例: 128×128 のコマ)ときも、横幅÷12 を1コマとして読む。ただし、コマは正方形にすること。
