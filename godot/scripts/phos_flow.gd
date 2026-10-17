class_name PhosFlow
extends RefCounted
## 燐の流れ(設計メモ 2026-10-17-dungeon-generator.md §5.6)。迷宮の階どうしを、物と魔物の行き来でつなぐ。
## - 燐と物は下へ: 上の階(第1〜6層)で全滅して失った持ち物と燐晶は、竪坑を落ちて、第6層のいちばん下の溜まり場に積もる。
##   拾えば取り戻せる(gs.flow["sump"])。
## - 骨亡者は静かな夜に下へ: 見つけたのに調べずに放っておいた遺体は、夜のうちに起き上がり、次の夜、一つ下の階に骨亡者の群れが出る
##   (gs.flow["risen"])。
## - 魔物は吐く夜に上へ: 吐く夜のワンダリング・モンスターには、一つ下の層の魔物が混じる(DungeonTime.spawn_wanderer)。
## - 竜の気配は吐く夜に上へ: 第7層から下では、吐く夜に縦穴の縁が熱い。焦げた遺体と、硫黄の華。
## 燐晶の量も、ここで層ごとの目安(数理モデルの kg_floor。data/manifest.json)に合わせる(GroundItems)。

const SUMP_FLOOR := 26          # 溜まり場のある階(第6層のいちばん下。竪坑の底)
const SUMP_MAX := 40            # 溜まり場に積もっている品の数の上限(古いものから、さらに下へ流れて消える)
const SUMP_KG_MAX := 3.0        # 溜まり場に積もる燐晶の上限(kg、純度ごと)
const RISEN_MAX := 4            # 起き上がって降りてくる骨亡者の数の上限(一つの階に)
const BELOW_P := 0.5            # 吐く夜のワンダリングが、一つ下の層の魔物になる確率
const BELOW_LEVEL_MAX := 2      # 下の層の魔物の強さ(舞台のレベル)は、この層のレベル + これまで
const HOT_LAYER := 7            # 竜の気配がする、いちばん浅い層
const HEAT_EVERY := 2.0         # 熱い縁に立っていると、この秒ごとに焼ける
const HEAT_DMG := "1d4"
const SULFUR_N := [3, 6]        # 吐く夜の縁に吹き出す硫黄の華の数
const SCORCH_P := 0.6           # 吐く夜に、遺体が焦げている確率(第7層から下)

static var _manifest: Dictionary = {}

## data/manifest.json(一度だけ読む)
static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var d: Variant = FloorMap.read_json("res://data/manifest.json")
		_manifest = d if typeof(d) == TYPE_DICTIONARY else {"layers": []}
	return _manifest

## 層の目安({layer, theme, kg_floor, ...})。無ければ {}
static func layer_info(layer: int) -> Dictionary:
	for L in manifest().get("layers", []):
		if int(L.get("layer", 0)) == layer:
			return L
	return {}

## 層の、1階に置く燐晶の目安(kg。Balance.CRYSTAL_SCALE をかける前)。無ければ 0
static func kg_floor(layer: int) -> float:
	return float(layer_info(layer).get("kg_floor", 0.0))

## gs.flow を、読める形にそろえる
static func sanitize(d: Variant) -> Dictionary:
	var out := {"sump": [], "sump_kg": {}, "risen": {}}
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for r in d.get("sump", []):
		if typeof(r) == TYPE_DICTIONARY and ItemDB.ITEMS.has(String(r.get("id", ""))):
			out["sump"].append({"id": String(r["id"]), "n": maxi(1, int(r.get("n", 1))), "day": int(r.get("day", 0)), "room": int(r.get("room", 0))})
	var kg: Dictionary = d.get("sump_kg", {}) if typeof(d.get("sump_kg", {})) == TYPE_DICTIONARY else {}
	for pid in kg:
		if float(kg[pid]) > 0.0:
			out["sump_kg"][String(pid)] = float(kg[pid])
	var rs: Dictionary = d.get("risen", {}) if typeof(d.get("risen", {})) == TYPE_DICTIONARY else {}
	for k in rs:
		var r: Variant = rs[k]
		if typeof(r) == TYPE_DICTIONARY:
			out["risen"][String(k)] = {"n": int(r.get("n", 1)), "day": int(r.get("day", 0))}
	return out

# ---------- 潜行の終わり(街へ戻る、全滅する) ----------

## 見つけたのに調べなかった遺体の数(この階で)
static func unattended(fl: FloorInstance) -> int:
	var m := fl.map
	var n := 0
	for e in fl.ground.entries:
		if String(e["kind"]) != "corpse" or bool(e["searched"]) or bool(e.get("scorched", false)):
			continue
		var c := m.cell_of(e["pos"])
		if m.in_bounds(c.x, c.y) and m.explored[m.idx(c.x, c.y)] == 1:
			n += 1
	return n

## 潜行が終わったとき(gs.day を進める前に呼ぶ)。放っておいた遺体は、次の夜、一つ下の階で骨亡者になる。
## 起き上がる遺体の数を返す(帰還の報告に使う)
static func end_dive(gs: GameState, floors: Dictionary) -> int:
	var risen: Dictionary = gs.flow["risen"]
	for k in risen.keys():
		if int(risen[k]["day"]) <= gs.day:
			risen.erase(k)          # 前の夜のぶんは、もう層に紛れた
	var total := 0
	for n in floors:
		var fl: FloorInstance = floors[n]
		if fl == null or not is_instance_valid(fl) or fl.arena or fl.floor_no + 1 > SUMP_FLOOR:
			continue
		var u := unattended(fl)
		if u <= 0:
			continue
		total += u
		var key := str(fl.floor_no + 1)
		var had := int(risen[key]["n"]) if risen.has(key) else 0
		risen[key] = {"n": mini(RISEN_MAX, had + int(ceil(u / 2.0))), "day": gs.day + 1}
	return total

## 全滅して失った物を、溜まり場へ流す(上の階で全滅したときだけ)。lost は id → 個数、bag は純度 → kg
static func to_sump(gs: GameState, floor_no: int, lost: Dictionary, bag: Dictionary) -> bool:
	if floor_no > SUMP_FLOOR or (lost.is_empty() and bag.is_empty()):
		return false
	var sump: Array = gs.flow["sump"]
	var room := gs.day % 4
	for id in lost:
		if int(lost[id]) > 0 and ItemDB.ITEMS.has(String(id)):
			sump.append({"id": String(id), "n": int(lost[id]), "day": gs.day, "room": room})
	var units := 0
	for r in sump:
		units += int(r["n"])
	while units > SUMP_MAX and not sump.is_empty():
		var r: Dictionary = sump[0]
		var cut := mini(int(r["n"]), units - SUMP_MAX)
		r["n"] = int(r["n"]) - cut
		units -= cut
		if int(r["n"]) <= 0:
			sump.remove_at(0)
	var kg: Dictionary = gs.flow["sump_kg"]
	for pid in bag:
		kg[pid] = minf(SUMP_KG_MAX, float(kg.get(pid, 0.0)) + float(bag[pid]) * 0.5)    # 半分は、落ちる途中で砕けて散る
	return true

## 溜まり場から拾った(gs.flow["sump"] から減らす)
static func take_from_sump(gs: GameState, e: Dictionary) -> void:
	if String(e["kind"]) == "crystal":
		var kg: Dictionary = gs.flow["sump_kg"]
		var pid := String(e["purity"])
		kg[pid] = maxf(0.0, float(kg.get(pid, 0.0)) - float(e["kg"]))
		if float(kg[pid]) <= 0.001:
			kg.erase(pid)
		return
	var left := int(e.get("qty", 1))
	var sump: Array = gs.flow["sump"]
	for i in range(sump.size() - 1, -1, -1):
		if left <= 0:
			break
		var r: Dictionary = sump[i]
		if String(r["id"]) != String(e["id"]):
			continue
		var cut := mini(left, int(r["n"]))
		r["n"] = int(r["n"]) - cut
		left -= cut
		if int(r["n"]) <= 0:
			sump.remove_at(i)

# ---------- 階に着いたとき(その夜、その階で一度だけ) ----------

## 階に着いたとき(仲間を置いたあと)。溜まり場の落とし物、降りてきた骨亡者、竜の気配を置く
static func on_enter(main: Node, fl: FloorInstance) -> void:
	if fl.arena or fl.visited_rooms.has("flow"):
		return
	fl.visited_rooms["flow"] = true       # 迷宮の中の記録にも残る(再開したとき、二度置かない)
	var gs: GameState = main.gs
	if fl.floor_no == SUMP_FLOOR:
		_place_sump(gs, fl)
	var r: Dictionary = gs.flow["risen"].get(str(fl.floor_no), {})
	if not r.is_empty() and int(r["day"]) == gs.day and main.dtime != null:
		if main.dtime.spawn_group(_risen_lines(int(r["n"])), "mindless", "上の階から降りてきた"):
			main.log_msg("どこかで、骨の擦れる音がする。上の階で放っておかれた遺体が、骨亡者になって降りてきたらしい。", Color(0.82, 0.78, 0.7))
	if hot_floor(fl):
		_scorch(fl)

## 溜まり場の部屋(第26階の竪坑の底。4つ)
static func sump_rooms(fl: FloorInstance) -> Array:
	var out: Array = []
	for r in fl.map.rooms:
		if String(r.get("kind", "")) == "sump":
			out.append(r)
	return out

static func _place_sump(gs: GameState, fl: FloorInstance) -> void:
	var rooms := sump_rooms(fl)
	if rooms.is_empty():
		return
	for r in gs.flow["sump"]:
		var room: Dictionary = rooms[int(r["room"]) % rooms.size()]
		var cell := fl.map.free_cell_in_room(room, [fl.up_cell, fl.down_cell])
		if cell.x < 0:
			continue
		var cen := fl.map.center_of(cell)
		for k in int(r["n"]):
			fl.ground.add_item(fl.ground._free_pos(cen, 30.0), String(r["id"]))
			fl.ground.entries[-1]["sump"] = true
	var kg: Dictionary = gs.flow["sump_kg"]
	for pid in kg:
		var left := float(kg[pid])
		var room: Dictionary = rooms[0]
		var cell := fl.map.free_cell_in_room(room, [fl.up_cell, fl.down_cell])
		if cell.x < 0:
			continue
		var cen := fl.map.center_of(cell)
		while left > 0.001:
			var piece := left if left < 0.2 else minf(left - 0.05, Dice.rng.randf_range(0.1, 0.4))     # 小さすぎるかけらを残さない
			fl.ground.add_crystal(fl.ground._free_pos(cen, 34.0), String(pid), piece)
			fl.ground.entries[-1]["sump"] = true
			left -= piece

## 溜まり場の部屋に、上で失くした物が積もっているか(部屋に入ったときのログ)
static func sump_has_lost(fl: FloorInstance, room: Dictionary) -> bool:
	var m := fl.map
	var rid := int(room.get("id", -1))
	for e in fl.ground.entries:
		if e.get("sump", false):
			var c := m.cell_of(e["pos"])
			if m.in_bounds(c.x, c.y) and m.room_at[m.idx(c.x, c.y)] == rid:
				return true
	return false

## 骨亡者の群れ(書き出しの monsters[] の形)。骨が多く、腐った体が少し
static func _risen_lines(n: int) -> Array:
	var mons := {}
	for m in EncounterGen.data().get("monsters", []):
		if String(m["i"]) in ["skeleton", "zombie"]:
			mons[String(m["i"])] = m
	var lines: Array = []
	var nz := int(n / 3)
	var ns := n - nz
	if mons.has("skeleton") and ns > 0:
		lines.append(EncounterGen.mon_line({"m": mons["skeleton"], "n": ns, "world": "骨亡者"}))
	if mons.has("zombie") and nz > 0:
		lines.append(EncounterGen.mon_line({"m": mons["zombie"], "n": nz, "world": "骨亡者"}))
	return lines

# ---------- 吐く夜に、下の層から上がってくる魔物 ----------

## 一つ下の層の舞台とレベル({theme, level})。下が無ければ {}
static func below(fl: FloorInstance, level: int) -> Dictionary:
	var L := layer_info(fl.layer_no + 1)
	if L.is_empty():
		return {}
	var th := String(L.get("theme", ""))
	var tinfo: Dictionary = EncounterGen.data().get("themes", {}).get(th, {})
	if tinfo.is_empty():
		return {}
	var lv := int(tinfo.get("level", level))
	if th == String(fl.map.data["meta"].get("theme", "")):
		lv = level + 1            # 同じ舞台の層(第1層の下は第2層)は、少しだけ強い群れ
	return {"theme": th, "level": clampi(lv, level, level + BELOW_LEVEL_MAX)}

# ---------- 竜の気配(第7層から下、吐く夜) ----------

## 竜の気配がする階か(第7層から下の、吐く夜)
static func hot_floor(fl: FloorInstance) -> bool:
	return fl.exhale and fl.layer_no >= HOT_LAYER and not fl.arena

## 遺体を焦がし、縁に硫黄の華を置く
static func _scorch(fl: FloorInstance) -> void:
	for e in fl.ground.entries:
		if String(e["kind"]) == "corpse" and Dice.rng.randf() < SCORCH_P:
			e["scorched"] = true
	if not ItemDB.ITEMS.has("iou_hana"):
		return
	var cells := rim_cells(fl, 1, 4)
	if cells.is_empty():
		return
	for i in Dice.rng.randi_range(int(SULFUR_N[0]), int(SULFUR_N[1])):
		var c: Vector2i = cells[Dice.rng.randi_range(0, cells.size() - 1)]
		fl.ground.add_item(fl.ground._jitter_in_cell(c), "iou_hana")

## 縦穴のまわり、lo〜hi マスの床
static func rim_cells(fl: FloorInstance, lo: int, hi: int) -> Array:
	var m := fl.map
	var sh: Dictionary = m.data.get("shaft", {})
	if not sh.has("x"):
		return []
	var r0 := Rect2i(int(sh["x"]), int(sh["y"]), int(sh["w"]), int(sh["h"]))
	var out: Array = []
	for y in range(r0.position.y - hi, r0.end.y + hi):
		for x in range(r0.position.x - hi, r0.end.x + hi):
			if not m.in_bounds(x, y) or r0.grow(lo - 1).has_point(Vector2i(x, y)):
				continue
			var t := m.tiles[m.idx(x, y)]
			if t == FloorMap.ROOM or t == FloorMap.CORR:
				out.append(Vector2i(x, y))
	return out

## 熱い縁に立っている仲間を焼く(DungeonTime が毎コマ呼ぶ。吐く夜の夜の間だけ)
static func heat(main: Node, fl: FloorInstance, delta: float) -> void:
	if fl.abyss == null or not fl.abyss._ok:
		return
	for h in main.heroes:
		if h.down or not fl.abyss.on_rim(h.position):
			h.heat_t = minf(h.heat_t, 0.6)      # 縁に戻ったら、すぐ熱い
			continue
		h.heat_t -= delta
		if h.heat_t > 0.0:
			continue
		h.heat_t = HEAT_EVERY
		if not fl.visited_rooms.has("hot"):
			fl.visited_rooms["hot"] = true
			main.log_msg("縦穴の縁が、焼けるように熱い。底で、何か大きなものが息をしている。", Color("ffb070"))
		Sfx.cue(fl, h.position, "heat")
		h.damage(maxf(1.0, Dice.roll(HEAT_DMG) * Balance.TRAP_DMG_SCALE * (1.0 - h.ch.skill_fx("survival"))), h.position + Vector2(0, 1), true)
