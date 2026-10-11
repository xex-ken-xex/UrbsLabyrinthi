class_name KeyConfig
extends Control
## 操作の設定(キーコンフィグ)。枠を選んで、割り当てたいキーかコントローラーのボタンを押す。
## 押している間は Esc でやめる、Delete / Backspace でその枠を空にする。変えたらすぐ保存する。

signal closed

var slots := {}            # "id:slot" → Button
var msg: Label
var _capture := ""         # 待っている枠("id:slot")。空なら待っていない
var _arm_t := 0.0          # 枠を選んだ入力そのものを拾わないための待ち
var first: Button

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := UIKit.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 24
	root.offset_bottom = -20
	add_child(root)
	var head := UIKit.hbox(16)
	head.add_child(UIKit.label("操作の設定", 28, UIKit.GOLD))
	var note := UIKit.label("枠を選んで、割り当てるキーかボタンを押す。Esc でやめる、Delete で空にする。左スティックでの移動はいつでもできる。", 14, UIKit.DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(note)
	root.add_child(head)
	var panel := UIKit.panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	sc.add_child(grid)
	for h in ["操作", "キー1", "キー2", "コントローラー"]:
		grid.add_child(UIKit.label(h, 15, UIKit.DIM))
	for a in Controls.ACTIONS:
		var id: String = a[0]
		var nm := UIKit.label(String(a[1]), 15)
		nm.custom_minimum_size = Vector2(250, 0)
		grid.add_child(nm)
		for s in ["k0", "k1", "pad"]:
			var b := UIKit.button("", _on_slot.bind(id, s), 230)
			b.custom_minimum_size = Vector2(230, 30)
			b.add_theme_font_size_override("font_size", 15)
			grid.add_child(b)
			slots["%s:%s" % [id, s]] = b
			if first == null:
				first = b
	msg = UIKit.label("", 15, UIKit.GOOD)
	root.add_child(msg)
	var bot := UIKit.hbox(12)
	bot.add_child(UIKit.button("初期設定に戻す", _on_reset, 220))
	bot.add_child(UIKit.button("閉じる", _close, 180))
	root.add_child(bot)
	_refresh()
	first.call_deferred("grab_focus")

func _refresh() -> void:
	for a in Controls.ACTIONS:
		var id: String = a[0]
		var b: Dictionary = Controls.binds[id]
		for s in ["k0", "k1", "pad"]:
			var d: Dictionary = b["pad"] if s == "pad" else b["keys"][int(s.substr(1))]
			var btn: Button = slots["%s:%s" % [id, s]]
			var key := "%s:%s" % [id, s]
			if key == _capture:
				btn.text = "押して…"
				btn.add_theme_color_override("font_color", UIKit.GOLD)
				continue
			btn.text = Controls.label(d) if not d.is_empty() else "—"
			var clash := not Controls.conflicts(id, d).is_empty()
			btn.add_theme_color_override("font_color", UIKit.BAD if clash else (UIKit.TEXT if not d.is_empty() else UIKit.DIM))

func _on_slot(id: String, s: String) -> void:
	_capture = "%s:%s" % [id, s]
	_arm_t = 0.25
	msg.text = "「%s」に割り当てる%sを押す(Esc でやめる、Delete で空にする)" % [Controls.action_name(id), "コントローラーの入力" if s == "pad" else "キー"]
	msg.add_theme_color_override("font_color", UIKit.GOLD)
	_refresh()

func _process(delta: float) -> void:
	_arm_t = maxf(0.0, _arm_t - delta)

func _input(e: InputEvent) -> void:
	if _capture == "":
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("inventory"):
			get_viewport().set_input_as_handled()
			_close()
		return
	# 待っている間は、どの入力も画面の操作に回さない
	get_viewport().set_input_as_handled()
	if _arm_t > 0.0:
		return
	var parts := _capture.split(":")
	var id: String = parts[0]
	var s: String = parts[1]
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			_end("やめた", UIKit.DIM)
			return
		if e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE:
			Controls.set_bind(id, s, {})
			_end("「%s」の枠を空にした" % Controls.action_name(id), UIKit.DIM)
			return
	var d := Controls.from_event(e)
	if d.is_empty():
		return
	var want_pad := s == "pad"
	if (String(d["t"]) == "key") == want_pad:
		msg.text = "この枠には%sを押す" % ("コントローラーの入力" if want_pad else "キーボードのキー")
		msg.add_theme_color_override("font_color", UIKit.BAD)
		return
	Controls.set_bind(id, s, d)
	var cl := Controls.conflicts(id, d)
	if cl.is_empty():
		_end("「%s」を %s にした" % [Controls.action_name(id), Controls.label(d)], UIKit.GOOD)
	else:
		_end("%s は「%s」にも割り当てている(赤い枠)" % [Controls.label(d), "」「".join(cl.map(func(x): return Controls.action_name(x)))], UIKit.BAD)

func _end(text: String, color: Color) -> void:
	var key := _capture
	_capture = ""
	msg.text = text
	msg.add_theme_color_override("font_color", color)
	_refresh()
	if slots.has(key):
		(slots[key] as Button).grab_focus()

func _on_reset() -> void:
	Controls.reset()
	_capture = ""
	msg.text = "初期設定に戻した"
	msg.add_theme_color_override("font_color", UIKit.GOOD)
	_refresh()

func _close() -> void:
	if _capture != "":
		return
	closed.emit()
