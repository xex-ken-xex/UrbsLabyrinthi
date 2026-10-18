class_name GroundItems
extends RefCounted
## 床に落ちているもの。光る燐晶の石、迷宮に自生するもの(茸や苔)、遺体、魔物の落とし物。
## 近づくと吸い寄せられて、拾える。燐晶は袋に入り(持ち帰るとき、査定と税)、自生物は持ち物へ入る(税なし)。
## 遺体は拾わない。そばで E を押すと調べられる(中身が散らばり、遺体をこうした魔物が湧く)。
## 宝箱はない。燐晶は、露頭(壁ぎわの光る石)、宝のある部屋、遺体、倒した魔物から手に入る。

const PICK_R := 17.0           # 触れて拾う距離
const MAGNET_R := 46.0         # 吸い寄せられ始める距離
const MAGNET_SPEED := 190.0
const POP_DELAY := 0.35        # 飛び散ってから、拾えるまで
## 光る自生物(淡い光の輪を描く)
const MAGIC_GLOW := Color(0.72, 0.5, 1.0)
const GLOW := {"tomoshi_take": Color("8ad8f0"), "hikari_goke": Color("a8f0d8"), "shizuku_goke": Color("a8e0ff"), "yawaraka_hikari": Color("c8c0ff"),
	"iki_take": Color("c898f0"), "kagami_goke": Color("e8f4ff"), "inori_goke": Color("fff8d0"), "zui_mitsu": Color("fff0c0"), "sui_sho_mo": Color("e8ffff")}
const SIZE_MASS := {"T": 0.4, "S": 0.7, "M": 1.0, "L": 1.6, "H": 2.5, "G": 4.0}
const MON_DROP_BASE := {"construct": 0.5, "elemental": 0.6, "undead": 0.5, "dragon": 0.9, "humanoid": 0.45, "fiend": 0.6, "monstrosity": 0.4,
	"beast": 0.3, "ooze": 0.25, "plant": 0.2, "fey": 0.35, "aberration": 0.4, "giant": 0.5, "celestial": 0.5, "swarm": 0.12}

var fl: FloorInstance
var entries: Array = []
var theme := "generic"
var base := "mid"
var kg_factor := 1.0            # 階の燐晶を、層の目安(PhosFlow.kg_floor)に合わせた倍率(テストと測る道具が見る)
const OUTCROP_MAX := 150        # 露頭の数の上限
var _room_cells: Array = []     # Vector2i(部屋のマス)
var _corr_cells: Array = []
var _wall_cells: Array = []     # 壁に接している床のマス
var _water_cells: Array = []    # 水路か浅瀬に接している床のマス(水ぎわの自生物)
var _dead_ends: Array = []      # 通路の行き止まり(遺体の理由)

func setup(floor_inst: FloorInstance) -> void:
	fl = floor_inst
	var m := fl.map
	theme = String(m.data["meta"].get("theme", "generic"))
	base = Crystal.base_of(theme)
	for y in m.h:
		for x in m.w:
			var t := m.tiles[m.idx(x, y)]
			if t != FloorMap.ROOM and t != FloorMap.CORR:
				continue
			var c := Vector2i(x, y)
			if absi(x - fl.up_cell.x) + absi(y - fl.up_cell.y) < 3 or absi(x - fl.down_cell.x) + absi(y - fl.down_cell.y) < 3:
				continue
			(_room_cells if t == FloorMap.ROOM else _corr_cells).append(c)
			var wall := false
			var wet := false
			var open_n := 0
			for dv in FloorMap.DIRS4:
				if not m.in_bounds(x + dv.x, y + dv.y):
					continue
				var nt := m.tiles[m.idx(x + dv.x, y + dv.y)]
				wall = wall or nt == FloorMap.ROCK
				wet = wet or nt == FloorMap.WATER or nt == FloorMap.SHALLOW
				if not m.solid(x + dv.x, y + dv.y):
					open_n += 1
			if wall:
				_wall_cells.append(c)
			if wet:
				_water_cells.append(c)
			if t == FloorMap.CORR and open_n == 1:
				_dead_ends.append(c)

# ---------- 置く ----------

func add_crystal(pos: Vector2, purity: String, kg: float, vel: Vector2 = Vector2.ZERO) -> void:
	entries.append({"kind": "crystal", "id": Crystal.icon_id(purity, kg), "purity": purity, "kg": kg, "pos": pos, "vel": vel, "t": 0.0, "ph": Dice.rng.randf()})

func add_item(pos: Vector2, id: String, qty: int = 1, vel: Vector2 = Vector2.ZERO) -> void:
	if not ItemDB.ITEMS.has(id):
		return
	entries.append({"kind": "item", "id": id, "qty": qty, "pos": pos, "vel": vel, "t": 0.0, "ph": Dice.rng.randf()})

## 遺体の見た目。食い荒らす魔物の近くは骨、人型と悪魔の近くは吊るされた体(横から見た絵)、それ以外は座って息絶えた体
const CORPSE_BONES_TYPES := ["beast", "monstrosity", "dragon", "swarm", "ooze"]
const CORPSE_HANG_TYPES := ["humanoid", "fiend", "giant"]
const CORPSE_NEAR := 16.0      # この距離(マス)の中の遭遇を、遺体の原因とみなす(無ければ層でいちばん近い遭遇)

static func corpse_look(mon_type: String, mon_index: String = "") -> String:
	var t := mon_type.to_lower()
	if t.begins_with("swarm") or CORPSE_BONES_TYPES.has(t) or mon_index.contains("ghoul") or mon_index.contains("ghast"):
		return "bones"
	if CORPSE_HANG_TYPES.has(t):
		return "hang"
	return "sit"

## 遺体を置く。cause は原因の魔物(書き出しの monsters[] の1行)と遭遇の種類 {mon, kind}。無ければ {}
func add_corpse(pos: Vector2, cause: Dictionary = {}, look_as: String = "") -> void:
	var look := "sit" if look_as == "" else look_as
	if look_as == "" and not cause.is_empty():
		look = corpse_look(String(cause["mon"].get("type", "")), String(cause["mon"].get("index", "")))
	entries.append({"kind": "corpse", "id": "corpse_" + look, "look": look, "cause": cause, "searched": false,
		"pos": pos, "vel": Vector2.ZERO, "t": 0.0, "ph": Dice.rng.randf()})

## pos からいちばん近い遭遇の、先頭の魔物
func _corpse_cause(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e18
	for e in fl.map.data.get("encounters", []):
		var mons: Array = e.get("monsters", [])
		if mons.is_empty():
			continue
		for t in e["tokens"]:
			var d := fl.map.center_of(Vector2i(int(t["x"]), int(t["y"]))).distance_squared_to(pos)
			if d < bd:
				bd = d
				best = {"mon": mons[int(t["g"])], "kind": String(e.get("kind", "beast"))}
	return best

## そばの、まだ調べていない遺体(無ければ {})
func corpse_near(pos: Vector2, r: float) -> Dictionary:
	for e in entries:
		if String(e["kind"]) == "corpse" and not bool(e["searched"]) and (e["pos"] as Vector2).distance_to(pos) <= r:
			return e
	return {}

func _jitter_in_cell(c: Vector2i, spread: float = 11.0) -> Vector2:
	var cen := fl.map.center_of(c)
	for i in 6:
		var p := cen + Vector2(Dice.rng.randf_range(-spread, spread), Dice.rng.randf_range(-spread, spread))
		if not fl.map.circle_blocked(p, 5.0):
			return p
	return cen

## center のまわり radius 以内で、壁に食い込まない位置
func _free_pos(center: Vector2, radius: float) -> Vector2:
	for i in 8:
		var p := center + Vector2.from_angle(Dice.rng.randf() * TAU) * Dice.rng.randf_range(0.0, radius)
		if not fl.map.circle_blocked(p, 5.0):
			return p
	return center

func _pick_cell(prefer_wall: bool, corr_p: float = 0.0) -> Vector2i:
	if corr_p > 0.0 and not _corr_cells.is_empty() and Dice.rng.randf() < corr_p:
		return _corr_cells[Dice.rng.randi_range(0, _corr_cells.size() - 1)]
	if prefer_wall and not _wall_cells.is_empty():
		return _wall_cells[Dice.rng.randi_range(0, _wall_cells.size() - 1)]
	if _room_cells.is_empty():
		return Vector2i(-1, -1)
	return _room_cells[Dice.rng.randi_range(0, _room_cells.size() - 1)]

# ---------- 層ができたとき ----------

func spawn_all() -> void:
	if String(fl.map.data["meta"].get("floor_label", "")) == "闘技場":
		return
	var trs: Array = []
	var dep_kg := 0.0          # 宝の部屋の山(生成器の宝の kg)
	for r in fl.map.rooms:
		var tr: Variant = r.get("treasure")
		if typeof(tr) == TYPE_DICTIONARY:
			trs.append(r)
			dep_kg += _deposit_kg(tr)
	var out_kg := 0.5 * dep_kg  # 壁ぎわの露頭は、宝の半分
	# 燐の流れ: 階の燐晶(宝の山 + 露頭)を、層ごとの目安(数理モデルの kg_floor)に合わせる。山と露頭の割合はそのまま
	kg_factor = 1.0
	var target := PhosFlow.kg_floor(fl.layer_no)
	if target > 0.0:
		if dep_kg + out_kg > 0.0:
			kg_factor = target / (dep_kg + out_kg)
		else:
			out_kg = target       # 宝の部屋が無い階は、露頭だけで
	for r in trs:
		_spawn_deposit(r, r["treasure"], kg_factor)
	_spawn_outcrops(out_kg * kg_factor)
	_spawn_forage()
	_spawn_corpses()
	_spawn_rope_corpses()
	for p in fl.world_props:
		if String(p["kind"]) == "blockade":        # 封鎖令の跡には、取り残された者の遺体(骨)
			add_corpse(_free_pos(fl.map.center_of(Vector2i(int(p["x"]), int(p["y"]))) + Vector2(30, 10), 20.0), {}, "bones")
			entries[-1]["why"] = "blockade"
			entries[-1]["rank"] = "青銅"
	for r in fl.map.rooms:
		if String(r.get("kind", "")) == "sump":
			_spawn_sump(r)

## 竪坑の底の溜まり場: 上の階から落ちてきた物が積もっている(遺体の骨、遺品、燐晶のかけら)
func _spawn_sump(room: Dictionary) -> void:
	var cell := fl.map.free_cell_in_room(room, [fl.up_cell, fl.down_cell])
	if cell.x < 0:
		return
	var cen := fl.map.center_of(cell)
	for i in Dice.rng.randi_range(1, 2):
		add_corpse(_free_pos(cen, 30.0), {}, "bones")
		entries[-1]["why"] = "shaft"
	for i in Dice.rng.randi_range(2, 4):
		var id: String = ["relic_tag", "relic_coins", "relic_tools", "relic_gear", "potion", "lamp_oil"][Dice.rng.randi_range(0, 5)]
		add_item(_free_pos(cen, 34.0), id)
	for i in Dice.rng.randi_range(4, 8):
		add_crystal(_free_pos(cen, 38.0), Crystal.roll(base, Dice.rng), Dice.rng.randf_range(0.05, 0.2) * Balance.CRYSTAL_SCALE)

## 宝の部屋の山の量(生成器の宝の kg。Balance.CRYSTAL_SCALE をかける前)
func _deposit_kg(tr: Dictionary) -> float:
	var silver := int(tr.get("silver", 0))
	return float(silver) / float(Crystal.price(base)) if silver > 0 else 1.0

## 宝のある部屋に、光る石の山を置く。持ち物(治療薬、灯具、遺品)も、そばに落ちている。f は層の目安に合わせる倍率
func _spawn_deposit(room: Dictionary, tr: Dictionary, f: float = 1.0) -> void:
	var avoid: Array = [fl.up_cell, fl.down_cell]
	var cell := fl.map.free_cell_in_room(room, avoid)
	if cell.x < 0:
		return
	var kg_total := _deposit_kg(tr) * f * Balance.CRYSTAL_SCALE
	var n := clampi(int(round(kg_total / 0.1)), 2, 6)
	var ws: Array = []
	var wsum := 0.0
	for i in n:
		var w := Dice.rng.randf_range(0.5, 1.5)
		ws.append(w)
		wsum += w
	var cen := fl.map.center_of(cell)
	for i in n:
		add_crystal(_free_pos(cen, 17.0), Crystal.roll(base, Dice.rng), kg_total * float(ws[i]) / wsum)
	var items: Array = tr.get("items", [])
	for i in range(1, items.size()):
		var s := String(items[i])
		var id := "relic_gear"
		if s.contains("治療薬"):
			id = "potion"
		elif s.contains("灯具"):
			id = "lamp_oil"
		elif s.contains("道具"):
			id = "relic_tools"
		add_item(_free_pos(cen, 20.0), id)
	if Dice.rng.randf() < 0.22:
		var gid := ItemDB.roll_gear(fl.layer_no, Dice.rng)
		if gid != "":
			add_item(_free_pos(cen, 22.0), gid)
	if Dice.rng.randf() < MAGIC_PILE_CHANCE:
		var mid := ItemDB.roll_magic_drop(fl.layer_no, Dice.rng)
		if mid != "":
			add_item(_free_pos(cen, 22.0), mid)

## 壁ぎわの露頭(小さな光る石)。kg は合わせて置く量(Balance.CRYSTAL_SCALE をかける前)。
## 1個はおよそ 0.1kg。深い層で量が多いときは、数を OUTCROP_MAX までにして、1個を大きくする
func _spawn_outcrops(kg: float) -> void:
	var n := mini(OUTCROP_MAX, int(round(kg / 0.1)))
	if n <= 0:
		return
	var each := kg / n
	for i in n:
		var c := _pick_cell(true, 0.12)
		if c.x < 0:
			return
		add_crystal(_jitter_in_cell(c), Crystal.roll(base, Dice.rng), each * Dice.rng.randf_range(0.4, 1.6) * Balance.CRYSTAL_SCALE)

func _forage_table() -> Array:
	var rows: Array = []
	for key in [theme, "all"]:
		for r in ForageData.SPOTS.get(key, []):
			if int(r[3]) <= fl.layer_no:
				rows.append(r)
	return rows

func _spawn_forage() -> void:
	var rows := _forage_table()
	if rows.is_empty():
		return
	var total := 0.0
	for r in rows:
		total += float(r[1])
	var n := int(round((_room_cells.size() + _corr_cells.size()) / Balance.FORAGE_CELLS))
	for i in n:
		var pick := Dice.rng.randf() * total
		var row: Array = rows[0]
		for r in rows:
			pick -= float(r[1])
			if pick <= 0.0:
				row = r
				break
		var spot := String(row[2])
		var c := _pick_cell(spot == "wall", 0.35 if spot == "corr" else 0.0)
		if spot == "water" and not _water_cells.is_empty():
			c = _water_cells[Dice.rng.randi_range(0, _water_cells.size() - 1)]     # 水ぎわの自生物は、水路と浅瀬のそばに
		if c.x < 0:
			continue
		add_item(_jitter_in_cell(c), String(row[0]), 1 if Dice.rng.randf() < 0.8 else 2)

## 先に来て、戻らなかった者たち。上の層ほど多い。
## 死んだ場所には理由がある(設計 §11.2): 罠の手前、巣の手前(巣の魔物にやられた)、縦穴の縁(上の階から落ちた)、
## 通路の行き止まり(逃げ込んで力尽きた)。理由は調べたときにログに出る
const CORPSE_WHY := {
	"trap": "足もとの床に、仕掛けの跡がある。罠にかかったらしい。",
	"nest": "爪と牙の跡がある。この先の巣の主にやられたらしい。",
	"rim": "体じゅうの骨が折れている。上の階の縁から落ちてきたらしい。",
	"dead_end": "行き止まりに追い詰められて、ここで力尽きたらしい。",
	"shaft": "骨がばらばらに砕けている。竪坑を、上の階から落ちてきたらしい。",
	"rope": "縄でこすれた手の皮がむけている。縄梯子から落ちたらしい。",
	"blockade": "手記を握っている。最後の日付は五十年前。封鎖令で取り残され、ここで待ち続けたらしい。",
}
const CORPSE_WHY_W := {"trap": 0.25, "nest": 0.25, "rim": 0.1, "dead_end": 0.12, "": 0.28}
const RANKS := ["灰", "青銅", "銀", "黒鉄"]      # 潜行許可証の等級(層で決まる)
const EXPEDITION_P := 0.3                       # 骨の層の遺体が、120年前の遠征隊である確率

## 層の等級(第1〜2層 灰、第3〜4層 青銅、第5〜6層 銀、第7層から 黒鉄)
static func rank_of(layer: int) -> String:
	return RANKS[clampi(int((layer - 1) / 2), 0, RANKS.size() - 1)]

func _spawn_corpses() -> void:
	var cells := _room_cells.size() + _corr_cells.size()
	var n := int(round(float(cells) / 300.0 * maxf(0.3, 1.0 - 0.07 * fl.layer_no)))
	n = maxi(n, 1)
	var nests: Array = []
	for r in fl.map.rooms:
		if r.get("encounter") != null and String(r.get("kind", "")) != "lair":
			nests.append(r)
	var rim: Array = PhosFlow.rim_cells(fl, 1, 2) if fl.floor_no > 1 else []
	var traps: Array = fl.traps.filter(func(t): return not fl.map.solid(int(t["x"]), int(t["y"])))
	for i in n:
		var why := _roll_why(traps, nests, rim)
		var c := Vector2i(-1, -1)
		var nest_id := -1
		match why:
			"trap":
				var t: Dictionary = traps[Dice.rng.randi_range(0, traps.size() - 1)]
				c = fl.map.nearest_walkable(Vector2i(int(t["x"]), int(t["y"])) + FloorMap.DIRS4[Dice.rng.randi_range(0, 3)], 2)
			"nest":
				var r: Dictionary = nests[Dice.rng.randi_range(0, nests.size() - 1)]
				c = _outside_room(r)
				nest_id = int(r["id"])
			"rim":
				c = rim[Dice.rng.randi_range(0, rim.size() - 1)]
			"dead_end":
				c = _dead_ends[Dice.rng.randi_range(0, _dead_ends.size() - 1)]
		if c.x < 0:
			why = ""
			c = _pick_cell(Dice.rng.randf() < 0.5, 0.25)
		if c.x < 0:
			continue
		var p := _jitter_in_cell(c)
		add_corpse(p, _corpse_cause(p), "bones" if why == "rim" else "")
		var e: Dictionary = entries[-1]
		e["why"] = why
		e["rank"] = rank_of(fl.layer_no)
		if nest_id >= 0 and why == "nest":
			e["nest"] = nest_id
		if theme == "hone" and Dice.rng.randf() < EXPEDITION_P:
			e["expedition"] = true

## 縄梯子の下は、落ちた者の遺体が溜まる(ken 10/18: 縄梯子の近くは魔物も遺品も多い)。縄梯子ごとに 1〜2体、骨になって
const ROPE_CORPSES := [1, 2]
func _spawn_rope_corpses() -> void:
	if fl.floor_no <= 1:
		return
	for rc in fl.ropes:
		for k in Dice.rng.randi_range(ROPE_CORPSES[0], ROPE_CORPSES[1]):
			var c := fl.map.nearest_walkable(rc + Vector2i(Dice.rng.randi_range(-2, 2), Dice.rng.randi_range(-2, 2)), 3)
			if c.x < 0:
				continue
			var p := _jitter_in_cell(c)
			add_corpse(p, _corpse_cause(p), "bones")
			var e: Dictionary = entries[-1]
			e["why"] = "rope"
			e["rank"] = rank_of(fl.layer_no)

func _roll_why(traps: Array, nests: Array, rim: Array) -> String:
	var ok := {"trap": not traps.is_empty(), "nest": not nests.is_empty(), "rim": not rim.is_empty(), "dead_end": not _dead_ends.is_empty(), "": true}
	var total := 0.0
	for k in CORPSE_WHY_W:
		if ok[k]:
			total += float(CORPSE_WHY_W[k])
	var pick := Dice.rng.randf() * total
	for k in CORPSE_WHY_W:
		if not ok[k]:
			continue
		pick -= float(CORPSE_WHY_W[k])
		if pick <= 0.0:
			return k
	return ""

## 巣の部屋の外の、入口から少し離れた床(巣の手前で見張りに殺された遺体)
func _outside_room(r: Dictionary) -> Vector2i:
	var m := fl.map
	var cen: Array = r.get("center", [r["x"], r["y"]])
	var start := m.nearest_walkable(Vector2i(int(cen[0]), int(cen[1])), 4)
	if start.x < 0:
		return start
	var flow := m.compute_flow(start.x, start.y, 14)
	var rid := int(r["id"])
	var cands: Array = []
	for i in flow.size():
		var d := flow[i]
		if d < 2 or d > 14 or m.room_at[i] == rid:
			continue
		var t := m.tiles[i]
		if t == FloorMap.ROOM or t == FloorMap.CORR:
			cands.append(i)
	if cands.is_empty():
		return Vector2i(-1, -1)
	cands.sort_custom(func(a, b): return flow[a] < flow[b])
	var k: int = cands[Dice.rng.randi_range(0, mini(5, cands.size() - 1))]      # 部屋を出てすぐの所
	return Vector2i(k % m.w, k / m.w)

# ---------- 魔物が倒れたとき ----------

func drop_from_enemy(en: Enemy) -> void:
	var m: Dictionary = en.mon
	var typ := String(m.get("type", "beast"))
	if typ.begins_with("swarm"):
		typ = "swarm"
	var idx := String(m.get("index", ""))
	var cr := float(m.get("cr", 0.0))
	var mass: float = SIZE_MASS.get(String(m.get("size", "M")), 1.0)
	var p := float(MON_DROP_BASE.get(typ, 0.3)) + minf(cr, 8.0) * 0.05
	if Dice.rng.randf() < p:
		var kg := Dice.rng.randf_range(0.03, 0.13) * mass * (1.0 + minf(cr, 10.0) * 0.25) * Balance.CRYSTAL_SCALE / 0.3
		add_crystal(en.position, Crystal.roll(base, Dice.rng, minf(0.25, cr * 0.03)), kg, _burst(60.0))
	for d in ForageData.DROPS:
		var tgt := String(d[0])
		var hit := (tgt == "type:" + typ) or (tgt.begins_with("idx:") and idx.contains(tgt.substr(4)))
		if hit and Dice.rng.randf() < float(d[2]):
			add_item(en.position, String(d[1]), 1, _burst(70.0))

func _burst(speed: float) -> Vector2:
	return Vector2.from_angle(Dice.rng.randf() * TAU) * Dice.rng.randf_range(speed * 0.5, speed)

# ---------- 毎フレーム ----------

func update(delta: float) -> void:
	if entries.is_empty():
		return
	var alive: Array = []
	for h in fl.heroes:
		if is_instance_valid(h) and h.is_alive():
			alive.append(h)
	var i := entries.size() - 1
	while i >= 0:
		var e: Dictionary = entries[i]
		e["t"] = float(e["t"]) + delta
		var pos: Vector2 = e["pos"]
		var vel: Vector2 = e["vel"]
		if vel.length_squared() > 1.0:
			var np := pos + vel * delta
			if not fl.map.circle_blocked(np, 4.0):
				pos = np
			else:
				vel = Vector2.ZERO
			vel *= pow(0.004, delta)
			e["vel"] = vel
		var near: Hero = null
		var nd := MAGNET_R * MAGNET_R
		for h in alive:
			var dd: float = (h.position - pos).length_squared()
			if dd < nd:
				nd = dd
				near = h
		var done := false
		if e.get("hold", false):
			# 捨てたばかりの品: 仲間が一度離れるまでは拾わない
			if near != null and nd < HOLD_R * HOLD_R:
				near = null
			else:
				e.erase("hold")
		if near != null and float(e["t"]) > POP_DELAY:
			var d := sqrt(nd)
			if String(e["kind"]) == "corpse":
				pass          # 遺体は拾わない(E で調べる)
			elif d < PICK_R:
				fl.ground_picked.emit(e, near)
				done = true
			else:
				pos += (near.position - pos).normalized() * MAGNET_SPEED * delta
		e["pos"] = pos
		if done:
			entries.remove_at(i)
		i -= 1

const HOLD_R := 40.0      # 捨てた品は、仲間がこれより離れるまで拾わない

## 遺体を調べる。持ち物が散らばり、遺体をこうした魔物が湧く。湧いた魔物を返す
func search_corpse(e: Dictionary) -> Array:
	if bool(e["searched"]):
		return []
	e["searched"] = true
	_loot_corpse(e)
	var cause: Dictionary = e["cause"]
	if cause.is_empty() or fl.arena:
		return []
	var line: Dictionary = (cause["mon"] as Dictionary).duplicate()
	var party_n := 0
	for h in fl.heroes:
		if is_instance_valid(h) and h.is_alive():
			party_n += 1
	line["count"] = clampi(int(line.get("count", 1)), 1, maxi(1, party_n - 1))
	var made: Array = fl.spawn_encounter([line], String(cause["kind"]), e["pos"], "遺体のそばにいた")
	if not made.is_empty():
		var nm := String(line.get("world_name", line.get("name_ja", "魔物")))
		fl.message.emit("遺体の陰から、%sが現れた!" % nm, "danger")
	return made

## 調べたときに分かる、遺体の身の上(等級と、死んだ理由)。無ければ ""
static func corpse_story(e: Dictionary) -> String:
	var out := ""
	if e.get("expedition", false):
		out = "百二十年前の遠征隊の紋章をつけている。装備は古いが、作りがよい。"
	elif String(e.get("rank", "")) != "":
		out = "認識票は%s等級。" % String(e["rank"])
	out += String(CORPSE_WHY.get(String(e.get("why", "")), ""))
	return out

const RARE_WEAPON_CHANCE := 0.04     # 遺体から、珍しい武器(固有の技つき)が出る確率
const MAGIC_CORPSE_CHANCE := 0.03    # 遺体から、魔法の品が出る確率(遠征隊の遺体は MAGIC_EXPEDITION_CHANCE)
const MAGIC_EXPEDITION_CHANCE := 0.08
const MAGIC_PILE_CHANCE := 0.06      # 宝の山から、魔法の品が出る確率

func _loot_corpse(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	fl.message.emit("遺体を調べた", "info")
	Sfx.cue(fl, pos, "corpse")
	var lines := corpse_story(e)
	if lines != "":
		fl.message.emit(lines, "info")
	for k in Dice.rng.randi_range(1, 3):
		add_crystal(pos, Crystal.roll(base, Dice.rng, 0.2), Dice.rng.randf_range(0.08, 0.35) * Balance.CRYSTAL_SCALE / 0.3, _burst(110.0))
	var table := [["relic_tag", 0.6], ["relic_coins", 0.45], ["relic_tools", 0.25], ["relic_gear", 0.15], ["potion", 0.12]]
	for r in table:
		if Dice.rng.randf() < float(r[1]):
			add_item(pos, String(r[0]), 1, _burst(110.0))
	if Dice.rng.randf() < (0.35 if e.get("expedition", false) else 0.12):     # 遠征隊の装備は古いが、作りがよい
		var gid := ItemDB.roll_gear(fl.layer_no, Dice.rng)
		if gid != "":
			add_item(pos, gid, 1, _burst(110.0))
	if Dice.rng.randf() < RARE_WEAPON_CHANCE:
		add_item(pos, String(ItemDB.RARE_WEAPONS[Dice.rng.randi_range(0, ItemDB.RARE_WEAPONS.size() - 1)]), 1, _burst(110.0))
	if Dice.rng.randf() < (MAGIC_EXPEDITION_CHANCE if e.get("expedition", false) else MAGIC_CORPSE_CHANCE):
		var mid := ItemDB.roll_magic_drop(fl.layer_no, Dice.rng)
		if mid != "":
			add_item(pos, mid, 1, _burst(110.0))
	var rows := _forage_table()
	if not rows.is_empty() and Dice.rng.randf() < 0.2:
		add_item(pos, String((rows[Dice.rng.randi_range(0, rows.size() - 1)] as Array)[0]), 1, _burst(110.0))

# ---------- 描く ----------

func draw(ci: CanvasItem, view: Rect2) -> void:
	var m := fl.map
	var tms := float(Time.get_ticks_msec()) / 1000.0
	for e in entries:
		var pos: Vector2 = e["pos"]
		if not view.has_point(pos):
			continue
		var c := m.cell_of(pos)
		if not m.in_bounds(c.x, c.y) or m.explored[m.idx(c.x, c.y)] == 0:
			continue
		var k := 1.0 if m.visible[m.idx(c.x, c.y)] == 1 else 0.45
		var ph: float = e["ph"]
		match String(e["kind"]):
			"crystal":
				_draw_crystal(ci, e, pos, k, tms, ph)
			"corpse":
				var tex := ItemIcons.texture(String(e["id"]))
				if tex == null:
					tex = ItemIcons.texture("corpse")
				var up := 12.0 if String(e.get("look", "")) == "hang" else 0.0     # 吊るされた体は、上へ高く描く
				var kk := k * (0.75 if bool(e.get("searched", false)) else 1.0)
				var tint := Color(kk, kk, kk)
				if bool(e.get("scorched", false)):
					tint = Color(kk * 0.42, kk * 0.33, kk * 0.28)      # 竜の熱で焦げた遺体(PhosFlow)
				if tex != null:
					ci.draw_texture_rect(tex, Rect2(pos - Vector2(15, 16 + up), Vector2(30, 30)), false, tint)
				if not bool(e.get("searched", false)):
					_glint(ci, pos + Vector2(4, -2), tms, ph, Color("b9d8ff"), k * 0.8)
			_:
				var id := String(e["id"])
				var bob := sin(tms * 2.2 + ph * TAU) * 1.2
				var glow: Variant = GLOW.get(id)
				if glow == null and ItemDB.is_magic(id):
					glow = ItemDB.name_color(id, MAGIC_GLOW)
				if glow != null:
					var gc: Color = glow
					ci.draw_circle(pos + Vector2(0, -2), 12.0 + sin(tms * 2.0 + ph * 6.0) * 1.5, Color(gc.r, gc.g, gc.b, 0.16 * k))
				ci.draw_circle(pos + Vector2(0, 6), 6.0, Color(0, 0, 0, 0.28 * k))
				var t2 := ItemIcons.texture(id)
				if t2 != null:
					ci.draw_texture_rect(t2, Rect2(pos - Vector2(10, 12 - bob), Vector2(20, 20)), false, Color(k, k, k))
				if ItemDB.is_magic(id):
					_glint(ci, pos + Vector2(6, -10 + bob), tms, ph, ItemDB.name_color(id, MAGIC_GLOW).lightened(0.4), k)     # 魔法の品は、格の色にきらめく

func _draw_crystal(ci: CanvasItem, e: Dictionary, pos: Vector2, k: float, tms: float, ph: float) -> void:
	var purity := String(e["purity"])
	var kg := float(e["kg"])
	var col: Color = Crystal.COLORS.get(purity, Color.WHITE)
	var sz := 20.0 if kg < Crystal.SIZE_S else (26.0 if kg < Crystal.SIZE_M else 32.0)
	var pulse := 0.5 + 0.5 * sin(tms * 2.6 + ph * TAU)
	var rich := 1.0 if purity in ["high", "pure", "unk"] else 0.85
	ci.draw_circle(pos, sz * 0.95 + pulse * 3.0, Color(col.r, col.g, col.b, (0.10 + 0.08 * pulse) * k * rich))
	ci.draw_circle(pos, sz * 0.62, Color(col.r, col.g, col.b, (0.16 + 0.08 * pulse) * k * rich))
	ci.draw_circle(pos, sz * 0.32, Color(1.0, 1.0, 1.0, 0.12 * k * rich))
	ci.draw_circle(pos + Vector2(0, sz * 0.32), sz * 0.3, Color(0, 0, 0, 0.25 * k))
	var tex := ItemIcons.texture(String(e["id"]))
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(pos - Vector2(sz / 2.0, sz * 0.62), Vector2(sz, sz)), false, Color(k, k, k))
	_glint(ci, pos + Vector2(cos(ph * TAU) * sz * 0.3, -sz * 0.45), tms, ph, Color.WHITE, k)
	_glint(ci, pos + Vector2(sin(ph * TAU * 2.0) * sz * 0.35, -sz * 0.1), tms, ph + 0.5, col.lightened(0.5), k)
	if kg >= Crystal.SIZE_M:
		_glint(ci, pos + Vector2(sz * 0.3, sz * 0.05), tms, ph + 0.25, Color.WHITE, k)

## きらり。短い間だけ、十字に光る
func _glint(ci: CanvasItem, p: Vector2, tms: float, ph: float, col: Color, k: float) -> void:
	var f := fmod(tms * 1.1 + ph, 1.0)
	if f > 0.34:
		return
	var a := sin(f / 0.34 * PI)
	var r := 2.0 + 4.0 * a
	var c := Color(col.r, col.g, col.b, a * k)
	ci.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), c, 1.0)
	ci.draw_line(p - Vector2(0, r), p + Vector2(0, r), c, 1.0)
	ci.draw_circle(p, 1.0, Color(1, 1, 1, a * k))
