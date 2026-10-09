class_name EncounterGen
extends RefCounted
## 遭遇を作る。docs/urbs-labyrinthi.html の Core.buildPool / genEncounter を、GDScript へ写したもの。
## 闘技場で、選んだ遭遇レベル・難度・舞台の魔物を出すために使う。データは data/encounter-data.json。

const DIFF_JP := ["低", "中", "高"]
const MINDLESS := ["undead", "ooze", "construct", "plant"]
const ACT := {
	"mindless": ["動かずに立っている", "同じ場所をゆっくり巡っている", "侵入者の気配に向き直ったところ"],
	"beast": ["餌をあさっている", "縄張りを見回っている"],
	"smart": ["待ち伏せている", "何かを探している", "見張りを立てて休んでいる"],
}

static var _data: Dictionary = {}
static var _regex_cache := {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounter-data.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
	return _data

static func theme_ids() -> Array:
	return ["fuyou", "sabi", "kagami", "hone", "soko", "generic"]

static func theme_name(id: String) -> String:
	return String(data()["themes"][id]["short"])

static func _re(src: String) -> RegEx:
	if not _regex_cache.has(src):
		var r := RegEx.new()
		r.compile(src)
		_regex_cache[src] = r
	return _regex_cache[src]

static func _test(src: String, s: String) -> bool:
	return src != "" and _re(src).search(s) != null

static func fam(m: Dictionary) -> String:
	var t := String(m["t"])
	return "swarm" if t.begins_with("swarm") else t

## 舞台とレベルから、候補の魔物と重みを作る
static func build_pool(theme_id: String, level: int) -> Array:
	var d := data()
	var theme: Dictionary = d["themes"][theme_id]
	var sig := {}
	for pair in theme["sig"]:
		for id in pair[1]:
			sig[String(id)] = String(pair[0])
	var types: Dictionary = theme["types"]
	var out: Array = []
	for m in d["monsters"]:
		if not m.has("at") or _test(", (Human|Bear|Boar|Rat|Tiger|Wolf|Bat|Mist) Form$", String(m["n"])):
			continue
		var f := fam(m)
		var w := float(types.get(f, 0))
		var world: String = sig.get(String(m["i"]), "")
		var i := String(m["i"])
		if world == "":
			if f == "beast" and String(theme["beastRe"]) != "" and not _test(theme["beastRe"], i):
				w = 0.0
			if f == "humanoid" and String(theme["humanoidRe"]) != "" and not _test(theme["humanoidRe"], i):
				w = 0.0
			if f == "elemental" and String(theme["elementalRe"]) != "" and not _test(theme["elementalRe"], i):
				w = 0.0
			if f == "swarm" and String(theme["beastRe"]) != "" and not _test(theme["beastRe"], i) and not _test("insect", i):
				w = 0.0
		else:
			w = maxf(w, 1.0) * 6.0
		var sp: Dictionary = m["sp"]
		var swim_only: bool = not sp.get("walk", 0) and not sp.get("fly", 0) and not sp.get("climb", 0) and not sp.get("burrow", 0)
		if swim_only and not theme["water"]:
			w = 0.0
		if theme["water"] and sp.get("swim", 0):
			w *= 1.6
		if float(m["cr"]) > level + 3:
			w = 0.0
		if float(m["cr"]) < level / 8.0 - 0.01 and world == "":
			w *= 0.25
		if w > 0.0:
			out.append({"m": m, "w": w, "world": world})
	return out

static func _weighted(items: Array, wf: Callable) -> Variant:
	var total := 0.0
	var ws: Array = []
	for x in items:
		var v := maxf(0.0, float(wf.call(x)))
		total += v
		ws.append(v)
	if total <= 0.0:
		return null
	var r := Dice.rng.randf() * total
	for i in items.size():
		r -= ws[i]
		if r < 0.0:
			return items[i]
	return items[items.size() - 1]

static func _cap(p: Dictionary) -> int:
	var m: Dictionary = p["m"]
	if fam(m) == "swarm":
		return 3
	if m.get("la", false):
		return 1
	return 3 if "LHG".contains(String(m["z"])) else 8

## 遭遇を一つ作る。返り値: {groups:[{m, n, world}], xp, budget, diff_label, kind, activity}。作れなければ空
static func generate(theme_id: String, level: int, diff: int, party: int) -> Dictionary:
	level = clampi(level, 1, 20)
	var budgets: Array = data()["xp_budget"][level]
	var budget := float(budgets[diff]) * party
	var pool := build_pool(theme_id, level)
	var cands: Array = pool.filter(func(p): return float(p["m"]["xp"]) <= budget)
	if cands.is_empty():
		if pool.is_empty():
			return {}
		var min_xp := 1e9
		for p in pool:
			min_xp = minf(min_xp, float(p["m"]["xp"]))
		cands = pool.filter(func(p): return float(p["m"]["xp"]) == min_xp)
	var bias := func(r: float) -> float:
		return 1.6 if r >= 0.5 else (1.3 if r >= 0.2 else (1.0 if r >= 0.08 else 0.3))
	var lead: Variant = _weighted(cands, func(p): return float(p["w"]) * float(bias.call(float(p["m"]["xp"]) / budget)))
	if lead == null:
		return {}
	var lead_m: Dictionary = lead["m"]
	var n := maxi(1, mini(_cap(lead), int(floor(budget / maxf(1.0, float(lead_m["xp"]))))))
	var groups: Array = []
	if n >= 3 and Dice.rng.randf() < 0.4:
		var n1 := int(ceil(n / 2.0))
		var rem := budget - n1 * float(lead_m["xp"])
		var seconds: Array = cands.filter(func(p): return p != lead and float(p["m"]["xp"]) <= rem and float(p["m"]["xp"]) <= float(lead_m["xp"]) \
			and (fam(p["m"]) == fam(lead_m) or (p["world"] != "" and lead["world"] != "")))
		var second: Variant = _weighted(seconds, func(p): return float(p["w"]))
		if second != null:
			groups.append({"m": lead_m, "n": n1, "world": lead["world"]})
			groups.append({"m": second["m"], "n": maxi(1, mini(6, int(floor(rem / maxf(1.0, float(second["m"]["xp"])))))), "world": second["world"]})
	if groups.is_empty():
		groups.append({"m": lead_m, "n": n, "world": lead["world"]})
	var xp := 0
	for g in groups:
		xp += int(g["m"]["xp"]) * int(g["n"])
	var f := fam(lead_m)
	var kind := "mindless" if MINDLESS.has(f) else ("beast" if (f == "beast" or f == "swarm" or int(lead_m["ab"][3]) <= 4) else "smart")
	var acts: Array = ACT[kind]
	var label := "ごく低"
	if xp > budgets[0] * party * 0.5:
		label = "低"
	if xp > budgets[0] * party:
		label = "中"
	if xp > budgets[1] * party:
		label = "高"
	if xp > budgets[2] * party:
		label = "危険"
	return {"groups": groups, "xp": xp, "budget": int(budget), "diff_label": label, "kind": kind, "activity": String(acts[Dice.rng.randi_range(0, acts.size() - 1)])}

## Enemy.setup が読む形(書き出した JSON の monsters[] と同じ)へ
static func mon_line(g: Dictionary) -> Dictionary:
	var m: Dictionary = g["m"]
	var o := {"index": m["i"], "name": m["n"], "name_ja": m["j"], "count": g["n"], "cr": m["cr"], "xp": m["xp"], "ac": m["ac"], "hp": m["hp"],
		"hit_dice": m["hd"], "size": m["z"], "type": m["t"], "speed": m["sp"], "abilities": m["ab"], "attacks": m.get("at", []), "traits": m.get("tr", []),
		"multiattack": m.has("mu"), "legendary": m.has("la")}
	if String(g["world"]) != "":
		o["world_name"] = g["world"]
	return o
