class_name HeroPreview
extends Control
## キャラ作成で、選んだ見た目を見せる。その場で歩き、少しずつ向きを変える(下 → 左 → 上 → 右)。

var char_name := ""
var cls := "fighter"
var race := "human"
var look := "M"
var t := 0.0

func set_look(nm: String, c: String, r: String, l: String) -> void:
	char_name = nm
	cls = c
	race = r
	look = l
	queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var v := Assets.hero_visual(char_name, cls, race, look)
	var tex: Texture2D = v["tex"]
	if tex == null:
		return
	var sz := minf(size.x, size.y)
	var c := Vector2(size.x / 2.0, size.y / 2.0)
	draw_set_transform(c + Vector2(0, sz * 0.4), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, sz * 0.2, Color(0, 0, 0, 0.4))      # 足もとの影
	draw_set_transform(Vector2.ZERO)
	if v["sheet"]:
		var dir: int = [0, 1, 3, 2][int(t / 1.6) % 4]
		draw_set_transform(c)
		Assets.draw_sheet_frame(self, tex, Assets.sheet_frame(dir, t * 6.0, true), sz, sz * 0.5)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) * 0.4, Vector2(sz, sz) * 0.8), false)
