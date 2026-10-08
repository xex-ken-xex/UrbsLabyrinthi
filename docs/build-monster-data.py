#!/usr/bin/env python3
"""SRD の魔物データを、Urbs Labyrinthi が持つ軽量 JSON に変換する。

元データ: https://github.com/5e-bits/5e-database （コードは MIT、中身は SRD。CC-BY-4.0 で使う）
  src/2014/en/5e-SRD-Monsters.json  … SRD 5.1（334体）
  src/2024/en/5e-SRD-Monsters.json  … SRD 5.2 系（341体）

使い方:
  git clone --depth 1 https://github.com/5e-bits/5e-database.git
  python3 build-monster-data.py 5e-database 出力フォルダ
→ 出力フォルダに monsters-2014.json と monsters-2024.json ができる（各 約125KB）。

日本語名（JP ほか）は、この企画のための仮訳。公式の訳語ではない。
名前の表に無い魔物が元データに増えると KeyError で止まるので、表に足す。
"""
import json,re,sys,os
ROOT=sys.argv[1] if len(sys.argv)>1 else "5e-database"
OUT=(sys.argv[2] if len(sys.argv)>2 else ".").rstrip("/")+"/"
SRC=os.path.join(ROOT,"src","%s","en","5e-SRD-Monsters.json")
JP={
"Aboleth":"アボレス","Acolyte":"侍祭","Air Elemental":"エア・エレメンタル","Allosaurus":"アロサウルス","Androsphinx":"アンドロスフィンクス","Animated Armor":"動く鎧","Animated Flying Sword":"飛ぶ剣","Animated Rug of Smothering":"窒息の絨毯","Ankheg":"アンケグ","Ankylosaurus":"アンキロサウルス","Ape":"類人猿","Archelon":"アーケロン","Archmage":"大魔道士","Assassin":"暗殺者","Awakened Shrub":"目覚めた低木","Awakened Tree":"目覚めた樹木","Axe Beak":"アックス・ビーク","Azer":"アザー","Azer Sentinel":"アザーの歩哨","Baboon":"ヒヒ","Badger":"アナグマ","Balor":"バロール","Bandit":"山賊","Bandit Captain":"山賊の頭","Barbed Devil":"バーブド・デヴィル","Basilisk":"バジリスク","Bat":"コウモリ","Bearded Devil":"ビアデッド・デヴィル","Behir":"ベヒル","Berserker":"狂戦士","Black Bear":"クロクマ","Black Pudding":"ブラック・プディング","Blink Dog":"ブリンク・ドッグ","Blood Hawk":"ブラッド・ホーク","Boar":"イノシシ","Bone Devil":"ボーン・デヴィル","Brown Bear":"ヒグマ","Bugbear":"バグベア","Bugbear Stalker":"バグベアの追跡者","Bugbear Warrior":"バグベアの戦士","Bulette":"ブレイ","Camel":"ラクダ","Cat":"ネコ","Centaur":"ケンタウロス","Centaur Trooper":"ケンタウロスの騎兵","Chain Devil":"チェイン・デヴィル","Chimera":"キマイラ","Chuul":"チュール","Clay Golem":"クレイ・ゴーレム","Cloaker":"クローカー","Cloud Giant":"クラウド・ジャイアント","Cockatrice":"コカトリス","Commoner":"平民","Constrictor Snake":"締めつけヘビ","Couatl":"コアトル","Crab":"カニ","Crocodile":"ワニ","Cult Fanatic":"狂信者","Cultist":"教団員","Cultist Fanatic":"狂信者","Darkmantle":"ダークマントル","Death Dog":"デス・ドッグ","Deep Gnome (Svirfneblin)":"ディープ・ノーム","Deer":"シカ","Deva":"デーヴァ","Dire Wolf":"ダイア・ウルフ","Djinni":"ジン","Doppelganger":"ドッペルゲンガー","Draft Horse":"荷馬","Dragon Turtle":"ドラゴン・タートル","Dretch":"ドレッチ","Drider":"ドライダー","Drow":"ドラウ","Druid":"ドルイド","Dryad":"ドライアド","Duergar":"ドゥエルガル","Dust Mephit":"ダスト・メフィット","Eagle":"ワシ","Earth Elemental":"アース・エレメンタル","Efreeti":"イフリート","Elephant":"ゾウ","Elk":"ヘラジカ","Erinyes":"エリニュス","Ettercap":"エターキャップ","Ettin":"エティン","Fire Elemental":"ファイアー・エレメンタル","Fire Giant":"ファイアー・ジャイアント","Flesh Golem":"フレッシュ・ゴーレム","Flying Snake":"空飛ぶヘビ","Flying Sword":"飛ぶ剣","Frog":"カエル","Frost Giant":"フロスト・ジャイアント","Gargoyle":"ガーゴイル","Gelatinous Cube":"ゼラチナス・キューブ","Ghast":"ガスト","Ghost":"ゴースト","Ghoul":"グール","Giant Ape":"巨大類人猿","Giant Badger":"巨大アナグマ","Giant Bat":"巨大コウモリ","Giant Boar":"巨大イノシシ","Giant Centipede":"巨大ムカデ","Giant Constrictor Snake":"巨大締めつけヘビ","Giant Crab":"巨大ガニ","Giant Crocodile":"巨大ワニ","Giant Eagle":"巨大ワシ","Giant Elk":"巨大ヘラジカ","Giant Fire Beetle":"巨大火甲虫","Giant Frog":"巨大ガエル","Giant Goat":"巨大ヤギ","Giant Hyena":"巨大ハイエナ","Giant Lizard":"巨大トカゲ","Giant Octopus":"巨大ダコ","Giant Owl":"巨大フクロウ","Giant Poisonous Snake":"巨大毒ヘビ","Giant Venomous Snake":"巨大毒ヘビ","Giant Rat":"巨大ネズミ","Giant Rat (Diseased)":"巨大ネズミ（病持ち）","Giant Scorpion":"巨大サソリ","Giant Sea Horse":"巨大タツノオトシゴ","Giant Seahorse":"巨大タツノオトシゴ","Giant Shark":"巨大ザメ","Giant Spider":"巨大グモ","Giant Toad":"巨大ヒキガエル","Giant Vulture":"巨大ハゲワシ","Giant Wasp":"巨大スズメバチ","Giant Weasel":"巨大イタチ","Giant Wolf Spider":"巨大コモリグモ","Gibbering Mouther":"ジバリング・マウザー","Glabrezu":"グラブレズゥ","Gladiator":"剣闘士","Gnoll":"ノール","Gnoll Warrior":"ノールの戦士","Goat":"ヤギ","Goblin":"ゴブリン","Goblin Boss":"ゴブリンの親分","Goblin Minion":"ゴブリンの手下","Goblin Warrior":"ゴブリンの戦士","Gorgon":"ゴルゴン","Gray Ooze":"グレイ・ウーズ","Green Hag":"グリーン・ハグ","Grick":"グリック","Griffon":"グリフォン","Grimlock":"グリムロック","Guard":"衛兵","Guard Captain":"衛兵隊長","Guardian Naga":"ガーディアン・ナーガ","Gynosphinx":"ガイノスフィンクス","Half-Dragon":"ハーフドラゴン","Half-Red Dragon Veteran":"ハーフ・レッド・ドラゴンの古強者","Harpy":"ハーピー","Hawk":"タカ","Hell Hound":"ヘル・ハウンド","Hezrou":"ヘズロウ","Hill Giant":"ヒル・ジャイアント","Hippogriff":"ヒポグリフ","Hippopotamus":"カバ","Hobgoblin":"ホブゴブリン","Hobgoblin Captain":"ホブゴブリンの隊長","Hobgoblin Warrior":"ホブゴブリンの戦士","Homunculus":"ホムンクルス","Horned Devil":"ホーンド・デヴィル","Hunter Shark":"ハンター・シャーク","Hydra":"ヒドラ","Hyena":"ハイエナ","Ice Devil":"アイス・デヴィル","Ice Mephit":"アイス・メフィット","Imp":"インプ","Incubus":"インキュバス","Invisible Stalker":"インヴィジブル・ストーカー","Iron Golem":"アイアン・ゴーレム","Jackal":"ジャッカル","Killer Whale":"シャチ","Knight":"騎士","Kobold":"コボルド","Kobold Warrior":"コボルドの戦士","Kraken":"クラーケン","Lamia":"ラミア","Lemure":"レムレー","Lich":"リッチ","Lion":"ライオン","Lizard":"トカゲ","Lizardfolk":"リザードフォーク","Mage":"魔道士","Magma Mephit":"マグマ・メフィット","Magmin":"マグミン","Mammoth":"マンモス","Manticore":"マンティコア","Marilith":"マリリス","Mastiff":"マスティフ犬","Medusa":"メドゥーサ","Merfolk":"マーフォーク","Merfolk Skirmisher":"マーフォークの散兵","Merrow":"メロウ","Mimic":"ミミック","Minotaur":"ミノタウロス","Minotaur Skeleton":"ミノタウロス・スケルトン","Minotaur of Baphomet":"ミノタウロス","Mule":"ラバ","Mummy":"ミイラ","Mummy Lord":"ミイラの王","Nalfeshnee":"ナルフェシュネー","Night Hag":"ナイト・ハグ","Nightmare":"ナイトメア","Noble":"貴族","Ochre Jelly":"オーカー・ジェリー","Octopus":"タコ","Ogre":"オーガ","Ogre Zombie":"オーガ・ゾンビ","Oni":"オニ","Orc":"オーク","Otyugh":"オティアグ","Owl":"フクロウ","Owlbear":"アウルベア","Panther":"ヒョウ","Pegasus":"ペガサス","Phase Spider":"フェイズ・スパイダー","Piranha":"ピラニア","Pirate":"海賊","Pirate Captain":"海賊船長","Pit Fiend":"ピット・フィーンド","Planetar":"プラネター","Plesiosaurus":"プレシオサウルス","Poisonous Snake":"毒ヘビ","Polar Bear":"ホッキョクグマ","Pony":"ポニー","Priest":"司祭","Priest Acolyte":"侍祭","Pseudodragon":"スードゥドラゴン","Pteranodon":"プテラノドン","Purple Worm":"パープル・ワーム","Quasit":"クアジット","Quipper":"クィッパー","Rakshasa":"ラークシャサ","Rat":"ネズミ","Raven":"ワタリガラス","Reef Shark":"リーフ・シャーク","Remorhaz":"レモラズ","Rhinoceros":"サイ","Riding Horse":"乗用馬","Roc":"ロック鳥","Roper":"ローパー","Rug of Smothering":"窒息の絨毯","Rust Monster":"ラスト・モンスター","Saber-Toothed Tiger":"剣歯虎","Sahuagin":"サフアグン","Sahuagin Warrior":"サフアグンの戦士","Salamander":"サラマンダー","Satyr":"サテュロス","Scorpion":"サソリ","Scout":"斥候","Sea Hag":"シー・ハグ","Sea Horse":"タツノオトシゴ","Seahorse":"タツノオトシゴ","Shadow":"シャドウ","Shambling Mound":"シャンブリング・マウンド","Shield Guardian":"シールド・ガーディアン","Shrieker":"シュリーカー（叫び茸）","Shrieker Fungus":"シュリーカー（叫び茸）","Skeleton":"スケルトン","Solar":"ソーラー","Specter":"スペクター","Sphinx of Lore":"知識のスフィンクス","Sphinx of Valor":"武勇のスフィンクス","Sphinx of Wonder":"驚異のスフィンクス","Spider":"クモ","Spirit Naga":"スピリット・ナーガ","Sprite":"スプライト","Spy":"密偵","Steam Mephit":"スチーム・メフィット","Stirge":"スタージ","Stone Giant":"ストーン・ジャイアント","Stone Golem":"ストーン・ゴーレム","Storm Giant":"ストーム・ジャイアント","Succubus":"サキュバス","Succubus/Incubus":"サキュバス／インキュバス","Tarrasque":"タラスク","Thug":"ならず者","Tiger":"トラ","Tough":"ならず者","Tough Boss":"ならず者の頭","Treant":"トレント","Tribal Warrior":"部族の戦士","Triceratops":"トリケラトプス","Troll":"トロル","Troll Limb":"トロルの手足","Tyrannosaurus Rex":"ティラノサウルス","Unicorn":"ユニコーン","Vampire Familiar":"ヴァンパイアの使い魔","Vampire Spawn":"ヴァンパイア・スポーン","Venomous Snake":"毒ヘビ","Veteran":"古強者","Violet Fungus":"ヴァイオレット・ファンガス","Vrock":"ヴロック","Vulture":"ハゲワシ","Warhorse":"軍馬","Warhorse Skeleton":"軍馬のスケルトン","Warrior Infantry":"歩兵","Warrior Veteran":"古強者","Water Elemental":"ウォーター・エレメンタル","Weasel":"イタチ","Wight":"ワイト","Will-o'-Wisp":"ウィル・オ・ウィスプ","Winter Wolf":"ウィンター・ウルフ","Wolf":"オオカミ","Worg":"ウォーグ","Wraith":"レイス","Wyvern":"ワイバーン","Xorn":"ゾーン","Zombie":"ゾンビ",
"Vampire, Vampire Form":"ヴァンパイア","Vampire, Bat Form":"ヴァンパイア（蝙蝠形態）","Vampire, Mist Form":"ヴァンパイア（霧形態）",
}
SW={"Bats":"コウモリ","Beetles":"甲虫","Centipedes":"ムカデ","Crawling Claws":"這う手","Insects":"虫","Piranhas":"ピラニア","Poisonous Snakes":"毒ヘビ","Venomous Snakes":"毒ヘビ","Quippers":"クィッパー","Rats":"ネズミ","Ravens":"ワタリガラス","Spiders":"クモ","Wasps":"スズメバチ"}
COL={"Black":"ブラック","Blue":"ブルー","Brass":"ブラス","Bronze":"ブロンズ","Copper":"カッパー","Gold":"ゴールド","Green":"グリーン","Red":"レッド","Silver":"シルヴァー","White":"ホワイト"}
AGE={"Adult":"アダルト","Ancient":"エインシェント","Young":"ヤング"}
LYC={"Werebear":"ワーベア","Wereboar":"ワーボア","Wererat":"ワーラット","Weretiger":"ワータイガー","Werewolf":"ワーウルフ"}
FORM={"Human Form":"人間形態","Hybrid Form":"中間形態","Bear Form":"熊形態","Boar Form":"猪形態","Rat Form":"鼠形態","Tiger Form":"虎形態","Wolf Form":"狼形態"}
def jp(n):
    n=n.replace("’","'")
    if n in JP: return JP[n]
    m=re.match(r"Swarm of (.+)$",n)
    if m: return SW[m.group(1)]+"の群れ"
    m=re.match(r"(Adult|Ancient|Young) (\w+) Dragon$",n)
    if m: return AGE[m.group(1)]+"・"+COL[m.group(2)]+"・ドラゴン"
    m=re.match(r"(\w+) Dragon Wyrmling$",n)
    if m: return COL[m.group(1)]+"・ドラゴン・ワームリング"
    m=re.match(r"(Were\w+), (.+)$",n)
    if m: return LYC[m.group(1)]+"（"+FORM[m.group(2)]+"）"
    raise KeyError(n)
def ft(s):
    m=re.search(r"(\d+)",str(s)); return int(m.group(1)) if m else 0
def names(lst):
    out=[]
    for x in lst or []:
        if isinstance(x,str): out.append(x)
        elif isinstance(x,dict): out.append(x.get("name") or x.get("index") or "")
    return [o for o in out if o]
def compact(m):
    ac=m.get("armor_class"); ac=ac[0]["value"] if isinstance(ac,list) and ac else (ac or 10)
    sp={k:ft(v) for k,v in (m.get("speed") or {}).items() if k in("walk","swim","fly","climb","burrow") and ft(v)>0}
    sn=m.get("senses") or {}
    at=[]
    for a in m.get("actions") or []:
        if a.get("name")=="Multiattack":
            continue
        dmg=[]
        for d in a.get("damage") or []:
            if isinstance(d,dict) and d.get("damage_dice"):
                dmg.append(d["damage_dice"]+" "+((d.get("damage_type") or {}).get("name","")).lower())
        dc=a.get("dc")
        dcs=""
        if isinstance(dc,dict) and dc.get("dc_value"):
            dcs="DC%d %s"%(dc["dc_value"],(dc.get("dc_type") or {}).get("name",""))
        if "attack_bonus" in a or dmg or dcs:
            e={"n":a["name"]}
            if a.get("attack_bonus") is not None: e["b"]=a["attack_bonus"]
            if dmg: e["d"]=" + ".join(dmg[:2])
            if dcs: e["s"]=dcs
            at.append(e)
    multi=next((a.get("desc","") for a in m.get("actions") or [] if a.get("name")=="Multiattack"),"")
    o={"i":m["index"],"n":m["name"].replace("’","'"),"j":jp(m["name"]),"z":m["size"][0],"t":m["type"].lower().split(" (")[0],
       "cr":m["challenge_rating"],"xp":m.get("xp",0),"ac":ac,"hp":m["hit_points"],"hd":m.get("hit_points_roll") or m.get("hit_dice"),
       "sp":sp,"ab":[m[k] for k in("strength","dexterity","constitution","intelligence","wisdom","charisma")],
       "pp":sn.get("passive_perception",10)}
    if m["size"]=="Gargantuan": o["z"]="G"
    for k,key in (("dv","darkvision"),("bs","blindsight"),("tv","tremorsense"),("ts","truesight")):
        if sn.get(key): o[k]=ft(sn[key])
    if at: o["at"]=at[:4]
    if multi: o["mu"]=1
    tr=[t["name"] for t in (m.get("special_abilities") or []) if t.get("name")]
    if tr: o["tr"]=tr[:5]
    for k,key in (("im","damage_immunities"),("re","damage_resistances"),("vu","damage_vulnerabilities")):
        v=names(m.get(key))
        if v: o[k]=v
    ci=names(m.get("condition_immunities"))
    if ci: o["ci"]=ci
    if m.get("legendary_actions"): o["lg"]=1
    lang=m.get("languages") or ""
    if lang and lang not in("--","—","None"): o["la"]=lang[:60]
    return o
tot={}
for ed in("2014","2024"):
    d=json.load(open(SRC%ed,encoding="utf-8"))
    out=[compact(m) for m in d]
    out.sort(key=lambda x:(x["cr"],x["n"]))
    s=json.dumps(out,ensure_ascii=False,separators=(",",":"))
    open(OUT+"monsters-%s.json"%ed,"w",encoding="utf-8").write(s)
    tot[ed]=(len(out),len(s.encode()))
    bad=[o["n"] for o in out if not o.get("at")]
    print(ed,tot[ed],"no-attack:",len(bad),bad[:12])
