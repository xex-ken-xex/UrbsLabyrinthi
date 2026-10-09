# 魔物の外見とサイズ

`tools/make-monster-sprites.py` が、SRD の全魔物(334体)のスプライトシート(`esheet_<index>.png`)と、型ごとの代表(`esheet_type_<type>.png`)を作る。
名前の一部(dragon, wolf, golem …)で描き方(型)と色を決める。手描き定義(`make-sprites.py`)があるものは上書きしない。

## サイズの考え方

SRD の大きさ区分が、そのまま当たり判定の半径・質量・描く大きさになる(押し合いの強さにも効く)。

| 区分 | 半径(px) | 質量 | 絵を描く大きさ(px) | 例 |
|---|---|---|---|---|
| T | 7 | 0.4 | 26 | ネズミ、コウモリ、小蛇 |
| S | 9 | 0.7 | 32 | ゴブリン、大ネズミ |
| M | 11 | 1.0 | 39 | 人間、狼、グール |
| L | 16 | 1.8 | 57 | オーガ、大蜘蛛、グリフォン |
| H | 22 | 2.8 | 79 | ティラノサウルス、ゾウ |
| G | 30 | 4.0 | 108 | タラスク、古代竜 |

## 型(アーキタイプ)

| 型 | 描き方 | 対象 |
|---|---|---|
| 四つ足 | 横は側面、正面・背面は顔と前脚。角・牙・たてがみ・翼・尻尾・縞・斑点を組み合わせる | 獣、竜、馬、熊、猫、犬、恐竜、グリフォン、キマイラ |
| 鳥・飛行 | 翼をはためかせる | 鷹、梟、鴉、ミフィット、妖精 |
| 虫 | 上から見た形。脚が交互に動く | 蠍、甲虫、百足、蜂 |
| 蛇 | うねる体、頭は進む向き | 蛇、ヒュドラ、ナーガ、ラミア、ワーム |
| ぷよぷよ | つぶれながら進む。キューブ/塚の変種 | ウーズ、ゼラチナスキューブ、シャンブリングマウンド |
| 幽霊・火の玉 | ふわふわ浮かぶ | ゴースト、レイス、ウィスプ、エレメンタル |
| 目玉・触手 | 浮かぶ眼球と触手 | アボレス系、ギバリングマウサー |
| 蟹・蛸・魚 | 横歩き、触手、泳ぐ | カニ、タコ、クラーケン、サメ |
| 植物 | 低木、きのこ、茎 | 低木、バイオレットファンガス |
| 群れ | 小さな粒の集まり | 各種スウォーム |
| 人型(拡張) | 角・耳・牙・翼・尻尾・幅(wide)・包帯・毛皮などの特徴を足す | 悪魔、巨人、ゴーレム、アンデッド、人間系 |

## 差し替え

`godot/assets/OVERRIDE.md` の `esheet_<index>` / `esheet_type_<type>` で、個別に差し替えられる。型の名前は、スウォームを `swarm` に寄せて探す。

## 一覧

| index | 名前 | 区分 | 型 | 半径 | 質量 |
|---|---|---|---|---|---|
| aboleth | アボレス | L | aberration | 16 | 1.8 |
| chuul | チュール | L | aberration | 16 | 1.8 |
| cloaker | クローカー | L | aberration | 16 | 1.8 |
| gibbering-mouther | ジバリング・マウザー | M | aberration | 11 | 1.0 |
| otyugh | オティアグ | L | aberration | 16 | 1.8 |
| ape | 類人猿 | M | beast | 11 | 1.0 |
| axe-beak | アックス・ビーク | L | beast | 16 | 1.8 |
| baboon | ヒヒ | S | beast | 9 | 0.7 |
| badger | アナグマ | T | beast | 7 | 0.4 |
| bat | コウモリ | T | beast | 7 | 0.4 |
| black-bear | クロクマ | M | beast | 11 | 1.0 |
| blood-hawk | ブラッド・ホーク | S | beast | 9 | 0.7 |
| boar | イノシシ | M | beast | 11 | 1.0 |
| brown-bear | ヒグマ | L | beast | 16 | 1.8 |
| camel | ラクダ | L | beast | 16 | 1.8 |
| cat | ネコ | T | beast | 7 | 0.4 |
| constrictor-snake | 締めつけヘビ | L | beast | 16 | 1.8 |
| crab | カニ | T | beast | 7 | 0.4 |
| crocodile | ワニ | L | beast | 16 | 1.8 |
| deer | シカ | M | beast | 11 | 1.0 |
| dire-wolf | ダイア・ウルフ | L | beast | 16 | 1.8 |
| draft-horse | 荷馬 | L | beast | 16 | 1.8 |
| eagle | ワシ | S | beast | 9 | 0.7 |
| elephant | ゾウ | H | beast | 22 | 2.8 |
| elk | ヘラジカ | L | beast | 16 | 1.8 |
| flying-snake | 空飛ぶヘビ | T | beast | 7 | 0.4 |
| frog | カエル | T | beast | 7 | 0.4 |
| giant-ape | 巨大類人猿 | H | beast | 22 | 2.8 |
| giant-badger | 巨大アナグマ | M | beast | 11 | 1.0 |
| giant-bat | 巨大コウモリ | L | beast | 16 | 1.8 |
| giant-boar | 巨大イノシシ | L | beast | 16 | 1.8 |
| giant-centipede | 巨大ムカデ | S | beast | 9 | 0.7 |
| giant-constrictor-snake | 巨大締めつけヘビ | H | beast | 22 | 2.8 |
| giant-crab | 巨大ガニ | M | beast | 11 | 1.0 |
| giant-crocodile | 巨大ワニ | H | beast | 22 | 2.8 |
| giant-eagle | 巨大ワシ | L | beast | 16 | 1.8 |
| giant-elk | 巨大ヘラジカ | H | beast | 22 | 2.8 |
| giant-fire-beetle | 巨大火甲虫 | S | beast | 9 | 0.7 |
| giant-frog | 巨大ガエル | M | beast | 11 | 1.0 |
| giant-goat | 巨大ヤギ | L | beast | 16 | 1.8 |
| giant-hyena | 巨大ハイエナ | L | beast | 16 | 1.8 |
| giant-lizard | 巨大トカゲ | L | beast | 16 | 1.8 |
| giant-octopus | 巨大ダコ | L | beast | 16 | 1.8 |
| giant-owl | 巨大フクロウ | L | beast | 16 | 1.8 |
| giant-poisonous-snake | 巨大毒ヘビ | M | beast | 11 | 1.0 |
| giant-rat | 巨大ネズミ | S | beast | 9 | 0.7 |
| giant-rat-diseased | 巨大ネズミ（病持ち） | S | beast | 9 | 0.7 |
| giant-scorpion | 巨大サソリ | L | beast | 16 | 1.8 |
| giant-sea-horse | 巨大タツノオトシゴ | L | beast | 16 | 1.8 |
| giant-shark | 巨大ザメ | H | beast | 22 | 2.8 |
| giant-spider | 巨大グモ | L | beast | 16 | 1.8 |
| giant-toad | 巨大ヒキガエル | L | beast | 16 | 1.8 |
| giant-vulture | 巨大ハゲワシ | L | beast | 16 | 1.8 |
| giant-wasp | 巨大スズメバチ | M | beast | 11 | 1.0 |
| giant-weasel | 巨大イタチ | M | beast | 11 | 1.0 |
| giant-wolf-spider | 巨大コモリグモ | M | beast | 11 | 1.0 |
| goat | ヤギ | M | beast | 11 | 1.0 |
| hawk | タカ | T | beast | 7 | 0.4 |
| hunter-shark | ハンター・シャーク | L | beast | 16 | 1.8 |
| hyena | ハイエナ | M | beast | 11 | 1.0 |
| jackal | ジャッカル | S | beast | 9 | 0.7 |
| killer-whale | シャチ | H | beast | 22 | 2.8 |
| lion | ライオン | L | beast | 16 | 1.8 |
| lizard | トカゲ | T | beast | 7 | 0.4 |
| mammoth | マンモス | H | beast | 22 | 2.8 |
| mastiff | マスティフ犬 | M | beast | 11 | 1.0 |
| mule | ラバ | M | beast | 11 | 1.0 |
| octopus | タコ | S | beast | 9 | 0.7 |
| owl | フクロウ | T | beast | 7 | 0.4 |
| panther | ヒョウ | M | beast | 11 | 1.0 |
| plesiosaurus | プレシオサウルス | L | beast | 16 | 1.8 |
| poisonous-snake | 毒ヘビ | T | beast | 7 | 0.4 |
| polar-bear | ホッキョクグマ | L | beast | 16 | 1.8 |
| pony | ポニー | M | beast | 11 | 1.0 |
| quipper | クィッパー | T | beast | 7 | 0.4 |
| rat | ネズミ | T | beast | 7 | 0.4 |
| raven | ワタリガラス | T | beast | 7 | 0.4 |
| reef-shark | リーフ・シャーク | M | beast | 11 | 1.0 |
| rhinoceros | サイ | L | beast | 16 | 1.8 |
| riding-horse | 乗用馬 | L | beast | 16 | 1.8 |
| saber-toothed-tiger | 剣歯虎 | L | beast | 16 | 1.8 |
| scorpion | サソリ | T | beast | 7 | 0.4 |
| sea-horse | タツノオトシゴ | T | beast | 7 | 0.4 |
| spider | クモ | T | beast | 7 | 0.4 |
| stirge | スタージ | T | beast | 7 | 0.4 |
| tiger | トラ | L | beast | 16 | 1.8 |
| triceratops | トリケラトプス | H | beast | 22 | 2.8 |
| tyrannosaurus-rex | ティラノサウルス | H | beast | 22 | 2.8 |
| vulture | ハゲワシ | M | beast | 11 | 1.0 |
| warhorse | 軍馬 | L | beast | 16 | 1.8 |
| weasel | イタチ | T | beast | 7 | 0.4 |
| wolf | オオカミ | M | beast | 11 | 1.0 |
| couatl | コアトル | M | celestial | 11 | 1.0 |
| deva | デーヴァ | M | celestial | 11 | 1.0 |
| pegasus | ペガサス | L | celestial | 16 | 1.8 |
| planetar | プラネター | L | celestial | 16 | 1.8 |
| solar | ソーラー | L | celestial | 16 | 1.8 |
| unicorn | ユニコーン | L | celestial | 16 | 1.8 |
| animated-armor | 動く鎧 | M | construct | 11 | 1.0 |
| clay-golem | クレイ・ゴーレム | L | construct | 16 | 1.8 |
| flesh-golem | フレッシュ・ゴーレム | M | construct | 11 | 1.0 |
| flying-sword | 飛ぶ剣 | S | construct | 9 | 0.7 |
| homunculus | ホムンクルス | T | construct | 7 | 0.4 |
| iron-golem | アイアン・ゴーレム | L | construct | 16 | 1.8 |
| rug-of-smothering | 窒息の絨毯 | L | construct | 16 | 1.8 |
| shield-guardian | シールド・ガーディアン | L | construct | 16 | 1.8 |
| stone-golem | ストーン・ゴーレム | L | construct | 16 | 1.8 |
| adult-black-dragon | アダルト・ブラック・ドラゴン | H | dragon | 22 | 2.8 |
| adult-blue-dragon | アダルト・ブルー・ドラゴン | H | dragon | 22 | 2.8 |
| adult-brass-dragon | アダルト・ブラス・ドラゴン | H | dragon | 22 | 2.8 |
| adult-bronze-dragon | アダルト・ブロンズ・ドラゴン | H | dragon | 22 | 2.8 |
| adult-copper-dragon | アダルト・カッパー・ドラゴン | H | dragon | 22 | 2.8 |
| adult-gold-dragon | アダルト・ゴールド・ドラゴン | H | dragon | 22 | 2.8 |
| adult-green-dragon | アダルト・グリーン・ドラゴン | H | dragon | 22 | 2.8 |
| adult-red-dragon | アダルト・レッド・ドラゴン | H | dragon | 22 | 2.8 |
| adult-silver-dragon | アダルト・シルヴァー・ドラゴン | H | dragon | 22 | 2.8 |
| adult-white-dragon | アダルト・ホワイト・ドラゴン | H | dragon | 22 | 2.8 |
| ancient-black-dragon | エインシェント・ブラック・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-blue-dragon | エインシェント・ブルー・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-brass-dragon | エインシェント・ブラス・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-bronze-dragon | エインシェント・ブロンズ・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-copper-dragon | エインシェント・カッパー・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-gold-dragon | エインシェント・ゴールド・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-green-dragon | エインシェント・グリーン・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-red-dragon | エインシェント・レッド・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-silver-dragon | エインシェント・シルヴァー・ドラゴン | G | dragon | 30 | 4.0 |
| ancient-white-dragon | エインシェント・ホワイト・ドラゴン | G | dragon | 30 | 4.0 |
| black-dragon-wyrmling | ブラック・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| blue-dragon-wyrmling | ブルー・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| brass-dragon-wyrmling | ブラス・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| bronze-dragon-wyrmling | ブロンズ・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| copper-dragon-wyrmling | カッパー・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| dragon-turtle | ドラゴン・タートル | G | dragon | 30 | 4.0 |
| gold-dragon-wyrmling | ゴールド・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| green-dragon-wyrmling | グリーン・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| pseudodragon | スードゥドラゴン | T | dragon | 7 | 0.4 |
| red-dragon-wyrmling | レッド・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| silver-dragon-wyrmling | シルヴァー・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| white-dragon-wyrmling | ホワイト・ドラゴン・ワームリング | M | dragon | 11 | 1.0 |
| wyvern | ワイバーン | L | dragon | 16 | 1.8 |
| young-black-dragon | ヤング・ブラック・ドラゴン | L | dragon | 16 | 1.8 |
| young-blue-dragon | ヤング・ブルー・ドラゴン | L | dragon | 16 | 1.8 |
| young-brass-dragon | ヤング・ブラス・ドラゴン | L | dragon | 16 | 1.8 |
| young-bronze-dragon | ヤング・ブロンズ・ドラゴン | L | dragon | 16 | 1.8 |
| young-copper-dragon | ヤング・カッパー・ドラゴン | L | dragon | 16 | 1.8 |
| young-gold-dragon | ヤング・ゴールド・ドラゴン | L | dragon | 16 | 1.8 |
| young-green-dragon | ヤング・グリーン・ドラゴン | L | dragon | 16 | 1.8 |
| young-red-dragon | ヤング・レッド・ドラゴン | L | dragon | 16 | 1.8 |
| young-silver-dragon | ヤング・シルヴァー・ドラゴン | L | dragon | 16 | 1.8 |
| young-white-dragon | ヤング・ホワイト・ドラゴン | L | dragon | 16 | 1.8 |
| air-elemental | エア・エレメンタル | L | elemental | 16 | 1.8 |
| azer | アザー | M | elemental | 11 | 1.0 |
| djinni | ジン | L | elemental | 16 | 1.8 |
| dust-mephit | ダスト・メフィット | S | elemental | 9 | 0.7 |
| earth-elemental | アース・エレメンタル | L | elemental | 16 | 1.8 |
| efreeti | イフリート | L | elemental | 16 | 1.8 |
| fire-elemental | ファイアー・エレメンタル | L | elemental | 16 | 1.8 |
| gargoyle | ガーゴイル | M | elemental | 11 | 1.0 |
| ice-mephit | アイス・メフィット | S | elemental | 9 | 0.7 |
| invisible-stalker | インヴィジブル・ストーカー | M | elemental | 11 | 1.0 |
| magma-mephit | マグマ・メフィット | S | elemental | 9 | 0.7 |
| magmin | マグミン | S | elemental | 9 | 0.7 |
| salamander | サラマンダー | L | elemental | 16 | 1.8 |
| steam-mephit | スチーム・メフィット | S | elemental | 9 | 0.7 |
| water-elemental | ウォーター・エレメンタル | L | elemental | 16 | 1.8 |
| xorn | ゾーン | M | elemental | 11 | 1.0 |
| blink-dog | ブリンク・ドッグ | M | fey | 11 | 1.0 |
| dryad | ドライアド | M | fey | 11 | 1.0 |
| green-hag | グリーン・ハグ | M | fey | 11 | 1.0 |
| satyr | サテュロス | M | fey | 11 | 1.0 |
| sea-hag | シー・ハグ | M | fey | 11 | 1.0 |
| sprite | スプライト | T | fey | 7 | 0.4 |
| balor | バロール | H | fiend | 22 | 2.8 |
| barbed-devil | バーブド・デヴィル | M | fiend | 11 | 1.0 |
| bearded-devil | ビアデッド・デヴィル | M | fiend | 11 | 1.0 |
| bone-devil | ボーン・デヴィル | L | fiend | 16 | 1.8 |
| chain-devil | チェイン・デヴィル | M | fiend | 11 | 1.0 |
| dretch | ドレッチ | S | fiend | 9 | 0.7 |
| erinyes | エリニュス | M | fiend | 11 | 1.0 |
| glabrezu | グラブレズゥ | L | fiend | 16 | 1.8 |
| hell-hound | ヘル・ハウンド | M | fiend | 11 | 1.0 |
| hezrou | ヘズロウ | L | fiend | 16 | 1.8 |
| horned-devil | ホーンド・デヴィル | L | fiend | 16 | 1.8 |
| ice-devil | アイス・デヴィル | L | fiend | 16 | 1.8 |
| imp | インプ | T | fiend | 7 | 0.4 |
| lemure | レムレー | M | fiend | 11 | 1.0 |
| marilith | マリリス | L | fiend | 16 | 1.8 |
| nalfeshnee | ナルフェシュネー | L | fiend | 16 | 1.8 |
| night-hag | ナイト・ハグ | M | fiend | 11 | 1.0 |
| nightmare | ナイトメア | L | fiend | 16 | 1.8 |
| pit-fiend | ピット・フィーンド | L | fiend | 16 | 1.8 |
| quasit | クアジット | T | fiend | 7 | 0.4 |
| rakshasa | ラークシャサ | M | fiend | 11 | 1.0 |
| succubus-incubus | サキュバス／インキュバス | M | fiend | 11 | 1.0 |
| vrock | ヴロック | L | fiend | 16 | 1.8 |
| cloud-giant | クラウド・ジャイアント | H | giant | 22 | 2.8 |
| ettin | エティン | L | giant | 16 | 1.8 |
| fire-giant | ファイアー・ジャイアント | H | giant | 22 | 2.8 |
| frost-giant | フロスト・ジャイアント | H | giant | 22 | 2.8 |
| hill-giant | ヒル・ジャイアント | H | giant | 22 | 2.8 |
| ogre | オーガ | L | giant | 16 | 1.8 |
| oni | オニ | L | giant | 16 | 1.8 |
| stone-giant | ストーン・ジャイアント | H | giant | 22 | 2.8 |
| storm-giant | ストーム・ジャイアント | H | giant | 22 | 2.8 |
| troll | トロル | L | giant | 16 | 1.8 |
| acolyte | 侍祭 | M | humanoid | 11 | 1.0 |
| archmage | 大魔道士 | M | humanoid | 11 | 1.0 |
| assassin | 暗殺者 | M | humanoid | 11 | 1.0 |
| bandit | 山賊 | M | humanoid | 11 | 1.0 |
| bandit-captain | 山賊の頭 | M | humanoid | 11 | 1.0 |
| berserker | 狂戦士 | M | humanoid | 11 | 1.0 |
| bugbear | バグベア | M | humanoid | 11 | 1.0 |
| commoner | 平民 | M | humanoid | 11 | 1.0 |
| cult-fanatic | 狂信者 | M | humanoid | 11 | 1.0 |
| cultist | 教団員 | M | humanoid | 11 | 1.0 |
| deep-gnome-svirfneblin | ディープ・ノーム | S | humanoid | 9 | 0.7 |
| drow | ドラウ | M | humanoid | 11 | 1.0 |
| druid | ドルイド | M | humanoid | 11 | 1.0 |
| duergar | ドゥエルガル | M | humanoid | 11 | 1.0 |
| gladiator | 剣闘士 | M | humanoid | 11 | 1.0 |
| gnoll | ノール | M | humanoid | 11 | 1.0 |
| goblin | ゴブリン | S | humanoid | 9 | 0.7 |
| grimlock | グリムロック | M | humanoid | 11 | 1.0 |
| guard | 衛兵 | M | humanoid | 11 | 1.0 |
| half-red-dragon-veteran | ハーフ・レッド・ドラゴンの古強者 | M | humanoid | 11 | 1.0 |
| hobgoblin | ホブゴブリン | M | humanoid | 11 | 1.0 |
| knight | 騎士 | M | humanoid | 11 | 1.0 |
| kobold | コボルド | S | humanoid | 9 | 0.7 |
| lizardfolk | リザードフォーク | M | humanoid | 11 | 1.0 |
| mage | 魔道士 | M | humanoid | 11 | 1.0 |
| merfolk | マーフォーク | M | humanoid | 11 | 1.0 |
| noble | 貴族 | M | humanoid | 11 | 1.0 |
| orc | オーク | M | humanoid | 11 | 1.0 |
| priest | 司祭 | M | humanoid | 11 | 1.0 |
| sahuagin | サフアグン | M | humanoid | 11 | 1.0 |
| scout | 斥候 | M | humanoid | 11 | 1.0 |
| spy | 密偵 | M | humanoid | 11 | 1.0 |
| thug | ならず者 | M | humanoid | 11 | 1.0 |
| tribal-warrior | 部族の戦士 | M | humanoid | 11 | 1.0 |
| veteran | 古強者 | M | humanoid | 11 | 1.0 |
| werebear-bear | ワーベア（熊形態） | M | humanoid | 11 | 1.0 |
| werebear-human | ワーベア（人間形態） | M | humanoid | 11 | 1.0 |
| werebear-hybrid | ワーベア（中間形態） | M | humanoid | 11 | 1.0 |
| wereboar-boar | ワーボア（猪形態） | M | humanoid | 11 | 1.0 |
| wereboar-human | ワーボア（人間形態） | M | humanoid | 11 | 1.0 |
| wereboar-hybrid | ワーボア（中間形態） | M | humanoid | 11 | 1.0 |
| wererat-human | ワーラット（人間形態） | M | humanoid | 11 | 1.0 |
| wererat-hybrid | ワーラット（中間形態） | M | humanoid | 11 | 1.0 |
| wererat-rat | ワーラット（鼠形態） | M | humanoid | 11 | 1.0 |
| weretiger-human | ワータイガー（人間形態） | M | humanoid | 11 | 1.0 |
| weretiger-hybrid | ワータイガー（中間形態） | M | humanoid | 11 | 1.0 |
| weretiger-tiger | ワータイガー（虎形態） | M | humanoid | 11 | 1.0 |
| werewolf-human | ワーウルフ（人間形態） | M | humanoid | 11 | 1.0 |
| werewolf-hybrid | ワーウルフ（中間形態） | M | humanoid | 11 | 1.0 |
| werewolf-wolf | ワーウルフ（狼形態） | M | humanoid | 11 | 1.0 |
| androsphinx | アンドロスフィンクス | L | monstrosity | 16 | 1.8 |
| ankheg | アンケグ | L | monstrosity | 16 | 1.8 |
| basilisk | バジリスク | M | monstrosity | 11 | 1.0 |
| behir | ベヒル | H | monstrosity | 22 | 2.8 |
| bulette | ブレイ | L | monstrosity | 16 | 1.8 |
| centaur | ケンタウロス | L | monstrosity | 16 | 1.8 |
| chimera | キマイラ | L | monstrosity | 16 | 1.8 |
| cockatrice | コカトリス | S | monstrosity | 9 | 0.7 |
| darkmantle | ダークマントル | S | monstrosity | 9 | 0.7 |
| death-dog | デス・ドッグ | M | monstrosity | 11 | 1.0 |
| doppelganger | ドッペルゲンガー | M | monstrosity | 11 | 1.0 |
| drider | ドライダー | L | monstrosity | 16 | 1.8 |
| ettercap | エターキャップ | M | monstrosity | 11 | 1.0 |
| gorgon | ゴルゴン | L | monstrosity | 16 | 1.8 |
| grick | グリック | M | monstrosity | 11 | 1.0 |
| griffon | グリフォン | L | monstrosity | 16 | 1.8 |
| guardian-naga | ガーディアン・ナーガ | L | monstrosity | 16 | 1.8 |
| gynosphinx | ガイノスフィンクス | L | monstrosity | 16 | 1.8 |
| harpy | ハーピー | M | monstrosity | 11 | 1.0 |
| hippogriff | ヒポグリフ | L | monstrosity | 16 | 1.8 |
| hydra | ヒドラ | H | monstrosity | 22 | 2.8 |
| kraken | クラーケン | G | monstrosity | 30 | 4.0 |
| lamia | ラミア | L | monstrosity | 16 | 1.8 |
| manticore | マンティコア | L | monstrosity | 16 | 1.8 |
| medusa | メドゥーサ | M | monstrosity | 11 | 1.0 |
| merrow | メロウ | L | monstrosity | 16 | 1.8 |
| mimic | ミミック | M | monstrosity | 11 | 1.0 |
| minotaur | ミノタウロス | L | monstrosity | 16 | 1.8 |
| owlbear | アウルベア | L | monstrosity | 16 | 1.8 |
| phase-spider | フェイズ・スパイダー | L | monstrosity | 16 | 1.8 |
| purple-worm | パープル・ワーム | G | monstrosity | 30 | 4.0 |
| remorhaz | レモラズ | H | monstrosity | 22 | 2.8 |
| roc | ロック鳥 | G | monstrosity | 30 | 4.0 |
| roper | ローパー | L | monstrosity | 16 | 1.8 |
| rust-monster | ラスト・モンスター | M | monstrosity | 11 | 1.0 |
| spirit-naga | スピリット・ナーガ | L | monstrosity | 16 | 1.8 |
| tarrasque | タラスク | G | monstrosity | 30 | 4.0 |
| winter-wolf | ウィンター・ウルフ | L | monstrosity | 16 | 1.8 |
| worg | ウォーグ | L | monstrosity | 16 | 1.8 |
| black-pudding | ブラック・プディング | L | ooze | 16 | 1.8 |
| gelatinous-cube | ゼラチナス・キューブ | L | ooze | 16 | 1.8 |
| gray-ooze | グレイ・ウーズ | M | ooze | 11 | 1.0 |
| ochre-jelly | オーカー・ジェリー | L | ooze | 16 | 1.8 |
| awakened-shrub | 目覚めた低木 | S | plant | 9 | 0.7 |
| awakened-tree | 目覚めた樹木 | H | plant | 22 | 2.8 |
| shambling-mound | シャンブリング・マウンド | L | plant | 16 | 1.8 |
| shrieker | シュリーカー（叫び茸） | M | plant | 11 | 1.0 |
| treant | トレント | H | plant | 22 | 2.8 |
| violet-fungus | ヴァイオレット・ファンガス | M | plant | 11 | 1.0 |
| swarm-of-bats | コウモリの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-beetles | 甲虫の群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-centipedes | ムカデの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-insects | 虫の群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-poisonous-snakes | 毒ヘビの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-quippers | クィッパーの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-rats | ネズミの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-ravens | ワタリガラスの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-spiders | クモの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| swarm-of-wasps | スズメバチの群れ | M | swarm of tiny beasts | 11 | 1.0 |
| ghast | ガスト | M | undead | 11 | 1.0 |
| ghost | ゴースト | M | undead | 11 | 1.0 |
| ghoul | グール | M | undead | 11 | 1.0 |
| lich | リッチ | M | undead | 11 | 1.0 |
| minotaur-skeleton | ミノタウロス・スケルトン | L | undead | 16 | 1.8 |
| mummy | ミイラ | M | undead | 11 | 1.0 |
| mummy-lord | ミイラの王 | M | undead | 11 | 1.0 |
| ogre-zombie | オーガ・ゾンビ | L | undead | 16 | 1.8 |
| shadow | シャドウ | M | undead | 11 | 1.0 |
| skeleton | スケルトン | M | undead | 11 | 1.0 |
| specter | スペクター | M | undead | 11 | 1.0 |
| vampire-bat | ヴァンパイア（蝙蝠形態） | M | undead | 11 | 1.0 |
| vampire-mist | ヴァンパイア（霧形態） | M | undead | 11 | 1.0 |
| vampire-spawn | ヴァンパイア・スポーン | M | undead | 11 | 1.0 |
| vampire-vampire | ヴァンパイア | M | undead | 11 | 1.0 |
| warhorse-skeleton | 軍馬のスケルトン | L | undead | 16 | 1.8 |
| wight | ワイト | M | undead | 11 | 1.0 |
| will-o-wisp | ウィル・オ・ウィスプ | T | undead | 7 | 0.4 |
| wraith | レイス | M | undead | 11 | 1.0 |
| zombie | ゾンビ | M | undead | 11 | 1.0 |
