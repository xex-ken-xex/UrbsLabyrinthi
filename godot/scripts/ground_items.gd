class_name GroundItems
extends RefCounted
## 床に落ちているもの。光る燐晶の石、迷宮に自生するもの(茸や苔)、遺体、魔物の落とし物。
## 近づくと吸い寄せられて、拾える。燐晶は袋に入り(持ち帰るとき、査定と税)、自生物は持ち物へ入る(税なし)。
## 宝箱はない。燐晶は、露頭(壁ぎわの光る石)、宝のある部屋、遺体、倒した魔物から手に入る。

const PICK_R := 17.0           # 触れて拾う距離
const MAGNET_R := 46.0         # 吸い寄せられ始める距離
const MAGNET_SPEED := 190.0
const POP_DELAY := 0.35        # 飛び散ってから、拾えるまで
## 光る自生物(淡い光の輪を描く)
const GLOW := {"tomoshi_take": Color("8ad8f0"), "hikari_goke": Color("a8f0d8"), "shizuku_goke": Color("a8e0ff"), "yawaraka_hikari": Color("c8c0ff"),
	"iki_take": Color("c898f0"), "kagami_goke": Color("e8f4ff"), "inori_goke": Color("fff8d0"), "zui_mitsu": Color("fff0c0"), "sui_sho_mo": Color("e8ffff")}
const SIZE_MASS := {"T": 0.4, "S": 0.7, "M": 1.0, "L": 1.6, "H": 2.5, "G": 4.0}
const MON_DROP_BASE := {"construct": 0.5, "elemental": 0.6, "undead": 0.5, "dragon": 0.9, "humanoid": 0.45, "fiend": 0.6, "monstrosity": 0.4,
	"beast": 0.3, "ooze": 0.25, "plant": 0.2, "fey": 0.35, "aberration": 0.4, "giant": 0.5, "celestial": 0.5, "swarm": 0.12}

var fl: FloorInstance
var entries: Array = []
var theme := "generic"
var base := "mid"
var _room_cells: Array = []     # Vector2i(部屋のマス)
var _corr_cells: Array = []
var _wall_cells: Array = []     # 壁に接している床のマス

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
			for dv in FloorMap.DIRS4:
				if m.in_bounds(x + dv.x, y + dv.y) and m.tiles[m.idx(x + dv.x, y + dv.y)] == FloorMap.ROCK:
					_wall_cells.append(c)
					break

# ---------- 置く ----------

func add_crystal(pos: Vector2, purity: String, kg: float, vel: Vector2 = Vector2.ZERO) -> void:
	entries.append({"kind": "crystal", "id": Crystal.icon_id(purity, kg), "purity": purity, "kg": kg, "pos": pos, "vel": vel, "t": 0.0, "ph": Dice.rng.randf()})

func add_item(pos: Vector2, id: String, qty: int = 1, vel: Vector2 = Vector2.ZERO) -> void:
	if not ItemDB.ITEMS.has(id):
		return
	entries.append({"kind": "item", "id": id, "qty": qty, "pos": pos, "vel": vel, "t": 0.0, "ph": Dice.rng.randf()})

func add_corpse(pos: Vector2) -> void:
	entries.append({"kind": "corpse", "id": "corpse", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "ph": Dice.rng.randf()})

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
	var treasure_value := 0
	for r in fl.map.rooms:
		var tr: Variant = r.get("treasure")
		if typeof(tr) == TYPE_DICTIONARY:
			treasure_value += _spawn_deposit(r, tr)
	_spawn_outcrops(treasure_value)
	_spawn_forage()
	_spawn_corpses()

## 宝のある部屋に、光る石の山を置く。持ち物(治療薬、灯具、遺品)も、そばに落ちている
func _spawn_deposit(room: Dictionary, tr: Dictionary) -> int:
	var avoid: Array = [fl.up_cell, fl.down_cell]
	var cell := fl.map.free_cell_in_room(room, avoid)
	if cell.x < 0:
		return 0
	var silver := int(tr.get("silver", 0))
	var kg_total := (float(silver) / float(Crystal.price(base)) if silver > 0 else 1.0) * Balance.CRYSTAL_SCALE
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
	return silver

## 壁ぎわの露頭(小さな光る石)。宝の量に比例する
func _spawn_outcrops(treasure_value: int) -> void:
	var n := int(round(0.5 * float(treasure_value) / (0.1 * float(Crystal.price(base)))))   # 数は宝に比例。1個の量は、下で Balance.CRYSTAL_SCALE をかける
	for i in n:
		var c := _pick_cell(true, 0.12)
		if c.x < 0:
			return
		add_crystal(_jitter_in_cell(c), Crystal.roll(base, Dice.rng), Dice.rng.randf_range(0.04, 0.16) * Balance.CRYSTAL_SCALE)

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
		if c.x < 0:
			continue
		add_item(_jitter_in_cell(c), String(row[0]), 1 if Dice.rng.randf() < 0.8 else 2)

## 先に来て、戻らなかった者たち。上の層ほど多い
func _spawn_corpses() -> void:
	var cells := _room_cells.size() + _corr_cells.size()
	var n := int(round(float(cells) / 300.0 * maxf(0.3, 1.0 - 0.07 * fl.layer_no)))
	n = maxi(n, 1)
	for i in n:
		var c := _pick_cell(Dice.rng.randf() < 0.5, 0.25)
		if c.x >= 0:
			add_corpse(_jitter_in_cell(c))

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
		if near != null and float(e["t"]) > POP_DELAY:
			var d := sqrt(nd)
			if String(e["kind"]) == "corpse":
				if d < PICK_R + 4.0:
					_loot_corpse(e)
					done = true
			elif d < PICK_R:
				fl.ground_picked.emit(e, near)
				done = true
			else:
				pos += (near.position - pos).normalized() * MAGNET_SPEED * delta
		e["pos"] = pos
		if done:
			entries.remove_at(i)
		i -= 1

func _loot_corpse(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	fl.message.emit("遺体を調べた", "info")
	for k in Dice.rng.randi_range(1, 3):
		add_crystal(pos, Crystal.roll(base, Dice.rng, 0.2), Dice.rng.randf_range(0.08, 0.35) * Balance.CRYSTAL_SCALE / 0.3, _burst(110.0))
	var table := [["relic_tag", 0.6], ["relic_coins", 0.45], ["relic_tools", 0.25], ["relic_gear", 0.15], ["potion", 0.12]]
	for r in table:
		if Dice.rng.randf() < float(r[1]):
			add_item(pos, String(r[0]), 1, _burst(110.0))
	if Dice.rng.randf() < 0.12:
		var gid := ItemDB.roll_gear(fl.layer_no, Dice.rng)
		if gid != "":
			add_item(pos, gid, 1, _burst(110.0))
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
				var tex := ItemIcons.texture("corpse")
				if tex != null:
					ci.draw_texture_rect(tex, Rect2(pos - Vector2(14, 15), Vector2(28, 28)), false, Color(k, k, k))
				_glint(ci, pos + Vector2(4, -2), tms, ph, Color("b9d8ff"), k * 0.8)
			_:
				var id := String(e["id"])
				var bob := sin(tms * 2.2 + ph * TAU) * 1.2
				var glow: Variant = GLOW.get(id)
				if glow != null:
					var gc: Color = glow
					ci.draw_circle(pos + Vector2(0, -2), 12.0 + sin(tms * 2.0 + ph * 6.0) * 1.5, Color(gc.r, gc.g, gc.b, 0.16 * k))
				ci.draw_circle(pos + Vector2(0, 6), 6.0, Color(0, 0, 0, 0.28 * k))
				var t2 := ItemIcons.texture(id)
				if t2 != null:
					ci.draw_texture_rect(t2, Rect2(pos - Vector2(10, 12 - bob), Vector2(20, 20)), false, Color(k, k, k))

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
