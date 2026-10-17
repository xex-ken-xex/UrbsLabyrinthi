class_name FloorProps
extends RefCounted
## 迷宮の手ざわり(設計 §11.5): 地図屋の印、壁の落書き(七芒星・静印)、闇潜りの野営。
## 生成器の props を読んで、絵を描き、仲間が近づいたら(野営は部屋に入ったら)一度だけログに出す。読んだ印は迷宮の記録に残る(visited_rooms)。

const KINDS := ["mark", "sigil", "camp"]
const READ_CELLS := 1          # 印と落書きは、隣のマスまで来たら読む

## 書き出しの props から、この仲間の物だけを抜く
static func pick(props: Array) -> Array:
	var out: Array = []
	for p in props:
		if String(p.get("kind", "")) in KINDS:
			out.append(p)
	return out

## 調べたときの一文
static func line(p: Dictionary) -> String:
	match String(p.get("kind", "")):
		"mark":
			var old := "前の夜に描かれた印だ。今夜も合っているとは限らない。" if int(p.get("night", -1)) >= 0 else "いつ描かれた印かは分からない。"
			return "地図屋の凧旗の印。壁に「%s」と描いてある。%s" % [String(p.get("text", "")), old]
		"sigil":
			if String(p.get("sign", "")) == "seven":
				return "壁に七芒星が刻まれている。目覚めの徒の印だ。誰かが、もっと深みを目指して通った。"
			return "壁に静印が描かれている。静寂派の印だ。ここより先を、眠らせておけという祈り。"
		"camp":
			return "焚き火の跡がある。吊るした鍋に、煮汁がこびりついている。許可証のない闇潜りが、ここで夜を越したらしい。"
	return ""

## 仲間の先頭が pc のマスに来た。近くの印を読み、野営の部屋ならその跡を見る(どれも一度だけ)
static func near(fl: FloorInstance, pc: Vector2i) -> Array:
	var said: Array = []
	var m := fl.map
	var rid := m.room_at[m.idx(pc.x, pc.y)] if m.in_bounds(pc.x, pc.y) else -1
	for i in fl.world_props.size():
		var p: Dictionary = fl.world_props[i]
		var key := "prop%d" % i
		if fl.visited_rooms.has(key):
			continue
		var c := Vector2i(int(p["x"]), int(p["y"]))
		var hit := false
		if String(p["kind"]) == "camp":
			hit = rid >= 0 and rid == int(p.get("room", -2))
		else:
			hit = maxi(absi(c.x - pc.x), absi(c.y - pc.y)) <= READ_CELLS
		if hit:
			fl.visited_rooms[key] = true
			said.append(line(p))
	return said

## 絵(FloorInstance._draw から。踏んだことのあるマスの、画面に入る物だけ)
static func draw(fl: FloorInstance, vr: Rect2) -> void:
	var m := fl.map
	for p in fl.world_props:
		var c := Vector2i(int(p["x"]), int(p["y"]))
		var i := m.idx(c.x, c.y)
		var cen := m.center_of(c)
		if m.explored[i] == 0 or not vr.has_point(cen):
			continue
		var f := 1.0 if m.visible[i] == 1 else 0.45
		match String(p["kind"]):
			"mark":
				_draw_mark(fl, cen, String(p.get("dir", "e")), f)
			"sigil":
				_draw_sigil(fl, cen + Vector2(0, -Balance.CELL * 0.62), String(p.get("sign", "")) == "seven", f)
			"camp":
				_draw_camp(fl, cen, f)

static func _dim(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)

## 地図屋の凧旗: 細い竿と三角の旗、床に白墨の矢印
static func _draw_mark(fl: FloorInstance, cen: Vector2, dir: String, f: float) -> void:
	var C := float(Balance.CELL)
	var v: Vector2 = {"e": Vector2.RIGHT, "w": Vector2.LEFT, "s": Vector2.DOWN, "n": Vector2.UP}.get(dir, Vector2.RIGHT)
	var chalk := _dim(Color(0.92, 0.9, 0.8, 0.85), f)
	var tip := cen + v * C * 0.38
	fl.draw_line(cen - v * C * 0.3, tip, chalk, 2.0)
	fl.draw_line(tip, tip - v.rotated(0.6) * C * 0.18, chalk, 2.0)
	fl.draw_line(tip, tip - v.rotated(-0.6) * C * 0.18, chalk, 2.0)
	var base := cen + Vector2(-C * 0.3, C * 0.3)
	var top := base + Vector2(0, -C * 0.85)
	fl.draw_line(base, top, _dim(Color(0.45, 0.33, 0.2), f), 2.0)
	fl.draw_colored_polygon(PackedVector2Array([top, top + Vector2(C * 0.42, C * 0.12), top + Vector2(0, C * 0.26)]), _dim(Color(0.85, 0.25, 0.2), f))
	fl.draw_line(top + Vector2(0, C * 0.13), top + Vector2(C * 0.3, C * 0.13), _dim(Color(0.95, 0.92, 0.85), f), 1.5)

## 壁の落書き: 七芒星(赤い刻み)か静印(青白い円に横棒)。壁の正面(マスの上の縁)に描く
static func _draw_sigil(fl: FloorInstance, at: Vector2, seven: bool, f: float) -> void:
	var r := Balance.CELL * 0.3
	if seven:
		var col := _dim(Color(0.85, 0.3, 0.28, 0.9), f)
		var pts: Array = []
		for n in 7:
			pts.append(at + Vector2.from_angle(-PI / 2.0 + TAU * n / 7.0) * r)
		for n in 7:
			fl.draw_line(pts[n], pts[(n + 3) % 7], col, 1.6)
	else:
		var col2 := _dim(Color(0.7, 0.8, 0.92, 0.85), f)
		fl.draw_arc(at, r, 0.0, TAU, 18, col2, 1.6)
		fl.draw_line(at + Vector2(-r * 0.7, 0), at + Vector2(r * 0.7, 0), col2, 1.6)
		fl.draw_circle(at + Vector2(0, -r * 0.45), 1.8, col2)

## 闇潜りの野営: 灰の輪、囲む石、組んだ薪の燃えさし、吊るした鍋
static func _draw_camp(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var C := float(Balance.CELL)
	fl.draw_circle(cen, C * 0.42, _dim(Color(0.16, 0.14, 0.13, 0.9), f))
	for n in 7:
		fl.draw_circle(cen + Vector2.from_angle(TAU * n / 7.0) * C * 0.45, 3.2, _dim(Color(0.5, 0.48, 0.44), f))
	var wood := _dim(Color(0.3, 0.2, 0.12), f)
	fl.draw_line(cen + Vector2(-9, -6), cen + Vector2(9, 6), wood, 3.0)
	fl.draw_line(cen + Vector2(-9, 6), cen + Vector2(9, -6), wood, 3.0)
	fl.draw_circle(cen, 3.0, _dim(Color(0.75, 0.35, 0.15, 0.8), f))
	var pot := cen + Vector2(C * 0.62, -C * 0.2)
	fl.draw_line(pot + Vector2(-8, -12), pot + Vector2(8, -12), wood, 2.0)
	fl.draw_line(pot + Vector2(0, -12), pot + Vector2(0, -6), _dim(Color(0.55, 0.5, 0.45), f), 1.2)
	fl.draw_circle(pot, 6.0, _dim(Color(0.22, 0.22, 0.24), f))
