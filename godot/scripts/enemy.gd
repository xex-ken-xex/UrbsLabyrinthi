class_name Enemy
extends Node2D
## 魔物一体。数値は SRD のまま持ち、リアルタイムの手触りに直す係数は Balance に置いてある。
## 頭は三種(展開メモ §2.5): mindless はまっすぐ迫る、beast は半分倒れると逃げる、
## smart は遠隔攻撃があれば距離を取り、傷が深いと逃げる。

signal died(enemy: Enemy)

const RANGED_RE := "bow|sling|dart|javelin|hurl|spit|ray|bolt|blast|flame|spell|fire "
const TYPE_COLOR := {
	"undead": Color("c9c4b2"), "beast": Color("9a6a3c"), "swarm": Color("8a5a3a"), "ooze": Color("6fb04a"),
	"construct": Color("8c97a6"), "plant": Color("4f8a3c"), "monstrosity": Color("b0663a"), "aberration": Color("a05ac0"),
	"fiend": Color("c0392b"), "humanoid": Color("c79a6a"), "elemental": Color("d98a3c"), "fey": Color("c06ab0"),
	"celestial": Color("e8e0a0"), "dragon": Color("c04030"), "giant": Color("a0805a"),
}
const SIZE_RADIUS := {"T": 7.0, "S": 9.0, "M": 11.0, "L": 16.0, "H": 22.0, "G": 30.0}

var game_floor: FloorInstance
var mon: Dictionary
var enc_id := -1
var kind := "beast"
var attitude := "敵対"
var display_name := ""
var max_hp := 1
var hp := 1
var ac := 10
var speed := 100.0
var radius := 11.0
var col_radius := 11.0
var dmg := 1.0                 # 一撃(係数をかけたあと)
var hits := 1                  # 一度の攻撃で何回当てるか
var ranged := false
var xp := 0
var color := Color.WHITE
var asleep := false

var state := "idle"            # idle / neutral / chase / windup / recover / flee
var timer := 0.0
var atk_cd := 0.0
var sense_t := 0.0
var flash := 0.0
var hits_left := 0
var fled := false
var dead := false
var shown_alert := 0.0
var knock := Vector2.ZERO

func setup(fl: FloorInstance, m: Dictionary, e: Dictionary, pos: Vector2) -> void:
	game_floor = fl
	mon = m
	position = pos
	enc_id = int(e["id"])
	kind = String(e.get("kind", "beast"))
	attitude = String(e.get("attitude", "敵対"))
	var act := String(e.get("activity", ""))
	asleep = act.contains("休んで") or act.contains("眠")
	display_name = String(m.get("world_name", m.get("name_ja", m.get("name", "?"))))
	max_hp = maxi(1, int(m.get("hp", 5)))
	hp = max_hp
	ac = int(m.get("ac", 10))
	xp = int(m.get("xp", 0))
	color = TYPE_COLOR.get(String(m.get("type", "beast")), Color("999999"))
	radius = SIZE_RADIUS.get(String(m.get("size", "M")), 11.0)
	col_radius = minf(radius, 13.0)           # 幅1マスの通路を通れるように
	var sp: Dictionary = m.get("speed", {})
	var best_ft := 0.0
	for k in sp:
		best_ft = maxf(best_ft, float(sp[k]))
	speed = clampf(best_ft * Balance.FT_TO_PX, 55.0, 200.0)
	_pick_attack()
	hits = 2 if m.get("multiattack", false) else 1
	state = "neutral" if attitude == "交渉の余地あり" else "idle"

func _pick_attack() -> void:
	var rr := RegEx.new()
	rr.compile(RANGED_RE)
	var best_melee := 0.0
	var best_ranged := 0.0
	for a in mon.get("attacks", []):
		if not a.has("d") or not a.has("b"):
			continue
		var avg := Dice.average(String(a["d"]))
		if rr.search(String(a["n"]).to_lower()) != null:
			best_ranged = maxf(best_ranged, avg)
		else:
			best_melee = maxf(best_melee, avg)
	var base := best_melee
	if kind == "smart" and best_ranged > 0.0 and best_ranged >= best_melee * 0.6:
		ranged = true
		base = best_ranged
	elif best_melee <= 0.0:
		base = best_ranged
		ranged = best_ranged > 0.0
	if base <= 0.0:
		base = Balance.fallback_round_damage(float(mon.get("cr", 0)))
	dmg = base * Balance.ENEMY_DMG_SCALE

# ---------- 被ダメージ ----------

func take_damage(amount: float, from_dir: Vector2) -> void:
	if dead:
		return
	# AC は軽減率に直す(展開メモ §3.2 案1)
	var red := clampf((ac - 10) * 0.03, 0.0, 0.45)
	var final := maxi(1, int(round(amount * (1.0 - red))))
	hp -= final
	flash = 0.12
	knock = from_dir.normalized() * 90.0
	game_floor.spawn_text(position + Vector2(0, -radius - 6), str(final), Color("ffe08a"))
	if hp <= 0:
		_die()
		return
	game_floor.alert_encounter(enc_id)
	_check_flee()

func _die() -> void:
	dead = true
	game_floor.spawn_text(position + Vector2(0, -radius - 16), "+%dXP" % xp, Color("9ad8ff"))
	died.emit(self)
	queue_free()

func _check_flee() -> void:
	if fled or state == "flee" or kind == "mindless":
		return
	var frac := float(hp) / float(max_hp)
	var go := false
	if kind == "beast":
		go = frac <= 0.5 and game_floor.group_dead_fraction(enc_id) >= 0.5
	else:
		go = frac <= 0.25
	if go:
		state = "flee"
		timer = 4.0
		fled = true
		game_floor.spawn_text(position + Vector2(0, -radius - 16), "逃げる", Color("d0d0d0"))

func wake() -> void:
	if state == "idle" or state == "neutral":
		state = "chase"
		shown_alert = 0.7

# ---------- 行動 ----------

func _can_sense(pl: Player, dist: float) -> bool:
	var cells := 8.0
	if kind == "mindless":
		cells = 6.0
	if asleep:
		cells = 3.5
	if attitude == "警戒":
		cells = minf(cells, 4.5)
	if dist > cells * Balance.CELL:
		return false
	var a := game_floor.map.cell_of(position)
	var b := game_floor.map.cell_of(pl.position)
	return game_floor.map.los(a.x, a.y, b.x, b.y)

func _physics_process(delta: float) -> void:
	if dead or game_floor == null or game_floor.player == null:
		return
	var pl: Player = game_floor.player
	var to_p := pl.position - position
	var dist := to_p.length()
	flash = maxf(0.0, flash - delta)
	shown_alert = maxf(0.0, shown_alert - delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	if knock.length() > 1.0:
		position = game_floor.map.move_circle(position, knock * delta, col_radius)
		knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	var vis := game_floor.map.visible[game_floor.map.idx(game_floor.map.cell_of(position).x, game_floor.map.cell_of(position).y)] == 1
	if visible != vis:
		visible = vis
	if pl.down:
		return
	match state:
		"idle":
			sense_t -= delta
			if sense_t <= 0.0:
				sense_t = 0.2
				if _can_sense(pl, dist):
					game_floor.alert_encounter(enc_id)
		"neutral":
			pass
		"chase":
			_chase(delta, pl, to_p, dist)
		"windup":
			timer -= delta
			if timer <= 0.0:
				_strike(pl, dist)
		"recover":
			timer -= delta
			if timer <= 0.0:
				state = "chase"
		"flee":
			timer -= delta
			_flee(delta)
			if timer <= 0.0:
				state = "chase"
	queue_redraw()

func _steer(delta: float, target: Vector2, spd: float) -> void:
	var dir := target - position
	if dir.length() < 2.0:
		return
	var step := dir.normalized() * spd * delta
	position = game_floor.map.move_circle(position, step, col_radius)
	_open_doors()

func _open_doors() -> void:
	for d in game_floor.map.doors_near(position, 28.0):
		if d["open"]:
			continue
		if d["type"] == "secret" and not d["found"]:
			continue
		if d["type"] == "locked" and not d["unlocked"]:
			continue
		d["open"] = true
		game_floor.map_changed()

func _chase(delta: float, pl: Player, to_p: Vector2, dist: float) -> void:
	var map := game_floor.map
	var mc := map.cell_of(position)
	var pc := map.cell_of(pl.position)
	var seen := map.los(mc.x, mc.y, pc.x, pc.y)
	if ranged:
		if seen and dist < 110.0:
			_steer(delta, position - to_p, speed * 0.8)
		elif seen and dist <= 200.0:
			if atk_cd <= 0.0:
				_shoot(pl)
		else:
			_approach(delta, pl, seen, mc)
		return
	var reach := radius + Balance.PLAYER_RADIUS + 10.0
	if dist <= reach and atk_cd <= 0.0:
		state = "windup"
		timer = 0.45
		hits_left = hits
		return
	_approach(delta, pl, seen, mc)

func _approach(delta: float, pl: Player, seen: bool, mc: Vector2i) -> void:
	if seen and position.distance_to(pl.position) < 220.0:
		_steer(delta, pl.position, speed)
		return
	var nxt := game_floor.map.flow_step(game_floor.flow, mc, true)
	if nxt.x >= 0:
		_steer(delta, game_floor.map.center_of(nxt), speed)

func _flee(delta: float) -> void:
	var mc := game_floor.map.cell_of(position)
	var nxt := game_floor.map.flow_step(game_floor.flow, mc, false)
	if nxt.x >= 0:
		_steer(delta, game_floor.map.center_of(nxt), speed * 1.1)

func _strike(pl: Player, dist: float) -> void:
	if dist <= radius + Balance.PLAYER_RADIUS + 16.0:
		pl.take_damage(_roll_dmg(), position)
	hits_left -= 1
	if hits_left > 0:
		timer = 0.28
	else:
		state = "recover"
		timer = 0.5
		atk_cd = Balance.ENEMY_ATTACK_INTERVAL * randf_range(0.9, 1.3)
		return
	# 次の一撃へ(windup のまま)

func _roll_dmg() -> float:
	return maxf(1.0, dmg * randf_range(0.85, 1.15))

func _shoot(pl: Player) -> void:
	atk_cd = Balance.ENEMY_ATTACK_INTERVAL * 1.4
	var p := Projectile.new()
	p.setup(game_floor, position, (pl.position - position).normalized(), _roll_dmg(), color)
	game_floor.add_child(p)

# ---------- 描画 ----------

func _draw() -> void:
	var c := Color.WHITE if flash > 0.0 else color
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
	# 目
	var pl: Player = game_floor.player if game_floor else null
	var face := Vector2.RIGHT
	if pl != null:
		face = (pl.position - position).normalized()
	draw_circle(face * radius * 0.45 + face.orthogonal() * 3.0, 1.8, Color.BLACK)
	draw_circle(face * radius * 0.45 - face.orthogonal() * 3.0, 1.8, Color.BLACK)
	if state == "windup":
		var k := 1.0 - clampf(timer / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 6.0 + 10.0 * k, 0.0, TAU, 24, Color(1, 0.2, 0.2, 0.3 + 0.6 * k), 2.5)
	if hp < max_hp:
		var bw := maxf(radius * 2.0, 20.0)
		draw_rect(Rect2(-bw / 2.0, -radius - 9.0, bw, 4.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-bw / 2.0, -radius - 9.0, bw * float(hp) / float(max_hp), 4.0), Color("d9534f"))
	if shown_alert > 0.0:
		UI.text_center(self, 0.0, -radius - 14.0, "!", 18, Color("ff5a4a"))
	if state == "neutral":
		UI.text_center(self, 0.0, -radius - 12.0, "…", 14, Color("c8d8ff"))
	UI.text_center(self, 0.0, radius + 14.0, display_name, 11, Color(1, 1, 1, 0.8))
