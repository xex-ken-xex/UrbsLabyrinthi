class_name FloorMap
extends RefCounted
## 1層ぶんの地図。Urbs Labyrinthi が書き出した JSON(urbs-labyrinthi/0.1)を読み、
## 通れるか、見通せるか、どこから見えるかを答える。描画も敵も知らない。

const ROCK := 0
const ROOM := 1
const CORR := 2
const DOOR := 3
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var data: Dictionary
var w := 0
var h := 0
var tiles := PackedByteArray()
var room_at := PackedInt32Array()
var explored := PackedByteArray()
var visible := PackedByteArray()
var wall_adj := PackedByteArray()      # 岩のうち、床に接しているもの(壁として描く)
var doors: Array = []
var door_at := {}                      # マスの番号 → 扉
var rooms: Array = []
var room_by_id := {}
var room_cells := {}                   # 部屋の id → マス番号の配列

## 層のファイルを読む。.json.gz(gzip。pck を小さくするため)でも、.json でも
static func read_json(path: String) -> Variant:
	if path.ends_with(".gz"):
		var raw := FileAccess.get_file_as_bytes(path)
		if raw.is_empty():
			return null
		return JSON.parse_string(raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text) if text != "" else null

static func floor_path(depth: int, night: int, party: int) -> String:
	return "res://data/floors/f%02d_n%02d_p%d.json.gz" % [depth, night, clampi(party, 1, 4)]

static func load_file(path: String) -> FloorMap:
	var parsed: Variant = read_json(path)
	if parsed == null:
		push_error("読めない: " + path)
		return null
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON が壊れている: " + path)
		return null
	return FloorMap.new(parsed)

func _init(d: Dictionary) -> void:
	data = d
	w = int(d["meta"]["grid"]["width"])
	h = int(d["meta"]["grid"]["height"])
	tiles.resize(w * h)
	var rows: Array = d["grid"]
	for y in h:
		var row: String = rows[y]
		for x in w:
			match row[x]:
				".": tiles[y * w + x] = ROOM
				",": tiles[y * w + x] = CORR
				"+": tiles[y * w + x] = DOOR
				_: tiles[y * w + x] = ROCK
	explored.resize(w * h)
	visible.resize(w * h)
	for dd in d["doors"]:
		var door := {
			"id": int(dd["id"]), "x": int(dd["x"]), "y": int(dd["y"]),
			"axis": String(dd["axis"]), "type": String(dd["type"]),
			"lock_dc": int(dd.get("lock_dc", 0)), "find_dc": int(dd.get("find_dc", 0)),
			"open": false, "found": dd["type"] != "secret", "unlocked": dd["type"] != "locked",
		}
		doors.append(door)
		door_at[int(dd["y"]) * w + int(dd["x"])] = door
	wall_adj.resize(w * h)
	for y in h:
		for x in w:
			if tiles[y * w + x] != ROCK:
				continue
			for dv in DIRS8:
				var nx: int = x + dv.x
				var ny: int = y + dv.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and tiles[ny * w + nx] != ROCK:
					wall_adj[y * w + x] = 1
					break
	rooms = d["rooms"]
	room_at.resize(w * h)
	room_at.fill(-1)
	for r in rooms:
		room_by_id[int(r["id"])] = r
		var seed_cell := _room_seed(r)
		if seed_cell.x >= 0:
			_flood_room(seed_cell, int(r["id"]))

func idx(x: int, y: int) -> int:
	return y * w + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

func _room_seed(r: Dictionary) -> Vector2i:
	var c: Array = r["center"]
	var cx := int(c[0])
	var cy := int(c[1])
	if in_bounds(cx, cy) and tiles[idx(cx, cy)] == ROOM:
		return Vector2i(cx, cy)
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for y in range(int(r["y"]), int(r["y"]) + int(r["h"])):
		for x in range(int(r["x"]), int(r["x"]) + int(r["w"])):
			if in_bounds(x, y) and tiles[idx(x, y)] == ROOM:
				var dd := (x - cx) * (x - cx) + (y - cy) * (y - cy)
				if dd < bd:
					bd = dd
					best = Vector2i(x, y)
	return best

func _flood_room(start: Vector2i, id: int) -> void:
	var cells := PackedInt32Array()
	var stack: Array[Vector2i] = [start]
	room_at[idx(start.x, start.y)] = id
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		cells.append(idx(c.x, c.y))
		for dv in DIRS4:
			var n: Vector2i = c + dv
			if in_bounds(n.x, n.y) and tiles[idx(n.x, n.y)] == ROOM and room_at[idx(n.x, n.y)] < 0:
				room_at[idx(n.x, n.y)] = id
				stack.append(n)
	room_cells[id] = cells

# ---------- 通れるか、見通せるか ----------

## 岩と、開いていない扉。移動も視線もこれでふさがる
func opaque(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	var t := tiles[idx(x, y)]
	if t == ROCK:
		return true
	if t == DOOR:
		return not door_at[idx(x, y)]["open"]
	return false

## 魔物が経路に使えるマス。閉じた普通の扉は、近づけば自分で開ける
func monster_passable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t := tiles[idx(x, y)]
	if t == ROCK:
		return false
	if t == DOOR:
		var d: Dictionary = door_at[idx(x, y)]
		if d["open"]:
			return true
		if d["type"] == "secret" and not d["found"]:
			return false
		if d["type"] == "locked" and not d["unlocked"]:
			return false
	return true

func circle_blocked(p: Vector2, r: float) -> bool:
	var c := float(Balance.CELL)
	var x0 := int(floor((p.x - r) / c))
	var x1 := int(floor((p.x + r) / c))
	var y0 := int(floor((p.y - r) / c))
	var y1 := int(floor((p.y + r) / c))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if not opaque(cx, cy):
				continue
			var nx := clampf(p.x, cx * c, (cx + 1) * c)
			var ny := clampf(p.y, cy * c, (cy + 1) * c)
			if (p - Vector2(nx, ny)).length_squared() < r * r:
				return true
	return false

## 軸ごとに動かして、壁に沿って滑らせる
func move_circle(p: Vector2, delta: Vector2, r: float) -> Vector2:
	var np := p + Vector2(delta.x, 0.0)
	if circle_blocked(np, r):
		np = p
	var np2 := np + Vector2(0.0, delta.y)
	if circle_blocked(np2, r):
		np2 = np
	return np2

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / Balance.CELL)), int(floor(p.y / Balance.CELL)))

func center_of(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * Balance.CELL, (c.y + 0.5) * Balance.CELL)

# ---------- 視界 ----------

func los(ax: int, ay: int, bx: int, by: int) -> bool:
	return _ray(ax, ay, bx, by) or _ray(bx, by, ax, ay)

func _ray(x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	while not (x == x1 and y == y1):
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		if x == x1 and y == y1:
			break
		if opaque(x, y):
			return false
	return true

## 駒のいるマスから見えるところを求め、「見たことがある」に足す。灯りのある部屋は丸ごと見える
func compute_visible(px: int, py: int, radius: int) -> void:
	visible.fill(0)
	var r2 := radius * radius
	for y in range(maxi(0, py - radius), mini(h, py + radius + 1)):
		for x in range(maxi(0, px - radius), mini(w, px + radius + 1)):
			var dx := x - px
			var dy := y - py
			if dx * dx + dy * dy > r2:
				continue
			if los(px, py, x, y):
				var i := idx(x, y)
				visible[i] = 1
				explored[i] = 1
	var rid := room_at[idx(px, py)] if in_bounds(px, py) else -1
	if rid >= 0 and room_by_id[rid].get("lit", false):
		for i in room_cells[rid]:
			var cx: int = i % w
			var cy: int = i / w
			for dv in DIRS8:
				var nx: int = cx + dv.x
				var ny: int = cy + dv.y
				if in_bounds(nx, ny):
					visible[idx(nx, ny)] = 1
					explored[idx(nx, ny)] = 1
			visible[i] = 1
			explored[i] = 1

# ---------- 魔物の経路 ----------

## 目標のマスからの歩数。魔物は、これが小さくなる方へ進む
func compute_flow(tx: int, ty: int, max_d: int = 48) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	if not in_bounds(tx, ty):
		return dist
	var q := PackedInt32Array()
	q.append(idx(tx, ty))
	dist[idx(tx, ty)] = 0
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		var d := dist[c]
		if d >= max_d:
			continue
		var cx := c % w
		var cy := c / w
		for dv in DIRS4:
			var nx: int = cx + dv.x
			var ny: int = cy + dv.y
			if not monster_passable(nx, ny):
				continue
			var ni := idx(nx, ny)
			if dist[ni] >= 0:
				continue
			dist[ni] = d + 1
			q.append(ni)
	return dist

## from から、flow を下る(または上る)隣のマス。なければ (-1,-1)
func flow_step(flow: PackedInt32Array, from: Vector2i, descend: bool = true) -> Vector2i:
	if not in_bounds(from.x, from.y):
		return Vector2i(-1, -1)
	var cur := flow[idx(from.x, from.y)]
	var best := Vector2i(-1, -1)
	var best_d := cur
	for dv in DIRS8:
		var n: Vector2i = from + dv
		if not monster_passable(n.x, n.y):
			continue
		if dv.x != 0 and dv.y != 0:
			if not monster_passable(from.x + dv.x, from.y) or not monster_passable(from.x, from.y + dv.y):
				continue
		var nd := flow[idx(n.x, n.y)]
		if nd < 0:
			continue
		if descend:
			if cur < 0 or nd < best_d:
				best_d = nd
				best = n
		elif nd > best_d:
			best_d = nd
			best = n
	return best

func doors_near(p: Vector2, dist: float) -> Array:
	var out: Array = []
	for d in doors:
		if p.distance_to(center_of(Vector2i(d["x"], d["y"]))) <= dist:
			out.append(d)
	return out

## 部屋の中で、中心に近い順に空いているマスを返す(宝箱などの置き場)
func free_cell_in_room(room: Dictionary, avoid: Array) -> Vector2i:
	var rid := int(room["id"])
	if not room_cells.has(rid):
		return Vector2i(-1, -1)
	var c: Array = room["center"]
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for i in room_cells[rid]:
		var cx: int = i % w
		var cy: int = i / w
		var cell := Vector2i(cx, cy)
		var ok := true
		for a in avoid:
			if absi(a.x - cx) + absi(a.y - cy) < 2:
				ok = false
				break
		if not ok:
			continue
		var dd := (cx - int(c[0])) * (cx - int(c[0])) + (cy - int(c[1])) * (cy - int(c[1]))
		# 中心から2〜3マス離れたところを好む
		var score := absi(dd - 5)
		if score < bd:
			bd = score
			best = cell
	return best
