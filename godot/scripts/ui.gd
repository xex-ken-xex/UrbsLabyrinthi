class_name UI
extends RefCounted
## 文字を描くための共通部品。

static var _font: Font

static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/ZenKakuGothicNew-Regular.ttf") as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int = 14, color: Color = Color.WHITE, outline: bool = true) -> void:
	if outline:
		ci.draw_string_outline(font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	ci.draw_string(font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func text_center(ci: CanvasItem, center_x: float, y: float, s: String, size: int = 14, color: Color = Color.WHITE) -> void:
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(center_x - w / 2.0, y), s, size, color)
