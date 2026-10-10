class_name Enemy
extends Body
## 魔物一体。数値は SRD のまま持ち、リアルタイムに直す係数は Balance に置いてある。
## 近づいて体当たりで押し込む(Contact が押し合いを決める)。頭は三種:
##   mindless: まっすぐ迫り、逃げない  beast: 群れの半分が倒れてHPが半分を切ると逃げる
##   smart: 後衛を狙い、遠隔攻撃があれば距離を取り、傷が深いと逃げる

signal died(enemy: Enemy)

const RANGED_RE := "bow|sling|dart|javelin|hurl|spit|ray|bolt|blast|flame|spell|fire "
const TYPE_COLOR := {
	"undead": Color("c9c4b2"), "beast": Color("9a6a3c"), "swarm": Color("8a5a3a"), "ooze": Color("6fb04a"),
	"construct": Color("8c97a6"), "plant": Color("4f8a3c"), "monstrosity": Color("b0663a"), "aberration": Color("a05ac0"),
	"fiend": Color("c0392b"), "humanoid": Color("c79a6a"), "elemental": Color("d98a3c"), "fey": Color("c06ab0"),
	"celestial": Color("e8e0a0"), "dragon": Color("c04030"), "giant": Color("a0805a"),
}
const SIZE_RADIUS := {"T": 7.0, "S": 9.0, "M": 11.0, "L": 16.0, "H": 22.0, "G": 30.0}

var mon: Dictionary
var enc_id := -1
var kind := "beast"
var attitude := "敵対"
var display_name := ""
var max_hp := 1
var hp := 1.0
var ac := 10
var speed := 100.0
var dmg_base := 1.0            # SRD の攻撃の平均ダメージ(係数をかける前)
var dmg_mult := 1.0
## 一撃(係数をかけたあと)。係数は実行中に変えられるので、毎回かけ直す
var dmg: float:
	get:
		return dmg_base * Balance.ENEMY_DMG_SCALE * dmg_mult
	set(v):
		dmg_base = v / maxf(0.0001, Balance.ENEMY_DMG_SCALE * dmg_mult)
var hits := 1
var ranged := false
var xp := 0
var size_key := "M"
var color := Color.WHITE
var asleep := false
var state := "idle"            # idle / neutral / chase / flee
var timer := 0.0
var atk_cd := 0.0
var sense_t := 0.0
var fled := false
var dead := false
var shown_alert := 0.0
var slow_t := 0.0
var slow_v := 0.5
var stun_t := 0.0
var target: Hero = null
var _tex: Texture2D = null
var _is_sheet := false
var _tex_ver := -1
var walk_t := 0.0
var moving := false
var face := Vector2.DOWN

func setup(fl: FloorInstance, m: Dictionary, e: Dictionary, pos: Vector2) -> void:
	game_floor = fl
	is_hero = false
	mon = m
	position = pos
	enc_id = int(e["id"])
	kind = String(e.get("kind", "beast"))
	attitude = String(e.get("attitude", "敵対"))
	var act := String(e.get("activity", ""))
	asleep = act.contains("休んで") or act.contains("眠")
	display_name = String(m.get("world_name", m.get("name_ja", m.get("name", "?"))))
	max_hp = maxi(1, int(m.get("hp", 5)))
	hp = float(max_hp)
	ac = int(m.get("ac", 10))
	xp = int(m.get("xp", 0))
	size_key = String(m.get("size", "M"))
	color = TYPE_COLOR.get(String(m.get("type", "beast")), Color("999999"))
	radius = SIZE_RADIUS.get(size_key, 11.0)
	col_radius = minf(radius, 13.0)
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
	dmg_base = base

# ---------- Body ----------

func is_alive() -> bool:
	return not dead

func hp_frac() -> float:
	return clampf(hp / float(max_hp), 0.0, 1.0)

func body_mass() -> float:
	return Balance.SIZE_MASS.get(size_key, 1.0)

func body_speed() -> float:
	if stun_t > 0.0:
		return 0.0
	return speed * (slow_v if slow_t > 0.0 else 1.0)

func contact_dps() -> float:
	if stun_t > 0.0 or state == "neutral":
		return 0.0
	var dps := dmg / Balance.ENEMY_ATTACK_INTERVAL * (1.5 if hits > 1 else 1.0)
	return dps * (0.5 if ranged else 1.0)

func receive_contact(amount: float, from_pos: Vector2, src: Body) -> void:
	take_damage(amount, position - from_pos, src)

# ---------- 被ダメージ ----------

func take_damage(amount: float, from_dir: Vector2, src: Body = null) -> void:
	if dead:
		return
	var red := clampf((ac - 10) * 0.03, 0.0, 0.45)
	var final := maxf(0.05, amount * (1.0 - red))
	hp -= final
	if src is Hero and is_instance_valid(src):
		(src as Hero).stat_dealt += final
	flash = 0.1
	queue_popup(final, Color("ffe08a"))
	game_floor.add_child(Spark.make(position - from_dir.normalized() * radius * 0.6, 10.0, Color("fff0a0"), 0.14))
	if hp <= 0.0:
		_die()
		return
	if state == "idle" or state == "neutral":
		game_floor.alert_encounter(enc_id)
	if src is Hero:
		target = src
	_check_flee()

func apply_slow(secs: float, v: float = 0.45) -> void:
	slow_t = maxf(slow_t, secs)
	slow_v = v

func apply_stun(secs: float) -> void:
	stun_t = maxf(stun_t, secs)

func _die() -> void:
	dead = true
	game_floor.spawn_text(position + Vector2(0, -radius - 16), "+%dXP" % xp, Color("9ad8ff"))
	died.emit(self)
	queue_free()

func _check_flee() -> void:
	if fled or state == "flee" or kind == "mindless":
		return
	var go := false
	if kind == "beast":
		go = hp_frac() <= 0.5 and game_floor.group_dead_fraction(enc_id) >= 0.5
	else:
		go = hp_frac() <= 0.25
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

func _nearest_hero(max_dist: float = 1e9) -> Hero:
	var best: Hero = null
	var bd := max_dist
	for h in game_floor.heroes:
		if h.down:
			continue
		var d := position.distance_to(h.position)
		# 知性のある魔物は、後衛(魔術師、僧侶)を優先して狙う
		if kind == "smart" and (h.ch.cls == "wizard" or h.ch.cls == "cleric"):
			d *= 0.6
		if d < bd:
			bd = d
			best = h
	return best

func _can_sense(h: Hero) -> bool:
	var cells := 8.0
	if kind == "mindless":
		cells = 6.0
	if asleep:
		cells = 3.5
	if attitude == "警戒":
		cells = minf(cells, 4.5)
	if position.distance_to(h.position) > cells * Balance.CELL:
		return false
	var a := game_floor.map.cell_of(position)
	var b := game_floor.map.cell_of(h.position)
	return game_floor.map.los(a.x, a.y, b.x, b.y)

func _physics_process(delta: float) -> void:
	if dead or game_floor == null:
		return
	moving = self_move.length() > 0.15
	walk_t = walk_t + delta * 8.0 if moving else 0.0
	if intent.length() > 0.1:
		face = intent
	elif target != null and is_instance_valid(target):
		face = (target.position - position).normalized()
	self_move = Vector2.ZERO
	intent = Vector2.ZERO
	flash = maxf(0.0, flash - delta)
	shown_alert = maxf(0.0, shown_alert - delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	slow_t = maxf(0.0, slow_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	pop_update(delta)
	apply_knock(delta)
	var c := game_floor.map.cell_of(position)
	visible = game_floor.map.in_bounds(c.x, c.y) and game_floor.map.visible[game_floor.map.idx(c.x, c.y)] == 1
	if game_floor.heroes.is_empty() or stun_t > 0.0:
		queue_redraw()
		return
	match state:
		"idle":
			sense_t -= delta
			if sense_t <= 0.0:
				sense_t = 0.2
				for h in game_floor.heroes:
					if not h.down and _can_sense(h):
						game_floor.alert_encounter(enc_id)
						break
		"chase":
			_chase(delta)
		"flee":
			timer -= delta
			_flee(delta)
			if timer <= 0.0:
				state = "chase"
	queue_redraw()

func _steer(delta: float, to: Vector2, spd: float) -> void:
	var dir := to - position
	if dir.length() < 2.0:
		return
	intent = dir.normalized()
	var sp := spd * (slow_v if slow_t > 0.0 else 1.0)
	walk(intent * sp * delta)
	if (Engine.get_physics_frames() + int(get_instance_id() % 6)) % 6 == 0:     # 毎コマでなくてよい(広い層で、魔物が多いとき)
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

func _chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.down:
		target = _nearest_hero()
	if target == null:
		return
	var map := game_floor.map
	var mc := map.cell_of(position)
	var tc := map.cell_of(target.position)
	var to_t := target.position - position
	var dist := to_t.length()
	var seen := dist < 260.0 and map.los(mc.x, mc.y, tc.x, tc.y)      # 遠くは、見えていても使わない(直進は220px、射撃は200pxまで)
	# 近くに別の仲間がいれば、そちらへ切り替える(押し込まれている間は目標を固定しない)
	if dist > radius + 30.0 and Engine.get_physics_frames() % 20 == int(get_instance_id() % 20):
		var near := _nearest_hero()
		if near != null:
			target = near
	if ranged:
		if seen and dist < 110.0:
			_steer(delta, position - to_t, speed * 0.8)
		elif seen and dist <= 200.0:
			if atk_cd <= 0.0:
				_shoot(target)
		else:
			_approach(delta, seen, mc)
		return
	_approach(delta, seen, mc)

func _approach(delta: float, seen: bool, mc: Vector2i) -> void:
	if seen and position.distance_to(target.position) < 220.0:
		_steer(delta, target.position, speed)
		return
	var nxt := game_floor.map.flow_step(game_floor.flow, mc, true)
	if nxt.x >= 0:
		_steer(delta, game_floor.map.center_of(nxt), speed)

func _flee(delta: float) -> void:
	var mc := game_floor.map.cell_of(position)
	var nxt := game_floor.map.flow_step(game_floor.flow, mc, false)
	if nxt.x >= 0:
		_steer(delta, game_floor.map.center_of(nxt), speed * 1.1)

func _shoot(h: Hero) -> void:
	atk_cd = Balance.ENEMY_ATTACK_INTERVAL * 1.4
	var p := Projectile.new()
	p.setup_enemy(game_floor, position, (h.position - position).normalized(), maxf(1.0, dmg * randf_range(0.85, 1.15)), color)
	game_floor.add_child(p)

# ---------- 描画 ----------

func _sprite() -> Texture2D:
	if _tex_ver != Assets.version:
		_tex_ver = Assets.version
		var v := Assets.enemy_visual(String(mon.get("index", "")), String(mon.get("type", "")))
		_tex = v["tex"]
		_is_sheet = v["sheet"]
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _is_sheet else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _tex

func _draw() -> void:
	draw_set_transform(lunge)
	var tex := _sprite()
	if tex != null and _is_sheet:
		var tint0 := Color(1, 0.6, 0.6) if flash > 0.0 else (Color(0.6, 0.6, 0.7) if stun_t > 0.0 else Color.WHITE)
		var size_px := maxf(radius * 3.6, 26.0)
		Assets.draw_sheet_frame(self, tex, Assets.sheet_frame(Assets.sheet_dir(face), walk_t, moving), size_px, radius + 5.0, tint0)
		_draw_overlays(-(size_px - radius - 5.0) + radius + 5.0 - 10.0)
		return
	if tex != null:
		var fx := 1.0
		if target != null and is_instance_valid(target):
			fx = -1.0 if target.position.x < position.x else 1.0
		var sz := maxf(radius * 2.8, 20.0)
		var tint := Color(1, 0.6, 0.6) if flash > 0.0 else (Color(0.6, 0.6, 0.7) if stun_t > 0.0 else Color.WHITE)
		draw_set_transform(lunge, 0.0, Vector2(fx, 1.0))
		draw_texture_rect(tex, Rect2(-sz / 2.0, -sz / 2.0 - radius * 0.2, sz, sz), false, tint)
		draw_set_transform(lunge)
		_draw_overlays()
		return
	var c := Color.WHITE if flash > 0.0 else color
	if stun_t > 0.0:
		c = c.darkened(0.4)
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
	var face := Vector2.RIGHT
	if target != null and is_instance_valid(target):
		face = (target.position - position).normalized()
	draw_circle(face * radius * 0.45 + face.orthogonal() * 3.0, 1.8, Color.BLACK)
	draw_circle(face * radius * 0.45 - face.orthogonal() * 3.0, 1.8, Color.BLACK)
	_draw_overlays()

func _draw_overlays(dy: float = 0.0) -> void:
	if slow_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 20, Color(0.5, 0.8, 1.0, 0.8), 2.0)
	if stun_t > 0.0:
		UI.text_center(self, 0.0, -radius - 16.0 + dy, "zzz", 12, Color(0.8, 0.9, 1.0))
	if hp < max_hp:
		var bw := maxf(radius * 2.0, 20.0)
		draw_rect(Rect2(-bw / 2.0, -radius - 9.0 + dy, bw, 4.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-bw / 2.0, -radius - 9.0 + dy, bw * hp_frac(), 4.0), Color("d9534f"))
	if shown_alert > 0.0:
		UI.text_center(self, 0.0, -radius - 14.0 + dy, "!", 18, Color("ff5a4a"))
	if state == "neutral":
		UI.text_center(self, 0.0, -radius - 12.0 + dy, "…", 14, Color("c8d8ff"))
	UI.text_center(self, 0.0, radius + 14.0, display_name, 11, Color(1, 1, 1, 0.8))
