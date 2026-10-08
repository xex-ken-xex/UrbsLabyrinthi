class_name UIKit
extends RefCounted
## 画面部品の見た目。暗い地に青銅の縁、金の文字(座環盤の配色に合わせた)。

const BG := Color(0.05, 0.06, 0.09, 0.88)
const BG2 := Color(0.09, 0.10, 0.14, 0.92)
const BRONZE := Color("a8794a")
const GOLD := Color("e8dcb0")
const TEXT := Color("d8dce6")
const DIM := Color("8a90a0")
const ACCENT := Color("5bc0de")
const GOOD := Color("8ae08a")
const BAD := Color("ff8a7a")

static var _theme: Theme

static func box(bg: Color, border: Color = BRONZE, bw: int = 1, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = UI.font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", cls, box(Color(0.12, 0.13, 0.18, 0.95)))
		t.set_stylebox("hover", cls, box(Color(0.2, 0.2, 0.26, 0.98), GOLD))
		t.set_stylebox("pressed", cls, box(Color(0.28, 0.24, 0.16, 1.0), GOLD))
		t.set_stylebox("focus", cls, box(Color(0, 0, 0, 0), ACCENT, 2))
		t.set_stylebox("disabled", cls, box(Color(0.08, 0.08, 0.1, 0.8), Color(0.3, 0.3, 0.34)))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, GOLD)
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color(0.45, 0.47, 0.52))
		t.set_color("font_focus_color", cls, GOLD)
	t.set_stylebox("panel", "PanelContainer", box(BG))
	t.set_stylebox("panel", "Panel", box(BG))
	t.set_stylebox("normal", "LineEdit", box(Color(0.03, 0.03, 0.05, 0.95)))
	t.set_stylebox("focus", "LineEdit", box(Color(0.03, 0.03, 0.05, 0.95), ACCENT, 2))
	t.set_color("font_color", "LineEdit", GOLD)
	t.set_stylebox("panel", "ItemList", box(Color(0.03, 0.03, 0.05, 0.8)))
	t.set_stylebox("selected", "ItemList", box(Color(0.3, 0.25, 0.14, 1.0), GOLD))
	t.set_stylebox("selected_focus", "ItemList", box(Color(0.3, 0.25, 0.14, 1.0), GOLD))
	t.set_stylebox("hovered", "ItemList", box(Color(0.16, 0.16, 0.22, 1.0), BRONZE))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", GOLD)
	t.set_constant("v_separation", "ItemList", 4)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.06, 0.07, 0.1, 0.98)))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.3, 0.25, 0.14, 1.0), GOLD))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	_theme = t
	return t

static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 36)
	b.pressed.connect(cb)
	return b

static func panel() -> PanelContainer:
	return PanelContainer.new()

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
