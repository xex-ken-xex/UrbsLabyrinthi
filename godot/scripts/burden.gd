class_name Burden
extends RefCounted
## 持ち物の重さ(ken 10/18)。人が普通に持てるのは、装備込みで一人 20kg。一行の荷(持ち物、料理、燐晶)と、
## 立っている仲間の装備を足して、立っている人数 × 20kg を超えたら足が遅くなる(重さの割合で、半分まで)。
## 倒れて背負われている仲間は重さに数えない(背負う側の速さと攻撃力が半分になる。Hero.carrying)。
## 遺品は重め(2kg)。燐晶は量(kg)のまま。

const CAP_KG := 20.0           # 一人が持てる重さ(装備込み)
const MIN_SPEED := 0.5         # 重すぎても、これより遅くはならない
const DISH_KG := 0.4           # 作った料理ひと皿
const RELIC_KG := 2.0          # 遺品(ken: 重めに、2kg くらい)
const ARMOR_KG := {"none": 1.0, "light": 4.0, "medium": 8.0, "heavy": 12.0}
const KIND_KG := {"consumable": 0.3, "acc": 0.3, "tome": 1.0, "material": 0.5}

## 迷宮の中で、いまの重さで足にかかる倍率(Main が数え直す。Hero._speed_now が掛ける)
static var speed_mult := 1.0

## 品ひとつの重さ(kg)。品に "kg" があればそれ
static func item_kg(id: String) -> float:
	var it: Dictionary = ItemDB.get_item(id)
	if it.is_empty():
		return 0.0
	if it.has("kg"):
		return float(it["kg"])
	if id.begins_with("relic_"):
		return RELIC_KG
	match String(it.get("kind", "")):
		"weapon":
			return snappedf(0.5 + float(it.get("power", 1.0)) * 0.6, 0.1)      # 短剣 1.1kg、両手剣 3.2kg、大斧 3.5kg
		"armor":
			return float(ARMOR_KG.get(String(it.get("type", "none")), 4.0))
		"acc":
			return 2.5 if id.begins_with("buckler") else 0.3
	return float(KIND_KG.get(String(it.get("kind", "")), 0.3))

## 装備の重さ
static func gear_kg(c: Character) -> float:
	var kg := 0.0
	for k in c.equip:
		if String(c.equip[k]) != "":
			kg += item_kg(String(c.equip[k]))
	return kg

## 一行の荷の重さ: 持ち物 + 料理 + 燐晶(bag: 純度 → kg) + 立っている仲間の装備(standing: Character の配列)
static func party_kg(gs: GameState, standing: Array, bag: Dictionary = {}) -> float:
	var kg := 0.0
	for id in gs.inventory:
		kg += item_kg(String(id)) * int(gs.inventory[id])
	for f in gs.food:
		kg += DISH_KG * int(f.get("n", 1))
	for p in bag:
		kg += float(bag[p])
	for c in standing:
		kg += gear_kg(c)
	return kg

static func cap_kg(standing_n: int) -> float:
	return CAP_KG * maxi(1, standing_n)

## 重さで足にかかる倍率(持てる重さまでは 1)
static func mult_for(kg: float, cap: float) -> float:
	if kg <= cap or kg <= 0.0:
		return 1.0
	return maxf(MIN_SPEED, cap / kg)

## 「荷の重さ 23.4 / 40kg」(重すぎれば、足の遅れも)
static func label(kg: float, cap: float) -> String:
	var s := "荷の重さ %.1f / %dkg" % [kg, int(cap)]
	if kg > cap:
		s += "(重すぎる。足が %d%% に)" % int(round(mult_for(kg, cap) * 100.0))
	return s
