class_name Hud
extends Control
## 画面の表示。HP、所持品、ログ、小さな地図、地上での報告。すべて _draw で描く。

var game: Node                      # Main
var log_lines: Array = []           # {text, color, age}
var overlay: Array = []             # 空でなければ全面の報告を出す(各要素は {text, color, size})
var hint := ""
var title_shown := 6.0
var show_credits := false

const CREDITS := "Urbs Labyrinthi (試作)\n\nThis work includes material taken from the System Reference Document 5.1 (\u201cSRD 5.1\u201d) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.\n\n魔物の数値は SRD 5.1 から要点だけに縮めて使っている(ゲームに合わせて係数をかけている)。日本語名はこの企画のための仮訳で、公式の訳語ではない。\n\nフォント: Zen Kaku Gothic New (SIL Open Font License 1.1)\n\nF1 で閉じる"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_log(text: String, color: Color = Color.WHITE) -> void:
	log_lines.append({"text": text, "color": color, "age": 0.0})
	while log_lines.size() > 8:
		log_lines.pop_front()

func _process(delta: float) -> void:
	for l in log_lines:
		l["age"] += delta
	title_shown = maxf(0.0, title_shown - delta)
	queue_redraw()

func _draw() -> void:
	if game == null or game.player == null or game.current == null:
		return
	var size_v := get_viewport_rect().size
	var pl: Player = game.player
	var fl: FloorInstance = game.current
	# 左上: 層と夜
	var head := "%s  %s" % [fl.map.data["meta"].get("floor_label", "第%d層" % fl.floor_no), fl.style.get("short", "")]
	UI.text(self, Vector2(16, 28), head, 20, Color("e8dcb0"))
	UI.text(self, Vector2(16, 50), "潜行 %d日目  %s" % [game.day + 1, fl.map.data["meta"].get("night_label", "")], 13, Color(0.8, 0.85, 0.9))
	# HP
	var bar := Rect2(16, 62, 220, 14)
	draw_rect(bar, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(pl.hp) / float(pl.max_hp), bar.size.y)), Color("c0392b"))
	draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.0)
	UI.text(self, Vector2(244, 75), "HP %d/%d" % [pl.hp, pl.max_hp], 13)
	var next_xp: int = Balance.XP_LEVELS[mini(pl.level, Balance.XP_LEVELS.size() - 1)]
	UI.text(self, Vector2(16, 96), "Lv%d   XP %d / %d" % [pl.level, pl.xp, next_xp], 13, Color("9ad8ff"))
	UI.text(self, Vector2(16, 116), "燐晶(未査定) %d銀貨相当    預け金 %d銀貨    治療薬 %d" % [game.bag_silver, game.bank_silver, pl.potions], 13, Color("f1d98a"))
	# ログ
	var y := size_v.y - 16.0 - (log_lines.size() - 1) * 20.0
	for l in log_lines:
		var a := clampf(1.0 - (l["age"] - 9.0) / 4.0, 0.0, 1.0)
		var c: Color = l["color"]
		UI.text(self, Vector2(16, y), String(l["text"]), 14, Color(c.r, c.g, c.b, a))
		y += 20.0
	# 足もとのヒント
	if hint != "":
		UI.text_center(self, size_v.x / 2.0, size_v.y - 70.0, hint, 18, Color("ffe9a8"))
	# 小さな地図
	_draw_minimap(fl, pl, size_v)
	# 操作
	if title_shown > 0.0:
		var a2 := clampf(title_shown / 2.0, 0.0, 1.0)
		var lines := ["移動: WASD / 矢印    攻撃: Space / 左クリック    転がり: Shift    調べる: E    探る: F    治療薬: Q",
			"燐晶を集めて第1層の上り階段から地上へ戻ると、3割が税として引かれて預け金になる。力尽きると未査定の燐晶は失う"]
		for i in lines.size():
			UI.text_center(self, size_v.x / 2.0, 150.0 + i * 22.0, lines[i], 14, Color(1, 1, 1, a2))
	if not overlay.is_empty():
		_draw_overlay(size_v)
	if show_credits:
		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0, 0, 0, 0.9))
		draw_multiline_string(UI.font(), Vector2(size_v.x * 0.15, 120.0), CREDITS, HORIZONTAL_ALIGNMENT_LEFT, size_v.x * 0.7, 16, -1, Color(0.9, 0.92, 0.95))

func _draw_minimap(fl: FloorInstance, pl: Player, size_v: Vector2) -> void:
	var m := fl.map
	var s := 3.0
	var ox := size_v.x - m.w * s - 16.0
	var oy := 16.0
	draw_rect(Rect2(ox - 4, oy - 4, m.w * s + 8, m.h * s + 8), Color(0, 0, 0, 0.55))
	for y in m.h:
		for x in m.w:
			var i := y * m.w + x
			if m.explored[i] == 0:
				continue
			var t := m.tiles[i]
			if t == FloorMap.ROCK:
				continue
			var c := Color(0.5, 0.55, 0.5) if t == FloorMap.ROOM else Color(0.38, 0.42, 0.38)
			if t == FloorMap.DOOR:
				c = Color("a06a30")
			if m.visible[i] == 0:
				c = c.darkened(0.35)
			draw_rect(Rect2(ox + x * s, oy + y * s, s, s), c)
	for st in [[fl.up_cell, Color("7bd0ff")], [fl.down_cell, Color("ffb050")]]:
		var cc: Vector2i = st[0]
		if m.explored[m.idx(cc.x, cc.y)] == 1:
			draw_rect(Rect2(ox + cc.x * s - 1, oy + cc.y * s - 1, s + 2, s + 2), st[1])
	var pc := m.cell_of(pl.position)
	draw_rect(Rect2(ox + pc.x * s - 1, oy + pc.y * s - 1, s + 2, s + 2), Color.WHITE)
	for en in fl.enemies:
		var ec := m.cell_of(en.position)
		if m.visible[m.idx(ec.x, ec.y)] == 1:
			draw_rect(Rect2(ox + ec.x * s - 1, oy + ec.y * s - 1, s + 1, s + 1), Color("ff4a3a"))

func _draw_overlay(size_v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size_v), Color(0, 0, 0, 0.82))
	var total := 0.0
	for l in overlay:
		total += float(l.get("size", 16)) + 10.0
	var y := size_v.y / 2.0 - total / 2.0
	for l in overlay:
		var sz: int = l.get("size", 16)
		UI.text_center(self, size_v.x / 2.0, y + sz, String(l["text"]), sz, l.get("color", Color.WHITE))
		y += sz + 10.0
