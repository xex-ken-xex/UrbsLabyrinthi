class_name FloorInstance
extends Node2D
## 潜っている最中の1層。地図、魔物、宝箱、罠、探索の跡を持ち、床を描く。
## 層を離れても捨てずに控えておく。戻ると、扉の開き具合も倒した魔物もそのまま。

signal message(text: String, kind: String)
signal enemy_killed(enemy: Enemy)

var map: FloorMap
var style: Dictionary
var col := {}
var floor_no := 1
var night_no := 0
var player: Player
var enemies: Array = []
var chests: Array = []        # {cell, silver, items, taken}
var traps: Array = []         # 書き出しの罠 + st(hidden / revealed / triggered / disarmed)
var up_cell := Vector2i.ZERO
var down_cell := Vector2i.ZERO
var flow := PackedInt32Array()
var flow_cell := Vector2i(-1, -1)
var visited_rooms := {}
var enc_total := {}
var enc_dead := {}
var light_pos := Vector2.ZERO
var exhale := false

static func create(path: String) -> FloorInstance:
	var m := FloorMap.load_file(path)
	if m == null:
		return null
	var fi := FloorInstance.new()
	fi.setup(m)
	return fi

func setup(m: FloorMap) -> void:
	map = m
	var d := m.data
	style = d.get("style", {})
	for k in style.get("col", {}):
		col[k] = Color.html(String(style["col"][k]))
	floor_no = int(d["meta"]["floor"])
	night_no = int(d["meta"]["night"])
	exhale = bool(d["meta"].get("exhale", false))
	up_cell = Vector2i(int(d["stairs"]["up"]["x"]), int(d["stairs"]["up"]["y"]))
	down_cell = Vector2i(int(d["stairs"]["down"]["x"]), int(d["stairs"]["down"]["y"]))
	for t in d["traps"]:
		var tt: Dictionary = t.duplicate()
		tt["st"] = "hidden"
		traps.append(tt)
	_spawn_chests()
	_spawn_enemies()

func _spawn_chests() -> void:
	var avoid: Array = [up_cell, down_cell]
	for e in map.data["encounters"]:
		for t in e["tokens"]:
			avoid.append(Vector2i(int(t["x"]), int(t["y"])))
	for r in map.rooms:
		var tr: Variant = r.get("treasure")
		if typeof(tr) != TYPE_DICTIONARY:
			continue
		var cell := map.free_cell_in_room(r, avoid)
		if cell.x < 0:
			continue
		avoid.append(cell)
		chests.append({"cell": cell, "silver": int(tr.get("silver", 0)), "gp": int(tr.get("gp", 0)),
			"items": tr.get("items", []), "taken": false, "room": int(r["id"])})

func _spawn_enemies() -> void:
	for e in map.data["encounters"]:
		var eid := int(e["id"])
		enc_total[eid] = 0
		enc_dead[eid] = 0
		for t in e["tokens"]:
			var mons: Array = e["monsters"]
			var m: Dictionary = mons[int(t["g"])]
			var en := Enemy.new()
			en.setup(self, m, e, map.center_of(Vector2i(int(t["x"]), int(t["y"]))))
			en.died.connect(_on_enemy_died)
			add_child(en)
			enemies.append(en)
			enc_total[eid] += 1

func _on_enemy_died(en: Enemy) -> void:
	enc_dead[en.enc_id] += 1
	enemies.erase(en)
	enemy_killed.emit(en)

# ---------- 魔物を束ねる ----------

func alert_encounter(eid: int) -> void:
	for en in enemies:
		if en.enc_id == eid:
			en.wake()

func alert_radius(pos: Vector2, cells: float) -> void:
	for en in enemies:
		if en.position.distance_to(pos) <= cells * Balance.CELL:
			en.wake()

func group_dead_fraction(eid: int) -> float:
	var total: int = enc_total.get(eid, 1)
	return float(enc_dead.get(eid, 0)) / float(maxi(1, total))

func spawn_text(pos: Vector2, s: String, c: Color) -> void:
	var ft := FloatText.new()
	ft.text = s
	ft.color = c
	ft.position = pos
	add_child(ft)

func map_changed() -> void:
	queue_redraw()

func update_flow(pc: Vector2i) -> void:
	if pc != flow_cell:
		flow_cell = pc
		flow = map.compute_flow(pc.x, pc.y)

func cell_of(p: Vector2) -> Vector2i:
	return map.cell_of(p)

# ---------- 描画 ----------

func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(h & 255) / 255.0

func _draw() -> void:
	var C := float(Balance.CELL)
	var rock: Color = col.get("rock", Color("111111"))
	var floor_a: Color = col.get("floor", Color("444444"))
	var wall: Color = floor_a.darkened(0.5).lerp(rock.lightened(0.2), 0.3)   # 壁は床より暗く、未踏の黒とは区別がつく明るさ
	var floor_b: Color = col.get("floor2", Color("4a4a4a"))
	var corr: Color = col.get("corr", Color("3a3a3a"))
	var glow: Color = col.get("glow", Color("ffffaa"))
	var lc := Vector2(light_pos.x / C, light_pos.y / C)
	var R := float(Balance.LIGHT_RADIUS)
	for y in map.h:
		for x in map.w:
			var i := y * map.w + x
			if map.explored[i] == 0:
				continue
			var vis := map.visible[i] == 1
			var f := 0.33
			if vis:
				var dd := Vector2(x + 0.5, y + 0.5).distance_to(lc)
				var rid := map.room_at[i]
				var lit: bool = rid >= 0 and map.room_by_id[rid].get("lit", false) and map.room_at[map.idx(int(lc.x), int(lc.y))] == rid
				f = 1.0 if lit else lerpf(1.0, 0.5, clampf((dd - 2.0) / R, 0.0, 1.0))
			var t := map.tiles[i]
			var rect := Rect2(x * C, y * C, C, C)
			if t == FloorMap.ROCK:
				if map.wall_adj[i] == 1:
					draw_rect(rect, _shade(wall, f))
					# 床に面した縁に明るい線を引いて、壁の輪郭を出す
					var edge := _shade(wall.lightened(0.45), f)
					for dv in FloorMap.DIRS4:
						var nx: int = x + dv.x
						var ny: int = y + dv.y
						if map.in_bounds(nx, ny) and map.tiles[map.idx(nx, ny)] != FloorMap.ROCK:
							var a := rect.position + Vector2(C if dv.x > 0 else 0.0, C if dv.y > 0 else 0.0)
							var b := a + (Vector2(0, C) if dv.x != 0 else Vector2(C, 0))
							draw_line(a, b, edge, 2.0)
				continue
			var base := corr if t == FloorMap.CORR else (floor_a if (x + y) % 2 == 0 else floor_b)
			base = base.lightened(_hash(x, y) * 0.06)
			if t == FloorMap.DOOR:
				var d: Dictionary = map.door_at[i]
				if d["type"] == "secret" and not d["found"]:
					draw_rect(rect, _shade(wall, f))
					continue
				draw_rect(rect, _shade(corr, f))
				_draw_door(d, rect, f)
				continue
			draw_rect(rect, _shade(base, f))
	# 階段
	_draw_stairs(up_cell, true, glow)
	_draw_stairs(down_cell, false, glow)
	# 宝箱
	for c in chests:
		if c["taken"]:
			continue
		var cc: Vector2i = c["cell"]
		if map.explored[map.idx(cc.x, cc.y)] == 0:
			continue
		var k := 1.0 if map.visible[map.idx(cc.x, cc.y)] == 1 else 0.45
		var p := Vector2(cc.x * C + 9.0, cc.y * C + 12.0)
		draw_rect(Rect2(p, Vector2(14, 10)), Color(0.55 * k, 0.38 * k, 0.12 * k))
		draw_rect(Rect2(p, Vector2(14, 4)), Color(0.8 * k, 0.6 * k, 0.2 * k))
		draw_circle(p + Vector2(7, 5), 1.6, _shade(glow, k))
	# 罠
	for t in traps:
		if t["st"] == "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if map.explored[map.idx(tc.x, tc.y)] == 0:
			continue
		var cen := map.center_of(tc)
		var a := 0.9 if t["st"] == "revealed" else 0.35
		var cc2 := Color(0.9, 0.25, 0.2, a)
		draw_line(cen + Vector2(-8, -8), cen + Vector2(8, 8), cc2, 2.5)
		draw_line(cen + Vector2(-8, 8), cen + Vector2(8, -8), cc2, 2.5)

func _shade(c: Color, f: float) -> Color:
	var k := f * 1.3
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0)

func _draw_door(d: Dictionary, rect: Rect2, f: float) -> void:
	var tall: bool = d["axis"] == "ew"       # 東西に抜ける扉は、縦長の板
	var c := Color("8a5a2b")
	if d["type"] == "locked" and not d["unlocked"]:
		c = Color("a8362b")
	elif d["type"] == "secret":
		c = Color("4aa0b0")
	c = _shade(c, f)
	var ctr := rect.get_center()
	if d["open"]:
		if tall:
			draw_rect(Rect2(rect.position.x + 1, rect.position.y, 4, rect.size.y), c)
		else:
			draw_rect(Rect2(rect.position.x, rect.position.y + 1, rect.size.x, 4), c)
	else:
		if tall:
			draw_rect(Rect2(ctr.x - 4, rect.position.y, 8, rect.size.y), c)
		else:
			draw_rect(Rect2(rect.position.x, ctr.y - 4, rect.size.x, 8), c)
		if d["type"] == "locked":
			draw_circle(ctr, 3.0, _shade(Color("e0c070"), f))

func _draw_stairs(cell: Vector2i, up: bool, glow: Color) -> void:
	if map.explored[map.idx(cell.x, cell.y)] == 0:
		return
	var C := float(Balance.CELL)
	var k := 1.0 if map.visible[map.idx(cell.x, cell.y)] == 1 else 0.5
	var c := Vector2((cell.x + 0.5) * C, (cell.y + 0.5) * C)
	var col2 := _shade(glow, k)
	var pts := PackedVector2Array()
	if up:
		pts = PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 9), c + Vector2(-11, 9)])
	else:
		pts = PackedVector2Array([c + Vector2(0, 11), c + Vector2(11, -9), c + Vector2(-11, -9)])
	draw_colored_polygon(pts, Color(col2.r, col2.g, col2.b, 0.35))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col2, 2.0)
	UI.text_center(self, c.x, c.y + 4.0, "上" if up else "下", 11, col2)
