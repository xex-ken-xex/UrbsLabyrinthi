# 擬音の実験室(cue-lab)

ゲームの擬音の動き(`godot/scripts/cue_text.gd` の `draw_word` と `sfx.gd` の `life`)を JS に写し、ブラウザで舞台に置いて再生する道具。リリースには入れない。

- `gen.py`: `sfx.gd` の CUES / STYLE と `layer_boss.gd` の咆哮から `cues.js` を作る。擬音を足したり変えたりしたら `python3 tools/cue-lab/gen.py` で作り直す。
- `cue_lab.js`: `draw_word` の写し。ゲームの描き方を変えたら、同じに直す。「実験」の印の所(濁点を前の字につける、音節ごとに向きを変える)はゲームにまだ無い試し。
- `cue_nodes.js`: 動きを「ノードのグラフ」(JSON)で表す評価器と、いまの11種をグラフに書き直したもの(GRAPHS)。写しと画素まで同じになることを確かめてある(Lee, Forlizzi, Hudson の Kinetic Typography Engine と同じデータフローの考え方)。
- `index.html`: 舞台・一覧・再生・帳面・ノードのグラフの編集と比較。`index.html` をそのまま開いても動く(帳面は claude.ai の Artifact として開いたときだけ残る)。

公開先(claude.ai の Artifact、帳面つき): https://claude.ai/artifact/Mxw8VWnnb7CeNVYBYj7kjS
