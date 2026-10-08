class_name FloatText
extends Node2D
## ダメージの数字などが、浮き上がって消える。

var text := ""
var color := Color.WHITE
var age := 0.0
const LIFE := 0.8

func _process(delta: float) -> void:
	age += delta
	position.y -= 26.0 * delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a := 1.0 - clampf((age - 0.4) / (LIFE - 0.4), 0.0, 1.0)
	UI.text_center(self, 0.0, 0.0, text, 16, Color(color.r, color.g, color.b, a))
