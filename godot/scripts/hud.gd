class_name Hud
extends Control
## 迷宮の中の表示。パーティの状態、スキルバー、ログ、小さな地図、足もとのヒント。すべて _draw で描く。

var game: Node                      # Main
var log_lines: Array = []           # {text, color, age}
var pickups: Array = []             # 拾ったものの知らせ {key, tex, name, color, amount, unit, age}。同じ物は数をまとめる
const PICKUP_LIFE := 4.0
var overlay: Array = []             # 空でなければ全面の報告を出す(各要素は {text, color, size})
var hint := ""
var title_shown := 7.0
var show_credits := false

const CREDITS := "Urbs Labyrinthi (試作)\n\nThis work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.\n\n魔物の数値は SRD 5.1 から要点だけに縮めて使っている(ゲームに合わせて係数をかけている)。日本語名はこの企画のための仮訳で、公式の訳語ではない。\n\nフォント: M+ 1p、Shippori Mincho (SIL Open Font License 1.1)\n\nF1 で閉じる"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_log(text: String, color: Color = Color.WHITE) -> void:
	log_lines.append({"text": text, "color": color, "age": 0.0})
	while log_lines.size() > 8:
		log_lines.pop_front()

## 拾ったものを、右の地図の下に絵つきで知らせる。続けて同じ物を拾うと、数を足す
func add_pickup(key: String, tex: Texture2D, name_s: String, color: Color, amount: float, unit: String) -> void:
	for p in pickups:
		if p["key"] == key and float(p["age"]) < PICKUP_LIFE - 0.5:
			p["amount"] = float(p["amount"]) + amount
			p["age"] = 0.0
			p["bump"] = 0.25
			return
	pickups.append({"key": key, "tex": tex, "name": name_s, "color": color, "amount": amount, "unit": unit, "age": 0.0, "bump": 0.25})
	while pickups.size() > 6:
		pickups.pop_front()

func _process(delta: float) -> void:
	for p in pickups:
		p["age"] = float(p["age"]) + delta
		p["bump"] = maxf(0.0, float(p["bump"]) - delta)
	pickups = pickups.filter(func(p): return float(p["age"]) < PICKUP_LIFE)
	for l in log_lines:
		l["age"] += delta
	title_shown = maxf(0.0, title_shown - delta)
	queue_redraw()

func _draw() -> void:
	var size_v := get_viewport_rect().size
	if show_credits:
		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0, 0, 0, 0.92))
		draw_multiline_string(UI.font(), Vector2(size_v.x * 0.15, 120.0), CREDITS, HORIZONTAL_ALIGNMENT_LEFT, size_v.x * 0.7, 16, -1, Color(0.9, 0.92, 0.95))
		return
	if game == null or game.current == null or not ["dungeon", "overlay"].has(game.phase) or game.key_config != null:
		return
	var fl: FloorInstance = game.current
	var heroes: Array = game.heroes
	var meta: Dictionary = fl.map.data["meta"]
	UI.text(self, Vector2(16, 28), "%s  %s" % [meta.get("floor_label", "第%d層" % fl.floor_no), fl.style.get("short", "")], 20, Color("e8dcb0"))
	if game.arena != null:
		UI.text(self, Vector2(16, 48), "調整用(経験点も宝も出ない)", 13, Color(0.8, 0.85, 0.9))
	else:
		UI.text(self, Vector2(16, 48), "潜行 %d日目  %s" % [game.gs.day + 1, meta.get("night_label", "")], 13, Color(0.8, 0.85, 0.9))
	# パーティ
	var y := 58.0
	for i in heroes.size():
		var h: Hero = heroes[i]
		var c: Character = h.ch
		var active: bool = i == game.active
		var r := Rect2(12, y, 262, 44)
		draw_rect(r, Color(0, 0, 0, 0.55))
		draw_rect(r, Color("e8dcb0") if active else Color(1, 1, 1, 0.15), false, 2.0 if active else 1.0)
		draw_rect(Rect2(r.position.x, r.position.y, 5, r.size.y), Jobs.class_color(c.cls))
		var col := Color(0.55, 0.55, 0.6) if h.down else Color.WHITE
		UI.text(self, Vector2(r.position.x + 12, r.position.y + 16), "%s  Lv%d %s" % [c.name, c.level, Jobs.CLASSES[c.cls]["name"]], 13, col, false)
		var hb := Rect2(r.position.x + 12, r.position.y + 22, 190, 8)
		draw_rect(hb, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * h.hp_frac(), hb.size.y)), Color("c0392b") if h.hp_frac() > 0.3 else Color("ff5a3a"))
		var mb := Rect2(r.position.x + 12, r.position.y + 33, 190, 5)
		draw_rect(mb, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(mb.position, Vector2(mb.size.x * clampf(c.mp / maxf(1.0, c.max_mp()), 0.0, 1.0), mb.size.y)), Color("3a7ad0"))
		UI.text(self, Vector2(r.position.x + 208, r.position.y + 30), "%d" % int(ceil(c.hp)), 12, col, false)
		if h.down:
			UI.text(self, Vector2(r.position.x + 208, r.position.y + 16), "倒", 12, Color("ff6a5a"), false)
		y += 48.0
	UI.text(self, Vector2(16, y + 14), ("燐晶 %s kg(見積 %d銀貨)" % [Crystal.bag_text(game.bag_crystal), game.bag_value()] if not game.bag_crystal.is_empty() else "燐晶 なし") + "    預け金 %d銀貨" % game.gs.bank_silver, 13, Color("f1d98a"))
	UI.text(self, Vector2(16, y + 32), "治療薬 %d    魔力水 %d" % [game.gs.count("potion") + game.gs.count("hi_potion"), game.gs.count("ether")], 13, Color(0.8, 0.9, 0.8))
	# ログ
	var ly := size_v.y - 16.0 - (log_lines.size() - 1) * 20.0
	for l in log_lines:
		var a := clampf(1.0 - (l["age"] - 9.0) / 4.0, 0.0, 1.0)
		var c2: Color = l["color"]
		UI.text(self, Vector2(16, ly), String(l["text"]), 14, Color(c2.r, c2.g, c2.b, a))
		ly += 20.0
	_draw_skillbar(size_v)
	if hint != "":
		UI.text_center(self, size_v.x / 2.0, size_v.y - 96.0, hint, 18, Color("ffe9a8"))
	if game.arena == null:
		_draw_minimap(fl, size_v)
	if game.dtime != null:
		_draw_sky(game.dtime, size_v, size_v.x - GameSettings.MINIMAP_SIZE.x - 20.0)
	_draw_pickups(fl, size_v)
	if GameSettings.show_fps:
		_draw_fps(fl, size_v)
	if title_shown > 0.0:
		var a2 := clampf(title_shown / 2.0, 0.0, 1.0)
		var H := func(id: String) -> String: return Controls.hint(id)
		var lines := ["移動: %s%s%s%s   攻撃: %s(押し続けて溜め)   転がり: %s   スキル: %s〜%s(%sで選び、右クリックで使う)   仲間の切替: %s" % [
				H.call("move_up"), H.call("move_left"), H.call("move_down"), H.call("move_right"), H.call("attack"), H.call("dodge"),
				H.call("skill1"), H.call("skill6"), H.call("skill_next"), H.call("switch")],
			"調べる: %s   探る: %s   持ち物: %s   治療薬: %s   休む: %s   ミニマップ: %s / %s(画面はホイール)   F1: クレジット(操作はタイトルか街の「操作の設定」で変えられる)" % [
				H.call("interact"), H.call("search"), H.call("inventory"), H.call("quick_heal"), H.call("rest"), H.call("zoom_in"), H.call("zoom_out")],
			"魔物は触れると殴ってくる。敵のHPを削るほど押し込め、こちらのHPが減ると押される。戻る・閉じる: Esc"]
		for i in lines.size():
			UI.text_center(self, size_v.x / 2.0, 150.0 + i * 22.0, lines[i], 14, Color(1, 1, 1, a2))
	if not overlay.is_empty():
		_draw_overlay(size_v)

## 迷宮の中の時刻を、太陽と月で見せる(時計は無い)。1時間刻みで動く。
## 昼は太陽が左(夜明け)から右(日没)へ、夜は月が同じ弧を渡る
func _draw_sky(dt: DungeonTime, size_v: Vector2, right: float) -> void:
	var w := 132.0
	var hh := 46.0
	var r := Rect2(minf(size_v.x / 2.0 - w / 2.0, right - 12.0 - w), 12.0, w, hh)
	var c := dt.clock()
	var hour := floorf(c / 60.0)
	var night := dt.is_night()
	var sky := Color("26407a")
	if night:
		sky = Color("0c1024")
	elif hour < 8.0:
		sky = Color("8a5a6a")
	elif hour >= 17.0:
		sky = Color("8a4a3a")
	draw_rect(r, Color(sky.r, sky.g, sky.b, 0.75))
	draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
	var base := Vector2(r.position.x + w / 2.0, r.end.y - 6.0)
	var rad := w / 2.0 - 12.0
	draw_line(Vector2(r.position.x + 4, base.y), Vector2(r.end.x - 4, base.y), Color(0, 0, 0, 0.5), 2.0)
	# 弧の上の位置(0 = 左の地平、1 = 右の地平)
	var t: float
	if night:
		var since := fmod(hour - Balance.NIGHT_MIN / 60.0 + 24.0, 24.0)
		t = since / ((24.0 * 60.0 - Balance.NIGHT_MIN + Balance.DAWN_MIN) / 60.0)
	else:
		t = (hour - Balance.DAWN_MIN / 60.0) / ((Balance.NIGHT_MIN - Balance.DAWN_MIN) / 60.0)
	t = clampf(t, 0.0, 1.0)
	var p := base + Vector2(-cos(t * PI), -sin(t * PI)) * Vector2(rad, hh - 14.0)
	if night:
		for k in 5:
			draw_rect(Rect2(r.position + Vector2(14.0 + k * 25.0, 8.0 + (k * 7) % 14), Vector2(2, 2)), Color(1, 1, 1, 0.6))
		draw_circle(p, 7.0, Color("e8e4c8"))
		draw_circle(p + Vector2(3.5, -2.5), 6.0, Color(sky.r, sky.g, sky.b, 1.0))      # 三日月
	else:
		draw_circle(p, 9.0, Color(1.0, 0.85, 0.35, 0.3))
		draw_circle(p, 6.0, Color("ffd85a"))
	UI.text_center(self, r.position.x + w / 2.0, r.end.y + 15.0, dt.phase_name(), 13, Color(0.9, 0.9, 0.95))
	if dt.resting:
		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.0, 0.02, 0.08, 0.35))
		var hrs := int(floorf((dt.minutes - dt.rest_from) / 60.0))
		UI.text_center(self, size_v.x / 2.0, size_v.y / 2.0 - 60.0, "休んでいる… %d時間" % hrs, 24, Color("e8dcb0"))
		UI.text_center(self, size_v.x / 2.0, size_v.y / 2.0 - 32.0, "%s / %s / Esc で起きる" % [Controls.hint("rest"), Controls.hint("interact")], 14, Color(0.8, 0.85, 0.9))

func _draw_pickups(fl: FloorInstance, size_v: Vector2) -> void:
	if pickups.is_empty():
		return
	var w := 230.0
	var x := size_v.x - w - 16.0
	var y := 16.0 + GameSettings.MINIMAP_SIZE.y + 16.0 if game.arena == null else 16.0
	for p in pickups:
		var age := float(p["age"])
		var a := clampf(minf(age / 0.15, (PICKUP_LIFE - age) / 0.6), 0.0, 1.0)
		var slide := (1.0 - clampf(age / 0.15, 0.0, 1.0)) * 30.0
		var r := Rect2(x + slide, y, w, 36)
		draw_rect(r, Color(0, 0, 0, 0.6 * a))
		var col: Color = p["color"]
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(col.r, col.g, col.b, a))
		var s := 28.0 + float(p["bump"]) * 16.0
		if p["tex"] != null:
			draw_texture_rect(p["tex"], Rect2(r.position + Vector2(8 + 14 - s / 2.0, 18 - s / 2.0), Vector2(s, s)), false, Color(1, 1, 1, a))
		var amt := float(p["amount"])
		var q := ""
		if String(p["unit"]) == "kg":
			q = "%.2fkg" % amt
		elif amt > 1.0:
			q = "×%d" % int(amt)
		UI.text(self, r.position + Vector2(44, 23), "%s  %s" % [p["name"], q], 14, Color(col.r, col.g, col.b, a), false)
		y += 40.0

## 下の帯: 通常攻撃(0)とスキル1〜6。Ctrl で選んでいるもの(右クリックで出る)を金の太枠で示す
func _draw_skillbar(size_v: Vector2) -> void:
	var heroes: Array = game.heroes
	if heroes.is_empty():
		return
	var h: Hero = heroes[game.active]
	var n := Character.SLOTS
	var w := 128.0
	var aw := 112.0
	var x0 := size_v.x / 2.0 - (w * n + 6.0 * (n - 1) + aw + 6.0) / 2.0 + aw + 6.0
	var y0 := size_v.y - 58.0
	var gold := Color("ffd060")
	# 通常攻撃: 待ち時間の進み具合を、左から満ちる棒で示す。溜めている間は、溜めの棒
	var ar := Rect2(x0 - aw - 6.0, y0, aw, 44)
	draw_rect(ar, Color(0, 0, 0, 0.6))
	var af := h.attack_ready_frac()
	if h.charging():
		draw_rect(Rect2(ar.position, Vector2(ar.size.x * h.charge_frac(), ar.size.y)), Color(0.85, 0.5, 0.15, 0.6))
	else:
		draw_rect(Rect2(ar.position, Vector2(ar.size.x * af, ar.size.y)), Color(0.55, 0.42, 0.2, 0.55) if af < 1.0 else Color(0.55, 0.42, 0.2, 0.25))
	UI.text(self, ar.position + Vector2(8, 18), "[%s] 攻撃" % Controls.hint("attack"), 14, Color("e8dcb0") if af >= 1.0 else Color(0.7, 0.7, 0.72), false)
	UI.text(self, ar.position + Vector2(8, 36), ("溜め %d%%" % int(h.charge_frac() * 100.0)) if h.charging() else "%s 待ち %.1f秒" % [ItemDB.WEAPON_CAT_JP.get(h.ch.weapon_cat(), "素手"), h.attack_cd()], 12, Color(0.7, 0.7, 0.75), false)
	_frame(ar, h.ch.skill_sel == 0, af >= 1.0, gold)
	for i in n:
		var id := String(h.ch.slots[i])
		var r := Rect2(x0 + i * (w + 6.0), y0, w, 44)
		draw_rect(r, Color(0, 0, 0, 0.6))
		var ready := false
		var sk := h.ch.skill_def(id) if id != "" else {}
		if not sk.is_empty():
			var cd := float(h.cds.get(id, 0.0))
			ready = h.can_cast(id)
			var full := float(sk["cd"])
			if cd > 0.0 and full > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(cd / full, 0.0, 1.0), r.size.y)), Color(0.3, 0.3, 0.35, 0.7))
			var nocol := Color("e8dcb0") if ready else Color(0.6, 0.6, 0.65)
			UI.text(self, r.position + Vector2(8, 18), "[%d] %s" % [i + 1, h.ch.skill_label(id)], 13, nocol, false)
			var mp_ok := h.ch.mp >= float(sk["mp"])
			UI.text(self, r.position + Vector2(8, 36), "MP %d" % int(sk["mp"]), 12, Color("7ab0ff") if mp_ok else Color("ff7a6a"), false)
		else:
			UI.text(self, r.position + Vector2(8, 18), "[%d] -" % (i + 1), 13, Color(0.4, 0.4, 0.45), false)
		_frame(r, h.ch.skill_sel == i + 1, ready, gold)

## 帯の一枠の縁。選んでいるものは金の太枠と、上に「右クリック」
func _frame(r: Rect2, selected: bool, ready: bool, gold: Color) -> void:
	if selected:
		draw_rect(r.grow(1.0), gold, false, 3.0)
		UI.text(self, r.position + Vector2(4, -5), "▶ %s" % _use_hint(), 11, gold)
	else:
		draw_rect(r, Color("e8dcb0") if ready else Color(1, 1, 1, 0.18), false, 1.5 if ready else 1.0)

## 「選んだスキルを使う」の入力の名前(マウスがあればマウス)
func _use_hint() -> String:
	var b: Dictionary = Controls.binds.get("skill_use", {})
	if not (b.get("mouse", {}) as Dictionary).is_empty():
		return Controls.label(b["mouse"])
	return Controls.hint("skill_use")

## 右上の小さな地図。仲間のまわりだけを、決まった大きさの枠に描く(+ / - で拡大・縮小)
func _draw_minimap(fl: FloorInstance, size_v: Vector2) -> void:
	var m := fl.map
	var s := GameSettings.minimap_scale()
	var box := GameSettings.MINIMAP_SIZE
	var bx := size_v.x - box.x - 16.0
	var by := 16.0
	draw_rect(Rect2(bx - 4, by - 4, box.x + 8, box.y + 8), Color(0, 0, 0, 0.55))
	var lc := m.cell_of(game.leader().position)
	var cw := int(box.x / s)
	var chh := int(box.y / s)
	var x0 := lc.x - cw / 2
	var y0 := lc.y - chh / 2
	# 枠の左上のマスが (x0, y0) になるよう、原点をずらす
	var ox := bx - x0 * s
	var oy := by - y0 * s
	var inside := func(c: Vector2i) -> bool: return c.x >= x0 and c.y >= y0 and c.x < x0 + cw and c.y < y0 + chh
	for y in range(maxi(0, y0), mini(m.h, y0 + chh)):
		for x in range(maxi(0, x0), mini(m.w, x0 + cw)):
			var i := y * m.w + x
			if m.explored[i] == 0:
				continue
			var t := m.tiles[i]
			if t == FloorMap.ROCK:
				continue
			if t == FloorMap.VOID:
				draw_rect(Rect2(ox + x * s, oy + y * s, s, s), Color.BLACK)   # 虚空(縦穴・竪坑の穴)
				continue
			if t == FloorMap.WATER or t == FloorMap.SHALLOW:
				var wc := Color(0.12, 0.3, 0.4) if t == FloorMap.WATER else Color(0.3, 0.5, 0.58)
				draw_rect(Rect2(ox + x * s, oy + y * s, s, s), wc if m.visible[i] == 1 else wc.darkened(0.35))
				continue
			if t == FloorMap.PILLAR:
				draw_rect(Rect2(ox + x * s, oy + y * s, s, s), Color(0.8, 0.76, 0.66))   # 柱
				continue
			var c := Color(0.5, 0.55, 0.5) if t == FloorMap.ROOM else Color(0.38, 0.42, 0.38)
			if t == FloorMap.DOOR:
				c = Color("a06a30")
			if m.visible[i] == 0:
				c = c.darkened(0.35)
			draw_rect(Rect2(ox + x * s, oy + y * s, s, s), c)
	for st in [[fl.up_cell, Color("7bd0ff")], [fl.down_cell, Color("ffb050")]]:
		var cc: Vector2i = st[0]
		if m.in_bounds(cc.x, cc.y) and m.explored[m.idx(cc.x, cc.y)] == 1 and inside.call(cc):
			draw_rect(Rect2(ox + cc.x * s - 1, oy + cc.y * s - 1, s + 2, s + 2), st[1])
	for h in game.heroes:
		var pc := m.cell_of(h.position)
		if inside.call(pc):
			draw_rect(Rect2(ox + pc.x * s - 1, oy + pc.y * s - 1, s + 2, s + 2), Color.WHITE if h == game.leader() else Color(0.8, 0.9, 1.0, 0.8))
	for en in fl.enemies:
		var ec := m.cell_of(en.position)
		if m.in_bounds(ec.x, ec.y) and m.visible[m.idx(ec.x, ec.y)] == 1 and inside.call(ec):
			draw_rect(Rect2(ox + ec.x * s - 1, oy + ec.y * s - 1, s + 1, s + 1), Color("ff4a3a"))

## FPS と、魔物の数(設定の「FPS の表示」)。上の真ん中、時刻の下に出す。
## 動 = 起きている、遠くを歩く = 軽い歩き方のワンダリング、眠り = 遠くで止めている、未出 = まだ出していない遭遇
func _draw_fps(fl: FloorInstance, size_v: Vector2) -> void:
	var fps := Engine.get_frames_per_second()
	var c := Color("8ae08a") if fps >= 55 else (Color("f1d98a") if fps >= 40 else Color("ff6a5a"))
	var sp := fl.spawner
	var t := "%d FPS   魔物 動 %d / 遠くを歩く %d / 眠り %d / 未出 %d組   上限 %d" % [fps, sp.awake, sp.light_n, sp.asleep_n, sp.pending.size(), Spawner.cap]
	if sp.queued > 0:
		t += "   順番待ち %d組" % sp.queued
	UI.text_center(self, size_v.x / 2.0, 92.0, t, 13, c)      # 時刻(太陽と月)の下

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
