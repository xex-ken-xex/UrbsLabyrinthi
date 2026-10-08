---
title: オープンゲームデータの出所とライセンス（魔物・罠・遭遇）
audience: GM、開発用。PLに見せても差し支えない
pair: urbs-labyrinthi-spec.md（Urbs Labyrinthi の仕様）、roadmap-fvtt-hackslash.md（FVTT とハクスラへの展開）
checked: 2026-10-08
---

# オープンゲームデータの出所とライセンス

## 0. この資料について

Urbs Labyrinthi（ランダムダンジョン生成）と、その先の FVTT 自動進行、ハクスラ化で使う「借りてくるデータ」の出所と、使うときの決まりをまとめたもの。

| タグ | 意味 |
|---|---|
| 【確認済】 | 2026-10-08 に、一次資料か公式ページで確かめた |
| 【要確認】 | まだ一次資料で確かめていない。使う前に確かめる |
| 【方針】 | この企画での決め事 |

法律上の助言ではない。販売や公開の前に、ライセンスの原文を自分で読むこと。

---

## 1. 結論

- 魔物、罠、遭遇の予算は、**D&D 5e の SRD（System Reference Document）** から取る。CC-BY-4.0 で公開されていて、帰属表示を付ければ、改変も商用利用もできる【確認済】
- 版は二つ持つ。**SRD 5.1（2014年版ルール）** と **SRD 5.2.1（2024年版ルール）**。Urbs Labyrinthi は両方を収録し、切り替えられる
- d20 SRD（3.5版）は使わない。OGL 1.0a だけで提供されていて、CC-BY の版がない【要確認】。表示義務が重く、5e の資産（FVTT の dnd5e システム）ともつながらない
- 層の魔物（洞窟鼠、粘泥など）は、この世界の固有名。能力値だけを SRD の魔物から借りる「置き換え」で扱う（§7）

---

## 2. SRD の版

| 版 | 対応ルール | ライセンス | 入手先 | 備考 |
|---|---|---|---|---|
| SRD 5.1 | 2014年版 | CC-BY-4.0 と OGL 1.0a の二本立て。どちらかを選ぶ | dndbeyond.com/srd | 独・西・仏・伊の版がある |
| SRD 5.2.1 | 2024年版 | CC-BY-4.0 のみ | dndbeyond.com/srd | 現行。英語は 2025-05-01 公開。5.2（2025-04-22）を置き換えた版 |
| d20 SRD | 3.5版 | OGL 1.0a のみ【要確認】 | — | 今回は使わない |

- 公式ページは「今後の SRD は CC-BY-4.0 のみで出す」としている【確認済】
- **日本語版の SRD は公開されていない**【確認済】。日本語の訳語は、こちらで付ける（§6）

---

## 3. 帰属表示

作るものに、下の文をそのまま入れる。Urbs Labyrinthi では、ページの末尾に両方を入れてある。

**SRD 5.1 を使う場合**

> This work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.

**SRD 5.2.1 を使う場合**

> This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

- 5.1 の文は、Markdown 化された SRD の Legal と照合した【確認済】
- 5.2.1 の文は、5.2 の Legal（版番号だけが違う）と照合した。5.2.1 の PDF 原文とは、要約でしか突き合わせていない【要確認】。公開や販売の前に、PDF の1ページ目と一字ずつ比べる

---

## 4. 使うときの決まり

SRD の Legal ページと、公式ページの記述から。

| してよい | 根拠 |
|---|---|
| 改変、翻訳、再配布、商用利用 | CC-BY-4.0 |
| 「compatible with fifth edition」「5E compatible」と書く | SRD の Legal ページが明記【確認済】 |
| ゲームソフトに数値を組み込む | CC-BY-4.0。媒体の制限はない |

| 避ける | 理由 |
|---|---|
| 上の帰属文のほかに、Wizards に関する帰属やお墨付きの表現を足す | Legal ページが「ほかの帰属を入れないでほしい」と書いている【確認済】 |
| SRD に載っていない固有の魔物や設定を使う | ライセンスの対象外。収録データに、ビホルダー、マインド・フレイヤー、ディスプレイサー・ビースト、ギスヤンキ、アンバー・ハルク、キャリオン・クローラー、ユアンティ、クオトア、スラードが**無い**ことを確かめた【確認済】 |
| 公式ロゴ、製品の装丁、公式イラストを使う | SRD に含まれない |
| 公式日本語版の訳語表や本文を写す | 日本語版は別の著作物。訳語は自前で付ける【方針】 |
| 改変したのに、原文のままのように見せる | CC-BY-4.0 は、変更の有無を示すよう求める。Urbs Labyrinthi では「要点だけに縮めた」「日本語名は仮訳」と明記している |

---

## 5. データの入手先

| 入手先 | 中身 | ライセンス | 使い方 |
|---|---|---|---|
| **5e-bits/5e-database**（GitHub） | SRD を JSON にしたもの。2014年版 334体、2024年版 341体。呪文、装備、クラスもある | コードは MIT。中身は SRD | **今回の取得元**。`src/2014/en/5e-SRD-Monsters.json` と `src/2024/en/…`。取得時のコミットは a6212be（2026-10-02） |
| 5e-bits/5e-srd-api | 上の後継。5e-database は凍結（アーカイブ）され、こちらへ統合された | MIT | 今後の更新はこちらを見る |
| dnd5eapi.co | 5e-srd-api の公開 API | — | 公開 API は 2014年版のみ【確認済】。2024年版は JSON を直接取る |
| Open5e（api.open5e.com） | SRD に加え、他社の公開資料も束ねた API。v2 が現行 | 文書ごとに違う | `…/v2/creatures/?document__key__in=srd-2024` のように文書を指定する。SRD 以外の文書は、OGL など別のライセンス。混ぜるときは一件ずつ確かめる【要確認】 |
| foundryvtt/dnd5e（FVTT のシステム） | SRD の魔物、呪文、装備が、FVTT のアクターやアイテムとして入っている | コードは MIT。中身は SRD 5.1 と 5.2（CC-BY-4.0） | FVTT では自前の JSON を読み込むより、これを名前で引くのが早い。パック名は `monsters`（2014年版）、`actors24`（2024年版） |
| SRD の Markdown 版 | OldManUmby/DND.SRD.Wiki（5.1）、springbov/dndsrd5.2_markdown（5.2） | 中身は SRD | 規則の表の確認に使った。第三者による変換なので、最終確認は公式 PDF で |
| 公式 PDF | dndbeyond.com/srd | CC-BY-4.0 | 原典 |

**上流データの注意**

- 5e-database の 2024年版が、SRD 5.2 と 5.2.1 のどちらに基づくかは、リポジトリに書かれていない【要確認】。数値が怪しいときは、公式 PDF と突き合わせる
- 5e-database の README は中身を「OGL 1.0a」と書いているが、SRD 5.1 は CC-BY-4.0 でも出ている。この企画は CC-BY-4.0 の側で使う【方針】
- 2024年版では、名前と種別が変わった魔物がある。例: Goblin → Goblin Warrior / Goblin Minion / Goblin Boss（種別はフェイ）、Thug → Tough、Poisonous Snake → Venomous Snake。2014年版だけの魔物が 40体、2024年版だけが 47体、共通が 294体

---

## 6. 収録データの形と日本語名

Urbs Labyrinthi は、元の JSON（各 1.3MB）を、遭遇の表示と裁定に要る項目だけに縮めて持っている（各 約125KB）。

| キー | 中身 | 例 |
|---|---|---|
| `i` | SRD の index。FVTT や API で引くときの鍵 | `giant-rat` |
| `n` / `j` | 英語名 / 日本語名（仮訳） | `Giant Rat` / `巨大ネズミ` |
| `z` | サイズ。T, S, M, L, H, G | `S` |
| `t` | 種別 | `beast` |
| `cr` / `xp` | 脅威度 / 経験点 | `0.125` / `25` |
| `ac` / `hp` / `hd` | AC / HP / ヒット・ダイス | `12` / `7` / `2d6` |
| `sp` | 移動速度（フィート） | `{"walk":30}` |
| `ab` | 能力値6つ（筋敏耐知判魅） | `[7,15,11,2,10,4]` |
| `pp` | 受動〈知覚〉 | `10` |
| `dv` `bs` `tv` `ts` | 暗視、擬似視覚、振動感知、真視（フィート） | `60` |
| `at` | 攻撃の要点。名前、命中ボーナス、ダメージ、セーヴ | `[{"n":"Bite","b":4,"d":"1d4+2 piercing"}]` |
| `mu` | 複数回攻撃の有無 | `1` |
| `tr` | 特徴の名前（本文は持たない） | `["Pack Tactics"]` |
| `im` `re` `vu` `ci` | 完全耐性、抵抗、脆弱、状態への完全耐性 | |
| `lg` | 伝説的アクションの有無 | `1` |

- 特徴や行動の本文は持っていない。裁定で要るときは、`i` を鍵に元データか公式 PDF を引く
- 変換スクリプトは `tools/build-monster-data.py`。日本語名の表（381件）もここにある

**日本語名の方針**【方針】

- 公式の訳語ではなく、この企画のための仮訳
- 獣は和名（ネズミ、コウモリ）、「Giant ○○」は「巨大○○」、固有の怪物はカタカナ（ラスト・モンスター、ゼラチナス・キューブ）
- 竜は「年齢・色・ドラゴン」（アダルト・レッド・ドラゴン）、ライカンスロープは「ワーウルフ（狼形態）」
- 画面では常に英語名を併記する。裁定で迷ったら英語名で引く

---

## 7. 層の魔物と SRD の対応（置き換え案）

都市PL資料 §6.1 の「代表的なモンスター」に、能力値を貸す SRD の魔物を割り当てたもの。**案であって、確定ではない**。合わなければ、Urbs Labyrinthi の `THEMES` の `sig` を書き換える。

| 層 | この世界の呼び名 | 借りる SRD の魔物 | 想定レベル |
|---|---|---|---|
| 第1〜2層 腐葉の回廊 | 洞窟鼠 | Giant Rat、Rat、Swarm of Rats | 1 |
| | 粘泥 | Gray Ooze、Ochre Jelly、Black Pudding、Gelatinous Cube | |
| | 骨亡者 | Skeleton、Zombie、Ogre Zombie | |
| 第3〜4層 錆鉄の坑道 | 鉱喰い蟲 | Rust Monster、Ankheg、Giant Fire Beetle、Swarm of Beetles / Insects | 3 |
| | 坑道の亡霊 | Specter、Ghost、Shadow、Will-o'-Wisp | |
| | 鎧鬼 | Animated Armor、Hobgoblin、Ogre | |
| 第5〜6層 鏡の水廊 | 水蛇 | Constrictor Snake、Giant Constrictor Snake、Giant Poisonous Snake、Swarm of Poisonous Snakes、Hydra | 5 |
| | 鏡像獣 | Doppelganger、Mimic | |
| 第7〜9層 骨の大聖堂 | 骨の守護者 | Minotaur Skeleton、Stone Golem、Shield Guardian、Clay Golem、Warhorse Skeleton | 9 |
| | 嘆きの聖歌隊 | Wraith、Ghost、Specter、Will-o'-Wisp | |
| | 黒蝕の騎士 | Wight、Vampire Spawn、Knight、Mummy | |
| 第10層以降 | （噂のみ） | 割り当てなし。異形、魔族、不死から脅威度で選ぶ | 15（仮） |

- 対応表にない魔物も、層ごとの種別の重みで混ざる（腐葉の回廊なら野獣・粘体・植物・不死・群れ）
- 鏡像獣の「死者の姿と記憶を再現する」（都市GM資料 火種5）は、Doppelganger の能力値では表せない。別に特徴を足す必要がある【未確定】
- 第10層以降は、世界設定で決まっていない。ここの中身は、すべて仮

---

## 8. SRD から借りた規則の表

Urbs Labyrinthi が計算に使っている表。数値は SRD のまま。

### 8.1 遭遇の経験点予算（SRD 5.2「Combat Encounter Difficulty」）

一人あたりの予算に人数を掛け、魔物の XP の合計がそれを超えないように選ぶ。

| レベル | 低 | 中 | 高 | | レベル | 低 | 中 | 高 |
|---|---|---|---|---|---|---|---|---|
| 1 | 50 | 75 | 100 | | 11 | 1,900 | 2,900 | 4,100 |
| 2 | 100 | 150 | 200 | | 12 | 2,200 | 3,700 | 4,700 |
| 3 | 150 | 225 | 400 | | 13 | 2,600 | 4,200 | 5,400 |
| 4 | 250 | 375 | 500 | | 14 | 2,900 | 4,900 | 6,200 |
| 5 | 500 | 750 | 1,100 | | 15 | 3,300 | 5,400 | 7,800 |
| 6 | 600 | 1,000 | 1,400 | | 16 | 3,800 | 6,100 | 9,800 |
| 7 | 750 | 1,300 | 1,700 | | 17 | 4,500 | 7,200 | 11,700 |
| 8 | 1,000 | 1,700 | 2,100 | | 18 | 5,000 | 8,700 | 14,200 |
| 9 | 1,300 | 2,000 | 2,600 | | 19 | 5,500 | 10,700 | 17,200 |
| 10 | 1,600 | 2,300 | 3,100 | | 20 | 6,400 | 13,200 | 22,000 |

- 2014年版の魔物を選んだときも、この表で予算を組んでいる。2014年版の本来の手順（人数による倍率）は SRD 5.1 に載っていないため【方針】

### 8.2 罠の難度（SRD 5.1「Traps」）

| 危険度 | セーヴ難易度 | 攻撃ボーナス |
|---|---|---|
| 軽度（Setback） | 10〜11 | +3〜+5 |
| 危険（Dangerous） | 12〜15 | +6〜+8 |
| 致命的（Deadly） | 16〜20 | +9〜+12 |

| レベル | 軽度 | 危険 | 致命的 |
|---|---|---|---|
| 1〜4 | 1d10 | 2d10 | 4d10 |
| 5〜10 | 2d10 | 4d10 | 10d10 |
| 11〜16 | 4d10 | 10d10 | 18d10 |
| 17〜20 | 10d10 | 18d10 | 24d10 |

- SRD の例示の罠は、5.1 が8種（Collapsing Roof、Falling Net、Fire-Breathing Statue、Pits、Poison Darts、Poison Needle、Rolling Sphere、Sphere of Annihilation）、5.2 が8種（Collapsing Roof、Falling Net、Fire-Casting Statue、Hidden Pit、Poisoned Darts、Poisoned Needle、Rolling Stone、Spiked Pit）
- Urbs Labyrinthi の罠は、仕組みを SRD の例に倣い、名前と描写を層ごとに書き下ろした（胞子溜まり、暴走する鉱車、鏡の眩惑、嘆きの共鳴など）。数値は上の表から引く
- 5.2 の罠は「nuisance / deadly」の二段階で、レベル帯ごとに数値が決め打ち。5.1 の三段階のほうが生成に向くので、5.1 の表を使っている【方針】

---

## 9. 【要確認】まとめ

- [ ] SRD 5.2.1 の帰属文を、公式 PDF の1ページ目と一字ずつ照合する（§3）
- [ ] 5e-database の 2024年版が、5.2 と 5.2.1 のどちらに基づくか（§5）
- [ ] d20 SRD（3.5版）のライセンス。使わない方針なので、優先度は低い（§2）
- [ ] Open5e で SRD 以外の文書を混ぜる場合の、文書ごとのライセンス（§5）
- [ ] 鏡像獣など、SRD の能力値では表せない固有の特徴をどう足すか（§7）
- [ ] 販売する場合の、帰属表示の置き場所（クレジット画面、ストアの説明文、同梱の LICENSE）

---

## 出典

- [Systems Reference Document（D&D Beyond）](https://www.dndbeyond.com/srd)
- [SRD 5.2.1 PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf)
- [SRD 5.1 PDF（CC 版）](https://media.wizards.com/2023/downloads/dnd/SRD_CC_v5.1.pdf)
- [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/legalcode)
- [5e-bits/5e-database](https://github.com/5e-bits/5e-database)、[5e-bits/5e-srd-api](https://github.com/5e-bits/5e-srd-api)
- [Open5e API](https://open5e.com/api-docs)
- [foundryvtt/dnd5e](https://github.com/foundryvtt/dnd5e)
- [OldManUmby/DND.SRD.Wiki](https://github.com/OldManUmby/DND.SRD.Wiki)、[springbov/dndsrd5.2_markdown](https://github.com/springbov/dndsrd5.2_markdown)
