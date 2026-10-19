# ゲーム・映像・SNS・掲示板での擬音の用例

ken 2026-10-19「ゲームや映像作品、特にネット SNS や掲示板でのオノマトペの用例もねちっこく調べて取り込んで」。読んだもの、分かったこと、実験室に写したもの(`cue_nodes.js` の `ex_*`)を出典つきで書く。読めなかったものも書く。

## 1. ゲーム

### 文字演出の分類(gameanimation.info「インゲーム文字演出の種類」)
- 出典: https://gameanimation.info/archives/2148
- 内容: 画面内の文字を 状況説明(状態異常・取得。ベルトコンベア的な機械的な動きかフェードで、目立たせない)/ 威力表現(ダメージの数字。連続ヒットをばらばらに・重ねて・合算して)/ コンボ(1 から数え上げ、増えるほど大きく派手に。派手すぎると集中を妨げる)/ カットイン(時間を止めて見せる)/ 場面切り替え(ボス戦の前に緊張を先に与える) に分ける。
- 取り込んだもの: 分類をゲームの擬音に当てると、擬音は「威力表現」と「場面切り替え」(層の主の咆哮)で、「状況説明」は頭上の文字とログが担う、という整理。実験室にノードは足していない。

### ペルソナ5 の総攻撃(New Frame Plus の解説の書き起こし)
- 出典: https://amara.org/subtitles/wIZbgZ3Jyy5D/en/1/download/The%20Overwhelming%20Style%20of%20Persona%205s%20All-Out%20Attacks.en.txt (動画「The Overwhelming Style of Persona 5's All-Out Attacks」の字幕)
- 内容: 攻撃の連打の間、片仮名の擬音と衝撃のフラッシュが画面中に出る。仲間は**一斉ではなく、ずらしたリズムで**跳ぶ(1 秒の中で退場のタイミングが違う。これが手触りになる)。2D の層には**ゆっくりした回転のドリフトと小さな揺れ**を入れて画面を生かす。台詞の窓は「元気に揺れる」。3D→2D の切り替えは 1 コマのクロスフェード。
- 取り込んだもの: `ex_persona`(一字ずつ 0.04 秒ずらし、3 倍の大きさから叩き込み、交互に傾けて、行き過ぎてから戻る)。「ずらしたリズム」は既にある `delay` の `per`、「ゆっくりしたドリフト」は `ex_menacing` にも入れた。
- 読めなかった: Persona 5 の UI 解説(mechanicsofmagic.com、itch.io の研究記事)は静的なデザインと日付の切り替え(12 秒)の話で、文字の動きは書いていなかった。

### スプラトゥーンの UI(娯楽の UI 公式レポート #2)
- 出典: https://careerhack.en-japan.com/report/detail/965
- 内容: ボタンは決定時に動き、カーソルはいつもイカが泳ぐ。動きは「音の質感を感じさせるまで」磨く。独自の「イカフォント」(力強く液体のような線)。文字は白く、背景は彩度を落として、大事な情報だけ立たせる。擬音の文字の話は無かった。
- 取り込んだもの: 指針。「動きが音の質感を持つ」= 擬音の文字の動きが音の代わり、という本作の方針そのもの。

### Celeste の揺れる台詞(Robin Rendle「Video games and WiggleTech」)
- 出典: https://robinrendle.com/adventures/video-games-and-wiggletech/
- 内容: Celeste は斜体を使わず、**字を上下に動かして**強調を表す。叫ぶときは字が暴れて跳ね回る。読む邪魔をしない範囲の動きで、声の調子が伝わる。
- 取り込んだもの: `ex_shaky`(細かく震え続け、時間とともに強くなる)。Undertale の震える台詞、Godot の `[shake]`、2ch の「ガクブル」と同じ型。

### 文字演出のエンジン(Unity Text Animator、pygame_gui、Godot RichTextLabel)
- 出典: https://tools.febucci.com/text-animator/unity/docs/effects/built-in-effects-list 、https://pygame-gui.readthedocs.io/en/v_065/text_effects.html 、https://docs.godotengine.org/ja/3.5/tutorials/ui/bbcode_in_richtextlabel.html (Godot のページは本文が取れなかった。wave / tornado / shake / fade / rainbow があることは Godot 4 の実装で既知)
- 内容: Text Animator の 12 種(pendulum, dangle, fade, rainbow, rotate, bounce, slide, swing, wave, incr, shake, wiggle。a = 強さ、s = 速さ の修飾)。pygame_gui の 6 種(fade in / out、typing、bounce、tilt、expand-contract)。どれも「字ごとの位置・回転・大きさ・色を時間の関数で動かす」で、実験室のノードと同じ性質の集合。
- 取り込んだもの: 一覧との突き合わせ。本作の 11 種に無いのは **typing(一字ずつ現れる)**、**rainbow(色)**、**pendulum / dangle(上端を支点に揺れる)**。typing は `delay` + `step` で書ける(`ex_persona` の alpha がそれ)。色のノードは無い(`props` に色が無い)。

### 映画・テレビの擬音(filmdaft「Onomatopoeia in film and TV」)
- 出典: https://filmdaft.com/onomatopoeia-in-film-and-tv-meaning-definition-examples/
- 内容: 1966 年の『バットマン』の POW / BAM / ZAP、『スコット・ピルグリム』(2010)、『スパイダーバース』(2018)。大きな大文字 = 大きな音、小さく細い字 = 小さな音、という漫画の作法をそのまま映像に。動きの細部は書いていない。
- 取り込んだもの: 指針。「大きさ = 音量」は既に `size` で、「細い = 小さい音」は半角カナで代える(`03` の中佐古)。

## 2. 映像・配信の文字(テロップ・弾幕)

### バラエティ番組のテロップ(鄭惠先 2016、video-knowledge)
- 出典: https://eprints.lib.hokudai.ac.jp/repo/huscap/all/73082/chon_kaken.pdf 、https://video-knowledge.com/types-and-roles-of-telop/ 、https://www.nemovideo.com/ja-JP/blog/text-overlay-design-guide-jp
- 内容: テロップは 情報明示型 / 強調型 / 解釈型(塩田 2005)。擬声語・擬態語・記号・絵は「視線集中字幕」(洪 2004。全体の 9.5〜14.6%)。色・大きさ・字体・矢印やハートで特定の語に目を集め、ズームインなどの開始・終了モーションと効果音を併用。「叩かれてパン!」のように擬音は発言の文字起こしの中に出る。強調テロップはキャプションより大きく色を変え、1 画面に同時に出さない。目安は 1 文字 0.1〜0.15 秒。
- 取り込んだもの: `ex_telop`(左から滑り込んで止まり、読む間だけ置いて、下へ抜ける)。「1 文字 0.1〜0.15 秒」は `life()` の字数の係数と同じ考え。

### ニコニコ動画の流れるコメント・弾幕
- 出典: https://dic.nicovideo.jp/a/%E5%BC%BE%E5%B9%95 、https://wiki.ubc.ca/Course:ASIA319/2024/%22Overtitle/Subtitle/Danmaku%22_(%E5%BC%B9%E5%B9%95) 、https://b.hatena.ne.jp/entry/s/originalnews.nico/346226 (ニコニコ 15 年のコメント分析の記事のブックマーク)
- 内容: 弾幕 = 同じコメントで画面が埋まる状態(語源は弾幕シューティング、1997 年の『怒首領蜂』)。コメントは右から左へ一定の速さで流れ、上下固定もある。色に意味が付く(bilibili では緑 = 裏切り、黄 = 成人、桃・赤 = 恋愛)。密度そのものが盛り上がりの表現で、「一人弾幕」は荒らし扱い。15 年で約 56 億件、「w」は 2007〜2012 年に年間上位を独占、「うぽつ」は 2011 年ごろ、「草」は 2016 年ごろ、「8888」(拍手)は 2021 年に初めて上位。「w の連打が減ったのはスマホで連打しにくいから」という読者の見方。
- 取り込んだもの: `ex_danmaku`(右から左へ一定の速さ、消えない、揺れない)。「密度で盛り上がりを表す」は、本作の「続けて起きる擬音は間引く」と逆の作法で、意図して使う所(層の主を倒した瞬間など)を決めれば使える。

## 3. SNS・掲示板

### ｷﾀ━━━━(ﾟ∀ﾟ)━━━━!!(paradisearmy の由来の記事)
- 出典: https://www.paradisearmy.com/doujin/pasok_kita.htm
- 内容: 2001 年 8 月 2 日の 2 ちゃんねる ラウンジ板のスレッドが確認できる最古。作法は **罫線(━ ― ─)を並べて勢いを伸ばす**、**半角カナ(ｷﾀ)**、**! の重ね**、**片仮名化(来た → キター)**、顔文字。待っていたものが来た歓喜。2005 年『電車男』で広まった。
- 取り込んだもの: 作法の一覧(伸ばし・半角・!重ね・片仮名)を `04-dakuten.md` の「ほかの強調の作法」と同じ段に置く。実験室では「自由入力」で ｷﾀ━━ を置けば stretch で伸びる。

### 2ch / 5ch のスラング(mittun-zakki「2ちゃんねる用語・ネットスラング 108 選」)
- 出典: https://mittun-zakki.com/2ch-5ch-slang-list/
- 内容: 擬音・擬態語由来は ハァハァ(小書きの ァ と反復)、ﾌﾞｯ・ﾄﾞﾝ・ｷﾞｬｰ(半角カナ。濁点が別の文字)。wktk(ワクワクテカテカ の子音略)、ktkr(キタコレ)。
- 取り込んだもの: 「半角カナ = 小さい声・AA の見た目」「濁点が別の字」という表記の癖。本作の ﾌｯ(半角 = かすか)と同じ。濁点を別の字として動かす(いまの `CueText.split` の振る舞い)は、2ch 的には自然でもある。

### SNS の特殊な仮名表記(中井「SNS における特殊な仮名表記について」広島大学 卒業論文)
- 出典: https://home.hiroshima-u.ac.jp/jshira/papers/SNS%E3%81%AB%E3%81%8A%E3%81%91%E3%82%8B%E7%89%B9%E6%AE%8A%E3%81%AA%E4%BB%AE%E5%90%8D%E8%A1%A8%E8%A8%98%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6%EF%BC%88%E4%B8%AD%E4%BA%95%EF%BC%89.pdf
- 内容: X の投稿で、清音に濁点を付ける表記(ぢ・づ、さらに濁音の無い仮名にも)は**興奮や感情の高まりに伴うざらついた声を文字で表す工夫**で、漫画の表現と共通。「まぢ」は 2012 年ごろのギャル語の流行で増え、その後減少。「おいちぃ」(し→ち + 濁点)は甘え語。「ゑ」は感動詞(驚き)に多い。小書き(ぅ ゎ)と半角カナ(ﾏﾁﾞ)は話し言葉の音声を写す試み。
- 取り込んだもの: 濁点の調査(`04-dakuten.md`)の裏づけ。「濁点 = 声がざらつく = 興奮」が SNS でも同じ。

### ぴえん(ニッセイ基礎研究所)
- 出典: https://www.nli-research.co.jp/files/topics/66831_ext_18_0.pdf
- 内容: 泣き声の「びえーん」から。初めは「え」の数で泣き声の長さを表し、のちに短く「ぴえん」(大泣きではない感情)。2018 年の絵文字 🥺 と結びついて定着。「ぴえん超えてパオン」の派生。
- 取り込んだもの: 指針。「伸ばしの字数 = 強さ・長さ」は本作の どかーーーーん! と同じ。

### JoJo の「ゴゴゴゴ」「ドドドド」(KnowYourMeme、Japanese with Anime、pixiv「どーん」)
- 出典: https://knowyourmeme.com/memes/menacing-%E3%82%B4%E3%82%B4%E3%82%B4%E3%82%B4 、https://www.japanesewithanime.com/2018/10/gogogogo.html 、https://www.japanesewithanime.com/2018/10/dodododo.html 、https://dic.pixiv.net/a/%E3%81%A9%E3%83%BC%E3%82%93
- 内容: ゴゴゴゴ は「menacing」。音ではなく雰囲気の擬態語(作中の人物には聞こえない)。1987 年の第 3 号から。2015 年に歩道橋の影が ゴゴゴゴ に見える写真が Twitter で広まり、2019 年に Reddit の r/ShitpostCrusaders で 7,100 点超。他作品の絵に ゴゴゴゴ と「menacing」を貼る改変が定番。ドドドド は JoJo では「正体不明」の不気味さ、ギャグ漫画がパロディに使う。「どーん」は漫画では唐突な登場の擬態語、『ペルソナ4』の千枝の追撃の代名詞。
- 取り込んだもの: `ex_menacing`(字がばらばらの高さに散り、ゆっくり漂い、消えない)。本作の ゴゴゴ…(隠し扉)は shake で「音」として使っていて、JoJo の雰囲気の型とは別物。層の主の間に入ったときの「気配」に、雰囲気の型を当てる案がある。

### 漫画の擬音の用語集(gwern の保存ページ、jref)
- 出典: https://gwern.net/doc/www/web.archive.org/296105d1b5ec1b8f0cdb6f13be909d1ddd9886ca.html 、https://jref.com/articles/japanese-sound-effects.322/
- 内容: 英語圏の読者向けの一覧。衝撃(ba, baki, don(強調にも), ban, dosa, gashan, gochin(滑稽な衝突), ton / to / kon(静かな衝撃))、扉(batan, gacha / kacha, paka)、きしみ(gishi, mishi mishi, zooon, goro / goron)、気配(go go go go, uzo uzo, zumo / zumomomo)、静寂(shiiin, jiiiin)、出現(bon, doron, nuuuu)、寒気(zoku, zotto, chiri chiri)。
- 取り込んだもの: ゲームの CUES と突き合わせる辞書。ズモモ…(召喚)は zumomomo = looming、ニュルッ は nuuuu に近い、と確認できる。

## 4. 読めなかったもの・見つからなかったもの
- Godot の RichTextLabel のページ本文(取得できず)。Persona 5 の文字の動きそのものの解説(動画の書き起こししか無い)。
- 『漫画のプロが全力で教える「描き文字」の基本』(東京デザイン専門学校 監修。https://news.denfaminicogamer.jp/news/260513m の紹介記事のみ)。描き文字の大きさ・字体・配置の実用書で、本の中身は読めていない。
- Twitter / X の擬音の表記の統計(秋田 2012 は語の出現割合まで。表記ごとの比率は無い)。
- 「ッ に濁点」の型そのものの解説は SNS 側でも見つからなかった(濁点付与は母音・清音が中心)。
