class_name BossFx
extends Node
## 層の主との戦いの演出(ken 10/18)。始まると咆哮(画面を埋める大きな擬音)。戦いの間は画面がモノクロになり、
## ダメージの数字だけ赤で、モノクロの上に描く(FloorInstance.spawn_damage)。倒すか、別の階へ移ると戻る。
## 重なり: 層(0)< モノクロ(3)< ダメージの数字・咆哮(4)< 画面(5)< HUD(10)

const ROAR_LIFE := 2.2
const FADE := 0.4

const GRAY_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c, vec3(g) * 0.92, amount), 1.0);
}
"""

var active := false
var fl: FloorInstance = null
var world: Node2D                    # ダメージの数字を置く所(層の座標。カメラについてくる)
var _gray_layer: CanvasLayer
var _gray: ColorRect
var _mat: ShaderMaterial
var _amount := 0.0
var _roar: RoarText

func _ready() -> void:
	_gray_layer = CanvasLayer.new()
	_gray_layer.layer = 3
	add_child(_gray_layer)
	_gray = ColorRect.new()
	_gray.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_gray.material = _mat
	_gray_layer.add_child(_gray)
	_gray_layer.visible = false
	var dl := CanvasLayer.new()
	dl.layer = 4
	dl.follow_viewport_enabled = true
	add_child(dl)
	world = Node2D.new()
	dl.add_child(world)
	var rl := CanvasLayer.new()
	rl.layer = 4
	add_child(rl)
	_roar = RoarText.new()
	rl.add_child(_roar)

## 戦いが始まった(咆哮)
func start(floor_inst: FloorInstance, roar: String) -> void:
	fl = floor_inst
	active = true
	fl.fx_overlay = world
	_roar.show_word(roar)

## 戦いが終わった(倒した、階を移った、街へ戻った)
func stop() -> void:
	if fl != null and is_instance_valid(fl):
		fl.fx_overlay = null
	fl = null
	active = false
	for c in world.get_children():
		c.queue_free()

func _process(delta: float) -> void:
	_amount = move_toward(_amount, 1.0 if active else 0.0, delta / FADE)
	_gray_layer.visible = _amount > 0.0
	_mat.set_shader_parameter("amount", _amount)

## モノクロの度合い(0〜1。テスト用)
func gray_amount() -> float:
	return _amount


## 画面を埋める咆哮の文字
class RoarText extends Node2D:
	var chars := PackedStringArray()
	var t := 99.0

	func show_word(s: String) -> void:
		chars = CueText.split(s)
		t = 0.0
		visible = true

	func showing() -> bool:
		return t < BossFx.ROAR_LIFE

	func _process(delta: float) -> void:
		if t >= BossFx.ROAR_LIFE:
			visible = false
			return
		t += delta
		queue_redraw()

	func _draw() -> void:
		if chars.is_empty() or t >= BossFx.ROAR_LIFE:
			return
		var vs := get_viewport_rect().size
		# 横幅いっぱい(縦は6割まで)。slam で一度大きく出て縮む
		var px := clampf(vs.x * 0.9 / maxf(1.0, chars.size() * 0.92), 24.0, vs.y * 0.6)
		var a := 1.0 - clampf((t - (BossFx.ROAR_LIFE - 0.5)) / 0.5, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25 * a))
		CueText.draw_word(self, chars, "slam", t, BossFx.ROAR_LIFE, px, Color(1.0, 0.32, 0.22), 1.7, false, vs / 2.0)
