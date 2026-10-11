class_name UI
extends RefCounted
## 文字を描くための共通部品。

static var _font: Font
static var _bold: Font
static var _title: Font

## 本文: M+ 1p Medium。差し替えのフォント(font.ttf)を置くと、本文も太字も見出しもそれになる
static func font() -> Font:
	if _font == null:
		_font = Assets.font()
	if _font == null:
		_font = load("res://assets/fonts/MPLUS1p-Medium.ttf") as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font

## 太字(RichTextLabel の [b]): M+ 1p Bold
static func bold_font() -> Font:
	if _bold == null:
		_bold = Assets.font()
	if _bold == null:
		_bold = load("res://assets/fonts/MPLUS1p-Bold.ttf") as Font
		if _bold == null:
			_bold = font()
	return _bold

## 見出しとタイトル: しっぽり明朝 SemiBold
static func title_font() -> Font:
	if _title == null:
		_title = Assets.font()
	if _title == null:
		_title = load("res://assets/fonts/ShipporiMincho-SemiBold.ttf") as Font
		if _title == null:
			_title = font()
	return _title

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int = 14, color: Color = Color.WHITE, outline: bool = true) -> void:
	if outline:
		ci.draw_string_outline(font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85 * color.a))
	ci.draw_string(font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func text_center(ci: CanvasItem, center_x: float, y: float, s: String, size: int = 14, color: Color = Color.WHITE, outline: bool = true) -> void:
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(center_x - w / 2.0, y), s, size, color, outline)
