class_name UnlockFx
extends Node2D
## 扉の解錠の演出。成功: 錠前の弓が外れて跳ね、金の光が散る。失敗: 錠前が揺れて赤く光る。
## 擬音(カチリ/ガチャガチャッ。Sfx.CUES の unlock / unlock_fail)は CueText で描く。

var ok := true
var age := 0.0
const LIFE := 0.9

static func make(pos: Vector2, success: bool) -> UnlockFx:
	var f := UnlockFx.new()
	f.position = pos
	f.ok = success
	f.z_index = 20
	return f

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a := 1.0 - clampf((age - 0.55) / 0.35, 0.0, 1.0)
	var gold := Color("e8c060")
	var body := Color(gold.r, gold.g, gold.b, a) if ok else Color(0.85, 0.35, 0.3, a)
	var dx := 0.0
	if not ok:
		dx = sin(age * 60.0) * 3.0 * (1.0 - clampf(age / 0.4, 0.0, 1.0))
	var c := Vector2(dx, -6.0)
	# 錠前の胴と鍵穴
	draw_rect(Rect2(c + Vector2(-7, -2), Vector2(14, 11)), body)
	draw_circle(c + Vector2(0, 2.5), 2.0, Color(0.1, 0.08, 0.05, a))
	draw_rect(Rect2(c + Vector2(-0.8, 3), Vector2(1.6, 4)), Color(0.1, 0.08, 0.05, a))
	# 弓(シャックル)。成功すると上へ外れて、片側が回る
	var lift := 0.0
	var turn := 0.0
	if ok:
		var k := clampf((age - 0.12) / 0.25, 0.0, 1.0)
		lift = 5.0 * k
		turn = -0.9 * k
	draw_set_transform(c + Vector2(5, -2 - lift), turn, Vector2.ONE)
	draw_arc(Vector2(-5, 0), 5.0, PI, TAU, 10, body, 2.4)
	draw_line(Vector2(0, 0), Vector2(0, 2), body, 2.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ok:
		# 光の筋と、広がる輪
		var g := clampf((age - 0.25) / 0.5, 0.0, 1.0)
		if g > 0.0:
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0 + 0.2)
				draw_line(c + dir * (8.0 + 14.0 * g), c + dir * (12.0 + 22.0 * g), Color(1.0, 0.92, 0.6, (1.0 - g)), 2.0)
			draw_arc(c, 10.0 + 26.0 * g, 0.0, TAU, 28, Color(1.0, 0.9, 0.55, (1.0 - g) * 0.8), 2.0)
		CueText.draw_word(self, CueText.split(String(Sfx.CUES["unlock"][0])), "pop", age, 99.0, 14.0, Color(1.0, 0.92, 0.6, a), 0.0, false, Vector2(0, -30.0))
	else:
		CueText.draw_word(self, CueText.split(String(Sfx.CUES["unlock_fail"][0])), "shake", age, 99.0, 13.0, Color(1.0, 0.6, 0.55, a), 0.0, false, Vector2(0, -30.0))
