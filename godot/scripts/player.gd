class_name Player
extends Node2D
## 潜行者。移動、斬撃、転がり回避。拾い物や階段などの「規則」は Main が持つ。

signal downed

var game_floor: FloorInstance
var level := 1
var xp := 0
var hp := 18
var max_hp := 18
var potions := 1
var facing := Vector2.DOWN
var attack_cd := 0.0
var swing_t := 0.0
var roll_t := 0.0
var roll_cd := 0.0
var roll_dir := Vector2.ZERO
var iframes := 0.0
var flash := 0.0
var down := false
var swing_dir := Vector2.DOWN
var scripted_input: Variant = null     # テスト用: {move, attack, dodge} を与えると入力を置き換える

func reset_stats() -> void:
	max_hp = Balance.player_max_hp(level)
	hp = max_hp

func gain_xp(amount: int) -> bool:
	xp += amount
	var lv := Balance.level_for_xp(xp)
	if lv > level:
		level = lv
		max_hp = Balance.player_max_hp(level)
		hp = max_hp
		return true
	return false

func is_rolling() -> bool:
	return roll_t > 0.0

func take_damage(amount: float, from_pos: Vector2) -> void:
	if down or iframes > 0.0 or roll_t > 0.0:
		return
	var n := maxi(1, int(round(amount)))
	hp -= n
	flash = 0.15
	iframes = 0.25
	game_floor.spawn_text(position + Vector2(0, -16), str(n), Color("ff6a5a"))
	var away := (position - from_pos).normalized()
	position = game_floor.map.move_circle(position, away * 8.0, Balance.PLAYER_RADIUS)
	if hp <= 0:
		hp = 0
		down = true
		downed.emit()

func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	game_floor.spawn_text(position + Vector2(0, -16), "+%d" % n, Color("7be08a"))

func _input_state() -> Dictionary:
	if scripted_input != null:
		return scripted_input
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return {"move": mv, "attack": Input.is_action_just_pressed("attack"),
		"dodge": Input.is_action_just_pressed("dodge"),
		"mouse_aim": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)}

func _physics_process(delta: float) -> void:
	if game_floor == null or down:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	iframes = maxf(0.0, iframes - delta)
	flash = maxf(0.0, flash - delta)
	swing_t = maxf(0.0, swing_t - delta)
	var inp := _input_state()
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if roll_t > 0.0:
		roll_t -= delta
		position = game_floor.map.move_circle(position, roll_dir * Balance.ROLL_SPEED * delta, Balance.PLAYER_RADIUS)
	else:
		if mv.length() > 0.1:
			facing = mv.normalized()
			position = game_floor.map.move_circle(position, mv * Balance.PLAYER_SPEED * delta, Balance.PLAYER_RADIUS)
		if inp.get("dodge", false) and roll_cd <= 0.0:
			roll_dir = facing if mv.length() <= 0.1 else mv.normalized()
			roll_t = Balance.ROLL_TIME
			roll_cd = Balance.ROLL_COOLDOWN
			iframes = Balance.ROLL_TIME + 0.08
		if inp.get("attack", false) and attack_cd <= 0.0:
			if inp.get("mouse_aim", false) and is_inside_tree():
				var aim := get_global_mouse_position() - global_position
				if aim.length() > 4.0:
					facing = aim.normalized()
			_swing()
	queue_redraw()

func _swing() -> void:
	attack_cd = Balance.ATTACK_COOLDOWN
	swing_t = 0.14
	swing_dir = facing
	var dmg := Balance.player_damage(level)
	var half := deg_to_rad(Balance.ATTACK_ARC_DEG)
	for en in game_floor.enemies.duplicate():
		if en.dead:
			continue
		var to_e: Vector2 = en.position - position
		if to_e.length() > Balance.ATTACK_REACH + en.radius:
			continue
		if absf(facing.angle_to(to_e)) > half:
			continue
		en.take_damage(dmg * randf_range(0.85, 1.15), to_e)

func _draw() -> void:
	var c := Color("e8e4d0") if flash <= 0.0 else Color("ff7a6a")
	if roll_t > 0.0:
		c = Color(c.r, c.g, c.b, 0.55)
	draw_circle(Vector2.ZERO, Balance.PLAYER_RADIUS, c)
	draw_arc(Vector2.ZERO, Balance.PLAYER_RADIUS, 0.0, TAU, 20, Color(0, 0, 0, 0.8), 2.0)
	draw_line(Vector2.ZERO, facing * (Balance.PLAYER_RADIUS + 5.0), Color("5bc0de"), 3.0)
	if swing_t > 0.0:
		var a0 := swing_dir.angle() - deg_to_rad(Balance.ATTACK_ARC_DEG)
		var a1 := swing_dir.angle() + deg_to_rad(Balance.ATTACK_ARC_DEG)
		var k := swing_t / 0.14
		draw_arc(Vector2.ZERO, Balance.ATTACK_REACH, a0, a1, 16, Color(1, 1, 0.8, 0.85 * k), 5.0)
