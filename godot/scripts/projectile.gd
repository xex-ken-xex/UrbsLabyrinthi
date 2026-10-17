class_name Projectile
extends Node2D
## 飛び道具。魔物の遠隔攻撃は仲間に、仲間の矢や魔弾は魔物に当たる。壁に当たると消える。

var game_floor: FloorInstance
var dir := Vector2.RIGHT
var dmg := 1.0
var color := Color.WHITE
var life := 3.0
var speed := 230.0
var from_hero := false
var pierce := false
var slow := 0.0
var stun := 0.0
var src: Hero = null
var src_type := ""             # 魔物の撃った弾の、魔物の種別(〈動物使い〉〈看破〉が見る)
var hit_set := {}
var elem := ""                 # 仲間の呪文の種類(火・雷など。魔物の再生や、雷を吸う特徴が見る)
var spell := false             # 呪文か(魔物の、魔法への抵抗が見る)
var web := false               # 魔物の吐いた糸(当たると絡まって動けない。傷はない)
var chill := 0.0               # 魔物の冷たい光線(当たった仲間の足が、この秒だけ鈍る)

func setup_enemy(fl: FloorInstance, pos: Vector2, d: Vector2, damage: float, col: Color, mon_type: String = "") -> void:
	game_floor = fl
	src_type = mon_type
	position = pos
	dir = d
	dmg = damage
	color = col
	from_hero = false

func setup_hero(fl: FloorInstance, h: Hero, d: Vector2, damage: float, col: Color, rng: float, spd: float, p: bool, sl: float, st: float) -> void:
	game_floor = fl
	src = h
	position = h.position + d * (h.radius + 2.0)
	dir = d
	dmg = damage
	color = col
	from_hero = true
	speed = spd
	life = rng / spd
	pierce = p
	slow = sl
	stun = st

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += dir * speed * delta
	var c := game_floor.map.cell_of(position)
	if game_floor.map.opaque(c.x, c.y):
		queue_free()
		return
	if from_hero:
		for en in game_floor.enemies:
			if en.dead or hit_set.has(en):
				continue
			if position.distance_to(en.position) < en.radius + 3.0:
				hit_set[en] = true
				en.elem_hit(elem, spell)
				en.take_damage(dmg, dir, src)
				var resist: bool = spell and (slow > 0.0 or stun > 0.0) and not en.dead and en.spell_resisted()
				if slow > 0.0 and not resist:
					en.apply_slow(slow)
				if stun > 0.0 and not resist:
					en.apply_stun(stun)
				if not pierce:
					queue_free()
					return
	else:
		for h in game_floor.heroes:
			if h.down:
				continue
			if position.distance_to(h.position) < h.radius + 4.0:
				if web:
					if not h.is_rolling():
						h.hold("web", 1.6)
						Sfx.cue(game_floor, h.position, "web")
					queue_free()
					return
				h.damage(dmg, position - dir * 10.0, false, src_type)
				if chill > 0.0 and not h.down:
					TrapFx.slow(h, "chill", 0.6, chill)
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	if web:
		draw_line(-dir * 14.0, Vector2.ZERO, Color(0.95, 0.95, 0.9, 0.5), 1.0)
		draw_circle(Vector2.ZERO, 3.5, Color(0.95, 0.95, 0.9, 0.9))
		return
	if from_hero:
		draw_line(-dir * 8.0, Vector2.ZERO, Color(color.r, color.g, color.b, 0.6), 3.0)
	draw_circle(Vector2.ZERO, 4.0, color)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
