class_name Spark
extends Node2D
## 一瞬だけ広がる輪。技の範囲や、体当たりの火花に使う。

var max_radius := 20.0
var color := Color.WHITE
var life := 0.25
var age := 0.0
var filled := false

static func make(pos: Vector2, r: float, c: Color, l: float = 0.25, fill: bool = false) -> Spark:
	var s := Spark.new()
	s.position = pos
	s.max_radius = r
	s.color = c
	s.life = l
	s.filled = fill
	return s

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := age / life
	var r := max_radius * (0.35 + 0.65 * k)
	var a := 1.0 - k
	if filled:
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.28 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(color.r, color.g, color.b, a), 3.0)
