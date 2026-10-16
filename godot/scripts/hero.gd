class_name Hero
extends Body
## パーティの一人の体。操作中の一人は Main が cmd に入力を入れ、それ以外は自分で考えて動く。
## 攻撃はボタンで正面へ一撃(待ち時間あり)。押し続けると溜まり、離すと強い一撃。触れると押し合う(Contact)が、仲間の体当たりではダメージは入らない。
## スキルは数字キー 1〜6。Ctrl で選んで(0 = 通常攻撃)、右クリックで選んだものを使うこともできる。

signal downed(hero: Hero)

const BUFF_COLORS := {"power": Color("ff9a5a"), "guard": Color("7ab8ff"), "speed": Color("9affb0"), "mass": Color("7ab8ff"), "regen": Color("8aff8a")}

var ch: Character
var controlled := false
var cmd := {"move": Vector2.ZERO, "attack": false, "dodge": false}   # attack: 攻撃を押している(操作中の一人だけ)
var facing := Vector2.DOWN
var roll_t := 0.0
var atk_cd := 0.0             # 通常攻撃の残りの待ち時間
var atk_cd_max := 0.0
var swing_t := 0.0            # 振りの描画
var swing_dir := Vector2.RIGHT
var swing_reach := Balance.ATTACK_REACH   # 描く弧の届く距離と角度(武器や技で変わる)
var swing_arc := Balance.ATTACK_ARC
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
var atk_held := false          # 前のフレームで攻撃を押していたか
var hold_t := 0.0              # 攻撃を押し続けている秒
var _full_cued := false        # 溜めきった擬音を出したか
var last_stand := true         # 不屈の特技を、この潜入でまだ使っていない
var stat_dealt := 0.0         # 闘技場の記録: 与えたダメージ、受けたダメージ
var stat_taken := 0.0
var _tex: Texture2D = null
var _is_sheet := false
var _tex_ver := -1
var walk_t := 0.0             # 歩きの絵を送る時間(スプライトシート用)
var moving := false
var sleep_t := 0.0            # 眠っている(休息中)、または寝込みを襲われて動けない残り秒

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
	if rush_t > 0.0:
		m *= 5.0
	return m

func body_speed() -> float:
	return _speed_now()

func _speed_now() -> float:
	var s := ch.speed() * buff("speed")
	if charging():
		s *= Balance.CHARGE_SPEED
	return s

## 仲間は体当たりではダメージを与えない(通常攻撃で殴る)。盾構えの特技だけ、溜めている間に触れている敵へ反撃する
func contact_dps() -> float:
	if down or not charging():
		return 0.0
	return ch.bump_power() * buff("power") * 0.4 if ch.has_feat("shield_master") else 0.0

func receive_contact(amount: float, from_pos: Vector2, src: Body) -> void:
	damage(amount, from_pos, false, (src as Enemy).mon_type() if src is Enemy else "")

## 魔物の体当たり、飛び道具、罠から受けるダメージ。防具の軽減、鉄壁や盾構え(溜めている間)がここで効く
## src_type は、ダメージを与えた魔物の種別(〈動物使い〉〈看破〉が見る。罠などは空)
func damage(amount: float, from_pos: Vector2, ignore_armor: bool = false, src_type: String = "") -> void:
	if down or iframes > 0.0 or roll_t > 0.0 or rush_t > 0.0:
		return
	var n := amount * buff("guard") * ch.taken_mult(src_type)
	if not ignore_armor:
		n *= 1.0 - ch.damage_reduction()
	if charging() and ch.has_feat("shield_master"):
		n *= 0.5
	n = maxf(0.05, n)
	stat_taken += n
	ch.hp -= n
	flash = 0.12
	queue_popup(n, Color("ff7a6a"))
	game_floor.add_child(Spark.make(position + (from_pos - position).normalized() * radius * 0.6, 9.0, Color("ff9a8a"), 0.14))
	if ch.hp <= 0.0 and last_stand and ch.has_feat("resilient") and amount < 99999.0:
		# 不屈: 一度の潜入で一度だけ、HP1 で踏みとどまる
		last_stand = false
		ch.hp = 1.0
		iframes = 0.8
		game_floor.spawn_text(position + Vector2(0, -radius - 18), "踏みとどまった", Color("ffe9a8"))
	if ch.hp <= 0.0:
		ch.hp = 0.0
		down = true
		buffs.clear()
		rush_t = 0.0
		cancel_charge()
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
	if sleep_t > 0.0:
		queue_redraw()
		return
	if not controlled:
		_ai(delta)
	_move(delta)
	moving = self_move.length() > 0.15
	walk_t = walk_t + delta * 9.0 if moving else 0.0
	queue_redraw()

func _tick(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	iframes = maxf(0.0, iframes - delta)
	sleep_t = maxf(0.0, sleep_t - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	swing_t = maxf(0.0, swing_t - delta)
	for k in cds.keys():
		cds[k] = maxf(0.0, float(cds[k]) - delta)
	for k in buffs.keys():
		buffs[k]["t"] = float(buffs[k]["t"]) - delta
		if float(buffs[k]["t"]) <= 0.0:
			buffs.erase(k)
	if down:
		return
	if game_floor.arena:
		ch.mp = minf(ch.max_mp(), ch.mp + ch.regen_mp() * delta)     # 迷宮では自然に戻らない(休息で戻す)。闘技場だけ戻る
	if buffs.has("regen"):
		ch.hp = minf(ch.max_hp(), ch.hp + float(buffs["regen"]["v"]) * delta)

func _move(delta: float) -> void:
	_attack_input(delta)
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
	if bool(cmd.get("dodge", false)) and roll_cd <= 0.0:
		roll_dir = facing if mv.length() <= 0.1 else mv.normalized()
		roll_t = Balance.ROLL_TIME
		roll_cd = ch.roll_cooldown()
		iframes = Balance.ROLL_TIME + 0.08
	cmd["dodge"] = false
	if roll_t > 0.0:
		cancel_charge()      # 転がると、溜めは消える

func _rush_hits() -> void:
	for en in game_floor.enemies:
		if en.dead or rush_hit.has(en):
			continue
		if position.distance_to(en.position) <= radius + en.radius + 6.0:
			rush_hit[en] = true
			en.take_damage(rush_dmg, rush_dir, self)
			en.knock = rush_dir * rush_knock / maxf(0.5, en.body_mass() * 0.7)
			game_floor.add_child(Spark.make(en.position, 22.0, Color("ffd080"), 0.2, true))

# ---------- 通常攻撃 ----------

func can_attack() -> bool:
	return not down and atk_cd <= 0.0 and rush_t <= 0.0 and roll_t <= 0.0 and sleep_t <= 0.0

## 正面へ一撃。届く範囲の魔物すべてに当たる。待ち時間のあいだは振れない
func attack() -> bool:
	if not can_attack():
		return false
	_swing_hit(_aim(), 1.0, 1.0, 1.0, 0.18)
	return true

## 攻撃の押し方を読む(操作中の一人)。押した瞬間に一度振り、押し続けると溜まり、離すと溜めの一撃
func _attack_input(delta: float) -> void:
	var held := bool(cmd.get("attack", false))
	if held and not atk_held:
		attack()
		hold_t = 0.0
	if held:
		if roll_t > 0.0 or rush_t > 0.0:
			hold_t = 0.0
		else:
			hold_t += delta
			if charge_frac() >= 1.0 and not _full_cued:
				_full_cued = true
				Sfx.cue(game_floor, position, "charge_full")
	elif atk_held:
		if charging() and hold_t - Balance.CHARGE_START >= Balance.CHARGE_MIN:
			charged_attack(charge_frac())
		cancel_charge()
	atk_held = held

## 溜めている最中か(押してから CHARGE_START 秒たった)
func charging() -> bool:
	return not down and atk_held and hold_t >= Balance.CHARGE_START

## 溜めの進み具合(0〜1)
func charge_frac() -> float:
	return clampf((hold_t - Balance.CHARGE_START) / Balance.CHARGE_TIME, 0.0, 1.0)

func cancel_charge() -> void:
	hold_t = 0.0
	_full_cued = false

## 溜めの一撃。ふつうの一撃より強く、遠くまで届き、よく押し返す。待ち時間は無視する(撃った後は待ち時間になる)
func charged_attack(frac: float) -> bool:
	if down or rush_t > 0.0 or roll_t > 0.0 or sleep_t > 0.0:
		return false
	var mult := lerpf(float(Balance.CHARGE_MULT[0]), float(Balance.CHARGE_MULT[1]), frac)
	var aim := _aim()
	var hit := _swing_hit(aim, mult, Balance.CHARGE_REACH, Balance.CHARGE_KNOCK, 0.28)
	lunge = aim * 11.0
	Sfx.cue(game_floor, position + aim * (radius + 14.0), "charge_hit" if hit > 0 else "charge_miss")
	return true

## 振る。届く範囲の魔物に当て、当たった数を返す。dmg_mult・reach_mult・knock_mult は溜めの一撃で使う
func _swing_hit(aim: Vector2, dmg_mult: float, reach_mult: float, knock_mult: float, draw_t: float) -> int:
	var sw := swing()
	facing = aim
	swing_dir = aim
	swing_t = draw_t
	swing_reach = float(sw["reach"]) * reach_mult
	swing_arc = float(sw["arc"])
	atk_cd_max = attack_cd()
	atk_cd = atk_cd_max
	lunge = aim * 6.0
	var dmg := ch.bump_power() * buff("power") * atk_cd_max * Balance.ATTACK_SCALE * float(sw["dmg"]) * dmg_mult
	var arc := deg_to_rad(swing_arc)
	var n := 0
	for en in game_floor.enemies.duplicate():
		if en.dead:
			continue
		var to: Vector2 = en.position - position
		if to.length() > radius + en.radius + swing_reach:
			continue
		if to.length() > 4.0 and absf(aim.angle_to(to)) > arc:
			continue
		n += 1
		var dir := to.normalized() if to.length() > 0.5 else aim
		en.take_damage(dmg, dir, self)
		if not en.dead:
			en.knock = dir * Balance.ATTACK_KNOCK * float(sw["knock"]) * knock_mult / maxf(0.5, en.body_mass())
			if Dice.rng.randf() < float(sw.get("stun", 0.0)):
				en.apply_stun(0.6)
		game_floor.add_child(Spark.make(en.position - dir * en.radius * 0.5, 12.0 * sqrt(dmg_mult), Color("ffe0a0"), 0.14))
	return n

## 装備している武器の種類の、通常攻撃の振り方(Balance.SWING)
func swing() -> Dictionary:
	return Balance.SWING.get(ch.weapon_cat(), Balance.SWING["none"])

## 通常攻撃の待ち時間(秒)
func attack_cd() -> float:
	return Balance.ATTACK_CD * float(swing()["cd"])

## 待ち時間の進み具合(0 = 振ったばかり、1 = 振れる)
func attack_ready_frac() -> float:
	if atk_cd_max <= 0.0:
		return 1.0
	return clampf(1.0 - atk_cd / atk_cd_max, 0.0, 1.0)

# ---------- スキル ----------

func can_cast(id: String) -> bool:
	if down:
		return false
	var sk := ch.skill_def(id)
	if sk.is_empty():
		return false
	return float(cds.get(id, 0.0)) <= 0.0 and ch.mp >= float(sk["mp"]) and rush_t <= 0.0

## Ctrl: 選ぶスキルを次へ(0 = 通常攻撃 → スキル1〜6 の割り当てのあるもの → 0 …)
func next_skill() -> void:
	for k in range(1, Character.SLOTS + 2):
		var i := (ch.skill_sel + k) % (Character.SLOTS + 1)
		if i == 0 or String(ch.slots[i - 1]) != "":
			ch.skill_sel = i
			return

## いま選んでいるスキルの id。0(通常攻撃)なら ""
func selected_skill() -> String:
	if ch.skill_sel <= 0 or ch.skill_sel > ch.slots.size():
		return ""
	return String(ch.slots[ch.skill_sel - 1])

func cast_slot(i: int) -> bool:
	if i < 0 or i >= ch.slots.size() or sleep_t > 0.0:
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
	var sk := ch.skill_def(id)
	var kind := String(sk["kind"])
	var aim := _aim()
	var ok := false
	match kind:
		"projectile": ok = _sk_projectile(sk, aim)
		"burst_self": ok = _sk_burst(sk, position)
		"burst_ahead": ok = _sk_burst(sk, position + aim * float(sk.get("ahead", 100.0)))
		"rush": ok = _sk_rush(sk, aim)
		"strike": ok = _sk_strike(sk, aim)
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

## スキルの威力。杖の技「魔力の溜め」の間は、呪文が強まる
func _skill_dmg(sk: Dictionary) -> float:
	return ch.skill_damage(sk) * (buff("spell") if sk.get("spell", false) else 1.0)

## 武器の技: 正面へ打つ(hits 回)。気絶・足止め・守りを割る(sunder)
func _sk_strike(sk: Dictionary, aim: Vector2) -> bool:
	var reach := float(sk.get("reach", 24.0))
	var arc := deg_to_rad(float(sk.get("arc", 45.0)))
	var d := _skill_dmg(sk)
	facing = aim
	swing_dir = aim
	swing_t = 0.18
	swing_reach = reach
	swing_arc = float(sk.get("arc", 45.0))
	lunge = aim * 8.0
	for en in game_floor.enemies.duplicate():
		if en.dead:
			continue
		var to: Vector2 = en.position - position
		if to.length() > radius + en.radius + reach:
			continue
		if to.length() > 4.0 and absf(aim.angle_to(to)) > arc:
			continue
		var dir := to.normalized() if to.length() > 0.5 else aim
		for k in int(sk.get("hits", 1)):
			if not en.dead:
				en.take_damage(d, dir, self)
		if en.dead:
			continue
		_skill_effects(en, sk, dir)
		game_floor.add_child(Spark.make(en.position - dir * en.radius * 0.5, 16.0, Jobs.class_color(ch.cls).lightened(0.3), 0.2))
	return true

## 当たった魔物への、押し返し・足止め・気絶・守りを割る
func _skill_effects(en: Enemy, sk: Dictionary, away: Vector2) -> void:
	var kn := float(sk.get("knock", 0.0))
	if kn > 0.0:
		en.knock = away * kn / maxf(0.5, en.body_mass() * 0.7)
	if float(sk.get("slow", 0.0)) > 0.0:
		en.apply_slow(float(sk["slow"]))
	if float(sk.get("stun", 0.0)) > 0.0:
		if sk.get("weapon", false) and en.stun_t <= 0.0:
			Sfx.cue(game_floor, en.position, "stun")      # 武器の技で気絶させたとき(呪文の眠りや閃光は、前からのまま)
		en.apply_stun(float(sk["stun"]))
	if float(sk.get("sunder", 0.0)) > 0.0:
		if en.sunder_t <= 0.0:
			Sfx.cue(game_floor, en.position, "sunder")
		en.apply_sunder(float(sk["sunder"]))

func _allies() -> Array:
	var out: Array = []
	for h in game_floor.heroes:
		if not h.down:
			out.append(h)
	return out

func _sk_projectile(sk: Dictionary, aim: Vector2) -> bool:
	var count: int = int(sk.get("count", 1))
	var spread: float = float(sk.get("spread", 0.0))
	var d := _skill_dmg(sk)
	for i in count:
		var ang := (i - (count - 1) / 2.0) * spread
		var p := Projectile.new()
		p.setup_hero(game_floor, self, aim.rotated(ang), d, Jobs.class_color(ch.cls).lightened(0.2),
			float(sk["range"]) * (1.25 if ch.has_feat("sharpshooter") else 1.0), float(sk["speed"]), bool(sk.get("pierce", false)), float(sk.get("slow", 0.0)), float(sk.get("stun", 0.0)))
		game_floor.add_child(p)
	facing = aim
	return true

func _sk_burst(sk: Dictionary, center: Vector2) -> bool:
	var r := float(sk["radius"])
	var d := _skill_dmg(sk)
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
		_skill_effects(en, sk, away)
	return true

func _sk_rush(sk: Dictionary, aim: Vector2) -> bool:
	rush_dir = aim
	rush_t = float(sk["dist"]) / (Balance.ROLL_SPEED * 1.15)
	rush_dmg = _skill_dmg(sk)
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
	cmd["attack"] = false

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
	for i in ch.slots.size():
		var id := String(ch.slots[i])
		if id == "" or not can_cast(id):
			continue
		var sk := ch.skill_def(id)
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
			"strike":
				ok = ai_target != null and is_instance_valid(ai_target) and tdist <= radius + ai_target.radius + float(sk.get("reach", 24.0)) - 2.0
		if ok and use_skill(id):
			return
	# 届く敵がいれば、通常攻撃で殴る
	if ai_target != null and is_instance_valid(ai_target) and not ai_target.dead and can_attack():
		if position.distance_to(ai_target.position) <= radius + ai_target.radius + float(swing()["reach"]) - 2.0:
			attack()

# ---------- 描画 ----------

func _sprite() -> Texture2D:
	if _tex_ver != Assets.version:
		_tex_ver = Assets.version
		var v := Assets.hero_visual(ch.name, ch.cls, ch.race, ch.look)
		_tex = v["tex"]
		_is_sheet = v["sheet"]
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _is_sheet else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _tex

## 差し替え画像を描く。右向きの絵を、左を向くときは反転する
func _draw_sprite(tex: Texture2D, tint: Color, face_x: float) -> void:
	if _is_sheet:
		# スプライトシート: 向きと歩きで、コマを選ぶ
		draw_set_transform(lunge)
		Assets.draw_sheet_frame(self, tex, Assets.sheet_frame(Assets.sheet_dir(facing), walk_t, moving and not down), radius * 4.6, radius + 4.0, tint)
		return
	var sz := radius * 3.0
	var r := Rect2(-sz / 2.0, -sz / 2.0 - radius * 0.25, sz, sz)
	draw_set_transform(lunge, 0.0, Vector2(-1.0 if face_x < 0.0 else 1.0, 1.0))
	draw_texture_rect(tex, r, false, tint)
	draw_set_transform(lunge)

## 振りの弧と、通常攻撃の待ち時間(操作中の一人だけ、足もとに細い棒で出す)
func _draw_attack() -> void:
	draw_set_transform(Vector2.ZERO)
	if swing_t > 0.0:
		var a := swing_dir.angle()
		var arc := deg_to_rad(swing_arc)
		var rr := radius + swing_reach * 0.7
		draw_arc(Vector2.ZERO, rr, a - arc, a + arc, 16, Color(1.0, 0.92, 0.7, minf(1.0, swing_t / 0.18)), 3.0 if swing_t <= 0.18 else 5.0)
	if controlled and atk_cd > 0.0:
		var w := 26.0
		var y := radius + 20.0
		draw_rect(Rect2(-w / 2.0, y, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, y, w * attack_ready_frac(), 4.0), Color("ffe9a8"))
	if charging():
		# 溜め: 足もとの棒と、向いている側の弧。溜めきると明るく脈打つ
		var f := charge_frac()
		var w2 := 30.0
		var y2 := radius + 26.0
		var full := f >= 1.0
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 70.0) if full else 1.0
		var cc := Color(1.0, 0.85, 0.35, pulse) if full else Color(1.0, 0.6, 0.25)
		draw_rect(Rect2(-w2 / 2.0, y2, w2, 5.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w2 / 2.0, y2, w2 * f, 5.0), cc)
		var a2 := facing.angle()
		draw_arc(Vector2.ZERO, radius + 6.0 + 4.0 * f, a2 - 0.9, a2 + 0.9, 12, Color(cc.r, cc.g, cc.b, 0.4 + 0.5 * f), 2.0 + 3.0 * f)

## 眠っている間は「z」、寝込みを襲われて動けない間は「!」
func _draw_sleep() -> void:
	if sleep_t <= 0.0:
		return
	var y := -radius - (34.0 if _is_sheet else 18.0)
	if sleep_t > Balance.SURPRISE_TIME + 0.01:
		var t := Time.get_ticks_msec() / 1000.0
		UI.text_center(self, 6.0 + sin(t * 2.0) * 2.0, y - fmod(t * 6.0, 6.0), "z", 12, Color(0.8, 0.85, 1.0, 0.9))
	else:
		UI.text_center(self, 0.0, y, "!", 16, Color("ff6a5a"))

func _draw() -> void:
	draw_set_transform(lunge)
	var col := Jobs.class_color(ch.cls)
	var tex := _sprite()
	if tex != null:
		if down:
			_draw_sprite(tex, Color(0.35, 0.35, 0.4, 0.8), facing.x)
			draw_line(Vector2(-6, -6), Vector2(6, 6), Color(0.8, 0.2, 0.2), 3.0)
			draw_line(Vector2(-6, 6), Vector2(6, -6), Color(0.8, 0.2, 0.2), 3.0)
			return
		for k in buffs:
			if BUFF_COLORS.has(k):
				draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 22, BUFF_COLORS[k], 2.0)
		var tint := Color(1, 0.55, 0.5) if flash > 0.0 else Color.WHITE
		if roll_t > 0.0:
			tint.a = 0.55
		_draw_sprite(tex, tint, facing.x)
		if controlled:
			var my := -radius - (30.0 if _is_sheet else 14.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, my), Vector2(5, my - 8), Vector2(-5, my - 8)]), Color("ffe9a8"))
		_draw_sleep()
		_draw_attack()
		return
	if down:
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.35, 0.38, 0.8))
		draw_line(Vector2(-6, -6), Vector2(6, 6), Color(0.8, 0.2, 0.2), 3.0)
		draw_line(Vector2(-6, 6), Vector2(6, -6), Color(0.8, 0.2, 0.2), 3.0)
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
	UI.text_center(self, 0.0, 4.0, Jobs.class_initial(ch.cls), 11, Color(0.05, 0.05, 0.08), false)
	if controlled:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -radius - 12), Vector2(5, -radius - 20), Vector2(-5, -radius - 20)]), Color("ffe9a8"))
	_draw_sleep()
	_draw_attack()
