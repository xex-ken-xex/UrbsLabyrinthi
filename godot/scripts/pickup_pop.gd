class_name PickupPop
extends Node2D
## 拾ったものの絵が、拾った場所から拾った仲間の頭の上へ跳ね上がり、名前を添えて消える。

const RISE := 0.35         # 頭の上へ跳ぶまで(秒)
const LIFE := 1.3

var tex: Texture2D
var text := ""
var color := Color.WHITE
var from := Vector2.ZERO
var hero: Node2D
var age := 0.0
var stack := 0             # 同時に拾った順。重ならないよう、上へずらす

static func make(t: Texture2D, label: String, c: Color, pos: Vector2, h: Node2D) -> PickupPop:
	var p := PickupPop.new()
	p.tex = t
	p.text = label
	p.color = c
	p.from = pos
	p.hero = h
	p.position = pos
	p.z_index = 20
	if h is Body and (h as Body).game_floor != null:
		for o in (h as Body).game_floor.get_children():
			if o is PickupPop and o.hero == h and o.age < LIFE - 0.3 and not o.is_queued_for_deletion():
				p.stack += 1
	return p

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	var top := from
	if hero != null and is_instance_valid(hero):
		top = hero.position + Vector2(0, -44 - stack * 30)
	var k := clampf(age / RISE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	# 弧を描いて跳ぶ。着いたら、ゆっくり上へ
	position = from.lerp(top, e) + Vector2(0, -sin(k * PI) * 18.0) + Vector2(0, -maxf(0.0, age - RISE) * 14.0)
	queue_redraw()

func _draw() -> void:
	var a := 1.0 - clampf((age - (LIFE - 0.4)) / 0.4, 0.0, 1.0)
	var k := clampf(age / RISE, 0.0, 1.0)
	var s := 18.0 + 10.0 * k                      # 跳びながら大きくなる
	if age > RISE and age < RISE + 0.25:          # 着いた瞬間に、光る輪
		var g := (age - RISE) / 0.25
		draw_arc(Vector2.ZERO, s * (0.6 + g * 0.8), 0.0, TAU, 24, Color(color.r, color.g, color.b, (1.0 - g) * 0.8), 2.0)
	if tex != null:
		draw_texture_rect(tex, Rect2(-s / 2.0, -s / 2.0, s, s), false, Color(1, 1, 1, a))
	else:
		draw_circle(Vector2.ZERO, s * 0.3, Color(color.r, color.g, color.b, a))
	if age > RISE * 0.6:
		UI.text(self, Vector2(s / 2.0 + 4.0, 5.0), text, 14, Color(color.r, color.g, color.b, a))
