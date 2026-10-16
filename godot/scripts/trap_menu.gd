class_name TrapMenu
extends Control
## 見つけた罠の前で、どうするかを選ぶ(解除する / わざと発動させる / 飛び越える / やめる)。
## 開いている間、迷宮は止まる(Main が止める)。Esc か B でやめる。

signal chosen(action: String)   # "disarm" / "spring" / "jump" / ""(やめる)

var _first: Button

## lines: [[action, ボタンの文字, 説明]]
func setup(title: String, note: String, lines: Array) -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(560, 0)
	cc.add_child(p)
	var v := UIKit.vbox(8)
	p.add_child(v)
	v.add_child(UIKit.label(title, 22, UIKit.GOLD))
	var n := UIKit.label(note, 14, UIKit.DIM)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(540, 0)
	v.add_child(n)
	for l in lines:
		var row := UIKit.hbox(12)
		var b := UIKit.button(String(l[1]), _pick.bind(String(l[0])), 200)
		row.add_child(b)
		var d := UIKit.label(String(l[2]), 14)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.custom_minimum_size = Vector2(330, 0)
		row.add_child(d)
		v.add_child(row)
		if _first == null:
			_first = b
	var cancel := UIKit.button("やめる(Esc)", _pick.bind(""), 200)
	v.add_child(cancel)
	if _first == null:
		_first = cancel
	_first.call_deferred("grab_focus")

func _pick(a: String) -> void:
	chosen.emit(a)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pick("")
