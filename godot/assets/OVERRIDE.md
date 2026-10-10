# 画像・フォントの差し替え

背景、キャラクター、魔物、床や壁、アイコン、ロゴ、フォントを、ファイルを置くだけで差し替えられる。
置いていないものは、ゲームがコードで描いた元の絵のまま(一部だけ差し替えてよい)。

## 置き場所(上にあるものが優先)

| 場所 | 使いどころ |
|---|---|
| 実行ファイルと同じフォルダの `assets/` | 配布したゲームを遊ぶとき。`Deploy/windows/assets/`、`Deploy/linux/assets/` |
| `user://assets/` | Windows: `%APPDATA%\Godot\app_userdata\Urbs Labyrinthi\assets\`<br>Linux: `~/.local/share/godot/app_userdata/Urbs Labyrinthi/assets/` |
| `godot/override/`(`res://override/`) | Godot のエディタで開発するとき。Godot が取り込み、書き出しにも入る |

ファイル名は **`キー.png`**(`.webp`、`.jpg` も可)。小文字、英数字とアンダースコア。
**ゲーム中に F6 を押すと、置いた画像を読み込み直す**(フォントは再起動が要る)。
見本は `Deploy/assets/samples/` にある。見本は読み込まれない(名前や大きさの参考用)。コピーして、`assets/` へ置いて直す。

## キーの一覧

### 背景(1280×720 以上を推奨。縦横比を保って、画面を覆うように拡大し、はみ出す分を切る)

| キー | 場所 |
|---|---|
| `bg_title` | タイトル(無ければ `bg_town`) |
| `bg_town` | 街の広場 |
| `bg_charamake` | キャラ作成(無ければ `bg_inn`) |
| `bg_smith` | 鍛冶屋(武器・防具) |
| `bg_general` | 雑貨屋 |
| `bg_magic` | 魔法屋 |
| `bg_temple` | 神殿 |
| `bg_inn` | 宿屋 |
| `bg_pleasure` | 花街(寝息通り) |
| `logo` | タイトルの文字の代わり。横長の透過PNG(620×180 ほど) |

### キャラクターと魔物(正方形の透過PNG。64×64〜256×256 を推奨。右向きの絵を、左を向くときは反転する)

| キー | 使い先 | 探す順 |
|---|---|---|
| `hero_<名前>` | その名前の仲間(例: `hero_セラ`) | 1番目 |
| `hero_<クラス>_<種族>` | 例: `hero_fighter_dwarf` | 2番目 |
| `hero_<クラス>` | 例: `hero_wizard` | 3番目 |
| `enemy_<SRDのindex>` | その魔物(例: `enemy_giant-rat`、`enemy_skeleton`) | 1番目 |
| `enemy_type_<種別>` | その種別すべて(例: `enemy_type_undead`) | 2番目 |

- クラス: `fighter` `barbarian` `rogue` `wizard` `cleric` `ranger`
- 種族: `human` `elf` `dwarf` `halfling`
- 種別: `undead` `beast` `swarm` `ooze` `construct` `plant` `monstrosity` `aberration` `fiend` `humanoid` `elemental` `fey` `celestial` `dragon` `giant`
- 魔物の index の一覧は、`godot/data/floors/*.json` の `monsters[].index`(英小文字とハイフン)
- 描く大きさは、仲間が体の直径の約1.5倍、魔物は体の大きさに応じる(超小型〜巨大)。大きな画像は、小さく縮めて描く

### スプライトシート(歩きのアニメーション。仲間と魔物)

1枚に **64×64 のコマを12枚、横一列(768×64)**、透過PNG。
コマ 1〜3 は下向き(DOWN)、4〜6 は左向き、7〜9 は右向き、10〜12 は上向き。各向きに、歩きの3コマ(0→1→2→1 と回す。止まると真ん中)。
**シートがあれば、1枚絵より優先される**。コマの大きさは、横幅÷12、高さ=コマの大きさとして読むので、128×128 のコマ(1536×128)でも使える(正方形にすること)。
足もとが、体の少し下に来る。仲間は直径の約2.3倍、魔物は体の大きさに応じて描く。ドット絵は、最近傍で拡大される。

| キー | 使い先 | 探す順 |
|---|---|---|
| `sheet_<名前>` | その名前の仲間 | 1番目 |
| `sheet_<クラス>_<M/F>` | 例: `sheet_fighter_F` | 2番目 |
| `sheet_<M/F>_<種類>` | 種類は `WARRIOR` `CLERIC` `FIGHTER` `THIEF` `MAGE`。例: `sheet_F_MAGE` | 3番目 |
| `esheet_<SRDのindex>` | その魔物(例: `esheet_giant-rat`) | 1番目 |
| `esheet_type_<種別>` | その種別すべて | 2番目 |

同梱のシートは、SRD の全魔物(334体)と、種別の代表(`esheet_type_aberration` など15種)。同じ名前のファイルを置けば差し替わる。外見とサイズの方針は `docs/monster-visuals.md`。

クラスと種類の対応: 戦士=WARRIOR、僧侶=CLERIC、盗賊=THIEF、魔術師=MAGE、蛮族=FIGHTER、野伏=FIGHTER。
キャラ作成で「見た目」(男性 M / 女性 F)を選ぶ。**同梱のシート**: 仲間の `sheet_M_*` `sheet_F_*` の10枚と、魔物 11種(`giant-rat` `rat` `gray-ooze` `green-slime` `giant-spider` `giant-bat` `bat` `skeleton` `zombie` `bandit` `goblin`)。
同梱のシートは、`tools/make-sprites.py` が、コードで描いたもの。AI で作った絵(プロンプトは `docs/asset-prompts.md`)に、同じファイル名で差し替えられる。

### 床、壁、アイコン(正方形。64×64 を推奨。1マス=32画素に縮めて、1マスずつ貼る)

| キー | 使い先 |
|---|---|
| `floor_<舞台>` / `floor` | 部屋の床。舞台ごと(`fuyou` 腐葉の回廊、`sabi` 錆鉄の坑道、`kagami` 鏡の水廊、`hone` 骨の大聖堂、`soko` 第10層以降) |
| `floor_<舞台>_2` `_3` `_4` | 部屋の床の変種(ばらつき用)。置いた数だけ使う |
| `corr_<舞台>` / `corr` | 通路の床(無ければ `floor`) |
| `wall_<舞台>` / `wall` | 壁の正面(南が床のマス。上端に明るい縁、下端に暗い影を描く)。`_2` `_3` `_4` は変種 |
| `walltop_<舞台>` / `walltop` | 壁の天面(それ以外の岩のマス。床よりずっと暗い石積み)。無ければ、同梱の天面(`wall` だけを置いたときは、その絵で通す) |
| `door_<舞台>` / `door` | 閉じた扉(縦長の板。南北の扉は、90度回して描く。透明な背景) |
| `door_open_<舞台>` / `door_open` | 開いた扉(左端に寄せた細い板。透明な背景) |
| `icon_stairs_up` `icon_stairs_down` | 階段(透明な背景) |
| `icon_chest` | 宝箱 |
| `icon_trap` | 気づいた罠 |

### フォント

| ファイル | 使い先 |
|---|---|
| `font.ttf`(`.otf` `.woff2` も可) | すべての文字。日本語が出るフォントを使うこと。再起動が要る |

## 注意

- 配布する場合は、使う画像とフォントの権利と、ライセンスの表示を、自分で確認すること(元の画像は、ゲームがコードで描いていて、素材ファイルは無い)。
- 画像が壊れている、読めない場合は、元の絵に戻る。


同梱のマップチップ(32×32、つなぎ目なしのドット絵)は、`godot/assets/tiles/` にある。全舞台の床・通路・壁・扉と、階段・宝箱・罠。プロンプトは `docs/tile-prompts.md`。
