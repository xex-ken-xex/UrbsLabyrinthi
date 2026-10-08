class_name Hero
extends Body
## パーティの一人の体。操作中の一人は Main が cmd に入力を入れ、それ以外は自分で考えて動く。
## 攻撃は体当たり(Contact が押し合いとダメージを決める)。スキルはショートカット 1〜4。

signal downed(hero: Hero)

const BUFF_COLORS := {"power": Color("ff9a5a"), "guard": Color("7ab8ff"), "speed": Color("9affb0"), "mass": Color("7ab8ff"), "regen": Color("8aff8a")}

var ch: Character
var controlled := false
var cmd := {"move": Vector2.ZERO, "guard": false, "dodge": false}
var facing := Vector2.DOWN
var roll_t := 0.0
var roll_cd := 0.0
var roll_dir := Vector2.ZERO
var rush_t := 0.0
var rush_dir := Vector2.ZERO
var rush_dmg := 0.0
var rush_knock := 0.0
var rush_hit := {}
var iframes := 0.0
var buffs := {}               # 名前 → {t, v}
var cds := {}                 # スキルid → 残り秒
var down := false
var follow_pos := Vector2.ZERO
var ai_t := 0.0
var ai_target: Enemy = null
var ai_move := Vector2.ZERO
var ai_catchup := false
var guarding := false

func setup(fl: FloorInstance, character: Character) -> void:
	game_floor = fl
	ch = character
	is_hero = true
	radius = Balance.HERO_RADIUS
	col_radius = Balance.HERO_RADIUS
	down = ch.hp <= 0.0

# ---------- Body ----------

func is_alive() -> bool:
	return not down

func hp_frac() -> float:
	return clampf(ch.hp / float(ch.max_hp()), 0.0, 1.0)

func buff(key: String, default: float = 1.0) -> float:
	if buffs.has(key) and float(buffs[key]["t"]) > 0.0:
		return float(buffs[key]["v"])
	return default

func body_mass() -> float:
	var m := ch.mass() * buff("mass")
	if guarding:
		m *= Balance.GUARD_MASS
	if rush_t > 0.0:
		m *= 5.0
	return m

func body_speed() -> float:
	return _speed_now()

func _speed_now() -> float:
	var s := ch.speed() * buff("speed")
	if guarding:
		s *= 0.55
	return s

func contact_dps() -> float:
	if guarding or down:
		return 0.0
	return ch.bump_power() * buff("power")

func receive_contact(amount: float, from_pos: Vector2, _src: Body) -> void:
	damage(amount, from_pos)

## 魔物の体当たり、飛び道具、罠から受けるダメージ。防具の軽減、鉄壁や構えがここで効く
func damage(amount: float, from_pos: Vector2, ignore_armor: bool = false) -> void:
	if down or iframes > 0.0 or roll_t > 0.0 or rush_t > 0.0:
		return
	var n := amount * buff("guard")
	if not ignore_armor:
		n *= 1.0 - ch.damage_reduction()
	if guarding:
		n *= 0.5
	n = maxf(0.05, n)
	ch.hp -= n
	flash = 0.12
	queue_popup(n, Color("ff7a6a"))
	game_floor.add_child(Spark.make(position + (from_pos - position).normalized() * radius * 0.6, 9.0, Color("ff9a8a"), 0.14))
	if ch.hp <= 0.0:
		ch.hp = 0.0
		down = true
		buffs.clear()
		rush_t = 0.0
		game_floor.spawn_text(position + Vector2(0, -radius - 18), "倒れた", Color("ff6a5a"))
		downed.emit(self)

func heal(n: float) -> void:
	if down:
		return
	ch.hp = minf(ch.max_hp(), ch.hp + n)
	game_floor.spawn_text(position + Vector2(0, -radius - 12), "+%d" % int(round(n)), Color("7be08a"))

func revive(frac: float) -> void:
	down = false
	ch.hp = maxf(1.0, ch.max_hp() * frac)
	iframes = 1.0

func is_rolling() -> bool:
	return roll_t > 0.0

# ---------- 毎フレーム ----------

func _physics_process(delta: float) -> void:
	if game_floor == null or ch == null:
		return
	self_move = Vector2.ZERO
	intent = Vector2.ZERO
	_tick(delta)
	pop_update(delta)
	if down:
		queue_redraw()
		return
	apply_knock(delta)
	if not controlled:
		_ai(delta)
	_move(delta)
	queue_redraw()

func _tick(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	iframes = maxf(0.0, iframes - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	for k in cds.keys():
		cds[k] = maxf(0.0, float(cds[k]) - delta)
	for k in buffs.keys():
		buffs[k]["t"] = float(buffs[k]["t"]) - delta
		if float(buffs[k]["t"]) <= 0.0:
			buffs.erase(k)
	if down:
		return
	ch.mp = minf(ch.max_mp(), ch.mp + ch.regen_mp() * delta)
	if buffs.has("regen"):
		ch.hp = minf(ch.max_hp(), ch.hp + float(buffs["regen"]["v"]) * delta)

func _move(delta: float) -> void:
	guarding = bool(cmd.get("guard", false)) and roll_t <= 0.0 and rush_t <= 0.0
	var mv: Vector2 = cmd.get("move", Vector2.ZERO)
	if rush_t > 0.0:
		rush_t -= delta
		intent = rush_dir
		walk(rush_dir * Balance.ROLL_SPEED * 1.15 * delta)
		_rush_hits()
		return
	if roll_t > 0.0:
		roll_t -= delta
		intent = roll_dir
		walk(roll_dir * Balance.ROLL_SPEED * delta)
		return
	if mv.length() > 0.1:
		intent = mv.normalized()
		facing = intent
		var sp := _speed_now() * (1.12 if ai_catchup and not controlled else 1.0)
		walk(intent * sp * delta)
	if bool(cmd.get("dodge", false)) and roll_cd <= 0.0 and not guarding:
		roll_dir = facing if mv.length() <= 0.1 else mv.normalized()
		roll_t = Balance.ROLL_TIME
		roll_cd = Balance.ROLL_COOLDOWN
		iframes = Balance.ROLL_TIME + 0.08
	cmd["dodge"] = false

func _rush_hits() -> void:
	for en in game_floor.enemies:
		if en.dead or rush_hit.has(en):
			continue
		if position.distance_to(en.position) <= radius + en.radius + 6.0:
			rush_hit[en] = true
			en.take_damage(rush_dmg, rush_dir, self)
			en.knock = rush_dir * rush_knock / maxf(0.5, en.body_mass() * 0.7)
			game_floor.add_child(Spark.make(en.position, 22.0, Color("ffd080"), 0.2, true))

# ---------- スキル ----------

func can_cast(id: String) -> bool:
	if down or not Jobs.SKILLS.has(id):
		return false
	var sk: Dictionary = Jobs.SKILLS[id]
	return float(cds.get(id, 0.0)) <= 0.0 and ch.mp >= float(sk["mp"]) and rush_t <= 0.0

func cast_slot(i: int) -> bool:
	if i < 0 or i >= ch.slots.size():
		return false
	var id := String(ch.slots[i])
	if id == "":
		return false
	return use_skill(id)

func _aim() -> Vector2:
	if not controlled and ai_target != null and is_instance_valid(ai_target):
		return (ai_target.position - position).normalized()
	# 操作中は、向いている方向の近くにいる敵へ少し吸い付く
	var best: Enemy = null
	var bd := 1e9
	for en in game_floor.enemies:
		if en.dead:
			continue
		var to: Vector2 = en.position - position
		if to.length() > 420.0 or absf(facing.angle_to(to)) > deg_to_rad(32.0):
			continue
		if to.length() < bd:
			bd = to.length()
			best = en
	if best != null:
		return (best.position - position).normalized()
	return facing

func use_skill(id: String) -> bool:
	if not can_cast(id):
		return false
	var sk: Dictionary = Jobs.SKILLS[id]
	var kind := String(sk["kind"])
	var aim := _aim()
	var ok := false
	match kind:
		"projectile": ok = _sk_projectile(sk, aim)
		"burst_self": ok = _sk_burst(sk, position)
		"burst_ahead": ok = _sk_burst(sk, position + aim * float(sk.get("ahead", 100.0)))
		"rush": ok = _sk_rush(sk, aim)
		"buff_self": ok = _sk_buff(sk, [self])
		"buff_party": ok = _sk_buff(sk, _allies())
		"heal": ok = _sk_heal(sk)
		"heal_all": ok = _sk_heal_all(sk)
		"regen_party": ok = _sk_regen(sk)
	if ok:
		ch.mp -= float(sk["mp"])
		cds[id] = float(sk["cd"])
		if kind != "buff_party":
			game_floor.spawn_text(position + Vector2(0, -radius - 22), String(sk["name"]), Color("ffe9a8"))
	return ok

func _allies() -> Array:
	var out: Array = []
	for h in game_floor.heroes:
		if not h.down:
			out.append(h)
	return out

func _sk_projectile(sk: Dictionary, aim: Vector2) -> bool:
	var count: int = int(sk.get("count", 1))
	var spread: float = float(sk.get("spread", 0.0))
	var d := ch.skill_damage(sk)
	for i in count:
		var ang := (i - (count - 1) / 2.0) * spread
		var p := Projectile.new()
		p.setup_hero(game_floor, self, aim.rotated(ang), d, Jobs.class_color(ch.cls).lightened(0.2),
			float(sk["range"]), float(sk["speed"]), bool(sk.get("pierce", false)), float(sk.get("slow", 0.0)), float(sk.get("stun", 0.0)))
		game_floor.add_child(p)
	facing = aim
	return true

func _sk_burst(sk: Dictionary, center: Vector2) -> bool:
	var r := float(sk["radius"])
	var d := ch.skill_damage(sk)
	var col := Jobs.class_color(ch.cls).lightened(0.25)
	game_floor.add_child(Spark.make(center, r, col, 0.35, true))
	for en in game_floor.enemies.duplicate():
		if en.dead:
			continue
		var to: Vector2 = en.position - center
		if to.length() > r + en.radius * 0.6:
			continue
		var away := to.normalized() if to.length() > 0.5 else facing
		if d > 0.0:
			en.take_damage(d, away, self)
		if en.dead:
			continue
		var kn := float(sk.get("knock", 0.0))
		if kn > 0.0:
			en.knock = away * kn / maxf(0.5, en.body_mass() * 0.7)
		if float(sk.get("slow", 0.0)) > 0.0:
			en.apply_slow(float(sk["slow"]))
		if float(sk.get("stun", 0.0)) > 0.0:
			en.apply_stun(float(sk["stun"]))
	return true

func _sk_rush(sk: Dictionary, aim: Vector2) -> bool:
	rush_dir = aim
	rush_t = float(sk["dist"]) / (Balance.ROLL_SPEED * 1.15)
	rush_dmg = ch.skill_damage(sk)
	rush_knock = float(sk["knock"])
	rush_hit = {}
	facing = aim
	iframes = rush_t + 0.1
	return true

func _sk_buff(sk: Dictionary, targets: Array) -> bool:
	var dur := float(sk["dur"])
	for h in targets:
		for k in (sk["mult"] as Dictionary):
			h.buffs[k] = {"t": dur, "v": float(sk["mult"][k])}
		game_floor.add_child(Spark.make(h.position, 24.0, Color("ffe9a8"), 0.4))
	return true

func _lowest_ally() -> Hero:
	var best: Hero = null
	var br := 2.0
	for h in game_floor.heroes:
		if h.down:
			continue
		var r: float = h.hp_frac()
		if r < br:
			br = r
			best = h
	return best

func _sk_heal(sk: Dictionary) -> bool:
	var t := _lowest_ally()
	if t == null or t.hp_frac() > 0.97 or position.distance_to(t.position) > float(sk["range"]):
		return false
	t.heal(ch.skill_amount(sk))
	game_floor.add_child(Spark.make(t.position, 20.0, Color("8aff9a"), 0.4, true))
	return true

func _sk_heal_all(sk: Dictionary) -> bool:
	var any := false
	var n := ch.skill_amount(sk)
	for h in game_floor.heroes:
		if not h.down and h.hp_frac() < 0.97:
			h.heal(n)
			game_floor.add_child(Spark.make(h.position, 20.0, Color("8aff9a"), 0.4, true))
			any = true
	return any

func _sk_regen(sk: Dictionary) -> bool:
	var per_sec := float(sk["amount"]) + maxi(0, ch.mod(String(ch.class_data()["cast"]))) * float(sk["stat"]) + ch.level * 0.15
	for h in _allies():
		h.buffs["regen"] = {"t": float(sk["dur"]), "v": per_sec}
		game_floor.add_child(Spark.make(h.position, 22.0, Color("8aff9a"), 0.4))
	return true

# ---------- 仲間の自動操作 ----------

func role() -> String:
	match ch.cls:
		"wizard", "ranger": return "ranged"
		"cleric": return "support"
	return "melee"

func _ai(delta: float) -> void:
	ai_t -= delta
	if ai_t <= 0.0:
		ai_t = 0.15
		_ai_think()
	cmd["move"] = ai_move
	cmd["guard"] = false

func _ai_think() -> void:
	var map := game_floor.map
	ai_target = null
	var best := 1e9
	var mc := map.cell_of(position)
	for en in game_floor.enemies:
		if en.dead or en.state == "neutral":
			continue
		var d := position.distance_to(en.position)
		if d > 240.0:
			continue
		var ec := map.cell_of(en.position)
		if d > 50.0 and not map.los(mc.x, mc.y, ec.x, ec.y):
			continue
		if d < best:
			best = d
			ai_target = en
	ai_move = Vector2.ZERO
	ai_catchup = false
	var leader := game_floor.leader
	var to_leader := Vector2.ZERO
	if leader != null:
		to_leader = leader.position - position
	if leader != null and to_leader.length() > 330.0:
		# 離れすぎたら、リーダーのそばへ(敵が見えていても)
		ai_move = to_leader.normalized()
		ai_catchup = true
	elif ai_target != null:
		var to := ai_target.position - position
		var dist := to.length()
		match role():
			"melee":
				ai_move = to.normalized()
			"ranged":
				if dist < 100.0:
					ai_move = -to.normalized()
				elif dist > 200.0:
					ai_move = to.normalized()
			"support":
				if leader != null and to_leader.length() > 80.0:
					ai_move = to_leader.normalized()
				elif dist < 60.0:
					ai_move = to.normalized()
	else:
		var to_f := follow_pos - position
		if to_f.length() > 14.0:
			ai_move = to_f.normalized()
			ai_catchup = to_f.length() > 60.0
	_ai_skills()

func _count_enemies_within(center: Vector2, r: float) -> int:
	var n := 0
	for en in game_floor.enemies:
		if not en.dead and center.distance_to(en.position) <= r + en.radius * 0.6:
			n += 1
	return n

func _ai_skills() -> void:
	for i in 4:
		var id := String(ch.slots[i])
		if id == "" or not can_cast(id):
			continue
		var sk: Dictionary = Jobs.SKILLS[id]
		var tdist := 1e9
		if ai_target != null and is_instance_valid(ai_target):
			tdist = position.distance_to(ai_target.position)
		var ok := false
		match String(sk["kind"]):
			"heal":
				var t := _lowest_ally()
				ok = t != null and t.hp_frac() < 0.55 and position.distance_to(t.position) <= float(sk["range"])
			"heal_all":
				var low := 0
				for h in game_floor.heroes:
					if not h.down and h.hp_frac() < 0.6:
						low += 1
				ok = low >= 2
			"regen_party":
				var low2 := 0
				for h in game_floor.heroes:
					if not h.down and h.hp_frac() < 0.8:
						low2 += 1
				ok = low2 >= 1 and ai_target != null
			"buff_self", "buff_party":
				ok = ai_target != null and tdist < 200.0
			"burst_self":
				ok = _count_enemies_within(position, float(sk["radius"]) * 0.9) >= 1
			"burst_ahead":
				ok = ai_target != null and tdist < float(sk.get("ahead", 100.0)) + float(sk["radius"]) * 0.6
			"projectile":
				ok = ai_target != null and tdist < float(sk["range"]) * 0.9
			"rush":
				ok = ai_target != null and tdist > 50.0 and tdist < float(sk["dist"]) * 0.85
		if ok and use_skill(id):
			return

# ---------- 描画 ----------

func _draw() -> void:
	draw_set_transform(lunge)
	var col := Jobs.class_color(ch.cls)
	if down:
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.35, 0.38, 0.8))
		draw_line(Vector2(-6, -6), Vector2(6, 6), Color(0.8, 0.2, 0.2), 3.0)
		draw_line(Vector2(-6, 6), Vector2(6, -6), Color(0.8, 0.2, 0.2), 3.0)
		UI.text_center(self, 0.0, radius + 14.0, ch.name, 11, Color(1, 1, 1, 0.6))
		return
	var c := col if flash <= 0.0 else Color("ff7a6a")
	if roll_t > 0.0:
		c = Color(c.r, c.g, c.b, 0.55)
	for k in buffs:
		if BUFF_COLORS.has(k):
			draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 22, BUFF_COLORS[k], 2.0)
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.8), 2.0)
	draw_line(Vector2.ZERO, facing * (radius + 5.0), Color("5bc0de"), 3.0)
	if guarding:
		draw_arc(Vector2.ZERO, radius + 5.0, facing.angle() - 1.0, facing.angle() + 1.0, 12, Color("a8d8ff"), 4.0)
	UI.text_center(self, 0.0, 4.0, Jobs.class_initial(ch.cls), 11, Color(0.05, 0.05, 0.08), false)
	if controlled:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -radius - 12), Vector2(5, -radius - 20), Vector2(-5, -radius - 20)]), Color("ffe9a8"))
	UI.text_center(self, 0.0, radius + 14.0, ch.name, 11, Color(1, 1, 1, 0.85))
