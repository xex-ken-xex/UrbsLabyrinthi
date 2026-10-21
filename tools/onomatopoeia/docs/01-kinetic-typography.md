# 文字を動かす仕組み(キネティック・タイポグラフィ)の先行研究

(2026-10-19 調べ。各項目の「取り込んだもの」は `cue_nodes.js` のノード名・例の名前)

### Lee, Forlizzi, Hudson「The Kinetic Typography Engine: An Extensible System for Animating Expressive Text」UIST 2002
- 出典: https://dl.acm.org/doi/10.1145/571985.571997 (PDF: http://johnnylee.net/academic/KT_Engine_UIST2002.pdf)
- 内容: 文字列を木(文字列 → 文字)にし、性質(位置・大きさ・回転・色・字間・透明度など)ごとに「振る舞い(behavior)」を繋ぐデータフロー。振る舞いの出力を次の振る舞いに**足す**(加算合成)、振る舞いの入力に別の振る舞いを繋ぐ(関数合成。「一方の大きさに、もう一方で包絡線をかける」)。時間は枝ごとに**時間フィルタ**で変換する(Delay / Speed / Loop / Reverse / PaceInOut / Pause / EventTrigger)。波形は UniformChange / Oscillate / Curve(ベジェ1本) / Jitter の4つ。アニメの技法(伸び縮み・予備動作・余韻)は「主たる動きの一階微分」や波形のいじりで自動生成する。全部で Java 2700 行。
- 取り込んだもの:
  - ノードの基本設計そのもの(`nodes → props`、add / mul で合流、名前で枝またぎ)。
  - 時間フィルタ: `speed` `loop` `reverse` `pace` `pause`(`delay` は元からある)。
  - 波形: `curve`(ベジェ)、`jitter`(種で決まる乱れ)。`osc` は元からある。
  - 自動技法: `deriv`(ノードの微分)で伸び縮みを作る、`anticip`(予備動作)。例 `ex_anticip`、`ex_pause`、`ex_flip`(loop)。

### Yeo, Hudson「KTE2: an engine for kinetic typography」
- 出典: https://www.semanticscholar.org/paper/a9b2dff312772b746fb7fcd1c3ab7779eeee9b5a
- **読めなかった**(ページの取得に失敗)。KTE の改訂版で、合成のしやすさを直したものらしい、までしか分からない。

### 加藤淳・中野倫靖・後藤真孝「TextAlive: Integrated Design Environment for Kinetic Typography」CHI 2015(産総研)
- 出典: https://junkato.jp/publications/chi2015-kato-textalive.pdf 、サービス https://textalive.jp/
- 内容: 歌詞を**フレーズ・単語・文字の階層**にし、各単位が「いつ歌われるか」の時刻を持つ。各段に「アニメーションのテンプレート」を重ねて貼る(フレーズに滑り、文字に跳ね)。テンプレートは Java のクラスで、`animate(time)` は純粋関数。繋ぐ操作は無く、重ね貼りだけ。被験者が「複数のテンプレートを組み合わせた結果が予測しにくい」と言った。
- 取り込んだもの: 階層の考え。文字の上に**音節(拍)**の段を足した(`syl` `nsyl` `alt`)。「組み合わせの結果が読めない」への対策として、合流は add / mul の二つに限り、実験室で即座に再生して見る。例 `ex_hira`。

### Adobe After Effects の Text Animator(Range Selector)
- 出典: https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation-examples/examples-resources-text-animation.html (ページ本文は取得を止められたので、仕様は一般に知られている範囲で書く)
- 内容: 文字列に性質のアニメーター(位置・拡縮・回転・不透明度…)を重ね、**Range Selector** が「文字の位置(0〜1)のどこからどこまでに、どんな形(ramp / triangle / square / round)で効かせるか」を決める。Randomize Order で文字の順をばらす。これが業界の定番の型。
- 取り込んだもの: `pos`(文字の位置 0〜1)、`rangesel`(範囲と形)、`perm`(順をばらす)。例 `ex_range`、`ex_shuffle`(ken の「シャッフル → キャンセル」)。

### Xie ほか「Wakey-Wakey: Animate Text by Mimicking Characters in a GIF」UIST 2023
- 出典: https://arxiv.org/abs/2308.00224
- **読めなかった**(取得を止められた)。GIF のキャラクターの動きを文字に写す、という題だけ確かめている。

### Wikipedia「Kinetic typography」
- 出典: https://en.wikipedia.org/wiki/Kinetic_typography
- 内容: Brownie の分類(動く文字 = scrolling / dynamic layout、流れる文字 = fluid: 字形そのものが変わる)。Wong の「形(form)と振る舞い(behaviour)を分ける」考え。
- 取り込んだもの: 分類だけ。実験室の 11 種はすべて「動く文字」で、「流れる文字(字形が変わる)」は無い。足すなら別の段(字形のモーフ)になる。
