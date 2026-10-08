class_name TownArt
extends Control
## 街の背景絵。画像素材は使わず、コードで描く(解像度に依存しない)。ゆっくり動く。
## style: town(大穴と城壁の夜景) / smith / general / magic / temple / inn / pleasure(寝息通り)

var style := "town"
var t := 0.0
var _rng := RandomNumberGenerator.new()
var stars: Array = []
var bldg: Array = []        # 遠景の建物 [x, w, h, win_seed]
var shacks: Array = []
var motes: Array = []
var lanterns: Array = []
var books: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func set_style(s: String) -> void:
	style = s
	_build()
	queue_redraw()

func _build() -> void:
	_rng.seed = hash(style) + 11
	stars.clear()
	bldg.clear()
	shacks.clear()
	motes.clear()
	lanterns.clear()
	books.clear()
	for i in 140:
		stars.append([_rng.randf(), _rng.randf() * 0.55, _rng.randf_range(0.5, 1.8), _rng.randf() * TAU])
	var x := -0.02
	while x < 1.02:
		var w := _rng.randf_range(0.018, 0.05)
		bldg.append([x, w, _rng.randf_range(0.04, 0.16), _rng.randi()])
		x += w * _rng.randf_range(0.85, 1.1)
	for i in 70:
		shacks.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.012, 0.03), _rng.randi()])
	for i in 60:
		motes.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.02, 0.08), _rng.randf() * TAU])
	for i in 26:
		lanterns.append([_rng.randf(), _rng.randf_range(0.08, 0.8), _rng.randf_range(0.016, 0.04), _rng.randi() % 4, _rng.randf() * TAU])
	for i in 60:
		books.append([_rng.randf(), _rng.randf(), _rng.randi() % 5])

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

# ---------- 部品 ----------

func _grad(r: Rect2, top: Color, bot: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bot, bot]))

func _glow(c: Vector2, r: float, col: Color, a: float = 0.5, steps: int = 9) -> void:
	for i in steps:
		var k := float(i) / steps
		draw_circle(c, r * (1.0 - k), Color(col.r, col.g, col.b, a * (1.0 / steps) * (0.6 + k)))

func _flick(seed_v: float, speed: float = 7.0) -> float:
	return 0.85 + 0.15 * sin(t * speed + seed_v) * sin(t * speed * 0.63 + seed_v * 2.1)

func _w() -> float:
	return size.x

func _h() -> float:
	return size.y

func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)

# ---------- 描画 ----------

func _draw() -> void:
	match style:
		"town": _draw_town()
		"smith": _draw_smith()
		"general": _draw_general()
		"magic": _draw_magic()
		"temple": _draw_temple()
		"inn": _draw_inn()
		"pleasure": _draw_pleasure()
		_: _grad(Rect2(Vector2.ZERO, size), Color("101018"), Color("202030"))
	# 周辺を落として、前面のUIを読みやすくする
	var v := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y * 0.18), Vector2(0, size.y * 0.18)]),
		PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45), v, v]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.7), Vector2(size.x, size.y * 0.7), size, Vector2(0, size.y)]),
		PackedColorArray([v, v, Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))

func _draw_town() -> void:
	var W := _w()
	var H := _h()
	var hor := H * 0.62
	_grad(Rect2(0, 0, W, hor), Color("04050d"), Color("26335a"))
	_grad(Rect2(0, hor, W, H - hor), Color("0a0d1c"), Color("04050a"))
	for s in stars:
		var a := 0.45 + 0.4 * sin(t * s[2] + s[3])
		draw_circle(Vector2(s[0] * W, s[1] * H), s[2] * 0.9, Color(0.85, 0.9, 1.0, a))
	# 月
	var moon := _p(0.14, 0.14)
	_glow(moon, H * 0.1, Color("c8d8ff"), 0.35)
	draw_circle(moon, H * 0.028, Color("e8efff"))
	draw_circle(moon + Vector2(H * 0.012, -H * 0.006), H * 0.026, Color("0a1030"))
	# 大穴の光の柱
	var pit := Vector2(W * 0.5, hor + H * 0.06)
	var beam := 0.5 + 0.2 * sin(t * 0.8)
	draw_polygon(PackedVector2Array([pit + Vector2(-W * 0.07, 0), pit + Vector2(W * 0.07, 0), Vector2(W * 0.56, 0), Vector2(W * 0.44, 0)]),
		PackedColorArray([Color(0.4, 0.85, 1.0, 0.32 * beam), Color(0.4, 0.85, 1.0, 0.32 * beam), Color(0.4, 0.85, 1.0, 0.0), Color(0.4, 0.85, 1.0, 0.0)]))
	_glow(pit + Vector2(0, -H * 0.04), W * 0.22, Color("5fd0ff"), 0.45)
	# 遠景の街並み(冠環区の丘と縁環区)
	for b in bldg:
		var bx: float = b[0] * W
		var bw: float = b[1] * W
		var bh: float = b[2] * H * (1.0 + 0.9 * clampf(1.0 - absf(b[0] - 0.12) * 5.0, 0.0, 1.0))
		draw_rect(Rect2(bx, hor - bh, bw, bh + 2), Color("0b1124"))
		if int(b[3]) % 3 == 0:
			draw_colored_polygon(PackedVector2Array([Vector2(bx, hor - bh), Vector2(bx + bw / 2.0, hor - bh - bw * 0.9), Vector2(bx + bw, hor - bh)]), Color("0b1124"))
		for k in 3:
			if (int(b[3]) >> k) & 1 == 1:
				var wy := hor - bh + 6 + k * (bh / 3.2)
				draw_rect(Rect2(bx + bw * 0.3, wy, maxf(2.0, bw * 0.22), maxf(2.0, bw * 0.3)), Color(1.0, 0.78, 0.4, 0.8 * _flick(float(b[3]))))
	# 大穴の縁(七角形の内壁)
	var rx := W * 0.19
	var ry := H * 0.06
	var pts := PackedVector2Array()
	for i in 8:
		var a2 := TAU * i / 7.0 - PI / 2.0
		pts.append(pit + Vector2(cos(a2) * rx, sin(a2) * ry))
	draw_polyline(pts, Color(0.55, 0.75, 0.9, 0.55), 2.0)
	for i in 7:
		var a3 := TAU * i / 7.0 - PI / 2.0
		var tp := pit + Vector2(cos(a3) * rx, sin(a3) * ry)
		draw_rect(Rect2(tp.x - 4, tp.y - 26, 8, 26), Color("111a30"))
		_glow(tp + Vector2(0, -28), 14.0, Color("8ae0ff"), 0.6, 5)
		draw_circle(tp + Vector2(0, -28), 2.5, Color("d8f6ff"))
	# 穴の口
	draw_colored_polygon(_ellipse(pit, rx * 0.82, ry * 0.78, 28), Color("02030a"))
	_glow(pit, rx * 0.8, Color("4cc8ff"), 0.3, 7)
	# 燐晶の粒子
	for m in motes:
		var k2 := fmod(t * m[2] + m[3], 1.0)
		var mx: float = W * (0.5 + (m[0] - 0.5) * 0.28 * (0.4 + k2)) + sin(t + m[3]) * 8.0
		var my: float = pit.y - k2 * H * 0.7
		draw_circle(Vector2(mx, my), 1.8, Color(0.55, 0.9, 1.0, (1.0 - k2) * 0.9))
	# 壁下区の斜面(右)
	for s in shacks:
		var sx: float = W * (0.62 + s[0] * 0.4)
		var sy: float = hor + H * 0.02 + s[1] * H * 0.34 + (sx - W * 0.62) * 0.05
		var sw: float = s[2] * W
		draw_rect(Rect2(sx, sy, sw, sw * 0.7), Color("0a0f1e"))
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 2, sy), Vector2(sx + sw / 2.0, sy - sw * 0.35), Vector2(sx + sw + 2, sy)]), Color("0d1326"))
		if int(s[3]) % 3 != 0:
			draw_rect(Rect2(sx + sw * 0.3, sy + sw * 0.2, sw * 0.28, sw * 0.28), Color(1.0, 0.7, 0.35, 0.85 * _flick(float(s[3]))))
	# 左の斜面
	for s in shacks:
		var sx2: float = W * (s[0] * 0.38)
		var sy2: float = hor + H * 0.03 + s[1] * H * 0.3 - (W * 0.38 - sx2) * 0.03
		var sw2: float = s[2] * W * 0.9
		draw_rect(Rect2(sx2, sy2, sw2, sw2 * 0.7), Color("090d1b"))
		if int(s[3]) % 4 == 0:
			draw_rect(Rect2(sx2 + sw2 * 0.3, sy2 + sw2 * 0.2, sw2 * 0.25, sw2 * 0.25), Color(1.0, 0.75, 0.4, 0.8 * _flick(float(s[3]))))
	# 前景: 提灯の列
	for i in 3:
		var y0 := H * (0.06 + i * 0.045)
		var pts2 := PackedVector2Array()
		for j in 41:
			var x2 := W * j / 40.0
			pts2.append(Vector2(x2, y0 + sin(j / 40.0 * PI * (3 + i)) * 10.0 + H * 0.025 * sin(j / 40.0 * PI)))
		draw_polyline(pts2, Color(0.05, 0.05, 0.08, 0.9), 1.5)
		for j in range(2, 40, 4):
			var lp := pts2[j]
			_glow(lp + Vector2(0, 6), 16.0, Color("ffb860"), 0.55, 5)
			draw_circle(lp + Vector2(0, 6), 3.2, Color("ffd890"))
	# 霧
	_grad(Rect2(0, hor - H * 0.03, W, H * 0.1), Color(0.5, 0.65, 0.9, 0.0), Color(0.5, 0.65, 0.9, 0.12))

func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p

func _draw_smith() -> void:
	var W := _w()
	var H := _h()
	_grad(Rect2(0, 0, W, H), Color("1a0f0a"), Color("2c1a10"))
	# 石の壁の目地
	for r in 8:
		for c in 14:
			var off := 0.5 if r % 2 == 1 else 0.0
			draw_rect(Rect2((c + off) * W / 13.0, r * H * 0.1, W / 13.0 - 3, H * 0.1 - 3), Color(0.12 + 0.02 * ((r * 7 + c * 3) % 4), 0.08, 0.06, 0.55))
	# 炉
	var fc := _p(0.8, 0.52)
	draw_rect(Rect2(fc.x - W * 0.12, fc.y - H * 0.2, W * 0.24, H * 0.4), Color("1c1210"))
	draw_rect(Rect2(fc.x - W * 0.085, fc.y - H * 0.08, W * 0.17, H * 0.2), Color("0c0604"))
	var fl := _flick(1.0, 9.0)
	_glow(fc + Vector2(0, H * 0.03), W * 0.22 * fl, Color("ff7a28"), 0.6, 10)
	draw_colored_polygon(PackedVector2Array([fc + Vector2(-W * 0.06, H * 0.12), fc + Vector2(-W * 0.02, -H * 0.02 * fl), fc + Vector2(0, H * 0.04), fc + Vector2(W * 0.02, -H * 0.05 * fl), fc + Vector2(W * 0.06, H * 0.12)]), Color("ffb04a"))
	# 火の粉
	for m in motes:
		var k := fmod(t * m[2] * 2.0 + m[3], 1.0)
		draw_circle(fc + Vector2((m[0] - 0.5) * W * 0.12 + sin(t * 3.0 + m[3]) * 10.0, -k * H * 0.5), 1.6, Color(1.0, 0.7, 0.3, 1.0 - k))
	# 金床
	var an := _p(0.42, 0.78)
	draw_rect(Rect2(an.x - W * 0.06, an.y, W * 0.12, H * 0.1), Color("141416"))
	draw_colored_polygon(PackedVector2Array([an + Vector2(-W * 0.09, 0), an + Vector2(W * 0.1, 0), an + Vector2(W * 0.07, -H * 0.05), an + Vector2(-W * 0.06, -H * 0.05)]), Color("24262c"))
	draw_rect(Rect2(an.x - W * 0.2, an.y + H * 0.1, W * 0.4, H * 0.04), Color("2a1a10"))
	# 武器掛け
	for i in 6:
		var x0 := W * (0.08 + i * 0.065)
		var y0 := H * 0.18
		draw_line(Vector2(x0, y0), Vector2(x0, y0 + H * (0.28 + 0.04 * (i % 3))), Color("b8bcc8"), 3.0)
		draw_line(Vector2(x0 - 8, y0 + H * 0.12), Vector2(x0 + 8, y0 + H * 0.12), Color("6a4a2a"), 3.0)
		draw_rect(Rect2(x0 - 2, y0 - 16, 4, 16), Color("5a3a22"))
	draw_rect(Rect2(W * 0.05, H * 0.14, W * 0.42, 6), Color("3a2414"))
	# 吊るした道具
	for i in 4:
		draw_line(Vector2(W * (0.5 + i * 0.05), 0), Vector2(W * (0.5 + i * 0.05), H * (0.1 + 0.03 * i)), Color("2a2a2a"), 2.0)
		draw_circle(Vector2(W * (0.5 + i * 0.05), H * (0.1 + 0.03 * i) + 6), 7.0, Color("30323a"))

func _draw_general() -> void:
	var W := _w()
	var H := _h()
	_grad(Rect2(0, 0, W, H), Color("1a140c"), Color("2a1f12"))
	for r in 4:
		var y := H * (0.14 + r * 0.17)
		draw_rect(Rect2(W * 0.04, y + H * 0.08, W * 0.92, 7), Color("4a3018"))
		for i in 18:
			var x := W * (0.06 + i * 0.05)
			var kind := (i * 5 + r * 3) % 4
			var col: Color = [Color("6fbf6a"), Color("d27a4a"), Color("6a9ae0"), Color("c8b46a")][kind]
			match kind:
				0:
					draw_rect(Rect2(x, y + H * 0.03, W * 0.026, H * 0.05), Color(col.r, col.g, col.b, 0.85))
					draw_rect(Rect2(x + 3, y + H * 0.02, W * 0.02, H * 0.012), Color("5a3a22"))
				1:
					draw_circle(Vector2(x + W * 0.013, y + H * 0.055), W * 0.014, col)
				2:
					draw_rect(Rect2(x + 2, y + H * 0.02, W * 0.018, H * 0.06), Color(col.r, col.g, col.b, 0.8))
				3:
					draw_rect(Rect2(x, y + H * 0.045, W * 0.032, H * 0.035), col)
	# 吊りランプ
	for i in 5:
		var lx := W * (0.12 + i * 0.19)
		draw_line(Vector2(lx, 0), Vector2(lx, H * 0.1), Color("1a1a1a"), 2.0)
		_glow(Vector2(lx, H * 0.11), W * 0.07 * _flick(float(i)), Color("ffc060"), 0.5, 8)
		draw_circle(Vector2(lx, H * 0.11), 6.0, Color("ffe0a0"))
	draw_rect(Rect2(0, H * 0.84, W, H * 0.16), Color("2a1a0c"))
	draw_rect(Rect2(0, H * 0.84, W, 6), Color("6a4624"))

func _draw_magic() -> void:
	var W := _w()
	var H := _h()
	_grad(Rect2(0, 0, W, H), Color("0a0820"), Color("1a1238"))
	# 魔法陣
	var c := _p(0.5, 0.42)
	var R := H * 0.34
	for i in 3:
		draw_arc(c, R * (1.0 - i * 0.16), 0.0, TAU, 64, Color(0.6, 0.5, 1.0, 0.35 - i * 0.06), 2.0)
	var pts := PackedVector2Array()
	for i in 8:
		var a := t * 0.15 + TAU * i * 3.0 / 7.0
		pts.append(c + Vector2(cos(a), sin(a)) * R * 0.84)
	for i in 7:
		draw_line(pts[i], pts[i + 1], Color(0.7, 0.6, 1.0, 0.4), 1.5)
	_glow(c, R * 0.9, Color("7a5aff"), 0.25, 8)
	# 本棚
	for side in 2:
		var x0 := 0.0 if side == 0 else W * 0.82
		draw_rect(Rect2(x0, 0, W * 0.18, H), Color("120c24"))
		for r in 7:
			var y := H * (0.06 + r * 0.13)
			draw_rect(Rect2(x0, y + H * 0.1, W * 0.18, 5), Color("2a1c44"))
			for i in 9:
				var bk: Array = books[(r * 9 + i + side * 31) % books.size()]
				var col: Color = [Color("6a3a8a"), Color("3a5a8a"), Color("8a3a4a"), Color("3a7a5a"), Color("8a7a3a")][int(bk[2])]
				draw_rect(Rect2(x0 + 6 + i * W * 0.018, y + H * (0.1 - 0.06 - 0.02 * (i % 3)), W * 0.014, H * (0.06 + 0.02 * (i % 3))), col)
	# 浮かぶ光球
	for m in motes:
		var k := fmod(t * m[2] * 0.5 + m[3], 1.0)
		var p := Vector2(W * (0.25 + 0.5 * m[0]) + sin(t * 0.6 + m[3]) * 14.0, H * (0.9 - k * 0.8))
		draw_circle(p, 2.2, Color(0.75, 0.65, 1.0, sin(k * PI) * 0.9))
	# 机と蝋燭
	draw_rect(Rect2(W * 0.18, H * 0.82, W * 0.64, H * 0.18), Color("1c1228"))
	for i in 4:
		var cx := W * (0.3 + i * 0.13)
		draw_rect(Rect2(cx, H * 0.74, 7, H * 0.08), Color("e8dcc0"))
		_glow(Vector2(cx + 3, H * 0.73), 26.0 * _flick(float(i) * 1.7, 8.0), Color("ffc870"), 0.6, 6)
		draw_circle(Vector2(cx + 3, H * 0.73), 3.0, Color("fff0b0"))

func _draw_temple() -> void:
	var W := _w()
	var H := _h()
	_grad(Rect2(0, 0, W, H), Color("12161e"), Color("2a3040"))
	# 光の筋
	for i in 4:
		var x := W * (0.18 + i * 0.2)
		var a := 0.1 + 0.05 * sin(t * 0.5 + i)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + W * 0.05, 0), Vector2(x + W * 0.16, H), Vector2(x + W * 0.04, H)]), Color(0.8, 0.88, 1.0, a))
	# 列柱(奥行き)
	for i in 6:
		var k := 1.0 - i * 0.14
		var xl := W * (0.5 - 0.1 - 0.3 * k)
		var xr := W * (0.5 + 0.1 + 0.3 * k - 0.05 * k)
		var pw := W * 0.05 * k
		for x in [xl, xr]:
			draw_rect(Rect2(x, H * (0.5 - 0.42 * k), pw, H * 0.84 * k), Color(0.16 + 0.04 * k, 0.18 + 0.04 * k, 0.24 + 0.05 * k))
			draw_rect(Rect2(x - pw * 0.2, H * (0.5 - 0.42 * k), pw * 1.4, H * 0.03 * k), Color(0.3, 0.32, 0.4))
	# 空座
	var th := _p(0.5, 0.55)
	_glow(th + Vector2(0, -H * 0.12), W * 0.16, Color("e8f0ff"), 0.25, 8)
	draw_rect(Rect2(th.x - W * 0.035, th.y - H * 0.02, W * 0.07, H * 0.14), Color("0c0e14"))
	draw_rect(Rect2(th.x - W * 0.04, th.y - H * 0.24, W * 0.08, H * 0.24), Color("0e1018"))
	draw_colored_polygon(PackedVector2Array([th + Vector2(-W * 0.045, -H * 0.24), th + Vector2(0, -H * 0.31), th + Vector2(W * 0.045, -H * 0.24)]), Color("0e1018"))
	# 床
	draw_rect(Rect2(0, H * 0.84, W, H * 0.16), Color("14161e"))
	# 燭台と塵
	for i in 2:
		var cx := W * (0.3 + i * 0.4)
		_glow(Vector2(cx, H * 0.7), 40.0 * _flick(float(i) * 2.0, 6.0), Color("ffd890"), 0.45, 6)
		draw_rect(Rect2(cx - 2, H * 0.7, 4, H * 0.14), Color("7a6a50"))
	for m in motes:
		var k2 := fmod(t * m[2] * 0.4 + m[3], 1.0)
		draw_circle(Vector2(W * m[0] + sin(t + m[3]) * 10.0, H * (0.05 + k2 * 0.8)), 1.3, Color(0.9, 0.95, 1.0, 0.5))

func _draw_inn() -> void:
	var W := _w()
	var H := _h()
	_grad(Rect2(0, 0, W, H), Color("1e130a"), Color("33200f"))
	# 梁
	for i in 5:
		draw_rect(Rect2(W * i * 0.25 - 6, 0, 12, H * 0.9), Color("2a1a0e"))
	draw_rect(Rect2(0, H * 0.08, W, 14), Color("3a2410"))
	# 窓
	var wn := _p(0.62, 0.2)
	draw_rect(Rect2(wn.x, wn.y, W * 0.14, H * 0.26), Color("0a1028"))
	for s in stars:
		if s[0] < 0.5:
			draw_circle(wn + Vector2(s[0] * 2.0 * W * 0.14, s[1] * 1.6 * H * 0.26), 1.0, Color(0.9, 0.95, 1.0, 0.7))
	draw_line(wn + Vector2(W * 0.07, 0), wn + Vector2(W * 0.07, H * 0.26), Color("3a2410"), 4.0)
	draw_rect(Rect2(wn.x, wn.y, W * 0.14, H * 0.26), Color("3a2410"), false, 5.0)
	# 暖炉
	var hc := _p(0.18, 0.58)
	draw_rect(Rect2(hc.x - W * 0.1, hc.y - H * 0.28, W * 0.2, H * 0.36), Color("2a2018"))
	draw_rect(Rect2(hc.x - W * 0.065, hc.y - H * 0.05, W * 0.13, H * 0.13), Color("0c0604"))
	var fl := _flick(3.0, 10.0)
	_glow(hc + Vector2(0, H * 0.02), W * 0.24 * fl, Color("ff8a30"), 0.5, 10)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-W * 0.05, H * 0.08), hc + Vector2(-W * 0.015, -H * 0.03 * fl), hc + Vector2(0, H * 0.02), hc + Vector2(W * 0.02, -H * 0.04 * fl), hc + Vector2(W * 0.05, H * 0.08)]), Color("ffb450"))
	# 卓と杯
	for i in 3:
		var tx := W * (0.38 + i * 0.2)
		var ty := H * (0.74 + 0.03 * (i % 2))
		draw_rect(Rect2(tx, ty, W * 0.13, 8), Color("5a3a1c"))
		draw_rect(Rect2(tx + 8, ty + 8, 6, H * 0.12), Color("3a2410"))
		draw_rect(Rect2(tx + W * 0.13 - 14, ty + 8, 6, H * 0.12), Color("3a2410"))
		draw_rect(Rect2(tx + W * 0.03, ty - 12, 9, 12), Color("c8b078"))
		draw_rect(Rect2(tx + W * 0.08, ty - 10, 8, 10), Color("c8b078"))
		_glow(Vector2(tx + W * 0.065, ty - 14), 22.0 * _flick(float(i), 8.0), Color("ffc870"), 0.4, 5)
	# 吊り灯
	for i in 3:
		var lx := W * (0.42 + i * 0.2)
		draw_line(Vector2(lx, H * 0.08), Vector2(lx, H * 0.2), Color("1a1a1a"), 2.0)
		_glow(Vector2(lx, H * 0.22), 38.0 * _flick(float(i) * 1.3), Color("ffc060"), 0.5, 7)
		draw_circle(Vector2(lx, H * 0.22), 5.0, Color("ffe0a0"))

func _draw_pleasure() -> void:
	var W := _w()
	var H := _h()
	_grad(Rect2(0, 0, W, H), Color("0c0614"), Color("2a0f26"))
	for s in stars:
		draw_circle(Vector2(s[0] * W, s[1] * H * 0.5), s[2] * 0.7, Color(1.0, 0.9, 0.95, 0.35 + 0.3 * sin(t * s[2] + s[3])))
	# 通りの両側の家並み(遠近)
	for side in 2:
		for i in 7:
			var k := 1.0 - i * 0.12
			var bw := W * 0.16 * k
			var x := (W * 0.05 + i * W * 0.045) if side == 0 else (W * 0.95 - bw - i * W * 0.045)
			var top := H * (0.12 + i * 0.07)
			draw_rect(Rect2(x, top, bw, H - top), Color(0.1 + 0.03 * k, 0.06, 0.1 + 0.02 * k))
			draw_rect(Rect2(x, top, bw, H * 0.02), Color(0.2 + 0.05 * k, 0.1, 0.14))
			for r in 3:
				for cc in 2:
					var wx := x + bw * (0.18 + cc * 0.42)
					var wy := top + H * (0.08 + r * 0.14) * k
					var on := ((i * 5 + r * 3 + cc + side) % 3) != 0
					draw_rect(Rect2(wx, wy, bw * 0.28, H * 0.07 * k), Color(1.0, 0.7, 0.45, 0.85 * _flick(float(i + r + cc))) if on else Color(0.05, 0.03, 0.06))
					if on:
						for g in 4:
							draw_line(Vector2(wx + bw * 0.28 * g / 3.0, wy), Vector2(wx + bw * 0.28 * g / 3.0, wy + H * 0.07 * k), Color(0.2, 0.08, 0.06, 0.7), 1.0)
	# 提灯(紅、桃、橙、白)
	var cols := [Color("ff4a5a"), Color("ff7aa8"), Color("ffa040"), Color("ffe8c8")]
	for l in lanterns:
		var sway := sin(t * 1.2 + l[4]) * 5.0
		var p := Vector2(W * l[0] + sway, H * l[1] * 0.75 + H * 0.05)
		var col: Color = cols[int(l[3])]
		draw_line(Vector2(p.x - sway, 0), p, Color(0.05, 0.03, 0.05, 0.9), 1.2)
		_glow(p, W * l[2] * 1.5 * _flick(l[4], 5.0), col, 0.4, 8)
		var rx: float = W * l[2] * 0.42
		draw_colored_polygon(_ellipse(p, rx, rx * 1.2, 16), Color(col.r, col.g, col.b, 0.92))
		draw_line(p + Vector2(-rx * 0.6, -rx * 0.5), p + Vector2(rx * 0.6, -rx * 0.5), Color(0.15, 0.05, 0.05, 0.7), 1.0)
		draw_line(p + Vector2(-rx * 0.6, rx * 0.5), p + Vector2(rx * 0.6, rx * 0.5), Color(0.15, 0.05, 0.05, 0.7), 1.0)
	# 石畳と霧
	draw_polygon(PackedVector2Array([Vector2(W * 0.38, H * 0.62), Vector2(W * 0.62, H * 0.62), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([Color("1a0c1c"), Color("1a0c1c"), Color("3a1a30"), Color("3a1a30")]))
	_grad(Rect2(0, H * 0.55, W, H * 0.25), Color(0.8, 0.5, 0.7, 0.0), Color(0.8, 0.5, 0.7, 0.12))
