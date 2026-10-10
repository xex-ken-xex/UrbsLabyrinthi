class_name FloorInstance
extends Node2D
## 潜っている最中の1層。地図、魔物、落ちているもの、罠、探索の跡を持ち、床を描く。
## 層を離れても捨てずに控えておく。戻ると、扉の開き具合も倒した魔物もそのまま。

signal message(text: String, kind: String)
signal enemy_killed(enemy: Enemy)
signal ground_picked(entry: Dictionary, hero: Hero)   # 落ちているものを拾った

var map: FloorMap
var style: Dictionary
var col := {}
var floor_no := 1
var night_no := 0
var heroes: Array = []        # Hero(パーティ全員。Main が持つ体への参照)
var leader: Hero = null
var enemies: Array = []
var ground := GroundItems.new()   # 光る燐晶、自生物、遺体、落とし物
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
var arena := false            # 闘技場(階段は上りだけ。魔物は後から出す)
var enc_serial := 5000
var tex := {}                 # 差し替え画像(床、壁、通路、アイコン)
var _tex_ver := -1

func _init() -> void:
	process_physics_priority = 100     # 魔物と仲間が動いたあとに、押し合いを決める

func _physics_process(delta: float) -> void:
	var bodies: Array = []
	for h in heroes:
		if h.is_alive():
			bodies.append(h)
	# 広い層では、仲間から遠い魔物(動かない)を、押し合いの計算に入れない
	for e in enemies:
		if not e.dead and _near_hero(e.position, NEAR_SIM):
			bodies.append(e)
	Contact.step(delta, bodies)
	ground.update(delta)

static func create_from_dict(d: Dictionary) -> FloorInstance:
	var fi := FloorInstance.new()
	fi.setup(FloorMap.new(d))
	return fi

## 舞台の色などを替える(闘技場で、舞台を切り替えたとき)
func set_style(st: Dictionary) -> void:
	style = st
	col = {}
	for k in st.get("col", {}):
		col[k] = Color.html(String(st["col"][k]))
	queue_redraw()

## 遭遇を、center のまわりに出す。出した魔物の数を返す
func spawn_encounter(monsters: Array, kind: String, center: Vector2, activity: String = "") -> Array:
	enc_serial += 1
	var eid := enc_serial
	enc_total[eid] = 0
	enc_dead[eid] = 0
	var out: Array = []
	var k := 0
	for m in monsters:
		for i in int(m["count"]):
			var en := Enemy.new()
			var pos := center
			for tries in 12:
				var ang := k * 2.399963 + tries * 0.7
				var rad := 14.0 + 15.0 * sqrt(float(k)) * (1.0 - tries * 0.07)
				pos = center + Vector2.from_angle(ang) * rad
				if not map.circle_blocked(pos, 12.0):
					break
			en.setup(self, m, {"id": eid, "kind": kind, "attitude": "敵対", "activity": activity}, pos)
			en.state = "chase"
			en.died.connect(_on_enemy_died)
			add_child(en)
			enemies.append(en)
			enc_total[eid] += 1
			out.append(en)
			k += 1
	return out

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
	ground.setup(self)
	ground.spawn_all()
	_spawn_enemies()

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
	enc_dead[en.enc_id] = int(enc_dead.get(en.enc_id, 0)) + 1
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

const NEAR_SIM := 520.0     # これより遠い魔物は、押し合いの計算に入れない

func _near_hero(p: Vector2, r: float) -> bool:
	var r2 := r * r
	for h in heroes:
		if (h.position - p).length_squared() < r2:
			return true
	return false

func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(h & 255) / 255.0

func _refresh_tex() -> void:
	if _tex_ver == Assets.version:
		return
	_tex_ver = Assets.version
	var th := String(map.data["meta"].get("theme", ""))
	tex = {
		"floor": Assets.first(["floor_" + th, "floor"]),
		"wall": Assets.first(["wall_" + th, "wall"]),
		"corr": Assets.first(["corr_" + th, "corr", "floor_" + th, "floor"]),
		# ばらつき用(_2、_3)。置いた「floor」(1枚)があるときは使わず、その1枚だけで敷く
		"floor_v": _variants("floor", th),
		"wall_v": _variants("wall", th),
		"walltop": _walltop(th),
		"door": Assets.first(["door_" + th, "door"]),
		"door_open": Assets.first(["door_open_" + th, "door_open"]),
		"stairs_up": Assets.texture("icon_stairs_up"),
		"stairs_down": Assets.texture("icon_stairs_down"),
		"trap": Assets.texture("icon_trap"),
	}

## 「floor_舞台」「floor_舞台_2」「floor_舞台_3」…を集める。同梱の絵が小さい(ドット絵)ときは、ぼかさず拡大する
func _variants(kind: String, th: String) -> Array:
	var out: Array = []
	if Assets.texture(kind, false) != null and Assets.texture("%s_%s" % [kind, th], false) == null:
		return out
	for suffix in ["", "_2", "_3", "_4"]:
		var t := Assets.texture("%s_%s%s" % [kind, th, suffix], true)
		if t != null:
			out.append(t)
	return out

## 壁の天面。壁の絵だけを置き換えたときは、同梱の天面と食い違うので使わず、置いた壁の絵で通す
func _walltop(th: String) -> Texture2D:
	var user_top := Assets.first(["walltop_" + th, "walltop"], false)
	if user_top != null:
		return user_top
	if Assets.first(["wall_" + th, "wall"], false) != null:
		return null
	return Assets.texture("walltop_" + th, true)

func _is_rock(x: int, y: int) -> bool:
	return map.in_bounds(x, y) and map.tiles[map.idx(x, y)] == FloorMap.ROCK

func _pick(variants: Array, fallback: Texture2D, x: int, y: int) -> Texture2D:
	if variants.size() <= 1:
		return fallback
	# 1枚目を多めにして、ばらつきを控えめにする
	var h := _hash(x, y)
	return variants[0] if h < 0.7 else variants[1 + int((h - 0.7) / 0.3 * (variants.size() - 1)) % (variants.size() - 1)]

func _draw() -> void:
	_refresh_tex()
	# 小さな絵(ドット絵)は、ぼかさずに拡大する。大きな絵は、縮めたときにざらつかないようにぼかす
	var small: bool = tex["floor"] != null and tex["floor"].get_width() <= 64
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if small else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var C := float(Balance.CELL)
	var rock: Color = col.get("rock", Color("111111"))
	var floor_a: Color = col.get("floor", Color("444444"))
	var wall: Color = floor_a.darkened(0.5).lerp(rock.lightened(0.2), 0.3)   # 壁は床より暗く、未踏の黒とは区別がつく明るさ
	var floor_b: Color = col.get("floor2", Color("4a4a4a"))
	var corr: Color = col.get("corr", Color("3a3a3a"))
	var glow: Color = col.get("glow", Color("ffffaa"))
	var lc := Vector2(light_pos.x / C, light_pos.y / C)
	var R := float(Balance.LIGHT_RADIUS)
	# 広い層では、画面に入るマスだけを描く
	var vr := (get_global_transform().affine_inverse() * get_canvas_transform().affine_inverse()) * Rect2(Vector2.ZERO, get_viewport_rect().size)
	vr = vr.grow(C * 3.0)
	var cx0 := clampi(int(floor(vr.position.x / C)), 0, map.w - 1)
	var cx1 := clampi(int(ceil(vr.end.x / C)), 0, map.w - 1)
	var cy0 := clampi(int(floor(vr.position.y / C)), 0, map.h - 1)
	var cy1 := clampi(int(ceil(vr.end.y / C)), 0, map.h - 1)
	for y in range(cy0, cy1 + 1):
		for x in range(cx0, cx1 + 1):
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
				if map.wall_adj[i] == 1 and tex["wall"] != null:
					var face_side := tex["walltop"] == null or not _is_rock(x, y + 1)    # 南が床なら、壁の正面
					if face_side:
						draw_texture_rect(_pick(tex["wall_v"], tex["wall"], x, y), rect, false, _shade(Color.WHITE, f))
					else:
						draw_texture_rect(tex["walltop"], rect, false, _shade(Color.WHITE, f))
						# 床に面した縁に、細い明るい線(天面の角)
						var rim := _shade(Color(0.7, 0.7, 0.78), f)
						rim.a = 0.22
						for dv in FloorMap.DIRS4:
							if not _is_rock(x + dv.x, y + dv.y) and map.in_bounds(x + dv.x, y + dv.y):
								var a2 := rect.position + Vector2(C if dv.x > 0 else 0.0, C if dv.y > 0 else 0.0)
								draw_line(a2, a2 + (Vector2(0, C) if dv.x != 0 else Vector2(C, 0)), rim, 1.0)
				elif map.wall_adj[i] == 1:
					draw_rect(rect, _shade(wall, f))
					# 床に面した縁に明るい線を引いて、壁の輪郭を出す(差し替え画像のときは引かない)
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
					if tex["wall"] != null:
						draw_texture_rect(tex["wall"], rect, false, _shade(Color.WHITE, f))
					else:
						draw_rect(rect, _shade(wall, f))
					continue
				if tex["corr"] != null:
					draw_texture_rect(tex["corr"], rect, false, _shade(Color.WHITE, f))
				else:
					draw_rect(rect, _shade(corr, f))
				_draw_door(d, rect, f)
				continue
			var ftex: Texture2D = tex["corr"] if t == FloorMap.CORR else _pick(tex["floor_v"], tex["floor"], x, y)
			if ftex != null:
				draw_texture_rect(ftex, rect, false, _shade(Color.WHITE, f))
			else:
				draw_rect(rect, _shade(base, f))
			# 壁の正面の真下の床に、影を落とす(壁が立って見える)
			if tex["walltop"] != null and map.wall_adj[map.idx(x, y - 1)] == 1 and _is_rock(x, y - 1):
				for k in 4:
					draw_rect(Rect2(rect.position.x, rect.position.y + k * 3.0, C, 3.0), Color(0, 0, 0, _shade(Color.WHITE, f).r * (0.42 - k * 0.1)))
	# 階段
	_draw_stairs(up_cell, true, glow)
	if not arena:
		_draw_stairs(down_cell, false, glow)
	# 落ちているもの(光る燐晶、自生物、遺体)
	ground.draw(self, vr)
	# 罠
	for t in traps:
		if t["st"] == "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if map.explored[map.idx(tc.x, tc.y)] == 0:
			continue
		var cen := map.center_of(tc)
		var a := 0.9 if t["st"] == "revealed" else 0.35
		if tex["trap"] != null:
			draw_texture_rect(tex["trap"], Rect2(cen - Vector2(C, C) / 2.0, Vector2(C, C)), false, Color(1, 1, 1, a))
			continue
		var cc2 := Color(0.9, 0.25, 0.2, a)
		draw_line(cen + Vector2(-8, -8), cen + Vector2(8, 8), cc2, 2.5)
		draw_line(cen + Vector2(-8, 8), cen + Vector2(8, -8), cc2, 2.5)

func _shade(c: Color, f: float) -> Color:
	var k := f * 1.3
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0)

func _draw_door(d: Dictionary, rect: Rect2, f: float) -> void:
	var tall: bool = d["axis"] == "ew"       # 東西に抜ける扉は、縦長の板
	var dt: Texture2D = tex["door_open"] if d["open"] else tex["door"]
	if dt != null:
		var tint := _shade(Color.WHITE, f)
		if d["type"] == "locked" and not d["unlocked"]:
			tint = _shade(Color(1.0, 0.55, 0.5), f)
		elif d["type"] == "secret":
			tint = _shade(Color(0.6, 0.9, 1.0), f)
		if tall:
			draw_texture_rect(dt, rect, false, tint)
		else:                                  # 南北に抜ける扉は、90度回す
			draw_set_transform(rect.get_center(), PI / 2.0, Vector2.ONE)
			draw_texture_rect(dt, Rect2(-rect.size / 2.0, rect.size), false, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if d["type"] == "locked" and not d["unlocked"] and not d["open"]:
			draw_circle(rect.get_center(), 3.0, _shade(Color("e0c070"), f))
		return
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
	var icon: Texture2D = tex["stairs_up"] if up else tex["stairs_down"]
	if icon != null:
		draw_texture_rect(icon, Rect2(c - Vector2(C, C) / 2.0, Vector2(C, C)), false, Color(k, k, k))
		return
	var col2 := _shade(glow, k)
	var pts := PackedVector2Array()
	if up:
		pts = PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 9), c + Vector2(-11, 9)])
	else:
		pts = PackedVector2Array([c + Vector2(0, 11), c + Vector2(11, -9), c + Vector2(-11, -9)])
	draw_colored_polygon(pts, Color(col2.r, col2.g, col2.b, 0.35))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col2, 2.0)
	UI.text_center(self, c.x, c.y + 4.0, "上" if up else "下", 11, col2)
