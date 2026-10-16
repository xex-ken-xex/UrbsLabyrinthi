class_name Home
extends RefCounted
## 自宅(ken 10/16、生産系②)。坑口館の「空き家の札」で買う。中身は GameState.home(空なら、まだ無い)。
## home = {"rooms": [部屋のid], "pantry": [料理の山], "storage": {品物: 数}, "pots": [熟成中の釜], "lab_closed": その夜は実験室が使えない(夜の番号)}
## 台所と寝床ははじめから。食料庫・物置・実験室は増築(鍛冶場は生産系③)。
## 魔法実験は data/alchemy.json。すぐできる調合と、何夜か寝かせる熟成(釜3つ。街へ戻るたびに1夜)。

const HOUSE_PRICE := 2000
const POTS := 3
const PANTRY_RATE := 0.25            # 食料庫の中では、傷む速さが4分の1
const ROOMS := {
	"kitchen": {"name": "台所", "price": 0, "desc": "全部の料理を作れる。燃料も時間も要らない。"},
	"bed": {"name": "寝床", "price": 0, "desc": "ただで休める(HPとMPが全快する)。記録もつけられる。"},
	"pantry": {"name": "食料庫", "price": 600, "desc": "しまった料理が傷む速さが4分の1になる。"},
	"storage": {"name": "物置", "price": 400, "desc": "持ち物を預けられる。全滅しても失わない。"},
	"lab": {"name": "実験室", "price": 1500, "desc": "魔法実験で薬を作る。釜が3つあり、何夜か寝かせる薬も作れる。"},
	"forge": {"name": "鍛冶場", "price": 1800, "desc": "武器と防具を作る(準備中)。", "soon": true},
}
const ROOM_ORDER := ["kitchen", "bed", "pantry", "storage", "lab", "forge"]
const ALCHEMY_PATH := "res://data/alchemy.json"

static var _alchemy: Array = []

static func owned(gs: GameState) -> bool:
	return not gs.home.is_empty()

static func has_room(gs: GameState, id: String) -> bool:
	return owned(gs) and (gs.home.get("rooms", []) as Array).has(id)

static func buy_house(gs: GameState) -> String:
	if owned(gs):
		return "もう家がある"
	if gs.bank_silver < HOUSE_PRICE:
		return "銀貨が足りない"
	gs.bank_silver -= HOUSE_PRICE
	gs.home = {"rooms": ["kitchen", "bed"], "pantry": [], "storage": {}, "pots": [], "lab_closed": -1}
	gs.save()
	return ""

static func build(gs: GameState, id: String) -> String:
	if not owned(gs) or not ROOMS.has(id):
		return "家が無い"
	if has_room(gs, id):
		return "もうある"
	if ROOMS[id].get("soon", false):
		return "まだ作れない"
	var price := int(ROOMS[id]["price"])
	if gs.bank_silver < price:
		return "銀貨が足りない"
	gs.bank_silver -= price
	(gs.home["rooms"] as Array).append(id)
	gs.save()
	return ""

# ---------- 食料庫 ----------

## 食料庫の山の、いまの残り時間(分)。0 以下ならくさっている
static func pantry_left(s: Dictionary, now: float) -> float:
	return float(s["left"]) - (now - float(s["at"])) * PANTRY_RATE

## 持ち物の料理(gs.food の i 番目)を、まるごと食料庫へ
static func store_food(gs: GameState, i: int) -> void:
	var s: Dictionary = gs.food[i]
	(gs.home["pantry"] as Array).append({"id": s["id"], "q": int(s["q"]), "n": int(s["n"]), "left": float(s["until"]) - gs.clock, "at": gs.clock})
	gs.food.remove_at(i)
	gs.save()

## 食料庫の i 番目を、まるごと持ち物へ
static func take_food(gs: GameState, i: int) -> void:
	var p: Array = gs.home["pantry"]
	var s: Dictionary = p[i]
	gs.add_food(String(s["id"]), int(s["q"]), gs.clock + pantry_left(s, gs.clock), int(s["n"]))
	p.remove_at(i)
	gs.save()

## 食料庫の山を、名前と残りの文で(くさっていれば「くさった」)
static func pantry_stack(s: Dictionary, now: float) -> Dictionary:
	return {"id": s["id"], "q": int(s["q"]), "n": int(s["n"]), "until": now + pantry_left(s, now)}

# ---------- 物置 ----------

static func deposit(gs: GameState, id: String, n: int) -> void:
	n = mini(n, gs.count(id))
	if n <= 0:
		return
	gs.remove_item(id, n)
	var st: Dictionary = gs.home["storage"]
	st[id] = int(st.get(id, 0)) + n
	gs.save()

static func withdraw(gs: GameState, id: String, n: int) -> void:
	var st: Dictionary = gs.home["storage"]
	n = mini(n, int(st.get(id, 0)))
	if n <= 0:
		return
	st[id] = int(st[id]) - n
	if int(st[id]) <= 0:
		st.erase(id)
	gs.add_item(id, n)
	gs.save()

# ---------- 魔法実験 ----------

static func alchemy() -> Array:
	if _alchemy.is_empty():
		var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(ALCHEMY_PATH))
		if typeof(p) == TYPE_DICTIONARY:
			_alchemy = p.get("recipes", [])
	return _alchemy

static func alchemy_recipe(id: String) -> Dictionary:
	for r in alchemy():
		if String(r["id"]) == id:
			return r
	return {}

## 実験の腕前(倒れていない仲間のうち、〈魔法学〉がいちばん高い人)
static func alchemist(gs: GameState) -> Character:
	var best: Character = null
	for c in gs.party:
		if c.hp > 0.0 and (best == null or c.skill_bonus("arcana") > best.skill_bonus("arcana")):
			best = c
	return best

static func lab_closed(gs: GameState) -> bool:
	return int(gs.home.get("lab_closed", -1)) == gs.day

static func free_pots(gs: GameState) -> int:
	return POTS - (gs.home.get("pots", []) as Array).size()

static func _fuel(gs: GameState) -> String:
	for id in Cooking.tag_ids("fuel"):
		if gs.count(String(id)) > 0:
			return String(id)
	return ""

## 調合する(すぐできるもの)か、釜に仕込む(何夜か)。{ok, msg, q, kind("pop"/"boom"/"fail"/"set")}
## d20 = 0 なら振る(テスト用に出目を渡せる)
static func brew(gs: GameState, rid: String, d20: int = 0) -> Dictionary:
	var r := alchemy_recipe(rid)
	if r.is_empty() or not has_room(gs, "lab"):
		return {"ok": false, "msg": "実験室が無い"}
	if lab_closed(gs):
		return {"ok": false, "msg": "実験室は煤だらけだ。今夜はもう使えない"}
	var nights := int(r["nights"])
	if nights > 0 and free_pots(gs) <= 0:
		return {"ok": false, "msg": "空いている釜が無い"}
	var need: Dictionary = r["in"]
	for k in need:
		if gs.count(String(k)) < int(need[k]):
			return {"ok": false, "msg": "材料が足りない"}
	var fuel := _fuel(gs)
	if fuel == "":
		return {"ok": false, "msg": "燃料が無い(焚き木束・焼け石・白蝋)"}
	var al := alchemist(gs)
	if al == null:
		return {"ok": false, "msg": "実験できる者がいない"}
	for k in need:
		gs.remove_item(String(k), int(need[k]))
	gs.remove_item(fuel)
	var roll := d20 if d20 > 0 else Dice.rng.randi_range(1, 20)
	var total := roll + al.skill_bonus("arcana")
	var dc := int(r["dc"])
	var out_name := ItemDB.item_name(String(r["out"]))
	if roll == 1:
		gs.home["lab_closed"] = gs.day
		gs.save()
		return {"ok": true, "q": -1, "kind": "boom", "msg": "ボフン! %sの釜が噴き上がった。材料は灰になり、今夜は実験室が使えない。" % al.name}
	var q := Cooking.Q_NORMAL
	if total < dc:
		q = Cooking.Q_BURNT
	elif total >= dc + 5 or roll == 20:
		q = Cooking.Q_GREAT
	if nights > 0:
		(gs.home["pots"] as Array).append({"id": rid, "q": q, "ready": gs.day + nights})
		gs.save()
		return {"ok": true, "q": q, "kind": "set", "msg": "%sが%sを釜に仕込んだ。%d夜寝かせる。" % [al.name, out_name, nights]}
	var got := _yield(gs, r, q)
	gs.save()
	if q == Cooking.Q_BURNT:
		return {"ok": true, "q": q, "kind": "fail", "msg": "%sの手もとで、液が濁った。濁った薬ができた。" % al.name}
	return {"ok": true, "q": q, "kind": "pop", "msg": "ポコン。%sが%sを%dつ作った。%s" % [al.name, out_name, got, "上出来だ。" if q == Cooking.Q_GREAT else ""]}

## できたものを持ち物へ。上出来は1つ多い。失敗は濁った薬
static func _yield(gs: GameState, r: Dictionary, q: int) -> int:
	if q == Cooking.Q_BURNT:
		gs.add_item("murky")
		return 0
	var n := int(r["n"]) + (1 if q == Cooking.Q_GREAT else 0)
	gs.add_item(String(r["out"]), n)
	return n

## 仕上がった釜(i 番目)から取り出す
static func collect(gs: GameState, i: int) -> String:
	var pots: Array = gs.home["pots"]
	var p: Dictionary = pots[i]
	if gs.day < int(p["ready"]):
		return ""
	var r := alchemy_recipe(String(p["id"]))
	var got := _yield(gs, r, int(p["q"]))
	pots.remove_at(i)
	gs.save()
	if got == 0:
		return "釜を開けると、中身は濁っていた。濁った薬ができた。"
	return "釜を開けた。%sが%dつできている。%s" % [ItemDB.item_name(String(r["out"])), got, "上出来だ。" if int(p["q"]) == Cooking.Q_GREAT else ""]

## 仕上がっている釜の名前(街へ戻ったときの報告)
static func ready_pots(gs: GameState) -> Array:
	var out: Array = []
	if not owned(gs):
		return out
	for p in gs.home.get("pots", []):
		if gs.day >= int(p["ready"]):
			out.append(ItemDB.item_name(String(alchemy_recipe(String(p["id"])).get("out", ""))))
	return out

## 記録から読んだ家を、形をそろえて戻す
static func sanitize(d: Variant) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or (d as Dictionary).is_empty():
		return {}
	var h := {"rooms": [], "pantry": [], "storage": {}, "pots": [], "lab_closed": int(d.get("lab_closed", -1))}
	for r in d.get("rooms", []):
		if ROOMS.has(String(r)):
			h["rooms"].append(String(r))
	for s in d.get("pantry", []):
		if not Cooking.recipe(String(s.get("id", ""))).is_empty():
			h["pantry"].append({"id": String(s["id"]), "q": int(s.get("q", 1)), "n": int(s.get("n", 1)), "left": float(s.get("left", 0.0)), "at": float(s.get("at", 0.0))})
	var st: Dictionary = d.get("storage", {})
	for k in st:
		if ItemDB.ITEMS.has(String(k)):
			h["storage"][String(k)] = int(st[k])
	for p in d.get("pots", []):
		if not alchemy_recipe(String(p.get("id", ""))).is_empty():
			h["pots"].append({"id": String(p["id"]), "q": int(p.get("q", 1)), "ready": int(p.get("ready", 0))})
	return h
