class_name ArenaPanel
extends PanelContainer
## 闘技場の操作盤(右側)。敵のポップ、キャラクターのレベル、係数の調整、記録。F2 で出し入れする。
## ボタンはキーボードの焦点を取らない(Space や Enter を、ゲームの操作として使うため)。

var arena: Arena
var main: Node
var summary_label: Label
var hist_label: Label
var pop_label: Label
var lvl_label: Label
var party_lvl_label: Label
var npc_label: Label
var diff_btns: Array = []
var hero_rows: VBoxContainer
var tune_sliders := {}
var tune_labels := {}
var _t := 0.0
var _all_level := 1

func setup(a: Arena, m: Node) -> void:
	arena = a
	main = m
	_all_level = a.enc_level

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	custom_minimum_size = Vector2(392, 0)
	offset_left = -392
	add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.04, 0.07, 0.86), Color(0.66, 0.47, 0.29, 0.8)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var v := UIKit.vbox(7)
	v.custom_minimum_size = Vector2(360, 0)
	scroll.add_child(v)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.label("闘技場(調整用)", 20, UIKit.GOLD))
	head.add_child(UIKit.button("街へ戻る", func(): main.exit_arena()))
	v.add_child(head)
	v.add_child(UIKit.label("F2 で、この盤を出し入れ。経験点も宝も出ない", 12, UIKit.DIM))
	# --- 敵をポップ ---
	v.add_child(_section("敵をポップ"))
	v.add_child(_stepper("遭遇レベル", func(d): arena.enc_level = clampi(arena.enc_level + d, 1, 20); _refresh(), func(): return str(arena.enc_level), "lvl"))
	var dr := UIKit.hbox(6)
	dr.add_child(UIKit.label("難度", 15, UIKit.DIM))
	for i in 3:
		var b := UIKit.button(EncounterGen.DIFF_JP[i], func(): arena.diff = i; _refresh())
		diff_btns.append(b)
		dr.add_child(b)
	v.add_child(dr)
	var tr := UIKit.hbox(6)
	tr.add_child(UIKit.label("舞台", 15, UIKit.DIM))
	var opt := OptionButton.new()
	for id in EncounterGen.theme_ids():
		opt.add_item(EncounterGen.theme_name(id))
	opt.item_selected.connect(func(i): arena.set_theme(EncounterGen.theme_ids()[i]))
	tr.add_child(opt)
	v.add_child(tr)
	v.add_child(_stepper("予算の人数", func(d): arena.party_n = clampi(arena.party_n + d, 1, 8); _refresh(), func(): return str(arena.party_n), "npc"))
	var pr := UIKit.hbox(6)
	pr.add_child(UIKit.button("ポップ", func(): pop_label.text = arena.pop(); _refresh(), 120))
	pr.add_child(UIKit.button("全消去", func(): arena.clear_enemies(); _refresh(), 100))
	v.add_child(pr)
	pop_label = UIKit.label("", 13, Color("b8d8ff"))
	pop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pop_label.custom_minimum_size = Vector2(350, 0)
	v.add_child(pop_label)
	v.add_child(_check("連戦(倒したら次の波を出す)", arena.auto_waves, func(on): arena.auto_waves = on; if on and not arena.wave_active: arena._next_t = 0.3))
	v.add_child(_check("波ごとに遭遇レベル+1", arena.level_up_each, func(on): arena.level_up_each = on))
	v.add_child(_check("波の間に、全回復する", arena.heal_between, func(on): arena.heal_between = on))
	# --- キャラクターのレベル ---
	v.add_child(_section("キャラクターのレベル"))
	var allrow := UIKit.hbox(6)
	allrow.add_child(UIKit.label("全員", 15, UIKit.DIM))
	allrow.add_child(_small("−", func(): _all_level = clampi(_all_level - 1, 1, 20); _refresh()))
	party_lvl_label = UIKit.label("", 16, UIKit.GOLD)
	party_lvl_label.custom_minimum_size = Vector2(46, 0)
	party_lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	allrow.add_child(party_lvl_label)
	allrow.add_child(_small("＋", func(): _all_level = clampi(_all_level + 1, 1, 20); _refresh()))
	allrow.add_child(UIKit.button("全員に適用", func(): arena.set_all_levels(_all_level); _refresh()))
	v.add_child(allrow)
	hero_rows = UIKit.vbox(4)
	v.add_child(hero_rows)
	for i in arena.chars.size():
		hero_rows.add_child(_hero_row(i))
	var hb := UIKit.hbox(6)
	hb.add_child(UIKit.button("HP・MPを全回復", func(): arena.heal_all()))
	hb.add_child(UIKit.button("記録を消す", func(): arena.reset_stats(); _refresh()))
	v.add_child(hb)
	# --- 係数 ---
	v.add_child(_section("係数(その場で効く)"))
	for key in Balance.TUNABLE:
		v.add_child(_tune_row(key))
	var tb := UIKit.hbox(6)
	tb.add_child(UIKit.button("初期値に戻す", func(): Balance.tune_reset(); _sync_sliders()))
	tb.add_child(UIKit.button("値をコピー", _copy_values))
	v.add_child(tb)
	# --- 記録 ---
	v.add_child(_section("記録"))
	summary_label = UIKit.label("", 13)
	v.add_child(summary_label)
	hist_label = UIKit.label("", 12, Color("c8d0e0"))
	hist_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hist_label.custom_minimum_size = Vector2(350, 0)
	v.add_child(hist_label)
	_nofocus(self)
	_refresh()

func _nofocus(n: Node) -> void:
	if n is Control and not (n is Label) and not (n is PanelContainer) and not (n is ScrollContainer):
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_nofocus(c)

func _section(t: String) -> Control:
	var l := UIKit.label("── " + t, 16, UIKit.ACCENT)
	return l

func _small(t: String, cb: Callable) -> Button:
	var b := UIKit.button(t, cb)
	b.custom_minimum_size = Vector2(36, 32)
	return b

func _stepper(title: String, step: Callable, value: Callable, tag: String) -> Control:
	var r := UIKit.hbox(6)
	var l := UIKit.label(title, 15, UIKit.DIM)
	l.custom_minimum_size = Vector2(96, 0)
	r.add_child(l)
	r.add_child(_small("−", func(): step.call(-1)))
	var vl := UIKit.label(String(value.call()), 17, UIKit.GOLD)
	vl.custom_minimum_size = Vector2(40, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(vl)
	r.add_child(_small("＋", func(): step.call(1)))
	if tag == "lvl":
		lvl_label = vl
	else:
		npc_label = vl
	return r

func _check(t: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = t
	c.button_pressed = on
	c.toggled.connect(cb)
	return c

func _hero_row(i: int) -> Control:
	var c: Character = arena.chars[i]
	var r := UIKit.hbox(6)
	var l := UIKit.label("%s(%s)" % [c.name, Jobs.CLASSES[c.cls]["name"]], 14)
	l.custom_minimum_size = Vector2(130, 0)
	r.add_child(l)
	r.add_child(_small("−", func(): arena.set_level(i, c.level - 1); _refresh()))
	var vl := UIKit.label("Lv%d" % c.level, 16, UIKit.GOLD)
	vl.name = "lv%d" % i
	vl.custom_minimum_size = Vector2(50, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(vl)
	r.add_child(_small("＋", func(): arena.set_level(i, c.level + 1); _refresh()))
	return r

func _tune_row(key: String) -> Control:
	var info: Array = Balance.TUNABLE[key]
	var box := UIKit.vbox(0)
	var lab := UIKit.label("", 13, Color("d0d8e8"))
	box.add_child(lab)
	var sl := HSlider.new()
	sl.min_value = float(info[1])
	sl.max_value = float(info[2])
	sl.step = (float(info[2]) - float(info[1])) / 200.0
	sl.value = Balance.tune_get(key)
	sl.custom_minimum_size = Vector2(340, 18)
	sl.value_changed.connect(func(v): Balance.tune_set(key, v); _update_tune_label(key))
	box.add_child(sl)
	tune_sliders[key] = sl
	tune_labels[key] = lab
	_update_tune_label(key)
	return box

func _update_tune_label(key: String) -> void:
	var info: Array = Balance.TUNABLE[key]
	(tune_labels[key] as Label).text = "%s = %.3f  (初期 %s)  %s" % [key, Balance.tune_get(key), str(info[0]), info[3]]

func _sync_sliders() -> void:
	for key in tune_sliders:
		(tune_sliders[key] as HSlider).set_value_no_signal(Balance.tune_get(key))
		_update_tune_label(key)

func _copy_values() -> void:
	var t := ""
	for key in Balance.TUNABLE:
		t += "static var %s := %s\n" % [key, str(snappedf(Balance.tune_get(key), 0.001))]
	DisplayServer.clipboard_set(t)
	pop_label.text = "係数をクリップボードへコピーした(balance.gd へ貼る)"

func _refresh() -> void:
	if arena == null:
		return
	lvl_label.text = str(arena.enc_level)
	npc_label.text = str(arena.party_n)
	party_lvl_label.text = "Lv%d" % _all_level
	for i in diff_btns.size():
		(diff_btns[i] as Button).add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2) if i == arena.diff else UIKit.box(Color(0.12, 0.13, 0.18, 0.95)))
	for i in arena.chars.size():
		var vl := hero_rows.get_child(i).get_node_or_null("lv%d" % i) as Label
		if vl != null:
			vl.text = "Lv%d" % arena.chars[i].level
	summary_label.text = arena.summary()
	hist_label.text = "\n".join(arena.history)

func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_refresh()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F2:
		visible = not visible
