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
	"return_scroll": {"name": "帰還の札", "kind": "consumable", "price": 150, "use": "return", "v": 0.0,
		"desc": "迷宮の中から、荷物を持ったまま地上へ戻る。"},
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
	"crystal_staff": {"name": "魔晶の杖", "kind": "weapon", "cat": "staff", "power": 1.5, "spell": 2.0, "price": 300, "desc": "燐晶を嵌めた杖。呪文の威力+2。"},
	"shortbow": {"name": "短弓", "kind": "weapon", "cat": "bow", "power": 1.5, "spell": 1.0, "price": 150, "desc": "軽い弓。矢の威力+1。"},
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

## 全品。自生物、魔物の素材、遺品(ForageData、tools/make-items.py が作る)を足してある。燐晶ではないので、税がかからない
static var ITEMS: Dictionary = BASE_ITEMS.merged(ForageData.ITEMS)

const SHOPS := {
	"smith": ["dagger", "shortsword", "longsword", "greatsword", "mace", "warhammer", "handaxe", "greataxe", "spear", "shortbow", "longbow",
		"leather", "studded", "chain_shirt", "breastplate", "chain_mail", "plate", "buckler", "power_band", "swift_boots"],
	"general": ["potion", "hi_potion", "ether", "lamp_oil", "return_scroll", "robe", "quarterstaff", "vital_ring", "lamp_charm"],
	"magic": ["ether", "crystal_staff", "mana_ring", "tome_mana_shield", "tome_sleep", "tome_regen", "tome_flash"],
}

const WEAPON_CAT_JP := {"sword": "剣", "dagger": "短剣", "blunt": "鈍器", "axe": "斧", "spear": "槍", "staff": "杖", "bow": "弓"}
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

## 深い層ほど、良い装備が出る
static func roll_gear(floor_no: int, rng: RandomNumberGenerator) -> String:
	var cap := 120 + floor_no * 130
	var pool: Array = []
	for id in BASE_ITEMS:
		var it: Dictionary = BASE_ITEMS[id]
		var k := String(it["kind"])
		if (k == "weapon" or k == "armor" or k == "acc") and int(it["price"]) <= cap:
			pool.append(id)
	return "" if pool.is_empty() else String(pool[rng.randi_range(0, pool.size() - 1)])

static func detail(id: String) -> String:
	var it: Dictionary = ITEMS[id]
	var s: String = String(it["desc"])
	if it.get("free", false):
		s += "
迷宮に自生するもの・魔物の素材。燐晶ではないので、税がかからない。"
	match String(it["kind"]):
		"weapon":
			s += "\n種類: %s   体当たり +%.1f" % [WEAPON_CAT_JP[it["cat"]], float(it["power"])]
			if it.has("spell"):
				s += "   技の威力 +%.1f" % float(it["spell"])
		"armor":
			s += "\n種類: %s   防御 +%d" % [ARMOR_TYPE_JP[it["type"]], int(it["ac"])]
		"tome":
			var names: Array = []
			for c in it["classes"]:
				names.append(Jobs.CLASSES[c]["name"])
			s += "\n覚えられるクラス: " + "、".join(names)
	return s
