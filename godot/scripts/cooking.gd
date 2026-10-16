class_name Cooking
extends RefCounted
## 料理(ken 10/16)。中身は data/cooking.json(市場の食材、材料の仲間、効き目、レシピ、生で食べたときの満腹)。
## 野営(迷宮の中)では燃料で火を熾して作る。自宅の台所(のちの PR)では、全部のレシピを作れる。
## 料理は一皿ずつ GameState.food に積む({id, q, until, n})。until を過ぎると「くさった○○」。
## 満腹度と、料理の効き目(一人一つ)は Character が持つ。時刻は「世界の時刻」(GameState.clock、通しの分)。

const PATH := "res://data/cooking.json"
const CAMP_MINUTES := 20.0        # 野営で一度作ると進む時間(分)
const FIRE_MINUTES := 60.0        # 燃料1つで、火がもつ時間(分)
const BELLY_MAX := 100.0
const BELLY_PER_MIN := 100.0 / (16.0 * 60.0)   # 起きていると、16時間で満腹が空になる
const BELLY_REST_MULT := 1.0 / 3.0
const HUNGRY := 30.0              # これ未満で「ぐぅ〜」
const STARVING := 10.0            # これ未満で力と足が落ちる
const BELLY_START := 80.0         # 街を出るとき(朝飯を食べた)
const Q_BURNT := 0
const Q_NORMAL := 1
const Q_GREAT := 2

static var clock := 0.0           # いまの世界の時刻(GameState が合わせる)。Character の効き目が見る
static var _data: Dictionary = {}
static var _recipes: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var p: Variant = JSON.parse_string(f.get_as_text())
			if typeof(p) == TYPE_DICTIONARY:
				_data = p
				for r in _data.get("recipes", []):
					_recipes[String(r["id"])] = r
	return _data

## 市場の食材を、ItemDB の品物の形にする(kind は material。生では食べられない)
static func ingredient_items() -> Dictionary:
	var out := {}
	var ing: Dictionary = data().get("ingredients", {})
	for id in ing:
		var it: Dictionary = ing[id]
		out[id] = {"name": it["name"], "kind": "material", "price": int(it["price"]), "food": true, "desc": it["desc"]}
	return out

static func market_ids() -> Array:
	return data().get("ingredients", {}).keys()

static func recipes() -> Array:
	return data().get("recipes", [])

static func recipe(id: String) -> Dictionary:
	data()
	return _recipes.get(id, {})

static func dish_name(id: String) -> String:
	return String(recipe(id).get("name", id))

static func tag_name(tag: String) -> String:
	return String(data().get("tags", {}).get(tag, {}).get("name", tag))

static func tag_ids(tag: String) -> Array:
	return data().get("tags", {}).get(tag, {}).get("ids", [])

static func raw_belly(id: String) -> float:
	return float(data().get("raw_belly", {}).get(id, 0.0))

static func is_fuel(id: String) -> bool:
	return tag_ids("fuel").has(id)

# ---------- 名前と説明 ----------

## 出来ばえと傷みを付けた名前(「上出来の胃袋スープ」「くさった胃袋スープ」)
static func stack_name(s: Dictionary, now: float) -> String:
	var n := dish_name(String(s["id"]))
	if rotten(s, now):
		return "くさった" + n
	match int(s.get("q", Q_NORMAL)):
		Q_GREAT: return "上出来の" + n
		Q_BURNT: return "焦げた" + n
	return n

static func rotten(s: Dictionary, now: float) -> bool:
	return now >= float(s["until"])

## 「あと5時間」「あと3夜」
static func left_text(s: Dictionary, now: float) -> String:
	var m := float(s["until"]) - now
	if m <= 0.0:
		return "傷んでいる"
	if m >= 24.0 * 60.0:
		return "あと%d夜" % int(floor(m / (24.0 * 60.0)))
	if m >= 60.0:
		return "あと%d時間" % int(floor(m / 60.0))
	return "あと少し"

static func life_text(hours: float) -> String:
	if hours >= 24.0:
		return "%d夜" % int(round(hours / 24.0))
	return "%d時間" % int(hours)

## 効き目の一行(「力: 体当たりと武器の威力 +6%」)
static func buff_text(buff: String, v: float) -> String:
	if buff == "":
		return "効き目なし(満腹だけ)"
	var b: Dictionary = data().get("buffs", {}).get(buff, {})
	var t := String(b.get("text", ""))
	var p := int(round(v * 100.0))
	if buff == "belly":
		p = int(round(v * 100.0))
	t = t.replace("{p}", str(p)).replace("{n}", str(int(v))).replace("{x}", "%.1f" % v)
	return "%s: %s" % [b.get("name", buff), t]

static func buff_name(buff: String) -> String:
	return String(data().get("buffs", {}).get(buff, {}).get("name", buff))

## 材料の一行(「茸 2」「岩塩 1」)と、持っている数
static func need_label(key: String) -> String:
	if key.begins_with("tag:"):
		return tag_name(key.substr(4))
	return ItemDB.item_name(key)

static func have_count(gs: GameState, key: String) -> int:
	if key.begins_with("tag:"):
		var n := 0
		for id in tag_ids(key.substr(4)):
			n += gs.count(String(id))
		return n
	return gs.count(key)

static func can_make(gs: GameState, r: Dictionary) -> bool:
	var need: Dictionary = r["in"]
	for k in need:
		if have_count(gs, String(k)) < int(need[k]):
			return false
	return true

## 材料を使う。仲間(tag:)は、持っている数の多いものから
static func _consume(gs: GameState, r: Dictionary) -> void:
	var need: Dictionary = r["in"]
	for k in need:
		var key := String(k)
		var n := int(need[k])
		if not key.begins_with("tag:"):
			gs.remove_item(key, n)
			continue
		var ids: Array = tag_ids(key.substr(4)).duplicate()
		ids.sort_custom(func(a, b): return gs.count(String(a)) > gs.count(String(b)))
		for id in ids:
			var take := mini(n, gs.count(String(id)))
			if take > 0:
				gs.remove_item(String(id), take)
				n -= take
			if n <= 0:
				break

# ---------- 作る ----------

## 料理番(倒れていない仲間のうち、〈生存〉がいちばん高い人)
static func cook_of(gs: GameState) -> Character:
	var best: Character = null
	for c in gs.party:
		if c.hp > 0.0 and (best == null or c.skill_bonus("survival") > best.skill_bonus("survival")):
			best = c
	return best

## 作る。材料を使い、料理を GameState.food に積む。{ok, q, n, name, roll, cook, msg} を返す
## d20 = 0 なら振る(テスト用に出目を渡せる)
static func cook(gs: GameState, rid: String, d20: int = 0) -> Dictionary:
	var r := recipe(rid)
	if r.is_empty():
		return {"ok": false, "msg": "そのレシピは知らない"}
	if not can_make(gs, r):
		return {"ok": false, "msg": "材料が足りない"}
	var ck := cook_of(gs)
	if ck == null:
		return {"ok": false, "msg": "作れる者がいない"}
	_consume(gs, r)
	var roll := d20 if d20 > 0 else Dice.rng.randi_range(1, 20)
	var total := roll + ck.skill_bonus("survival")
	var dc := int(r["dc"])
	var q := Q_NORMAL
	if roll == 1 or total < dc:
		q = Q_BURNT
	elif total >= dc + 5 or roll == 20:
		q = Q_GREAT
	var n := int(r["n"])
	gs.add_food(rid, q, gs.clock + float(r["life"]) * 60.0, n)
	var s := {"id": rid, "q": q, "until": gs.clock + float(r["life"]) * 60.0}
	var nm := stack_name(s, gs.clock)
	var msg := "%sが%sを作った(%d人分)。" % [ck.name, nm, n]
	if q == Q_GREAT:
		msg = "%sが%sを作った(%d人分)。会心の出来だ。" % [ck.name, nm, n]
	elif q == Q_BURNT:
		msg = "%sは%sを焦がした(%d人分)。" % [ck.name, dish_name(rid), n]
	return {"ok": true, "q": q, "n": n, "name": nm, "roll": roll, "total": total, "cook": ck.name, "msg": msg, "kind": String(r.get("kind", ""))}

# ---------- 食べる ----------

## ch が、gs.food の i 番目を一皿食べる。{ok, msg, rotten, q, poison} を返す(迷宮での手ごたえは Main が付ける)
static func eat(gs: GameState, i: int, ch: Character) -> Dictionary:
	if i < 0 or i >= gs.food.size():
		return {"ok": false, "msg": ""}
	if ch.hp <= 0.0:
		return {"ok": false, "msg": "%sは倒れていて、食べられない" % ch.name}
	var s: Dictionary = gs.food[i]
	var r := recipe(String(s["id"]))
	var nm := stack_name(s, gs.clock)
	var bad := rotten(s, gs.clock)
	var q := int(s.get("q", Q_NORMAL))
	gs.take_food(i)
	if bad:
		ch.belly = minf(BELLY_MAX, ch.belly + 5.0)
		return {"ok": true, "rotten": true, "q": q, "msg": "%sは%sを食べた。腹の具合が悪い…" % [ch.name, nm]}
	var belly := float(r.get("belly", 20.0)) * (0.6 if q == Q_BURNT else 1.0)
	ch.belly = minf(BELLY_MAX, ch.belly + belly)
	var poison := false
	var line := "%sは%sを食べた。" % [ch.name, nm]
	if q == Q_BURNT:
		if String(s["id"]) == "doku_nuki":
			poison = true
			line += "毒が抜けていなかった!"
	elif String(r.get("buff", "")) != "":
		var hrs := float(r["hours"]) * (1.5 if q == Q_GREAT else 1.0)
		ch.meal = {"id": String(s["id"]), "buff": String(r["buff"]), "v": float(r["v"]), "until": gs.clock + hrs * 60.0}
		line += "(%s、%d時間)" % [buff_name(String(r["buff"])), int(round(hrs))]
	ch.clamp_resources()
	return {"ok": true, "rotten": false, "q": q, "poison": poison, "msg": line}
