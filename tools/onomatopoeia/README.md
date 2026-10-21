# 擬音の実験室(onomatopoeia)

ゲームの擬音の動き(`godot/scripts/cue_text.gd` の `draw_word` と `sfx.gd` の `life`)を JS に写し、ブラウザで舞台に置いて再生し、動きを「ノードのグラフ」で書き換え、リール向けに書き出す道具。リリースには入れない。

公開先(claude.ai の Artifact、帳面つき): https://claude.ai/artifact/Mxw8VWnnb7CeNVYBYj7kjS

## ファイル
- `index.html`: 舞台・一覧・再生・帳面・ノードのグラフの編集と比較・書き出し。そのまま開いても動く(帳面は claude.ai の Artifact として開いたときだけ残る)。
- `gen.py`: `sfx.gd` の CUES / STYLE と `layer_boss.gd` の咆哮から `cues.js` を作る。擬音を足したり変えたりしたら `python3 tools/onomatopoeia/gen.py` で作り直す。`cues.js` は手で直さない。
- `cue_lab.js`: `draw_word` の写し。ゲームの描き方を変えたら、同じに直す。「実験」の印の所(濁点を前の字につける、音節ごとに向きを変える)はゲームにまだ無い試し。
- `cue_nodes.js`: 動きを「ノードのグラフ」(JSON)で表す評価器と、いまの 11 種をグラフに書き直したもの(GRAPHS)。写しと画素まで同じになることを確かめてある。先行研究と用例から写した例は `EXAMPLES`(`ex_*`)。
- `cue_export.js`: 書き出し(APNG・PNG 連番の zip・WebM)。外部ライブラリなし。

## 決めた流れ
動きの実験はまず JS(実験室)で試して帳面で決め、決まったものだけ `cue_text.gd` に写す。

## 調べたこと(docs/)
- [01 文字を動かす仕組み(キネティック・タイポグラフィ)](docs/01-kinetic-typography.md): KTE(UIST 2002)、TextAlive(CHI 2015)、After Effects の Range Selector ほか。ノードのエンジンの設計の元。
- [02 文字の動きと印象](docs/02-motion-and-emotion.md): 動きの属性 → 勢い・気分(Lee 2014)、水口 2012。
- [03 オノマトペと動き](docs/03-onomatopoeia-and-motion.md): 物理量 → 擬音(Fukusato 2014)、擬態語の動作 DB(Koguchi 2013)、動的音喩(松下 2011、寺島 2012)、語末の標識 ッ・ン・ー(陳 2022)ほか。
- [04 濁点で強める書き方](docs/04-dakuten.md): 漫画の ッ゙・あ゛、フォント(Dela Gothic One)で出るかの確認、ゲームでの使い方の案。
- [05 ゲーム・映像・SNS・掲示板の用例](docs/05-games-video-sns.md): ペルソナ5、Celeste、スプラトゥーン、テロップ、ニコニコの弾幕、ｷﾀ━━、2ch の半角カナ、SNS の濁点、ぴえん、JoJo の ゴゴゴゴ ほか。
- [06 リール向けの書き出し](docs/06-reel-export.md): 入れた形式(APNG・PNG 連番・WebM)、確かめたこと、使い方、入れなかったもの。

それぞれの出典は各ファイルに書いてある。
