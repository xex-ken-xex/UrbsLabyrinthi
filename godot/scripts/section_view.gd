class_name SectionView
extends Control
## 迷宮の断面図(持ち物の画面の「迷宮の断面」)。縦穴の中心を通る東西の切り口を、地上から竜の巣まで描く。
## 縦と横の縮尺は同じ(1マス = 5フィート)。浅い層ほど広い(地上の大穴の漏斗の形)。データは data/section.json(Abyss.data())。
## まだ着いていない階は暗い影だけ。竜の巣は真っ黒(底は見せない)。

var here := 0          # いまいる階(0 は街)
var known := 0         # 着いたことのある最も深い階
var selected := 0      # 一覧で選んだ階

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(420, 360)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _draw() -> void:
	var d := Abyss.data()
	var fls: Array = d.get("floors", [])
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.035))
	if fls.is_empty():
		return
	var font := UI.font()
	var cell_m := float(d.get("cell_m", 1.524))
	var last: Dictionary = fls[fls.size() - 1]
	var bottom_m := float(last["top_m"]) + float(last["h_m"])
	var wide_m := 0.0
	for f in fls:
		wide_m = maxf(wide_m, float(f["w"]) * cell_m)
	var top := 34.0
	var left := 128.0
	var right := 52.0
	var sc := minf((size.x - left - right) / wide_m, (size.y - top - 16.0) / bottom_m)   # 縦横同じ縮尺(px / m)
	var mid := left + (size.x - left - right) * 0.5
	# 地上
	draw_line(Vector2(left - 8, top), Vector2(size.x - right + 8, top), Color(0.45, 0.42, 0.36), 1.0)
	draw_string(font, Vector2(mid - 70, top - 10), "地上(大穴の底)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.DIM)
	var prev_layer := -1
	for f in fls:
		var depth := int(f["depth"])
		var y0 := top + float(f["top_m"]) * sc
		var hh := float(f["h_m"]) * sc
		var slab := maxf(1.5, 0.8 * sc)
		var reached := known <= 0 or depth <= known
		var lair := bool(f.get("lair", false))
		var cols: Dictionary = f["col"]
		var rock := Color.html(String(cols.get("rock", "#111111"))).lightened(0.08)
		var floor_c := Color.html(String(cols.get("floor", "#444444"))).lightened(0.15)
		var corr_c := Color.html(String(cols.get("corr", "#3a3a3a"))).lightened(0.1)
		if not reached:
			rock = rock.darkened(0.3)
			floor_c = floor_c.darkened(0.75)
			corr_c = corr_c.darkened(0.75)
		var row := String(f["row"])
		var w := row.length()
		var cx := int(f["cx"])
		var sh_half := 6       # 縦穴(13マス)の半分
		var x := 0
		while x < w:
			var ch := row[x]
			var x2 := x
			while x2 + 1 < w and row[x2 + 1] == ch:
				x2 += 1
			var xa := mid + (float(x - cx) - 0.5) * cell_m * sc
			var xb := mid + (float(x2 - cx) + 0.5) * cell_m * sc
			var r := Rect2(xa, y0, xb - xa, hh)
			if lair and absi(x - cx) <= sh_half and absi(x2 - cx) <= sh_half:
				ch = "O"        # 竜の巣は真っ黒(底は見せない)
			match ch:
				"O":
					pass
				"#":
					draw_rect(r, rock)
				"~":
					draw_rect(Rect2(xa, y0, xb - xa, hh - slab), Color(0.02, 0.03, 0.04))
					draw_rect(Rect2(xa, y0 + hh * 0.55, xb - xa, hh * 0.45), Color(0.12, 0.3, 0.4) if reached else Color(0.05, 0.1, 0.13))
				"I":
					draw_rect(Rect2(xa, y0, xb - xa, hh - slab), Color(0.02, 0.03, 0.04))
					draw_rect(Rect2(xa + (xb - xa) * 0.25, y0, (xb - xa) * 0.5, hh - slab), Color(0.8, 0.76, 0.66) if reached else Color(0.25, 0.24, 0.22))
					draw_rect(Rect2(xa, y0 + hh - slab, xb - xa, slab), rock)
				_:
					# 部屋は天井まで、通路は低い。床の下は岩の板
					var head := hh - slab if ch == "." else minf(hh - slab, 3.0 * sc)
					draw_rect(Rect2(xa, y0, xb - xa, hh - slab - head), rock)
					draw_rect(Rect2(xa, y0 + hh - slab - head, xb - xa, head), floor_c if ch == "." else corr_c)
					if ch == "=":
						draw_rect(Rect2(xa, y0 + hh - slab - 1.5, xb - xa, 1.5), Color(0.3, 0.55, 0.65))
					draw_rect(Rect2(xa, y0 + hh - slab, xb - xa, slab), rock)
			x = x2 + 1
		# 縄梯子(縦穴の角に垂れる)
		if not lair:
			for rp in f.get("ropes", []):
				var rx := mid + float(rp[0]) * cell_m * sc + (0.5 if float(rp[0]) < 0 else -0.5) * cell_m * sc
				draw_line(Vector2(rx, y0), Vector2(rx, y0 + hh), Color(0.62, 0.48, 0.3, 0.9 if reached else 0.3), 1.0)
		# 層の名前(層の最初の階に)と深さ
		var layer := int(f["layer"])
		if layer != prev_layer:
			prev_layer = layer
			draw_line(Vector2(left - 8, y0), Vector2(left - 2, y0), UIKit.DIM, 1.0)
			var nm := "第%d層 %s" % [layer, String(f.get("short", ""))] if reached else "第%d層 ？？？" % layer
			draw_string(font, Vector2(4, y0 + 11), nm, HORIZONTAL_ALIGNMENT_LEFT, left - 22, 11, UIKit.GOLD if reached else UIKit.DIM)
			draw_string(font, Vector2(size.x - right + 6, y0 + 11), "%dm" % int(round(float(f["top_m"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.DIM)
		if depth == selected:
			draw_rect(Rect2(left - 4, y0, size.x - left - right + 8, hh), Color(0.6, 0.8, 1.0, 0.9), false, 1.0)
		if depth == here:
			draw_rect(Rect2(left - 4, y0 - 1, size.x - left - right + 8, hh + 2), UIKit.GOLD, false, 2.0)
			var cy := y0 + hh * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(left - 16, cy - 5), Vector2(left - 8, cy), Vector2(left - 16, cy + 5)]), UIKit.GOLD)   # いまの階
	draw_string(font, Vector2(size.x - right + 6, top + bottom_m * sc), "%dm" % int(round(bottom_m)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.DIM)
