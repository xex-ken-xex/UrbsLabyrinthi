class_name FloorProps
extends RefCounted
## 迷宮の手ざわり(設計 §11.5): 地図屋の印、壁の落書き(七芒星・静印)、闇潜りの野営、灯守の詰所、封鎖令の跡、
## 鉄脚のオルドの時代の杭、水鏡の刻み、空の座。
## 生成器の props を読んで、絵を描き、仲間が近づいたら(野営は部屋に入ったら)一度だけログに出す。読んだ印は迷宮の記録に残る(visited_rooms)。

const KINDS := ["mark", "sigil", "camp", "post", "blockade", "stake", "carving", "seat"]
const ROOM_KINDS := ["camp", "blockade"]     # 部屋に入ったら見る物(ほかは隣のマスまで来たら)
const POST_STALE := 6          # 灯守の詰所の芯替えが、これより前の夜なら「灯守が来ていない」
const READ_CELLS := 1          # 印と落書きは、隣のマスまで来たら読む
## 水鏡の刻み: 七つの間(候補地 0〜6)の水底に一文字ずつ。その夜の下り階段の光が差す間の刻みだけが読める(GM資料 §12.3)
const CARVE := ["底", "待", "汝", "の", "つ", "を", "王"]
const CARVE_COLOR := Color(0.75, 0.95, 1.0)

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
		"post":
			var d := int(p.get("days", 0))
			var when := "今夜" if d == 0 else "%d夜前" % d
			var s := "灯守の詰所。板に「芯替え 済」と、%sの日付が書いてある。" % when
			return s + ("しばらく灯守が来ていないらしい。この先の灯は、あてにならない。" if d >= POST_STALE else "")
		"blockade":
			return "壁に、日を数えた刻み線がびっしり並んでいる。五十年前の空振りの年、封鎖令で門を閉ざされ、取り残された者の野営の跡だ。"
		"stake":
			return "床に古い鉄の杭が打ち込まれている。鉄脚のオルドの時代、坑口盟約のころのものだ。いまも抜けない。"
		"carving":
			return "水底に、文字のような刻みが並んでいる。今夜は暗くて読めない。光が差す夜なら読めるかもしれない。"
		"seat":
			return "誰も座っていない石の座がある。空座と呼ばれるものらしい。冷たい。"
	return ""

## 水鏡の刻みが、どの間(候補地の番号)にあるか。分からなければ -1
static func carving_site(fl: FloorInstance, p: Dictionary) -> int:
	for s in fl.map.data.get("stair_sites", []):
		if int(s.get("room", -1)) == int(p.get("room", -2)):
			return int(s["k"])
	return -1

## 今夜、この刻みに下り階段の光が差しているか(読める夜か)
static func carving_lit(fl: FloorInstance, p: Dictionary) -> bool:
	var d := fl.down_cell
	if d.x < 0 or not fl.map.in_bounds(d.x, d.y):
		return false
	return fl.map.room_at[fl.map.idx(d.x, d.y)] == int(p.get("room", -2))

## これまでに読んだ刻みを、間の順に並べる(読んでいない間は「?」)
static func carving_tally(gs: GameState, also: int = -1) -> String:
	var out: Array = []
	for k in CARVE.size():
		out.append(CARVE[k] if k == also or Journal.stat(gs, "carving%d" % k) > 0 else "?")
	return "・".join(out)

const SEAT_REACH := 1.5        # 空の座に座れる距離(マス)

## 空の座のそばにいれば、その置き物を返す(なければ空)
static func seat_near(fl: FloorInstance, pos: Vector2) -> Dictionary:
	for p in fl.world_props:
		if String(p["kind"]) == "seat" and pos.distance_to(fl.map.center_of(Vector2i(int(p["x"]), int(p["y"])))) <= Balance.CELL * SEAT_REACH:
			return p
	return {}

## 空の座に座ったときの一文。真相(GM資料 §2 の A/B/C)は決めないので、どれとも取れる書き方にする。
## 初めて座ると、底から子守唄のような歌が聞こえる(教会で習った歌より息継ぎが多い。削られた三息)。
## 空座の七七夜(大閏の空座の月 31夜目から)だけは、座がほのかに温かい
static func sit_line(who: String, first: bool, kuuza: bool) -> String:
	var s := "%sは、空の座に腰を下ろした。" % who
	if kuuza:
		s += "座が、ほのかに温かい。いましがた誰かが立ったばかりのように。"
	else:
		s += "石は冷たい。"
	if first:
		s += "…底のほうから、子守唄のような歌が聞こえた気がした。教会で習った歌より、息継ぎが多い。"
	else:
		s += "何も聞こえない。"
	return s

## 仲間の先頭が pc のマスに来た。近くの印を読み、野営の部屋ならその跡を見る(どれも一度だけ)。
## 下り階段の光が差した水鏡の刻みは、一文字読める(頭上にその文字、迷宮の記録に残す)
static func near(fl: FloorInstance, pc: Vector2i, gs: GameState = null) -> Array:
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
		if String(p["kind"]) in ROOM_KINDS:
			hit = rid >= 0 and rid == int(p.get("room", -2))
		else:
			hit = maxi(absi(c.x - pc.x), absi(c.y - pc.y)) <= READ_CELLS
		if hit and String(p["kind"]) == "carving" and carving_lit(fl, p) and carving_site(fl, p) >= 0:
			fl.visited_rooms[key] = true
			var k := carving_site(fl, p)
			said.append("水底の刻みに、階段の光が差している。今夜は読める。「%s」と刻んである。" % CARVE[k])
			if gs != null:
				said.append("これまでに読んだ水鏡の刻み(間の順): %s" % carving_tally(gs, k))
			fl.spawn_text(fl.map.center_of(c) + Vector2(0, -30), CARVE[k], CARVE_COLOR)
			fl.stat.emit.call_deferred("carving%d" % k)      # ログの後に実績を知らせる
		elif hit:
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
			"post":
				_draw_post(fl, cen, f)
			"blockade":
				_draw_blockade(fl, cen, f)
			"stake":
				_draw_stake(fl, cen, f)
			"carving":
				_draw_carving(fl, cen, f, carving_lit(fl, p))
			"seat":
				_draw_seat(fl, cen, f)

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

## 灯守の詰所: 二本の脚に渡した板(芯替えの日付を書く)
static func _draw_post(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var wood := _dim(Color(0.45, 0.32, 0.2), f)
	fl.draw_line(cen + Vector2(-9, 10), cen + Vector2(-9, -8), wood, 2.0)
	fl.draw_line(cen + Vector2(9, 10), cen + Vector2(9, -8), wood, 2.0)
	fl.draw_rect(Rect2(cen + Vector2(-13, -14), Vector2(26, 11)), _dim(Color(0.62, 0.48, 0.3), f))
	for i in 3:
		fl.draw_line(cen + Vector2(-10, -11 + i * 3), cen + Vector2(4 - i * 3, -11 + i * 3), _dim(Color(0.25, 0.18, 0.1), f), 1.0)

## 封鎖令の跡: 冷えた灰の輪と、壁ぎわの刻み線(五本ずつ束ねる)
static func _draw_blockade(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var C := float(Balance.CELL)
	fl.draw_circle(cen, C * 0.36, _dim(Color(0.22, 0.21, 0.2, 0.85), f))
	fl.draw_arc(cen, C * 0.36, 0.0, TAU, 16, _dim(Color(0.42, 0.4, 0.38), f), 2.0)
	var mark := _dim(Color(0.8, 0.78, 0.7, 0.8), f)
	var at := cen + Vector2(-C * 0.9, -C * 0.85)
	for g in 3:
		for i in 4:
			var x := at.x + g * 14.0 + i * 3.0
			fl.draw_line(Vector2(x, at.y), Vector2(x, at.y + 9.0), mark, 1.0)
		fl.draw_line(Vector2(at.x + g * 14.0 - 1.0, at.y + 7.0), Vector2(at.x + g * 14.0 + 11.0, at.y + 2.0), mark, 1.0)

## オルドの杭: 床に打ち込まれた太い鉄の杭(錆の輪)
static func _draw_stake(fl: FloorInstance, cen: Vector2, f: float) -> void:
	fl.draw_circle(cen, 7.0, _dim(Color(0.4, 0.25, 0.15, 0.6), f))
	fl.draw_circle(cen, 4.5, _dim(Color(0.3, 0.3, 0.32), f))
	fl.draw_circle(cen + Vector2(-1, -1), 2.2, _dim(Color(0.55, 0.55, 0.58), f))

## 水鏡の刻み: 床に淡く光る、読めない文字の並び
static func _draw_carving(fl: FloorInstance, cen: Vector2, f: float, lit: bool = false) -> void:
	var col := _dim(Color(0.6, 0.85, 0.95, 0.7), f)
	if lit:      # 階段の光が差した夜は、水底が明るい
		fl.draw_circle(cen, Balance.CELL * 0.55, _dim(Color(0.7, 0.95, 1.0, 0.22), f))
		col = _dim(Color(0.85, 1.0, 1.0, 0.95), f)
	for i in 4:
		var x := cen.x - 12.0 + i * 8.0
		fl.draw_line(Vector2(x, cen.y - 6), Vector2(x + 3, cen.y + 6), col, 1.2)
		fl.draw_line(Vector2(x - 1, cen.y - 1 + (i % 2) * 3), Vector2(x + 4, cen.y - 1 + (i % 2) * 3), col, 1.2)

## 空の座: 背もたれのある石の座
static func _draw_seat(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var stone := _dim(Color(0.55, 0.53, 0.5), f)
	fl.draw_rect(Rect2(cen + Vector2(-12, -18), Vector2(24, 12)), stone.darkened(0.2))
	fl.draw_rect(Rect2(cen + Vector2(-14, -6), Vector2(28, 10)), stone)
	fl.draw_rect(Rect2(cen + Vector2(-12, 4), Vector2(6, 9)), stone.darkened(0.3))
	fl.draw_rect(Rect2(cen + Vector2(6, 4), Vector2(6, 9)), stone.darkened(0.3))

# ---------- 地物の絵(設計 §11.3)。見るだけの物なので、擬音もログも足さない(部屋の地物は、入ったときの一行のまま) ----------

## 部屋の地物の名前 → 絵
const FEAT_PIC := {"湧き水": "spring", "黒い茸の畝": "shrooms", "揚水機": "pump", "沈んだ揚水機": "pump_sunk", "骨の祭壇": "altar", "聖歌席": "choir"}
const DECOR_KINDS := ["rail", "cart"]

## 書き出しから、絵だけの物を抜く(錆鉄の軌条と止まったトロッコ、部屋の地物)
static func decor(d: Dictionary) -> Array:
	var out: Array = []
	for p in d.get("props", []):
		if String(p.get("kind", "")) in DECOR_KINDS:
			out.append(p)
	for r in d.get("rooms", []):
		var f: Variant = r.get("feature")
		if typeof(f) == TYPE_DICTIONARY and FEAT_PIC.has(String(f.get("name", ""))) and f.has("x"):
			out.append({"kind": FEAT_PIC[String(f["name"])], "x": int(f["x"]), "y": int(f["y"])})
	return out

## 軌条のマス(端から端まで)
static func rail_cells(p: Dictionary) -> Array:
	var a := Vector2i(int(p["x"]), int(p["y"]))
	var b := Vector2i(int(p.get("x2", p["x"])), int(p.get("y2", p["y"])))
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var out: Array = [a]
	var c := a
	while c != b and step != Vector2i.ZERO:
		c += step
		out.append(c)
	return out

## c のマスを通る軌条(なければ空)。暴走する鉱車は、この軌条の端から端へ走る
static func rail_at(fl: FloorInstance, c: Vector2i) -> Dictionary:
	for p in fl.decor:
		if String(p["kind"]) != "rail":
			continue
		var x0 := mini(int(p["x"]), int(p["x2"]))
		var x1 := maxi(int(p["x"]), int(p["x2"]))
		var y0 := mini(int(p["y"]), int(p["y2"]))
		var y1 := maxi(int(p["y"]), int(p["y2"]))
		if c.x >= x0 and c.x <= x1 and c.y >= y0 and c.y <= y1:
			return p
	return {}

## 床の上に描く(階段より下)。踏んだことのあるマスの、画面に入る物だけ
static func draw_decor(fl: FloorInstance, vr: Rect2) -> void:
	var m := fl.map
	for p in fl.decor:
		var k := String(p["kind"])
		if k == "rail":
			_draw_rail(fl, p, vr)
			continue
		var c := Vector2i(int(p["x"]), int(p["y"]))
		var i := m.idx(c.x, c.y)
		var cen := m.center_of(c)
		if m.explored[i] == 0 or not vr.has_point(cen):
			continue
		var f := 1.0 if m.visible[i] == 1 else 0.45
		match k:
			"cart":
				draw_cart(fl, cen, String(p.get("axis", "h")) == "v", f, 1.0, true)
			"spring":
				_draw_spring(fl, cen, f)
			"shrooms":
				_draw_shrooms(fl, cen, f)
			"pump":
				_draw_pump(fl, cen, f, false)
			"pump_sunk":
				_draw_pump(fl, cen, f, true)
			"altar":
				_draw_altar(fl, cen, f)
			"choir":
				_draw_choir(fl, cen, f)

## 軌条: 錆びた二本の鉄と、枕木
static func _draw_rail(fl: FloorInstance, p: Dictionary, vr: Rect2) -> void:
	var m := fl.map
	var C := float(Balance.CELL)
	var vert := int(p["x"]) == int(p.get("x2", p["x"]))
	var along := Vector2(0, 1) if vert else Vector2(1, 0)
	var side := Vector2(1, 0) if vert else Vector2(0, 1)
	for c in rail_cells(p):
		var i := m.idx(c.x, c.y)
		var cen := m.center_of(c)
		if m.explored[i] == 0 or not vr.has_point(cen):
			continue
		var f := 1.0 if m.visible[i] == 1 else 0.45
		var wood := _dim(Color(0.32, 0.24, 0.17, 0.9), f)
		for s in [-0.25, 0.25]:
			fl.draw_line(cen + along * C * s - side * C * 0.34, cen + along * C * s + side * C * 0.34, wood, 4.0)
		var iron := _dim(Color(0.55, 0.36, 0.24), f)
		for o in [-0.22, 0.22]:
			fl.draw_line(cen - along * C * 0.5 + side * C * o, cen + along * C * 0.5 + side * C * o, iron, 2.0)

## トロッコ: 鉄の箱に四つの車輪。止まっている物(wreck)は少し傾いて、中に石くず。暴走する鉱車の罠も、この絵で走る
static func draw_cart(ci: CanvasItem, cen: Vector2, vertical: bool, f: float, a: float, wreck: bool = false) -> void:
	var C := float(Balance.CELL)
	var along := Vector2(0, 1) if vertical else Vector2(1, 0)
	var side := Vector2(1, 0) if vertical else Vector2(0, 1)
	var half_a := C * 0.42
	var half_s := C * 0.32
	var tilt := 0.08 if wreck else 0.0
	var al := along.rotated(tilt)
	var sd := side.rotated(tilt)
	var wheel := _dim(Color(0.15, 0.13, 0.12, a), f)
	for u in [-0.62, 0.62]:
		for v in [-1.0, 1.0]:
			ci.draw_circle(cen + al * half_a * u + sd * half_s * v, 3.4, wheel)
	ci.draw_circle(cen + Vector2(0, 5), C * 0.4, Color(0, 0, 0, 0.25 * a))
	var box := PackedVector2Array([cen - al * half_a - sd * half_s, cen + al * half_a - sd * half_s, cen + al * half_a + sd * half_s, cen - al * half_a + sd * half_s])
	ci.draw_colored_polygon(box, _dim(Color(0.46, 0.32, 0.22, a), f))
	var inner := PackedVector2Array([cen - al * half_a * 0.75 - sd * half_s * 0.65, cen + al * half_a * 0.75 - sd * half_s * 0.65, cen + al * half_a * 0.75 + sd * half_s * 0.65, cen - al * half_a * 0.75 + sd * half_s * 0.65])
	ci.draw_colored_polygon(inner, _dim(Color(0.18, 0.13, 0.1, a), f))
	box.append(box[0])
	ci.draw_polyline(box, _dim(Color(0.62, 0.42, 0.28, a), f), 1.5)
	if wreck:
		for n in 4:
			ci.draw_circle(cen + al * half_a * (-0.5 + n * 0.33) + sd * half_s * (0.2 if n % 2 == 0 else -0.25), 2.6, _dim(Color(0.5, 0.48, 0.45, a), f))

## 湧き水: 岩の割れ目から湧いて、小さな水たまりになっている(波紋がゆっくり広がる)
static func _draw_spring(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var C := float(Balance.CELL)
	var tm := Time.get_ticks_msec() / 1000.0
	fl.draw_line(cen + Vector2(-4, -C * 0.55), cen + Vector2(1, -C * 0.3), _dim(Color(0.12, 0.12, 0.13), f), 2.0)
	fl.draw_line(cen + Vector2(1, -C * 0.3), cen + Vector2(-1, -C * 0.12), _dim(Color(0.12, 0.12, 0.13), f), 2.0)
	fl.draw_set_transform(cen + Vector2(0, 4), 0.0, Vector2(1.0, 0.62))
	fl.draw_circle(Vector2.ZERO, C * 0.44, _dim(Color(0.32, 0.3, 0.27), f))
	fl.draw_circle(Vector2.ZERO, C * 0.38, _dim(Color(0.2, 0.42, 0.55), f))
	var k := fmod(tm * 0.6, 1.0)
	fl.draw_arc(Vector2.ZERO, C * 0.36 * k, 0.0, TAU, 18, _dim(Color(0.7, 0.88, 1.0, 0.6 * (1.0 - k)), f), 1.2)
	fl.draw_set_transform(Vector2.ZERO)
	fl.draw_line(cen + Vector2(-1, -C * 0.12), cen + Vector2(-1, -2), _dim(Color(0.6, 0.85, 1.0, 0.7), f), 1.2)

## 黒い茸の畝: 盛った土の畝が三本、黒い茸が並ぶ
static func _draw_shrooms(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var C := float(Balance.CELL)
	for row in 3:
		var y := cen.y - C * 0.35 + row * C * 0.35
		fl.draw_rect(Rect2(cen.x - C * 0.5, y - 3.0, C, 6.0), _dim(Color(0.24, 0.17, 0.12), f))
		for n in 4:
			var x := cen.x - C * 0.38 + n * C * 0.25 + (row % 2) * 3.0
			fl.draw_line(Vector2(x, y), Vector2(x, y - 4.0), _dim(Color(0.55, 0.52, 0.46), f), 1.5)
			fl.draw_circle(Vector2(x, y - 5.0), 3.2, _dim(Color(0.1, 0.08, 0.1), f))
			fl.draw_circle(Vector2(x - 1.0, y - 6.0), 1.0, _dim(Color(0.4, 0.38, 0.45), f))

## 揚水機: 木の水車と枠、つるべの鎖。沈んだ物は、水面から水車の上の半分だけが出ている
static func _draw_pump(fl: FloorInstance, cen: Vector2, f: float, sunk: bool) -> void:
	var C := float(Balance.CELL)
	var wood := _dim(Color(0.42, 0.3, 0.2), f)
	var rust := _dim(Color(0.55, 0.32, 0.2), f)
	var hub := cen + Vector2(0, -C * 0.1)
	var R := C * 0.42
	if not sunk:
		fl.draw_line(cen + Vector2(-R - 4, C * 0.45), hub, wood, 3.0)
		fl.draw_line(cen + Vector2(R + 4, C * 0.45), hub, wood, 3.0)
	fl.draw_arc(hub, R, PI if sunk else 0.0, TAU, 20, wood, 3.0)
	for n in 8:
		var a := TAU * n / 8.0
		if sunk and sin(a) > 0.05:
			continue
		fl.draw_line(hub, hub + Vector2.from_angle(a) * R, wood, 1.5)
		fl.draw_rect(Rect2(hub + Vector2.from_angle(a) * R - Vector2(2.5, 2.5), Vector2(5, 5)), rust)
	fl.draw_circle(hub, 3.5, rust)
	if sunk:
		fl.draw_set_transform(hub + Vector2(0, 2), 0.0, Vector2(1.0, 0.3))
		fl.draw_circle(Vector2.ZERO, R + 6.0, _dim(Color(0.2, 0.42, 0.52, 0.85), f))
		fl.draw_set_transform(Vector2.ZERO)
		fl.draw_line(hub + Vector2(-R - 3, 2), hub + Vector2(R + 3, 2), _dim(Color(0.7, 0.88, 1.0, 0.5), f), 1.0)
	else:
		fl.draw_line(hub + Vector2(R, 0), hub + Vector2(R, C * 0.4), _dim(Color(0.5, 0.5, 0.52), f), 1.0)
		fl.draw_rect(Rect2(hub + Vector2(R - 4, C * 0.4), Vector2(8, 7)), wood)

## 骨の祭壇: 骨の台に、一枚の肩甲骨
static func _draw_altar(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var C := float(Balance.CELL)
	var bone := _dim(Color(0.86, 0.82, 0.7), f)
	var shade := _dim(Color(0.6, 0.56, 0.47), f)
	fl.draw_rect(Rect2(cen + Vector2(-C * 0.42, -2), Vector2(C * 0.84, 9)), shade)
	fl.draw_rect(Rect2(cen + Vector2(-C * 0.46, -6), Vector2(C * 0.92, 5)), bone)
	fl.draw_rect(Rect2(cen + Vector2(-C * 0.36, 7), Vector2(5, 7)), shade)
	fl.draw_rect(Rect2(cen + Vector2(C * 0.36 - 5, 7), Vector2(5, 7)), shade)
	fl.draw_colored_polygon(PackedVector2Array([cen + Vector2(-9, -8), cen + Vector2(9, -8), cen + Vector2(3, -22), cen + Vector2(-5, -20)]), bone)
	fl.draw_line(cen + Vector2(-6, -12), cen + Vector2(5, -18), shade, 1.2)

## 聖歌席: 段になった骨の座席が三列
static func _draw_choir(fl: FloorInstance, cen: Vector2, f: float) -> void:
	var C := float(Balance.CELL)
	for row in 3:
		var w := C * (0.6 + row * 0.18)
		var y := cen.y - C * 0.38 + row * C * 0.3
		var col := _dim(Color(0.84, 0.8, 0.68).darkened(0.12 * (2 - row)), f)
		fl.draw_rect(Rect2(cen.x - w / 2.0, y, w, 6.0), col)
		fl.draw_rect(Rect2(cen.x - w / 2.0, y + 6.0, w, 2.0), _dim(Color(0.35, 0.32, 0.28), f))
		for n in 3:
			fl.draw_line(Vector2(cen.x - w / 2.0 + w * (n + 0.5) / 3.0, y), Vector2(cen.x - w / 2.0 + w * (n + 0.5) / 3.0, y + 6.0), _dim(Color(0.55, 0.5, 0.42), f), 1.0)
