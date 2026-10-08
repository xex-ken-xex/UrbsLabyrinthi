class_name TitleScreen
extends Control
## タイトル。街の夜景の前で、はじめから / つづきから。

signal new_game
signal continue_game
signal show_credits

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
	var b1 := UIKit.button("はじめから", func(): new_game.emit(), 260)
	var b2 := UIKit.button("つづきから", func(): continue_game.emit(), 260)
	b2.disabled = not GameState.has_save()
	var b3 := UIKit.button("クレジット", func(): show_credits.emit(), 260)
	var b4 := UIKit.button("終了", func(): get_tree().quit(), 260)
	for b in [b1, b2, b3, b4]:
		v.add_child(b)
	(b2 if not b2.disabled else b1).call_deferred("grab_focus")
	var foot := UIKit.label("燐晶を持ち帰れ。通路は毎夜、変わる。", 14, UIKit.DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
