class_name Smithing
extends RefCounted
## 鍛冶(ken 10/16、生産系③)。自宅の鍛冶場で、武器と防具を作る。中身は data/smithing.json。
## 炉火の槌の品は全部作れる(鉄塊の数は値段から。革・弓・小盾は json)。素材からだけ作れる品が6つある。
## 出来ばえ: 失敗(材料の半分を失う)/ 並 / 良品(+1)/ 逸品(+2)。良品・逸品は「<id>+1」「<id>+2」という別の品として ItemDB に足す。
## 腕前は、【筋力】の補正 + 戦士・蛮族なら習熟。重い鎧は1夜かかる(Home の鍛冶場に仕込む)。

const PATH := "res://data/smithing.json"
const SMITH_CLASSES := ["fighter", "barbarian"]
const Q_FAIL := 0
const Q_NORMAL := 1
const Q_GOOD := 2
const Q_FINE := 3
const TIER_NAME := {1: "良品の", 2: "逸品の"}
const TIER_PRICE := {1: 1.5, 2: 2.2}

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(p) == TYPE_DICTIONARY:
			_data = p
	return _data

## 素材からだけ作れる品(ItemDB に足す)
static func gear_items() -> Dictionary:
	var out := {}
	var g: Dictionary = data().get("gear", {})
	for id in g:
		var it: Dictionary = (g[id] as Dictionary).duplicate(true)
		it["forged"] = true
		out[id] = it
	return out

## 良品と逸品(ItemDB に足す)。base は、作れる品すべて
static func tier_items(base: Dictionary) -> Dictionary:
	var out := {}
	for id in forgeable_ids(base):
		var b: Dictionary = base[id]
		for tier in [1, 2]:
			var it: Dictionary = b.duplicate(true)
			it["name"] = TIER_NAME[tier] + String(b["name"])
			it["price"] = int(round(int(b["price"]) * float(TIER_PRICE[tier])))
			it["base"] = id
			it["tier"] = tier
			it.erase("rare")
			match String(b["kind"]):
				"weapon":
					it["power"] = float(b["power"]) + 0.5 * tier
				"armor":
					it["ac"] = int(b["ac"]) + tier
				"acc":
					var fx: Dictionary = (b.get("fx", {}) as Dictionary).duplicate()
					fx["ac"] = float(fx.get("ac", 0.0)) + tier
					it["fx"] = fx
			it["desc"] = String(b["desc"]) + ("\n鍛冶場で作った%s(%s)。" % ["良品" if tier == 1 else "逸品", "威力 +%.1f" % (0.5 * tier) if String(b["kind"]) == "weapon" else "防御 +%d" % tier])
			out["%s+%d" % [id, tier]] = it
	return out

## 作れる品の id(炉火の槌の品から魔法の品を除いたもの + 素材からだけ作れる品)
static func forgeable_ids(base: Dictionary) -> Array:
	var ids: Array = []
	var no: Array = data().get("not_forgeable", [])
	for id in ItemDB.SHOPS["smith"]:
		if not no.has(id) and base.has(id) and ["weapon", "armor", "acc"].has(String(base[id]["kind"])):
			ids.append(id)
	for id in data().get("gear", {}):
		ids.append(id)
	return ids

static func base_of(id: String) -> String:
	return String(ItemDB.ITEMS.get(id, {}).get("base", id))

static func tier_of(id: String) -> int:
	return int(ItemDB.ITEMS.get(id, {}).get("tier", 0))

## そのレシピ {in, dc, nights}
static func recipe(id: String) -> Dictionary:
	var it: Dictionary = ItemDB.ITEMS.get(id, {})
	if it.is_empty() or not forgeable_ids(ItemDB.ITEMS).has(id):
		return {}
	var r: Dictionary = (data().get("recipes", {}).get(id, {}) as Dictionary).duplicate(true)
	var price := int(it["price"])
	if r.is_empty():
		r = {"in": {"tetsukai": maxi(1, int(round(price / 100.0)))}, "dc": clampi(8 + price / 100, 8, 20)}
	r["nights"] = 1 if String(it.get("type", "")) == "heavy" else 0
	return r

static func smelt_recipe() -> Dictionary:
	return data().get("smelt", {})

## 鍛冶の腕前(【筋力】の補正、戦士・蛮族は習熟も)
static func smith_bonus(c: Character) -> int:
	return c.mod("str") + (c.prof_bonus() if SMITH_CLASSES.has(c.cls) else 0)

## 鍛冶役(倒れていない仲間のうち、腕前がいちばん高い人)
static func smith_of(gs: GameState) -> Character:
	var best: Character = null
	for c in gs.party:
		if c.hp > 0.0 and (best == null or smith_bonus(c) > smith_bonus(best)):
			best = c
	return best

static func fuel(gs: GameState) -> String:
	for id in data().get("fuel", []):
		if gs.count(String(id)) > 0:
			return String(id)
	return ""

static func can_make(gs: GameState, r: Dictionary) -> bool:
	var need: Dictionary = r.get("in", {})
	for k in need:
		if gs.count(String(k)) < int(need[k]):
			return false
	return not need.is_empty()

## 鉄屑を溶かす。{ok, msg}
static func smelt(gs: GameState) -> Dictionary:
	if not Home.has_room(gs, "forge"):
		return {"ok": false, "msg": "鍛冶場が無い"}
	var r := smelt_recipe()
	if not can_make(gs, r):
		return {"ok": false, "msg": "鉄屑が足りない(3つで鉄塊1つ)"}
	var f := fuel(gs)
	if f == "":
		return {"ok": false, "msg": "炉の燃料が無い(炭か焼け石)"}
	gs.remove_item(f)
	for k in r["in"]:
		gs.remove_item(String(k), int(r["in"][k]))
	gs.add_item(String(r["out"]))
	gs.save()
	return {"ok": true, "msg": "ジュウゥ…。鉄屑が溶けて、鉄塊が1つできた。"}

## 鍛える。{ok, msg, q, out}(out は持ち物に入った品の id。重い鎧は鍛冶場に仕込む)
## d20 = 0 なら振る(テスト用に出目を渡せる)
static func forge(gs: GameState, id: String, d20: int = 0) -> Dictionary:
	if not Home.has_room(gs, "forge"):
		return {"ok": false, "msg": "鍛冶場が無い"}
	var r := recipe(id)
	if r.is_empty():
		return {"ok": false, "msg": "それは作れない"}
	if int(r["nights"]) > 0 and not (gs.home.get("anvil", {}) as Dictionary).is_empty():
		return {"ok": false, "msg": "金床には、まだ仕上がっていない鎧がある"}
	if not can_make(gs, r):
		return {"ok": false, "msg": "材料が足りない"}
	var f := fuel(gs)
	if f == "":
		return {"ok": false, "msg": "炉の燃料が無い(炭か焼け石)"}
	var sm := smith_of(gs)
	if sm == null:
		return {"ok": false, "msg": "槌を振れる者がいない"}
	gs.remove_item(f)
	var roll := d20 if d20 > 0 else Dice.rng.randi_range(1, 20)
	var total := roll + smith_bonus(sm)
	var dc := int(r["dc"])
	var need: Dictionary = r["in"]
	var nm := ItemDB.item_name(id)
	if roll == 1 or total < dc:
		for k in need:
			gs.remove_item(String(k), maxi(1, int(need[k]) / 2))
		gs.save()
		return {"ok": true, "q": Q_FAIL, "out": "", "msg": "カン、カン…ガキン。%sの槌の下で、%sが割れた。材料の半分を無駄にした。" % [sm.name, nm]}
	for k in need:
		gs.remove_item(String(k), int(need[k]))
	var tier := 0
	if roll == 20 or total >= dc + 10:
		tier = 2
	elif total >= dc + 5:
		tier = 1
	var out := id if tier == 0 else "%s+%d" % [id, tier]
	var q: int = [Q_NORMAL, Q_GOOD, Q_FINE][tier]
	var grade: String = ["", "良品だ。", "逸品だ!"][tier]
	if int(r["nights"]) > 0:
		gs.home["anvil"] = {"id": out, "ready": gs.day + int(r["nights"])}
		gs.save()
		return {"ok": true, "q": q, "out": "", "set": true, "msg": "カン、カン、カン…。%sが%sを打ち上げた。冷ましと仕上げに一夜かかる。%s" % [sm.name, ItemDB.item_name(out), grade]}
	gs.add_item(out)
	gs.save()
	return {"ok": true, "q": q, "out": out, "msg": "カン、カン、カン…。%sが%sを打ち上げた。%s" % [sm.name, ItemDB.item_name(out), grade]}

## 金床の鎧が仕上がっていれば、持ち物へ
static func collect(gs: GameState) -> String:
	var a: Dictionary = gs.home.get("anvil", {})
	if a.is_empty() or gs.day < int(a["ready"]):
		return ""
	gs.add_item(String(a["id"]))
	gs.home["anvil"] = {}
	gs.save()
	return "金床の%sが仕上がっていた。" % ItemDB.item_name(String(a["id"]))

static func anvil_ready(gs: GameState) -> String:
	if not Home.owned(gs):
		return ""
	var a: Dictionary = gs.home.get("anvil", {})
	if a.is_empty() or gs.day < int(a["ready"]):
		return ""
	return ItemDB.item_name(String(a["id"]))
