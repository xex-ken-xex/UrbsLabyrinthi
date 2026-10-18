class_name TitleScreen
extends Control
## タイトル。街の夜景の前で、はじめから / つづきから。

signal new_game
signal continue_game
signal show_credits
signal key_config

var _focus: Button
var _note: Label

## big: 「保存しました。」のように、目立たせたい一言
func set_note(text: String, big: bool = false) -> void:
	if _note != null:
		_note.text = text
		_note.add_theme_font_size_override("font_size", 22 if big else 14)
		_note.add_theme_color_override("font_color", UIKit.GOLD if big else Color("a8c8e8"))

func focus_default() -> void:
	if _focus != null:
		_focus.grab_focus()

## 「つづきから」の下に出す、記録の中身(保存した日時、居場所、日付、仲間のレベル)
static func save_info() -> String:
	var sm := GameState.save_summary()
	if sm.is_empty():
		return ""
	var names: Array = []
	for p in sm["party"]:
		var cls := String(p[1])
		var cname := String(Jobs.CLASSES[cls]["name"]) if Jobs.CLASSES.has(cls) else cls
		names.append("%s %s Lv%d" % [p[0], cname, int(p[2])])
	return "%s 保存 ・ %s ・ %s ・ 預け金 %d銀貨\n%s" % [sm["when"], sm["where"], ZaCalendar.label(int(sm["day"])), int(sm["bank"]), " / ".join(names)]

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TownArt.new()
	art.style = "town"
	art.asset_key = "bg_title"
	add_child(art)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var logo := Assets.texture("logo")
	if logo != null:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(620, 180)
		v.add_child(tr)
	else:
		var t1 := UIKit.label("Urbs Labyrinthi", 58, UIKit.GOLD)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t1)
	var t2 := UIKit.label("迷宮都市ヴェルガ・ノクス", 22, Color("a8c8e8"))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	v.add_child(Control.new())
	# 目的を、ボタンの上に大きく。ゆっくり明滅して目を引く
	var goal := UIKit.label("燐晶を持ち帰れ。通路は毎夜、変わる。", 26, Color("ffe6a0"))
	goal.add_theme_font_override("font", UI.title_font())
	goal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	goal.add_theme_constant_override("outline_size", 6)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(goal)
	var tw := goal.create_tween().set_loops()
	tw.tween_property(goal, "modulate", Color(1.25, 1.15, 0.9), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(goal, "modulate", Color(0.8, 0.78, 0.72), 1.4).set_trans(Tween.TRANS_SINE)
	v.add_child(Control.new())
	var b1 := UIKit.button("はじめから", func(): new_game.emit(), 260)
	var b2 := UIKit.button("つづきから", func(): continue_game.emit(), 260)
	b2.disabled = not GameState.has_save()
	var b3 := UIKit.button("クレジット", func(): show_credits.emit(), 260)
	var b5 := UIKit.button("操作の設定", func(): key_config.emit(), 260)
	var b4 := UIKit.button("終了", func(): get_tree().quit(), 260)
	for b in [b1, b2]:
		v.add_child(b)
	var info := save_info()
	if info != "":
		var il := UIKit.label(info, 14, Color("c8d8e8"))
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		il.add_theme_constant_override("outline_size", 4)
		v.add_child(il)
	for b in [b5, b3, b4]:
		v.add_child(b)
	_focus = b2 if not b2.disabled else b1
	_focus.call_deferred("grab_focus")
	_note = UIKit.label("", 14, Color("a8c8e8"))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_note.add_theme_constant_override("outline_size", 4)
	v.add_child(_note)
