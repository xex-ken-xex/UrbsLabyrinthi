class_name Projectile
extends Node2D
## 遠隔攻撃の飛び道具。壁に当たると消える。

var game_floor: FloorInstance
var dir := Vector2.RIGHT
var dmg := 1.0
var color := Color.WHITE
var life := 3.0
const SPEED := 230.0

func setup(fl: FloorInstance, pos: Vector2, d: Vector2, damage: float, col: Color) -> void:
	game_floor = fl
	position = pos
	dir = d
	dmg = damage
	color = col

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += dir * SPEED * delta
	var c := game_floor.map.cell_of(position)
	if game_floor.map.opaque(c.x, c.y):
		queue_free()
		return
	var pl := game_floor.player
	if pl != null and not pl.down and position.distance_to(pl.position) < Balance.PLAYER_RADIUS + 4.0:
		pl.take_damage(dmg, position - dir * 10.0)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, color)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
