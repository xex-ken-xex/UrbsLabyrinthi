class_name ItemDB
extends RefCounted
## 道具の定義と店の品ぞろえ。値段は銀貨(燐晶の精錬品が 1kg=80銀貨、冒険者の年収が約2,830銀貨という設計値に合わせた)。

const SELL_RATE := 0.4

## kind: consumable / weapon / armor / acc / tome
## weapon: cat(sword dagger blunt axe spear staff bow), power(体当たりの加算), spell(技の威力の加算)
## armor: type(none light medium heavy), ac(防御の加算。軽減率は1点につき3.5%)
## acc: 効果の辞書(ac, power_pct, hp_pct, mp_pct, speed_pct, mass_pct)
const BASE_ITEMS := {
	# --- 消耗品 ---
	"potion": {"name": "治療薬", "kind": "consumable", "price": 60, "use": "heal_pct", "v": 0.5,
		"desc": "HPを最大の50%回復する(最低12)。薬師組の標準品。"},
	"hi_potion": {"name": "上級治療薬", "kind": "consumable", "price": 200, "use": "heal_pct", "v": 1.0,
		"desc": "HPを全快させる。"},
	"ether": {"name": "魔力水", "kind": "consumable", "price": 80, "use": "mp_pct", "v": 0.5,
		"desc": "MPを最大の50%回復する。"},
	"revive_charm": {"name": "蘇生の護符", "kind": "consumable", "price": 400, "use": "revive", "v": 0.4,
		"desc": "倒れた仲間を、HP40%で立ち上がらせる。"},
	"lamp_oil": {"name": "燐晶の灯油", "kind": "consumable", "price": 40, "use": "light", "v": 2.0,
		"desc": "180秒間、灯りの届く半径が2マス広がる。"},
	"corpse_cart": {"name": "遺体カート", "kind": "material", "price": 250, "kg": 2.0,
		"desc": "灯手隊のお下がりの大八車。持っていると、倒れた仲間を背負わずに載せて引ける(足も攻撃も落ちない)。空なら畳んで2kg。調べる(E)で載せ、もう一度で下ろす。一台で足りる。"},
	"return_scroll": {"name": "帰還の札", "kind": "consumable", "price": 150, "use": "return", "v": 0.0,
		"desc": "迷宮の中から、荷物を持ったまま地上へ戻る。"},
	# --- 魔法実験で作る薬(店には無い。data/alchemy.json) ---
	"antidote": {"name": "毒消し", "kind": "consumable", "price": 50, "use": "cure", "v": 0.0, "brewed": true,
		"desc": "毒を消す。薬師組の処方を、自分の手で写したもの。"},
	"sleep_bottle": {"name": "眠り薬の瓶", "kind": "consumable", "price": 70, "use": "sleep_throw", "v": 6.0, "brewed": true,
		"desc": "足もとに叩きつけると、眠りの胞子が広がる。まわり4マスの魔物が、6秒ほど動けなくなる。"},
	"shriek_bottle": {"name": "叫び瓶", "kind": "consumable", "price": 60, "use": "shriek", "v": 3.0, "brewed": true,
		"desc": "割ると、叫び茸の甲高い声が響く。まわり5マスの魔物がすくむ(3秒)。ただし、遠くの魔物も目を覚ます。"},
	"power_draught": {"name": "力の水薬", "kind": "consumable", "price": 120, "use": "buff", "buff": "power", "v": 1.25, "t": 90.0, "brewed": true,
		"desc": "90秒間、体当たりと武器の威力が 25% 上がる。坑道韮の辛さが、喉を焼く。"},
	"stone_draught": {"name": "石肌の水薬", "kind": "consumable", "price": 120, "use": "buff", "buff": "guard", "v": 0.75, "t": 90.0, "brewed": true,
		"desc": "90秒間、受けるダメージが 25% 減る。肌が、少し灰色になる。"},
	"wind_draught": {"name": "疾風の水薬", "kind": "consumable", "price": 120, "use": "buff", "buff": "speed", "v": 1.25, "t": 60.0, "brewed": true,
		"desc": "60秒間、足が 25% 速くなる。"},
	"hi_ether": {"name": "上級魔力水", "kind": "consumable", "price": 240, "use": "mp_pct", "v": 1.0, "brewed": true,
		"desc": "MPを全快させる。"},
	"regen_elixir": {"name": "再生の霊薬", "kind": "consumable", "price": 300, "use": "buff", "buff": "regen", "v": 1.0, "t": 60.0, "brewed": true,
		"desc": "60秒かけて、最大HPぶんがじわじわ戻る。"},
	"marrow_elixir": {"name": "髄蜜の霊薬", "kind": "consumable", "price": 500, "use": "elixir", "v": 1.0, "brewed": true,
		"desc": "HPとMPが全快する。骨の髄の蜜と、名なしの実を五夜寝かせたもの。"},
	"murky": {"name": "濁った薬", "kind": "material", "price": 2, "brewed": true,
		"desc": "実験に失敗した、何の役にも立たない液体。"},
	# --- 鍛冶の材料(炉火の槌で売る。data/smithing.json) ---
	"tetsukai": {"name": "鉄塊", "kind": "material", "price": 60,
		"desc": "鍛冶組が溶かして固めた、鍛冶の材料。鉄屑3つを鍛冶場で溶かしても作れる。"},
	"sumi": {"name": "炭", "kind": "material", "price": 8,
		"desc": "炉の燃料。焚き木より熱い。鍛冶場で1回に1つ使う。"},
	"yumizai": {"name": "弓材", "kind": "material", "price": 40,
		"desc": "乾かして削り出した、弓や盾の木地。壁の外の林から運ばれてくる。"},
	# --- 武器 ---
	"dagger": {"name": "短剣", "kind": "weapon", "cat": "dagger", "power": 1.0, "price": 50, "desc": "軽い。盗賊と魔術師も使える。"},
	"shortsword": {"name": "片手剣", "kind": "weapon", "cat": "sword", "power": 2.0, "price": 120, "desc": "扱いやすい剣。"},
	"longsword": {"name": "長剣", "kind": "weapon", "cat": "sword", "power": 3.0, "price": 220, "desc": "鍛冶組の定番。"},
	"greatsword": {"name": "両手剣", "kind": "weapon", "cat": "sword", "power": 4.5, "price": 380, "desc": "重い一撃で押し込む。"},
	"mace": {"name": "メイス", "kind": "weapon", "cat": "blunt", "power": 2.0, "price": 100, "desc": "僧侶の標準の武器。"},
	"warhammer": {"name": "戦鎚", "kind": "weapon", "cat": "blunt", "power": 3.5, "price": 260, "desc": "炉火の神の槌に倣った打撃武器。"},
	"handaxe": {"name": "手斧", "kind": "weapon", "cat": "axe", "power": 2.0, "price": 100, "desc": "投げても使える斧。"},
	"greataxe": {"name": "大斧", "kind": "weapon", "cat": "axe", "power": 5.0, "price": 420, "desc": "蛮族が好む重い斧。"},
	"spear": {"name": "槍", "kind": "weapon", "cat": "spear", "power": 2.5, "price": 140, "desc": "突き押す。"},
	"quarterstaff": {"name": "杖", "kind": "weapon", "cat": "staff", "power": 1.0, "price": 30, "desc": "ただの木の杖。"},
	"crystal_staff": {"name": "魔晶の杖", "kind": "weapon", "magic": true, "cat": "staff", "power": 1.5, "spell": 2.0, "price": 300, "desc": "燐晶を嵌めた杖。呪文の威力+2。"},
	"shortbow": {"name": "短弓", "kind": "weapon", "cat": "bow", "power": 1.5, "spell": 1.0, "price": 150, "desc": "軽い弓。矢の威力+1。"},
	# 珍しい武器(店に無い。遺体から、まれに出る)。tech で固有の技
	"shadow_dagger": {"name": "影縫いの短剣", "kind": "weapon", "cat": "dagger", "power": 2.0, "price": 600, "rare": true, "tech": "w_shadow",
		"desc": "刃が光を吸う短剣。持ち主の影は、いつも少し遅れてついてくる。技「影縫い」。"},
	"miner_pick": {"name": "坑夫の大鶴嘴", "kind": "weapon", "cat": "axe", "power": 5.5, "price": 650, "rare": true, "tech": "w_rend",
		"desc": "錆鉄の坑道で使われていた、両手の鶴嘴。技「大地割り」。"},
	"comet_spear": {"name": "流星の槍", "kind": "weapon", "cat": "spear", "power": 3.5, "price": 700, "rare": true, "tech": "w_comet",
		"desc": "穂先に燐晶の欠片が嵌まった槍。投げても手元へ戻る。技「流星投げ」。"},
	"longbow": {"name": "長弓", "kind": "weapon", "cat": "bow", "power": 3.0, "spell": 2.5, "price": 380, "desc": "長い弓。矢の威力+2.5。"},
	# --- 防具 ---
	"robe": {"name": "ローブ", "kind": "armor", "type": "none", "ac": 1, "price": 30, "desc": "ただの布。"},
	"leather": {"name": "革鎧", "kind": "armor", "type": "light", "ac": 2, "price": 80, "desc": "なめした革の鎧。"},
	"studded": {"name": "鋲革鎧", "kind": "armor", "type": "light", "ac": 3, "price": 160, "desc": "鋲を打った革鎧。"},
	"chain_shirt": {"name": "鎖の胴着", "kind": "armor", "type": "medium", "ac": 4, "price": 260, "desc": "鎖を編んだ胴着。"},
	"breastplate": {"name": "胸甲", "kind": "armor", "type": "medium", "ac": 5, "price": 420, "desc": "胴を守る金属の板。"},
	"chain_mail": {"name": "鎖帷子", "kind": "armor", "type": "heavy", "ac": 7, "price": 520, "desc": "全身を覆う鎖。重く、動きが鈍る。"},
	"plate": {"name": "板金鎧", "kind": "armor", "type": "heavy", "ac": 9, "price": 1200, "desc": "鍛冶組の最高級。とても重い。"},
	# --- 装飾品 ---
	"buckler": {"name": "小盾", "kind": "acc", "price": 90, "fx": {"ac": 1, "mass_pct": 0.1}, "desc": "防御+1。押されにくくなる。"},
	"power_band": {"name": "剛力の腕輪", "kind": "acc", "price": 450, "fx": {"power_pct": 0.18}, "desc": "体当たりの威力+18%。"},
	"vital_ring": {"name": "活力の指輪", "kind": "acc", "price": 400, "fx": {"hp_pct": 0.15}, "desc": "最大HP+15%。"},
	"mana_ring": {"name": "魔力の指輪", "kind": "acc", "price": 400, "fx": {"mp_pct": 0.25}, "desc": "最大MP+25%。"},
	"swift_boots": {"name": "俊足の長靴", "kind": "acc", "price": 350, "fx": {"speed_pct": 0.07}, "desc": "足が速くなる。"},
	"lamp_charm": {"name": "灯守の護符", "kind": "acc", "price": 300, "fx": {"light": 1}, "desc": "灯りの半径+1マス(仲間のうち最大)。"},
	# --- 呪文書 ---
	"tome_mana_shield": {"name": "呪文書「魔法の盾」", "kind": "tome", "teaches": "mana_shield", "classes": ["wizard", "cleric"], "price": 500,
		"desc": "8秒間、受けるダメージが半分になる。"},
	"tome_sleep": {"name": "呪文書「眠りの雲」", "kind": "tome", "teaches": "sleep", "classes": ["wizard", "cleric", "ranger"], "price": 600,
		"desc": "前方の敵を眠らせて動けなくする。"},
	"tome_regen": {"name": "呪文書「再生の光」", "kind": "tome", "teaches": "regen_light", "classes": ["cleric", "ranger"], "price": 700,
		"desc": "仲間全員のHPがじわじわ回復する。"},
	"tome_flash": {"name": "呪文書「閃光」", "kind": "tome", "teaches": "flash", "classes": ["wizard", "rogue", "cleric"], "price": 550,
		"desc": "周囲の敵を怯ませて止める。"},
}


## 魔法の品(SRD 5.1 の魔法の品を下敷きにした。ken 10/18「魔法武器防具アイテムを増やす」)。店にはほとんど無く、
## 遺体や宝の山からまれに、層の主からは必ず一つ出る。mlayer はその品が出はじめる層。magic は「魔法でない武器」への耐性を抜ける。
## weapon: elem(傷の種類が火・冷気・光になる。火と光は再生を止める)、slay(魔物の種別ごとの倍率)、drain(与えた傷の割合だけ癒える)、
##   venom(当てると毒にする確率)
## 全部の装備: resist(その種類の傷を半分にする)、fx(装飾品と同じ効き目。regen は毎秒、最大HPの割合が戻る。feather は落ちても傷を負わない。
##   poison_immune は毒が効かない)。armor: no_slow(重装でも足が遅くならない)
const MAGIC_ITEMS := {
	# --- 魔法の武器 ---
	"magic_longbow": {"name": "魔力の長弓", "kind": "weapon", "magic": true, "mlayer": 1, "cat": "bow", "power": 3.5, "spell": 3.5, "price": 900,
		"desc": "弦が、引くたびにかすかに鳴る長弓。並の長弓より矢が重い。"},
	"venom_dagger": {"name": "毒蛇の短剣", "kind": "weapon", "magic": true, "mlayer": 2, "cat": "dagger", "power": 1.5, "venom": 0.3, "price": 900,
		"desc": "刃の溝に、いつも黒い滴が溜まっている短剣。当てると、ときどき相手を毒にする。"},
	"mace_disruption": {"name": "破邪の鎚矛", "kind": "weapon", "magic": true, "mlayer": 2, "cat": "blunt", "power": 2.5, "slay": {"undead": 1.6, "fiend": 1.6}, "price": 1200,
		"desc": "神殿の銘が刻まれた鎚矛。亡者と悪魔によく効く。"},
	"flame_tongue": {"name": "炎の舌", "kind": "weapon", "magic": true, "mlayer": 3, "cat": "sword", "power": 3.5, "elem": "fire", "price": 1800,
		"desc": "振るうと刃が炎をまとう長剣。傷は火になり、魔物の再生を止める。"},
	"life_stealer": {"name": "命吸いの剣", "kind": "weapon", "magic": true, "mlayer": 3, "cat": "sword", "power": 2.5, "drain": 0.12, "price": 1500,
		"desc": "柄が、握る手より少しだけ温かい片手剣。与えた傷の一割あまりが、持ち主の傷を塞ぐ。"},
	"frost_brand": {"name": "霜の刃", "kind": "weapon", "magic": true, "mlayer": 5, "cat": "sword", "power": 5.0, "elem": "cold", "resist": ["fire"], "price": 2600,
		"desc": "鞘から抜くと、まわりの空気が白く曇る両手剣。傷は冷気になり、持ち主は火に強くなる。"},
	"dragon_slayer": {"name": "竜殺しの剣", "kind": "weapon", "magic": true, "mlayer": 6, "cat": "sword", "power": 3.5, "slay": {"dragon": 1.8}, "price": 2400,
		"desc": "竜の鱗で研いだという長剣。竜によく効く。"},
	"sun_blade": {"name": "陽光の剣", "kind": "weapon", "magic": true, "mlayer": 6, "cat": "sword", "power": 3.0, "elem": "radiant", "fx": {"light": 2}, "price": 2800,
		"desc": "柄だけに見える剣。握ると、光の刃が伸びる。傷は光になり、魔物の再生を止める。灯りの半径+2マス。"},
	# --- 魔法の防具 ---
	"elven_chain": {"name": "森人の鎖の胴着", "kind": "armor", "magic": true, "mlayer": 3, "type": "light", "ac": 5, "price": 1500,
		"desc": "絹のように軽い鎖の胴着。鎖の胴着より固いのに、軽装として着られる。"},
	"mithral_mail": {"name": "真銀の鎖帷子", "kind": "armor", "magic": true, "mlayer": 3, "type": "heavy", "ac": 7, "no_slow": true, "price": 1800,
		"desc": "真銀を編んだ鎖帷子。重装なのに、足が遅くならない。"},
	"fireproof_plate": {"name": "耐火の胸甲", "kind": "armor", "magic": true, "mlayer": 4, "type": "medium", "ac": 5, "resist": ["fire"], "price": 1600,
		"desc": "赤い琺瑯を焼きつけた胸甲。火の傷が半分になる。"},
	# --- 魔法の装飾品 ---
	"ring_feather": {"name": "羽落ちの指輪", "kind": "acc", "magic": true, "mlayer": 1, "price": 600, "fx": {"feather": 1},
		"desc": "羽の彫られた銀の指輪。縄梯子から手を滑らせても、落とし穴に落ちても、ふわりと降りて傷を負わない。"},
	"ring_protection": {"name": "守りの指輪", "kind": "acc", "magic": true, "mlayer": 2, "price": 1200, "fx": {"ac": 2},
		"desc": "防御+2。小盾より軽い。"},
	"periapt_poison": {"name": "毒除けの護符", "kind": "acc", "magic": true, "mlayer": 2, "price": 900, "fx": {"poison_immune": 1},
		"desc": "銀の鎖に下げた、小さな緑の石。毒が効かなくなる。"},
	"amulet_health": {"name": "健康の首飾り", "kind": "acc", "magic": true, "mlayer": 4, "price": 1600, "fx": {"hp_pct": 0.3},
		"desc": "赤い石の首飾り。最大HP+30%。"},
	"ogre_gauntlets": {"name": "怪力の籠手", "kind": "acc", "magic": true, "mlayer": 4, "price": 1600, "fx": {"power_pct": 0.3},
		"desc": "鬼の力が宿るという鉄の籠手。体当たりと武器の威力+30%。"},
	"boots_speed": {"name": "速さの長靴", "kind": "acc", "magic": true, "mlayer": 5, "price": 1800, "fx": {"speed_pct": 0.15},
		"desc": "踵を打ち合わせると、足が軽くなる長靴。足が15%速くなる。"},
	"ring_regen": {"name": "再生の指輪", "kind": "acc", "magic": true, "mlayer": 5, "price": 2600, "fx": {"regen": 0.005},
		"desc": "緑の石の指輪。迷宮の中でも、傷がじわじわ塞がる(200秒ほどで全快)。"},
	# --- 魔法の消耗品 ---
	"fire_bead": {"name": "火球の珠", "kind": "consumable", "magic": true, "mlayer": 1, "price": 300, "use": "fireball", "v": 8.0,
		"desc": "火球の首飾りから外した珠。前へ投げると弾けて、まわり3マスの魔物を焼く(8d6の火)。"},
	"fire_res_draught": {"name": "耐火の水薬", "kind": "consumable", "magic": true, "mlayer": 1, "price": 200, "use": "buff", "buff": "fire_res", "v": 0.5, "t": 120.0,
		"desc": "120秒間、火の傷が半分になる。舌に、灰の味が残る。"},
}

## 魔力の+1〜+3(SRD の Weapon / Armor, +1〜+3)。炉火の槌の武器と鎧の、魔力を帯びた品。id は "m1_longsword" のように。
## 威力は1につき+1(技の威力のある弓・杖は、そちらも+1)、防御は1につき+1。+1 は第2層、+2 は第4層、+3 は第6層から出る
const PLUS_LAYER := {1: 2, 2: 4, 3: 6}
const PLUS_PRICE := {1: 500, 2: 1500, 3: 4000}
static var PLUS_ITEMS: Dictionary = _plus_items()

static func _plus_items() -> Dictionary:
	var out := {}
	for id in SHOPS["smith"]:
		var b: Dictionary = BASE_ITEMS.get(id, {})
		var k := String(b.get("kind", ""))
		if k != "weapon" and k != "armor":
			continue
		for n in [1, 2, 3]:
			var it: Dictionary = b.duplicate(true)
			it["name"] = "%s+%d" % [b["name"], n]
			it["magic"] = true
			it["plus"] = n
			it["plus_of"] = id
			it["mlayer"] = int(PLUS_LAYER[n])
			it["price"] = int(b["price"]) + int(PLUS_PRICE[n])
			if k == "weapon":
				it["power"] = float(b["power"]) + n
				if b.has("spell"):
					it["spell"] = float(b["spell"]) + n
				it["desc"] = "%s\n魔力を帯びている(威力+%d)。" % [b["desc"], n]
			else:
				it["ac"] = int(b["ac"]) + n
				it["desc"] = "%s\n魔力を帯びている(防御+%d)。" % [b["desc"], n]
			out["m%d_%s" % [n, id]] = it
	return out

## 全品。自生物、魔物の素材、遺品(ForageData、tools/make-items.py が作る)と、市場の食材(Cooking)を足してある。燐晶ではないので、税がかからない
static var ITEMS: Dictionary = _all_items()

## 鍛冶で作れる品(素材からだけ作れる品)と、その良品・逸品も足す(Smithing)
static func _all_items() -> Dictionary:
	var all: Dictionary = BASE_ITEMS.merged(MAGIC_ITEMS).merged(PLUS_ITEMS).merged(ForageData.ITEMS).merged(Cooking.ingredient_items()).merged(Smithing.gear_items())
	return all.merged(Smithing.tier_items(all))

const SHOPS := {
	"smith": ["dagger", "shortsword", "longsword", "greatsword", "mace", "warhammer", "handaxe", "greataxe", "spear", "shortbow", "longbow",
		"leather", "studded", "chain_shirt", "breastplate", "chain_mail", "plate", "buckler", "power_band", "swift_boots",
		"tetsukai", "sumi", "yumizai"],
	"general": ["potion", "hi_potion", "ether", "lamp_oil", "return_scroll", "corpse_cart", "robe", "quarterstaff", "vital_ring", "lamp_charm"],
	"magic": ["ether", "crystal_staff", "mana_ring", "tome_mana_shield", "tome_sleep", "tome_regen", "tome_flash", "fire_bead", "fire_res_draught", "ring_feather"],
	"market": ["haimugi", "suzumame", "chikabu", "makina", "hai_imo", "sunauo", "yagi_raku", "iwadori_tamago", "shirokona",
		"kuromugishu", "jushi", "koushin", "iwa_jio", "takigi"],
}

## 坑口館の遺品課でしか引き取らない遺品(店では売れない)
const GUILD_ONLY := ["relic_tag", "relic_gear"]
const RARE_WEAPONS := ["shadow_dagger", "miner_pick", "comet_spear"]
const WEAPON_CAT_JP := {"sword": "剣", "dagger": "短剣", "blunt": "鈍器", "axe": "斧", "spear": "槍", "staff": "杖", "bow": "弓"}
const ELEM_JP := {"fire": "火", "cold": "冷気", "lightning": "雷", "radiant": "光", "force": "力場", "poison": "毒"}
const MON_TYPE_JP := {"undead": "亡者", "fiend": "悪魔", "dragon": "竜", "giant": "巨人", "beast": "獣"}
const ARMOR_TYPE_JP := {"none": "布", "light": "軽装", "medium": "中装", "heavy": "重装"}

static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func item_name(id: String) -> String:
	return String(ITEMS[id]["name"]) if ITEMS.has(id) else id

static func sell_price(id: String) -> int:
	return int(floor(int(ITEMS[id]["price"]) * SELL_RATE))

static func slot_of(id: String) -> String:
	match String(ITEMS[id]["kind"]):
		"weapon": return "weapon"
		"armor": return "armor"
		"acc": return "acc"
	return ""

## そのクラスが装備できるか
static func can_equip(id: String, cls: String) -> bool:
	var it: Dictionary = ITEMS[id]
	var cd: Dictionary = Jobs.CLASSES[cls]
	match String(it["kind"]):
		"weapon": return (cd["weapons"] as Array).has(String(it["cat"]))
		"armor": return (cd["armor"] as Array).has(String(it["type"]))
		"acc": return true
	return false

## 魔法の品を一つ選ぶ(その層までに出はじめる品から。深い層ほど、深い層の品が出やすい)。kinds が空でなければ、その種類だけ
static func roll_magic(layer: int, rng: RandomNumberGenerator, kinds: Array = []) -> String:
	var pool: Array = []
	var weights: Array = []
	var total := 0.0
	for id in MAGIC_ITEMS:
		var it: Dictionary = MAGIC_ITEMS[id]
		if int(it["mlayer"]) > layer or (not kinds.is_empty() and not kinds.has(String(it["kind"]))):
			continue
		var w := 1.0 + float(int(it["mlayer"])) * 0.5
		pool.append(id)
		weights.append(w)
		total += w
	if pool.is_empty():
		return ""
	var r := rng.randf() * total
	for i in pool.size():
		r -= float(weights[i])
		if r <= 0.0:
			return String(pool[i])
	return String(pool[pool.size() - 1])

static func is_magic(id: String) -> bool:
	return MAGIC_ITEMS.has(id) or PLUS_ITEMS.has(id)

## 魔法の品の格(名前の色。ken 10/18): +1 は薄緑、名のある品と+2 は青、+3 と第6層からの名のある品(本当に強い品)は黄色。ふつうの品は ""
const GRADE_COLOR := {"plus1": Color(0.66, 0.94, 0.62), "magic": Color(0.48, 0.72, 1.0), "legend": Color(1.0, 0.86, 0.36)}
static func grade(id: String) -> String:
	if PLUS_ITEMS.has(id):
		match int(PLUS_ITEMS[id]["plus"]):
			1: return "plus1"
			3: return "legend"
		return "magic"
	if MAGIC_ITEMS.has(id):
		return "legend" if int(MAGIC_ITEMS[id]["mlayer"]) >= 6 else "magic"
	return ""

## 名前の色。魔法の品でなければ fallback
static func name_color(id: String, fallback: Color) -> Color:
	var g := grade(id)
	return GRADE_COLOR[g] if g != "" else fallback

## 魔法の品の落とし物: 半分は名のある品(roll_magic)、半分は魔力の+1〜+3(深い層ほど+の大きい品)。消耗品だけの絞り込みでは、名のある品だけ
static func roll_magic_drop(layer: int, rng: RandomNumberGenerator, kinds: Array = []) -> String:
	if rng.randf() < 0.5 and (kinds.is_empty() or kinds.has("weapon") or kinds.has("armor")):
		var pool: Array = []
		for id in PLUS_ITEMS:
			var it: Dictionary = PLUS_ITEMS[id]
			if int(it["mlayer"]) <= layer and (kinds.is_empty() or kinds.has(String(it["kind"]))):
				pool.append(id)
		if not pool.is_empty():
			# いちばん大きい+を出やすく
			var top := 0
			for id in pool:
				top = maxi(top, int(PLUS_ITEMS[id]["plus"]))
			var want := top if rng.randf() < 0.6 else rng.randi_range(1, top)
			var hit: Array = pool.filter(func(x): return int(PLUS_ITEMS[x]["plus"]) == want)
			if not hit.is_empty():
				return String(hit[rng.randi_range(0, hit.size() - 1)])
	return roll_magic(layer, rng, kinds)

## 深い層ほど、良い装備が出る
static func roll_gear(floor_no: int, rng: RandomNumberGenerator) -> String:
	var cap := 120 + floor_no * 130
	var pool: Array = []
	for id in BASE_ITEMS:
		var it: Dictionary = BASE_ITEMS[id]
		var k := String(it["kind"])
		if (k == "weapon" or k == "armor" or k == "acc") and int(it["price"]) <= cap and not it.get("rare", false):
			pool.append(id)
	return "" if pool.is_empty() else String(pool[rng.randi_range(0, pool.size() - 1)])

static func detail(id: String) -> String:
	var it: Dictionary = ITEMS[id]
	var s: String = String(it["desc"])
	if it.get("free", false):
		s += "
迷宮に自生するもの・魔物の素材。燐晶ではないので、税がかからない。"
	if it.get("food", false):
		s += "\n料理の材料(持ち物の「料理」で使う)。"
	if Cooking.is_fuel(id):
		s += "\n野営の燃料になる(燃料1つで、火が1時間もつ)。"
	if it.get("forged", false) or it.has("tier"):
		s += "\n店には無い。自宅の鍛冶場で作る。"
	if is_magic(id):
		s += "\n[魔法の品] 迷宮でまれに見つかる。層の主は必ず一つ落とす。"
	if GUILD_ONLY.has(id):
		s += "\n店では売れない。坑口館(冒険者ギルド)の遺品課が引き取り、謝礼を出す。"
	match String(it["kind"]):
		"weapon":
			s += "\n種類: %s   体当たり +%.1f" % [WEAPON_CAT_JP[it["cat"]], float(it["power"])]
			var sw: Dictionary = Balance.SWING.get(String(it["cat"]), Balance.SWING["none"])
			s += "\n振り方: 届く %d   待ち ×%.2f   押し返し ×%.1f%s" % [int(sw["reach"]), float(sw["cd"]), float(sw["knock"]), ("   怯ませ %d%%" % int(float(sw["stun"]) * 100.0)) if sw.has("stun") else ""]
			var tid := String(it.get("tech", Jobs.WEAPON_TECH.get(String(it["cat"]), "")))
			if tid != "":
				s += "\n武器の技: %s%s(MP%d) %s" % ["[珍品] " if it.get("rare", false) else "", Jobs.SKILLS[tid]["name"], int(Jobs.SKILLS[tid]["mp"]), Jobs.SKILLS[tid]["desc"]]
			if it.has("spell"):
				s += "   技の威力 +%.1f" % float(it["spell"])
			if it.has("elem"):
				s += "\n傷の種類: %s" % ELEM_JP.get(String(it["elem"]), String(it["elem"]))
			for t in (it.get("slay", {}) as Dictionary):
				s += "\n%sに ×%.1f" % [MON_TYPE_JP.get(t, t), float(it["slay"][t])]
			if it.has("drain"):
				s += "\n与えた傷の %d%% だけ癒える" % int(round(float(it["drain"]) * 100.0))
			if it.has("venom"):
				s += "\n当てると %d%% で毒にする" % int(round(float(it["venom"]) * 100.0))
		"armor":
			s += "\n種類: %s   防御 +%d" % [ARMOR_TYPE_JP[it["type"]], int(it["ac"])]
			if it.get("light_mass", false):
				s += "   軽い"
			if it.get("rustproof", false):
				s += "   錆びない"
			if it.get("no_slow", false):
				s += "   足が遅くならない"
		"tome":
			var names: Array = []
			for c in it["classes"]:
				names.append(Jobs.CLASSES[c]["name"])
			s += "\n覚えられるクラス: " + "、".join(names)
	for e in (it.get("resist", []) as Array):
		s += "\n%sの傷が半分" % ELEM_JP.get(String(e), String(e))
	return s
