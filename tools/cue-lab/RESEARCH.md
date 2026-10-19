# 擬音の動きの先行研究と、実験室に取り込んだもの

ken 2026-10-19「先行研究の内容をとりこんでくれ。一人の考えだと限界がある」。読んだものと、`cue_nodes.js` のどのノード・どの例に写したかを、出典つきで書く。読めなかったものも書く。

## 1. 文字を動かす仕組み(キネティック・タイポグラフィ)

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

## 2. 文字の動きと印象の対応(どう動かすと何が伝わるか)

### Lee, Kim, Wee, Jang, Ha, Jun「Evaluating Pre-defined Kinetic Typography Effects to Convey Emotions」Journal of Korea Multimedia Society 17(1), 2014
- 出典: https://koreascience.kr/article/JAKO201409864556113.do
- 内容: 80 種の動きを 21 人が「気分(mood)」と「勢い(energy)」で評価。**勢い**は 文字の大きさ・透明度・動く向き・移動量・速さ・加速度 で決まり、**気分**は 透明度・動く向き・動きの規則性・速さ で決まる。
- 取り込んだもの: ノードではなく、擬音を設計する指針。slam(大きく速く)= 勢い、wave(規則的)= 気分。「強さの段を上げる」なら大きさ・移動量・加速度を上げる。

### 水口充・上田晃寿・山本景子・倉本到・辻野嘉宏「文字アニメーションによる動き方が表現された感情に与える影響に関する基礎調査」ヒューマンインタフェース学会論文誌 14(1), 2012
- 出典: https://www.jstage.jst.go.jp/article/his/14/1/14_9/_article/-char/ja
- 内容: 感情の単語 × 動きのパターン。単語も動きも 3 群に分かれ、組み合わせで伝わり方が変わる(抄録のみ。全文は未読)。
- 取り込んだもの: 「文字(言葉)と動きは別々に効き、組み合わせで変わる」という前提。擬音は言葉の側が強いので、動きは言葉を裏切らない範囲に。

## 3. オノマトペと動きの対応(音象徴)

### Fukusato, Morishima「Automatic depiction of onomatopoeia in animation considering physical phenomena」ACM SIGGRAPH MIG 2014
- 出典: https://dl.acm.org/doi/10.1145/2668064.2668096 (https://www.researchgate.net/publication/286808730)
- 内容: CG の衝突の物理量(質量・体積・加速度・粘性など 6 つ)から、100 語の衝突の擬音の中から合うものを選んで画面に置く。擬音は音素のベクトルで表す。500 人超の評価で「動きが生き生きする」。配置は視点依存のガウス関数で、重なりを避ける。
- 取り込んだもの: ノードではなく、ゲーム側の設計。「出来事の物理量 → 擬音」の段は sfx.gd の CUES の選び方(重い = 濁音、など。`design/2026-10-17-onomatopoeia.md`)に当たる。配置の「重なりを避ける」は未実装(続けて出る擬音は間引いている)。

### Koguchi, Yamada, Taura「The database of motion constructed by focusing on mimetic words」ICED 2013
- 出典: https://www.designsociety.org/download-publication/34584/
- 内容: 擬態語 52 語を 9 語(ひらひら、ぴょんぴょん など)に束ね、動物や植物の実写から取った 160 の基本動作と対応づけた。動きの「リズム」= 動きの量と角速度の変化。人の一致は弱い(最高 46%、κ=0.46)が有意。
- 取り込んだもの: `rhythm`(音節ごとに位相をずらした振動)。例 `ex_hira`。「一致が弱い」ので、ひらひらの割り当ては実験室で見て決める。

### 三浦佳世「オノマトペによる速度感」人工知能学会全国大会 2011
- 出典: https://www.ai-gakkai.or.jp/jsai2011/webprogram/2011/pdf/35.pdf
- 内容: 擬音語は速さを、擬態語は軌跡や様態を伝える。運動線と擬音が一致すれば言葉が優先される。
- 取り込んだもの: 指針。fly(ヒュッ)の残像は運動線の代わりで、言葉と向きを一致させる(`dir`)。

### 中佐古真実・松村耕平・野間春生「オノマトペのイメージを考慮した可視化による子どもたちの表現能力向上の試み」インタラクション 2016
- 出典: http://www.interaction-ipsj.org/proceedings/2016/data/pdf/2C44.pdf
- 内容: 62 語で、太さ(細・普通・太)と ひらがな / カタカナ の好みを一対比較で調べた。「てくてく」は細いひらがな、「ごそごそ」は普通の太さ。
- 取り込んだもの: 指針。ひらがな = 柔らかい音、は決まりに既にある。太さは Dela Gothic One 一本なので、細い擬音は半角カナ(ﾌｯ)で代える。

### 宮内彩璃・小林桂「日本漫画におけるオノマトペの体験型インスタレーションの検討」インタラクション 2024
- 出典: https://www.interaction-ipsj.org/proceedings/2024/data/pdf/1P-78.pdf
- 内容: 体験者の動きに合わせて手描きの擬音を出す。動きの大きさで字体や大きさを変える案は今後の課題。
- 取り込んだもの: 無し(方向が同じ、という確認)。

## 4. 濁点の強調(文字の側)
- `design/2026-10-19-dakuten-emphasis.md` に出典つきでまとめた(ニコニコ大百科、和語の里、Wikipedia「あ゙」、Japanese with Anime、ピクシブ百科事典)。実験室の「ッ に濁点」と「濁点を前の字にくっつける」切り替えがそれ。

## 5. まだ取り込んでいないもの・読めなかったもの
- KTE2、Wakey-Wakey、After Effects の公式ページ本文、Lee 2014 と水口 2012 の全文(どの動きがどの感情か、の表)。
- 「流れる文字」(字形が変わる、Brownie の fluid typography)。
- Fukusato の「重なりを避ける配置」。
