class_name TownFx
extends Control
## 街の画面いっぱいの演出(ken 10/18)。
## sleep: 宿に泊まる。暗転して ｚｚｚｚ…… がゆっくり昇り、明けると翌朝。暗くなりきったときに at_dark を呼ぶ。
## bless: 神殿で加護を願う。画面の中央に キラキラ フワァ〜〜〜 がじんわり浮かんで消える。

signal finished

const SLEEP_LEN := 3.8
const BLESS_LEN := 2.6

var kind := "sleep"
var t := 0.0
var at_dark: Callable = Callable()
var _dark_done := false
var _seed := 0.0

static func play(parent: Control, k: String, dark_cb: Callable = Callable()) -> TownFx:
	var fx := TownFx.new()
	fx.kind = k
	fx.at_dark = dark_cb
	parent.add_child(fx)
	return fx

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 眠っている間は、街のボタンを押せないようにする
	mouse_filter = Control.MOUSE_FILTER_STOP if kind == "sleep" else Control.MOUSE_FILTER_IGNORE
	_seed = randf() * 10.0

func length() -> float:
	return SLEEP_LEN if kind == "sleep" else BLESS_LEN

func _process(delta: float) -> void:
	t += delta
	if kind == "sleep" and not _dark_done and t >= 0.75:
		_dark_done = true
		if at_dark.is_valid():
			at_dark.call()
	if t >= length():
		finished.emit()
		queue_free()
		return
	queue_redraw()

## 0→1→0 のなだらかな山(入り、留まり、抜け)
static func envelope(x: float, a: float, b: float, c: float) -> float:
	if x < a:
		return smoothstep(0.0, a, x)
	if x < a + b:
		return 1.0
	return 1.0 - smoothstep(a + b, a + b + c, x)

func _draw() -> void:
	var sz := size
	var c := sz / 2.0
	if kind == "sleep":
		# 暗転: 0.75秒で真っ暗、明ける前の0.8秒で戻る
		var dark := envelope(t, 0.75, SLEEP_LEN - 0.75 - 0.8, 0.8)
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.02, dark))
		# ｚｚｚｚ…… が、下から上へゆっくり昇る
		var zt := t - 0.45
		if zt > 0.0:
			var za := envelope(zt, 0.5, 1.6, 0.9)
			var origin := Vector2(c.x + sin(zt * 1.3) * 18.0, sz.y * 0.66 - zt * 62.0)
			CueText.draw_word(self, CueText.split("ｚｚｚｚ……"), "wave", zt, 99.0, 50.0, Color(0.75, 0.82, 1.0, za), _seed, false, origin)
	else:
		var a := envelope(t, 0.8, 0.8, 1.0)
		# うっすら明るく、中央に光の輪
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.95, 0.75, 0.10 * a))
		for i in 4:
			draw_circle(c, 70.0 + i * 46.0 + t * 20.0, Color(1.0, 0.92, 0.6, 0.06 * a))
		# きらめき(十字の星)
		for i in 9:
			var ang := i * TAU / 9.0 + t * 0.4
			var r := 150.0 + 40.0 * sin(i * 1.7 + t * 1.5)
			var p := c + Vector2(cos(ang) * r * 1.5, sin(ang) * r * 0.7)
			var tw := (0.5 + 0.5 * sin(t * 6.0 + i * 2.1)) * a
			var s := 6.0 + 6.0 * tw
			draw_line(p - Vector2(s, 0), p + Vector2(s, 0), Color(1.0, 0.97, 0.8, tw), 2.0)
			draw_line(p - Vector2(0, s), p + Vector2(0, s), Color(1.0, 0.97, 0.8, tw), 2.0)
		CueText.draw_word(self, CueText.split("キラキラ"), "wave", t, 99.0, 36.0, Color(1.0, 0.96, 0.7, a), _seed, false, c + Vector2(0, -70))
		CueText.draw_word(self, CueText.split("フワァ〜〜〜"), "wave", t, 99.0, 60.0, Color(1.0, 0.9, 0.6, a), _seed + 3.0, false, c + Vector2(0, 10))
