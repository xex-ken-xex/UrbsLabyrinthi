class_name DiceFx
extends Node2D
## ロール式で能力値を振ったときの擬音。サイコロ3つぶんの「コロコロ」「コロ」「コロコロコロ」が、
## 画面を横切って跳ねながら転がる。文字は一文字ずつ跳ねる(CueText の bounce)。

const WORDS := ["dice_1", "dice_2", "dice_3"]
const LIFE := 1.25

var text := ""
var color := Color.WHITE
var age := 0.0
var delay := 0.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var hop := 60.0          # 跳ねる高さ
var bounces := 3.0       # 跳ねる回数
var spin := 1.0          # 転がる向きと速さ
var size := 30

## サイコロ3つぶんを投げる。parent は画面(Control)、area はその中の飛び交う範囲
static func throw(parent: CanvasItem, area: Rect2) -> void:
	if parent == null:
		return
	for i in WORDS.size():
		var id: String = WORDS[i]
		var f := DiceFx.new()
		f.text = String(Sfx.CUES[id][0])
		f.color = Sfx.CUES[id][1]
		var left := randf() < 0.5
		var y0 := area.position.y + area.size.y * randf_range(0.25, 0.75)
		var y1 := area.position.y + area.size.y * randf_range(0.3, 0.85)
		var x0 := area.position.x + area.size.x * randf_range(0.02, 0.2)
		var x1 := area.position.x + area.size.x * randf_range(0.8, 0.98)
		f.from = Vector2(x0 if left else x1, y0)
		f.to = Vector2(x1 if left else x0, y1)
		f.delay = i * 0.12 + randf_range(0.0, 0.06)
		f.hop = randf_range(50.0, 110.0)
		f.bounces = randf_range(2.5, 4.0)
		f.spin = (1.0 if left else -1.0) * randf_range(0.8, 1.4)
		f.size = randi_range(28, 36)
		f.position = f.from
		f.visible = false
		f.z_index = 50
		parent.add_child(f)

func _process(delta: float) -> void:
	age += delta
	if age >= delay + LIFE:
		queue_free()
		return
	var t := clampf((age - delay) / LIFE, 0.0, 1.0)
	visible = age >= delay
	var e := 1.0 - pow(1.0 - t, 2.0)                       # 転がるうちに遅くなる
	var b := absf(sin(t * PI * bounces)) * hop * (1.0 - t)  # 跳ねるたびに低くなる
	position = from.lerp(to, e) - Vector2(0, b)
	rotation = sin(t * PI * bounces * 2.0) * 0.35 * spin * (1.0 - t)
	queue_redraw()

func _draw() -> void:
	var t := clampf((age - delay) / LIFE, 0.0, 1.0)
	var a := 1.0 - clampf((t - 0.75) / 0.25, 0.0, 1.0)
	var pop := 1.0 + 0.3 * (1.0 - clampf(t / 0.1, 0.0, 1.0))
	CueText.draw_word(self, CueText.split(text), "wave", age - delay, 99.0, size * pop, Color(color.r, color.g, color.b, a))
