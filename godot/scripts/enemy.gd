class_name Enemy
extends Body
## 魔物一体。数値は SRD のまま持ち、リアルタイムに直す係数は Balance に置いてある。
## 近づいて体当たりで押し込む(Contact が押し合いを決める)。頭は三種:
##   mindless: まっすぐ迫り、逃げない  beast: 群れの半分が倒れてHPが半分を切ると逃げる
##   smart: 後衛を狙い、遠隔攻撃があれば距離を取り、傷が深いと逃げる
## そのうえで、SRD の特徴(群れで囲む、擬態、突進など)を持つ魔物は、その動きをする(MonTraits、このファイルの末尾)。

signal died(enemy: Enemy)

const RANGED_RE := "bow|sling|dart|javelin|hurl|spit|ray|bolt|blast|flame|spell|fire "
const TYPE_COLOR := {
	"undead": Color("c9c4b2"), "beast": Color("9a6a3c"), "swarm": Color("8a5a3a"), "ooze": Color("6fb04a"),
	"construct": Color("8c97a6"), "plant": Color("4f8a3c"), "monstrosity": Color("b0663a"), "aberration": Color("a05ac0"),
	"fiend": Color("c0392b"), "humanoid": Color("c79a6a"), "elemental": Color("d98a3c"), "fey": Color("c06ab0"),
	"celestial": Color("e8e0a0"), "dragon": Color("c04030"), "giant": Color("a0805a"),
}
const DISGUISE_TINT := Color(0.62, 0.6, 0.56)
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
var sunder_t := 0.0          # 守りを割られている秒(受けるダメージが Balance.SUNDER_MULT 倍)
var poison_t := 0.0          # 罠の毒(毎秒 poison_dps)
var poison_dps := 0.0
var _poison_tick := 1.0
var trap_cell := Vector2i(-1, -1)   # 最後にいたマス。マスを移ったときだけ、罠を踏んだか調べる
var target: Hero = null
var _tex: Texture2D = null
var _is_sheet := false
var _tex_ver := -1
var walk_t := 0.0
var moving := false
var face := Vector2.DOWN
# SRD の特徴(MonTraits の印)と、その動きの状態
var traits := {}
var disguised := false        # 擬態: 気づかれるまで物のふり
var surprise_t := 0.0         # 不意打ち: 襲いかかった直後の、痛い一瞬
var charge_cd := 0.0
var windup_t := 0.0           # 突進・跳びかかりの構え
var charge_t := 0.0
var charge_dir := Vector2.ZERO
var fort_cd := 0.0
var relent_used := false
var regen_stop_t := 0.0
var last_elem := ""           # いま受けている攻撃の種類(火・光など)
var flyby_t := 0.0
var grab_cd := 0.0
var rust_cd := 0.0
var con := 0
var _regen_acc := 0.0
var _pack_t := 0.0
var _pack_on := false
var _in_wall := false
var _emerge_cd := 0.0
var seen_noted := false       # 冒険日記帳に「見かけた」と知らせたか

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
	max_hp = maxi(1, int(round(float(m.get("hp", 5)) * Balance.ENEMY_HP_SCALE)))
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
	trap_cell = fl.map.cell_of(pos)     # 置かれたマスの罠は、踏んだことにしない
	traits = MonTraits.flags_for(m)
	con = MonTraits.con_mod(m)
	disguised = has_trait("mimic") and state == "idle"
	charge_cd = randf_range(0.5, 2.0)

func has_trait(f: String) -> bool:
	return traits.has(f)

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

func mon_type() -> String:
	return String(mon.get("type", ""))

func hp_frac() -> float:
	return clampf(hp / float(max_hp), 0.0, 1.0)

func body_mass() -> float:
	return Balance.SIZE_MASS.get(size_key, 1.0)

## 歩く速さ(Balance.ENEMY_SPEED_SCALE と、設定の「魔物の速さ」をかけたもの)
func move_speed() -> float:
	return speed * Balance.ENEMY_SPEED_SCALE * GameSettings.enemy_speed()

func body_speed() -> float:
	if stun_t > 0.0:
		return 0.0
	return move_speed() * (slow_v if slow_t > 0.0 else 1.0)

func contact_dps() -> float:
	if stun_t > 0.0 or state == "neutral" or disguised or windup_t > 0.0 or charge_t > 0.0:
		return 0.0
	var dps := dmg / Balance.ENEMY_ATTACK_INTERVAL * (1.5 if hits > 1 else 1.0) * trait_dmg_mult()
	return dps * (0.5 if ranged else 1.0)

## 特徴で変わる、与えるダメージの倍率
func trait_dmg_mult() -> float:
	var k := 1.0
	if surprise_t > 0.0:
		k *= 2.5
	if _pack_on:
		k *= 1.3
	if traits.has("swarm") and hp_frac() <= 0.5:
		k *= 0.5
	if traits.has("frenzy") and target != null and is_instance_valid(target) and target.ch.hp < target.ch.max_hp():
		k *= 1.3
	if traits.has("reckless"):
		k *= 1.25
	return k

func receive_contact(amount: float, from_pos: Vector2, src: Body) -> void:
	take_damage(amount, position - from_pos, src)

# ---------- 被ダメージ ----------

func take_damage(amount: float, from_dir: Vector2, src: Body = null) -> void:
	if dead:
		return
	var elem := last_elem
	last_elem = ""
	if disguised:
		_reveal()
	if traits.has("reckless"):
		amount *= 1.15
	var red := clampf((ac - 10) * 0.03, 0.0, 0.45)
	if sunder_t > 0.0:
		amount *= Balance.SUNDER_MULT
	if src is Hero and is_instance_valid(src):
		amount *= (src as Hero).ch.dealt_mult(mon_type())
	var final := maxf(0.05, amount * (1.0 - red))
	hp -= final
	if src is Hero and is_instance_valid(src):
		(src as Hero).stat_dealt += final
	flash = 0.1
	queue_popup(final, Color("ffe08a"))
	game_floor.add_child(Spark.make(position - from_dir.normalized() * radius * 0.6, 10.0, Color("fff0a0"), 0.14))
	if hp <= 0.0 and _hold_on(final, elem):
		hp = 1.0
	if hp <= 0.0:
		_die()
		return
	if state == "idle" or state == "neutral":
		game_floor.alert_encounter(enc_id)
	if src is Hero:
		target = src
	_check_flee(src as Hero if src is Hero and is_instance_valid(src) else null)

func apply_slow(secs: float, v: float = 0.45) -> void:
	slow_t = maxf(slow_t, secs)
	slow_v = v

func apply_stun(secs: float) -> void:
	stun_t = maxf(stun_t, secs)

func apply_sunder(secs: float) -> void:
	sunder_t = maxf(sunder_t, secs)

func poison(secs: float, dps: float) -> void:
	poison_dps = maxf(poison_dps if poison_t > 0.0 else 0.0, dps)
	poison_t = maxf(poison_t, secs)

## 落とし穴に落ちて、この層からいなくなる(経験点も落とし物もない)
func fall_away() -> void:
	if dead:
		return
	dead = true
	game_floor.spawn_text(position + Vector2(0, -radius - 16), "落ちた", Color("d0d0d0"))
	game_floor.enemy_gone(self)
	queue_free()

func _die() -> void:
	dead = true
	if traits.has("burst"):
		_death_burst()
	game_floor.spawn_text(position + Vector2(0, -radius - 16), "+%dXP" % xp, Color("9ad8ff"))
	died.emit(self)
	queue_free()

func _check_flee(by: Hero = null) -> void:
	if fled or state == "flee" or kind == "mindless":
		return
	# 〈威圧〉: 傷つけた相手が怖いほど、早く逃げ出す
	var scare := by.ch.skill_fx("intimidation") if by != null else 0.0
	var go := false
	if kind == "beast":
		go = hp_frac() <= 0.5 + scare and game_floor.group_dead_fraction(enc_id) >= 0.5
	else:
		go = hp_frac() <= 0.25 + scare
	if go:
		state = "flee"
		timer = 4.0
		fled = true
		game_floor.spawn_text(position + Vector2(0, -radius - 16), "逃げる", Color("d0d0d0"))

func wake() -> void:
	if disguised:
		_reveal()
		return
	if state == "idle" or state == "neutral":
		state = "chase"
		shown_alert = 0.7
		if traits.has("ambush"):
			surprise_t = 1.0

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
	# 鋭い感覚: 遠くから気づく。嗅覚と聴覚は、近ければ壁越しでも
	var through := 0.0
	if traits.has("smell"):
		cells *= 1.3
		through = 6.0
	elif traits.has("hearing"):
		cells *= 1.2
		through = 4.0
	elif traits.has("sight"):
		cells *= 1.5
	if traits.has("ghost"):
		through = cells
	cells *= 1.0 - h.ch.skill_fx("stealth")    # 〈隠密〉
	var d := position.distance_to(h.position)
	if d > cells * Balance.CELL:
		return false
	if not asleep and d <= through * (1.0 - h.ch.skill_fx("stealth")) * Balance.CELL:
		return true
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
	sunder_t = maxf(0.0, sunder_t - delta)
	_tick_traits(delta)
	if poison_t > 0.0:
		poison_t -= delta
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 1.0
			take_damage(poison_dps, Vector2.ZERO, null)
			if dead:
				return
	pop_update(delta)
	apply_knock(delta)
	var c := game_floor.map.cell_of(position)
	visible = game_floor.map.in_bounds(c.x, c.y) and game_floor.map.visible[game_floor.map.idx(c.x, c.y)] == 1
	if visible and not seen_noted and not disguised and not game_floor.arena:
		seen_noted = true
		game_floor.enemy_seen.emit(self)
	_trait_look(c)
	if game_floor.heroes.is_empty() or stun_t > 0.0:
		queue_redraw()
		return
	match state:
		"idle":
			sense_t -= delta
			if sense_t <= 0.0:
				sense_t = 0.2
				if disguised:
					# 擬態: 物のふりをして待ち、すぐそばまで来たら飛びかかる
					for h in game_floor.heroes:
						if not h.down and position.distance_to(h.position) <= radius + h.radius + 18.0:
							_reveal()
							break
				else:
					for h in game_floor.heroes:
						if not h.down and _can_sense(h):
							if traits.has("smell"):
								_cue_seen("sniff")
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
	if traits.has("ghost"):
		# すり抜け: 壁の中も進む(層の外へは出ない)
		var np := position + intent * sp * delta
		var nc := game_floor.map.cell_of(np)
		if game_floor.map.in_bounds(nc.x, nc.y):
			self_move += np - position
			position = np
		return
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
	var seen := dist < 260.0 and (traits.has("ghost") or map.los(mc.x, mc.y, tc.x, tc.y))      # 遠くは、見えていても使わない(直進は220px、射撃は200pxまで)
	if windup_t > 0.0 or charge_t > 0.0:
		_charge_step(delta)
		return
	if flyby_t > 0.0:
		_steer(delta, position - to_t, move_speed())     # 当てて離れる
		return
	if not ranged and charge_cd <= 0.0 and seen and dist > 70.0 and dist < 190.0 \
			and (traits.has("charge") or traits.has("trample") or traits.has("leap")):
		_start_charge(to_t)
		return
	# 近くに別の仲間がいれば、そちらへ切り替える(押し込まれている間は目標を固定しない)
	if dist > radius + 30.0 and Engine.get_physics_frames() % 20 == int(get_instance_id() % 20):
		var near := _nearest_hero()
		if near != null:
			target = near
	if ranged:
		if seen and dist < 110.0:
			_steer(delta, position - to_t, move_speed() * 0.8)
		elif seen and dist <= 200.0:
			if atk_cd <= 0.0:
				_shoot(target)
		else:
			_approach(delta, seen, mc)
		return
	_approach(delta, seen, mc)

func _approach(delta: float, seen: bool, mc: Vector2i) -> void:
	if seen and position.distance_to(target.position) < 220.0:
		_steer(delta, _flank_goal() if traits.has("pack") else target.position, move_speed())
		return
	var nxt := game_floor.map.flow_step(game_floor.flow, mc, true)
	if nxt.x >= 0:
		_steer(delta, game_floor.map.center_of(nxt), move_speed())

func _flee(delta: float) -> void:
	var mc := game_floor.map.cell_of(position)
	var nxt := game_floor.map.flow_step(game_floor.flow, mc, false)
	if nxt.x >= 0:
		_steer(delta, game_floor.map.center_of(nxt), move_speed() * 1.1)

func _shoot(h: Hero) -> void:
	atk_cd = Balance.ENEMY_ATTACK_INTERVAL * 1.4
	var p := Projectile.new()
	p.setup_enemy(game_floor, position, (h.position - position).normalized(), maxf(1.0, dmg * trait_dmg_mult() * randf_range(0.85, 1.15)), color, mon_type())
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
		var tint0 := Color(1, 0.6, 0.6) if flash > 0.0 else (Color(0.6, 0.6, 0.7) if stun_t > 0.0 else (DISGUISE_TINT if disguised else Color.WHITE))
		var size_px := maxf(radius * 3.6, 26.0)
		Assets.draw_sheet_frame(self, tex, Assets.sheet_frame(Assets.sheet_dir(face), walk_t, moving), size_px, radius + 5.0, tint0)
		_draw_overlays(-(size_px - radius - 5.0) + radius + 5.0 - 10.0)
		return
	if tex != null:
		var fx := 1.0
		if target != null and is_instance_valid(target):
			fx = -1.0 if target.position.x < position.x else 1.0
		var sz := maxf(radius * 2.8, 20.0)
		var tint := Color(1, 0.6, 0.6) if flash > 0.0 else (Color(0.6, 0.6, 0.7) if stun_t > 0.0 else (DISGUISE_TINT if disguised else Color.WHITE))
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
	if disguised:
		return     # 物のふり: 名前もHPも出さない
	if slow_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 20, Color(0.5, 0.8, 1.0, 0.8), 2.0)
	if poison_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 20, Color(0.55, 0.9, 0.35, 0.7), 2.0)
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

# ---------- SRD の特徴(MonTraits) ----------

func _tick_traits(delta: float) -> void:
	surprise_t = maxf(0.0, surprise_t - delta)
	charge_cd = maxf(0.0, charge_cd - delta)
	fort_cd = maxf(0.0, fort_cd - delta)
	regen_stop_t = maxf(0.0, regen_stop_t - delta)
	flyby_t = maxf(0.0, flyby_t - delta)
	grab_cd = maxf(0.0, grab_cd - delta)
	rust_cd = maxf(0.0, rust_cd - delta)
	_emerge_cd = maxf(0.0, _emerge_cd - delta)
	if traits.has("regen") and hp < max_hp and regen_stop_t <= 0.0:
		# 再生: SRD の毎ラウンド10点を、毎秒に直す
		var n := 10.0 / 6.0 * Balance.ENEMY_HP_SCALE * delta
		hp = minf(float(max_hp), hp + n)
		_regen_acc += n
		if _regen_acc >= 4.0:
			if visible:
				game_floor.spawn_text(position + Vector2(0, -radius - 8), "+%d" % int(_regen_acc), Color("7be08a"))
			_regen_acc = 0.0
	if traits.has("pack"):
		_pack_t -= delta
		if _pack_t <= 0.0:
			_pack_t = 0.25
			_pack_on = _ally_on_target()

## 見た目: 闇にまぎれる(近づかないと薄い)、壁の中は透ける。壁から出てきたら「スゥ…」
func _trait_look(c: Vector2i) -> void:
	var a := 1.0
	if traits.has("shadow") and flash <= 0.0:
		a = 0.28
		for h in game_floor.heroes:
			if not h.down and position.distance_to(h.position) <= 80.0:
				a = 1.0
				break
	if traits.has("ghost"):
		var inside := game_floor.map.opaque(c.x, c.y)
		if _in_wall and not inside and _emerge_cd <= 0.0 and state == "chase":
			_emerge_cd = 4.0
			_cue_seen("emerge")
		_in_wall = inside
		if inside:
			a = minf(a, 0.45)
	modulate.a = a

func _cue_seen(id: String) -> void:
	if visible:
		Sfx.cue(game_floor, position, id)

## 群れで囲む: 同じ相手に、ほかの魔物が触れているか
func _ally_on_target() -> bool:
	if target == null or not is_instance_valid(target) or target.down:
		return false
	for en in game_floor.enemies:
		if en != self and not en.dead and en.state != "neutral" \
				and en.position.distance_to(target.position) <= en.radius + target.radius + 6.0:
			return true
	return false

## 群れで囲む: 近くに仲間の魔物がいれば、正面からではなく、回り込んで相手を囲む
func _flank_goal() -> Vector2:
	var tp := target.position
	if position.distance_to(tp) <= radius + target.radius + 10.0:
		return tp
	var others := 0
	for en in game_floor.enemies:
		if en != self and not en.dead and en.position.distance_to(tp) <= 110.0:
			others += 1
	if others == 0:
		return tp
	var slot := int(get_instance_id() % 5) - 2
	var base := (position - tp).normalized()
	return tp + base.rotated(slot * 0.8) * (radius + target.radius + 4.0)

## 擬態をやめて、飛びかかる
func _reveal() -> void:
	if not disguised:
		return
	disguised = false
	state = "chase"
	shown_alert = 0.7
	surprise_t = 1.0
	_cue_seen("ambush")
	game_floor.alert_encounter(enc_id)

## 倒れても起き上がる(ゾンビのしぶとさ、猪の踏みとどまり)。光と、大きすぎる一撃には耐えられない
func _hold_on(final: float, elem: String) -> bool:
	if traits.has("fortitude") and elem != "radiant" and fort_cd <= 0.0:
		# SRD: 耐久力セーヴ(難易度 5+受けたダメージ)
		if Dice.d20() + con >= 5 + int(round(final)):
			fort_cd = 1.5
			_cue_seen("rise")
			return true
	if traits.has("relentless") and not relent_used and final <= max_hp * 0.35:
		relent_used = true
		_cue_seen("rise")
		return true
	return false

## 仲間の攻撃の種類(火・光など)。再生を止め、しぶとさを破る。take_damage の直前に呼ぶ
func elem_hit(e: String) -> void:
	last_elem = e
	if traits.has("regen") and e in MonTraits.REGEN_STOP:
		if regen_stop_t <= 0.0 and visible:
			game_floor.spawn_text(position + Vector2(0, -radius - 16), "再生が止まった", Color("ffb070"))
		regen_stop_t = 6.0

## 死に際に弾けて、まわりの仲間を傷つける
func _death_burst() -> void:
	var r := radius + 40.0
	game_floor.add_child(Spark.make(position, r, color.lightened(0.3), 0.35, true))
	Sfx.cue(game_floor, position, "burst")
	for h in game_floor.heroes:
		if not h.down and h.position.distance_to(position) <= r + h.radius:
			h.damage(maxf(1.0, dmg), position)

## 体当たりが仲間に当たったとき(Hero.receive_contact から): 張りつく、錆びさせる、当てて離れる
func on_hit_hero(h: Hero) -> void:
	if traits.has("grapple") and grab_cd <= 0.0 and h.stuck_t <= 0.0:
		grab_cd = 5.0
		h.hold("glue", 1.6)
		Sfx.cue(game_floor, h.position, "glue")
		if traits.has("mimic"):
			game_floor.stat.emit("mimic_bite")
	if traits.has("rust") and rust_cd <= 0.0 and h.rust < 3:
		rust_cd = 4.0
		Sfx.cue(game_floor, h.position, "rust")
		if bool(h.ch.equip_item("armor").get("rustproof", false)):
			game_floor.message.emit("%sの鎧は錆を弾いた" % h.ch.name, "info")
		else:
			h.rust += 1
			game_floor.message.emit("%sの鎧が錆びた。この潜行の間、守りが %d 下がる" % [h.ch.name, h.rust], "danger")
	if traits.has("flyby"):
		flyby_t = 0.7

## 突進・跳びかかり: 構えて(「!」と擬音)、まっすぐ突っ込む。転がってかわせる
func _start_charge(to_t: Vector2) -> void:
	charge_dir = to_t.normalized()
	var leap := traits.has("leap") and not traits.has("charge") and not traits.has("trample")
	windup_t = 0.25 if leap else 0.45
	shown_alert = windup_t
	if not leap:
		_cue_seen("mon_charge")

func _charge_step(delta: float) -> void:
	var leap := traits.has("leap") and not traits.has("charge") and not traits.has("trample")
	if windup_t > 0.0:
		windup_t -= delta
		if target != null and is_instance_valid(target):
			charge_dir = (target.position - position).normalized()    # 構えの間は、相手に向きを合わせる
		face = charge_dir
		if windup_t <= 0.0:
			charge_t = 0.3 if leap else 0.55
			if leap:
				_cue_seen("leap")
		return
	charge_t -= delta
	var sp := move_speed() * (3.0 if leap else 2.4)
	var before := position
	intent = charge_dir
	walk(charge_dir * sp * delta)
	for h in game_floor.heroes:
		if not h.down and h.position.distance_to(position) <= radius + h.radius + 4.0:
			_charge_hit(h, leap)
			return
	if charge_t <= 0.0 or position.distance_to(before) < sp * delta * 0.3:
		_end_charge()

func _charge_hit(h: Hero, leap: bool) -> void:
	var was := h.ch.hp
	h.damage(dmg * (1.0 if leap else 1.5), position)
	if h.ch.hp < was:
		h.knock = charge_dir * 260.0 / maxf(0.5, h.ch.mass())
		if traits.has("trample"):
			h.hold("prone", 0.8)
		Sfx.cue(game_floor, h.position, "ram")
	_end_charge()

func _end_charge() -> void:
	windup_t = 0.0
	charge_t = 0.0
	charge_cd = randf_range(4.0, 6.0)
