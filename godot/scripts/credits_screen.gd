class_name CreditsScreen
extends Control
## クレジットとライセンスの表記(ken 10/18「ちゃんとした SRD のライセンス表記」)。タイトルの「クレジット」か F1 で開く。
## SRD 5.1 は CC-BY-4.0 なので、決まった帰属表示の文、ライセンスへのリンク、手を加えたこと、
## Wizards of the Coast が認めたものではないこと、を書く(docs/srd-data-sources.md §3)。
## フォント(OFL 1.1)と Godot Engine(MIT と、中の部品のライセンス)も、ここに載せる。
## 長いので、ホイール・上下キーで送る。Esc・F1・閉じるで閉じる。

signal closed

const SRD_ATTRIBUTION := "This work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode."
const SRD_CHANGES := "Changes: the SRD 5.1 material used in this game (monster statistics, traits and actions, traps, spells, conditions, class proficiencies, equipment and damage dice) has been abridged, rescaled for real-time play and translated into Japanese. Names in Japanese are unofficial translations or new names made for this game."
const SRD_NO_ENDORSE := "This game is not affiliated with, endorsed, sponsored, or specifically approved by Wizards of the Coast LLC."
const SRD_JA := "魔物の数値・特徴・行動、罠、呪文、状態、クラスの習熟、装備、ダメージの式を SRD 5.1 から借り、要点だけに縮め、リアルタイムに合わせて係数をかけ、日本語にした。日本語の名前は、このゲームのための仮訳か、新しく付けた名前で、公式の訳語ではない。このゲームは Wizards of the Coast LLC と関係がなく、同社が認めたものでもない。"
const FONTS := [
	["M+ 1p", "Copyright 2016 The M+ Project Authors."],
	["Shippori Mincho", "Copyright 2021 The Shippori Mincho Project Authors (https://github.com/fontdasu/ShipporiMincho)"],
	["Dela Gothic One(擬音)", "Copyright 2020 The Dela Gothic Project Authors (https://github.com/syakuzen/DelaGothic)"],
]

var text: RichTextLabel
var scroll: ScrollContainer

## 表記の全文(BBCode)。Godot の部品とライセンスの全文は、動いている Engine から取る
static func body() -> String:
	var b := PackedStringArray()
	b.append("[font_size=28][color=#e8dcb0]Urbs Labyrinthi[/color][/font_size]\n迷宮都市ヴェルガ・ノクス(試作)\n")
	b.append(_head("System Reference Document 5.1(CC-BY-4.0)"))
	b.append(SRD_ATTRIBUTION + "\n\n" + SRD_CHANGES + "\n\n" + SRD_NO_ENDORSE + "\n\n[color=#c8d8e8]" + SRD_JA + "[/color]\n")
	b.append(_head("フォント(SIL Open Font License, Version 1.1)"))
	for f in FONTS:
		b.append("%s — %s" % [f[0], f[1]])
	b.append("\nThese fonts are licensed under the SIL Open Font License, Version 1.1 (https://openfontlicense.org). 許諾文は godot/assets/fonts/ に同梱。\n")
	b.append(_head("Godot Engine"))
	b.append("This game uses Godot Engine, available under the following license:\n\n" + Engine.get_license_text())
	b.append(_head("Godot Engine の中の部品"))
	for c in Engine.get_copyright_info():
		for p in c["parts"]:
			var who := PackedStringArray()
			for s in p["copyright"]:
				who.append("© " + String(s))
			b.append("%s — %s (%s)" % [c["name"], ", ".join(who), p["license"]])
	b.append(_head("ライセンスの全文"))
	var lic: Dictionary = Engine.get_license_info()
	var keys: Array = lic.keys()
	keys.sort()
	for k in keys:
		b.append("[color=#e8dcb0]%s[/color]\n%s\n" % [k, String(lic[k]).replace("[", "[lb]")])
	return "\n".join(b)

static func _head(s: String) -> String:
	return "\n[font_size=20][color=#ffe6a0]%s[/color][/font_size]\n" % s

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 120)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	add_child(m)
	var v := UIKit.vbox(10)
	m.add_child(v)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.selection_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", UI.font())
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95))
	text.text = body()
	scroll.add_child(text)
	var row := UIKit.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close := UIKit.button("閉じる(Esc / F1)", close_screen, 240)
	row.add_child(close)
	v.add_child(row)
	close.call_deferred("grab_focus")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down"):
		scroll.scroll_vertical += 60 * (1 if e.is_action_pressed("ui_down") else -1)
		get_viewport().set_input_as_handled()

func close_screen() -> void:
	closed.emit()
	queue_free()
