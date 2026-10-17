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
var state := "idle"            # idle / neutral / chase / flee / wander(ワンダリング・モンスターが歩き回る)
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
# 第二弾の特徴
var lurk := ""                # 潜んで待つ形(擬態 disguised とは別): water 水たまりに沈む / ceiling 天井から垂れる / shape 化ける
var shape_look := {}          # 化けた姿の絵 {tex, sheet}
var shape_name := ""
var web_attack := false       # 糸を吐く(SRD の Web)
var web_cd := 0.0
var in_light := false         # 灯りの中(光に弱い魔物)
var lit_cd := 0.0
var stench_cd := 0.0
var gaze_cd := 0.0
var last_spell := false       # いま受けている攻撃が呪文か(魔法への抵抗)
var squeeze_to := Vector2.ZERO
var squeeze_t := 0.0          # 扉の下をくぐっている
var _trait2_t := 0.0
var _note_cd := 0.0
var _glow_vis := false
# 第三弾の特徴
var dmods := {}               # ダメージの種類 → 倍率(耐性・無効・弱点。MonTraits.damage_mods)
var cimm := {}                # 効かない状態(SRD の ci。Stunned、Unconscious など)
var legend := 0               # 伝説的な抵抗の残り(気絶・眠り・足止めを跳ね返す)
var spells: Array = []        # 唱える呪文(MonSpells)
var spell_cds := {}           # 呪文 → 残りの待ち時間
var cast_id := ""             # 詠唱している呪文
var cast_t := 0.0
var cast_at := Vector2.ZERO   # 狙った所
var cast_tgt: Hero = null
var vanish_t := 0.0           # 姿を消している
var misty_used := false
var mist_t := 0.0             # 霧になって逃げている
var heat_cd := 0.0
# 眠らせる(Spawner)
var dormant := false          # 仲間から遠いので、動きも描画も止めている
var light := false            # ワンダリング・モンスターの軽い歩き方(位置だけ Spawner が進める)

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
	web_attack = (m.get("attacks", []) as Array).any(func(a): return String(a.get("n", "")) == "Web")
	web_cd = randf_range(1.0, 3.0)
	var dm := MonTraits.damage_mods(m)
	dmods = dm["mult"]
	cimm = dm["ci"]
	legend = 3 if traits.has("legend") else 0
	if traits.has("caster"):
		spells = MonSpells.kit_for(m, mon_type())
		for sid in spells:
			spell_cds[sid] = randf_range(1.5, 4.0)
	# 出た瞬間から、見えるかを決めておく(暗がりに出た魔物が、最初のコマだけ見えないように)
	var vc := fl.map.cell_of(pos)
	visible = fl.map.in_bounds(vc.x, vc.y) and fl.map.visible[fl.map.idx(vc.x, vc.y)] == 1
	if state == "idle" and not disguised:
		if has_trait("shape"):
			_set_shape()
		elif has_trait("climb"):
			lurk = "ceiling"
		elif has_trait("aquatic") or has_trait("amphib"):
			lurk = "water"

## 化ける: 小さな魔物は鼠に、ほかは迷い込んだ冒険者に化けて待つ
func _set_shape() -> void:
	lurk = "shape"
	if size_key in ["T", "S"]:
		shape_look = Assets.enemy_visual("giant-rat", "beast")
		shape_name = "大鼠"
	else:
		var cls: String = ["fighter", "rogue", "cleric", "wizard"][randi() % 4]
		shape_look = Assets.hero_visual("", cls, "human", "M" if randf() < 0.5 else "F")
		shape_name = "迷い込んだ冒険者"

## 物のふりや、潜んで待っているか(名前もHPも出さず、触れても殴らない)
func hidden_form() -> bool:
	return disguised or lurk != ""

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
	var k := 1.0
	if in_light:
		k *= 0.85        # 光に弱い: 灯りの中では鈍る
	if traits.has("aquatic") and not traits.has("amphib"):
		k *= 0.6         # 水に棲む魔物は、陸では鈍い
	elif game_floor != null:
		k *= game_floor.map.speed_at(position)   # 浅瀬は遅い(水に棲む魔物は平気)
	return speed * Balance.ENEMY_SPEED_SCALE * GameSettings.enemy_speed() * k

func body_speed() -> float:
	if stun_t > 0.0:
		return 0.0
	return move_speed() * (slow_v if slow_t > 0.0 else 1.0)

func contact_dps() -> float:
	if stun_t > 0.0 or state == "neutral" or hidden_form() or windup_t > 0.0 or charge_t > 0.0:
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
	if in_light:
		k *= 0.7
	return k

func receive_contact(amount: float, from_pos: Vector2, src: Body) -> void:
	take_damage(amount, position - from_pos, src)

# ---------- 被ダメージ ----------

func take_damage(amount: float, from_dir: Vector2, src: Body = null) -> void:
	if dead:
		return
	var elem := last_elem
	var spell := last_spell
	last_elem = ""
	last_spell = false
	if hidden_form():
		_reveal()
	if elem == "lightning" and traits.has("absorb_lightning"):
		# 雷を吸う: 傷つかず、癒える
		var n := amount * 0.5
		hp = minf(float(max_hp), hp + n)
		_note("雷を吸った", Color("9ad8ff"))
		game_floor.spawn_text(position + Vector2(0, -radius - 4), "+%d" % maxi(1, int(n)), Color("7be08a"))
		return
	if spell and traits.has("magic_res"):
		amount *= 0.5
		_note("魔法に抵抗した", Color("c8b0ff"))
	if elem == "cold" and traits.has("water_sus"):
		amount *= 2.0
		_note("冷気に弱い", Color("9ad8ff"))
	if traits.has("sun_weak") and in_light:
		amount *= 1.3
	# 耐性・無効・弱点(SRD の re / im / vu)。武器なら、その武器の傷の種類
	var dtype := elem
	var magic := spell
	if dtype == "" and spell:
		dtype = "force"
	elif dtype == "" and src is Hero and is_instance_valid(src):
		dtype = (src as Hero).weapon_dtype()
		magic = (src as Hero).weapon_magic()
	var dm := damage_mult(dtype, magic, spell)
	if dm != 1.0:
		amount *= dm
		if dm <= 0.0:
			_note("効かない", Color(0.75, 0.75, 0.8))
		elif dm < 1.0:
			_note("効きが悪い", Color(0.8, 0.8, 0.85))
		else:
			_note("よく効く!", Color("ffd27a"))
	if traits.has("heated") and src is Hero and is_instance_valid(src) and elem == "" and not spell and heat_cd <= 0.0 \
			and position.distance_to(src.position) <= radius + src.radius + 40.0:
		# 熱い体: 近くで殴ると、殴った側が火傷する
		heat_cd = 0.8
		(src as Hero).damage(maxf(1.0, dmg * 0.3), position, false, mon_type())
		Sfx.cue(game_floor, src.position, "burn")
	if amount <= 0.0:
		flash = 0.06
		if state == "idle" or state == "neutral" or state == "wander":
			game_floor.alert_encounter(enc_id)
		return
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
	if hp <= 0.0 and traits.has("misty") and not misty_used:
		_mist_away()
	if hp <= 0.0:
		_die()
		return
	if state == "idle" or state == "neutral" or state == "wander":
		game_floor.alert_encounter(enc_id)
	if src is Hero:
		target = src
	_check_flee(src as Hero if src is Hero and is_instance_valid(src) else null)

## ダメージの倍率(耐性・無効・弱点)。dtype は傷の種類、magic は魔力を帯びた武器か、spell は呪文か
func damage_mult(dtype: String, magic: bool, spell: bool) -> float:
	var k := float(dmods.get(dtype, 1.0))
	if not magic and not spell:
		k *= float(dmods.get("nm_" + dtype, 1.0))
	if spell:
		k *= float(dmods.get("spell", 1.0))
	return k

## 状態が効かないか(SRD の ci、妖精の血)。cond: stun 気絶 / sleep 眠り / blind 目くらまし / hold 足止め・網
func immune_to(cond: String) -> bool:
	match cond:
		"stun":
			return cimm.has("Stunned") or cimm.has("Paralyzed")
		"sleep":
			return cimm.has("Unconscious") or traits.has("fey_anc")
		"blind":
			return cimm.has("Blinded")
		"hold":
			return cimm.has("Restrained") or cimm.has("Grappled")
		"prone":
			return cimm.has("Prone")
		"slow":
			return traits.has("immutable")
		"poison":
			return cimm.has("Poisoned") or dmods.get("poison", 1.0) == 0.0
	return false

## 状態を弾くか(効かない、または伝説的な抵抗)。弾いたら true
func _shrug(cond: String) -> bool:
	if immune_to(cond):
		_note({"sleep": "眠らない", "poison": "毒が効かない"}.get(cond, "効かない"), Color(0.8, 0.8, 0.85))
		return true
	if legend > 0:
		legend -= 1
		_cue_seen("shrug")
		_note("跳ね返した(残り%d)" % legend, Color("ffd27a"))
		return true
	return false

func apply_slow(secs: float, v: float = 0.45) -> void:
	if slow_t <= 0.0 and _shrug("slow"):
		return
	slow_t = maxf(slow_t, secs)
	slow_v = v

func apply_stun(secs: float, cond: String = "stun") -> void:
	if stun_t <= 0.0 and _shrug(cond):
		return
	stun_t = maxf(stun_t, secs)
	_end_cast()

func apply_sunder(secs: float) -> void:
	sunder_t = maxf(sunder_t, secs)

func poison(secs: float, dps: float) -> void:
	if immune_to("poison"):
		_note("毒が効かない", Color(0.7, 0.85, 0.6))
		return
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
	if hidden_form():
		_reveal()
		return
	if state == "idle" or state == "neutral" or state == "wander":
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
	if traits.has("recall"):
		# 迷宮を覚えている: 遠くから、壁越しにも迫る
		cells *= 1.5
		through = cells
	if not traits.has("devil_sight"):
		cells *= 1.0 - h.ch.skill_fx("stealth")    # 〈隠密〉(悪魔の目は見通す)
	var d := position.distance_to(h.position)
	if d > cells * Balance.CELL:
		return false
	if not asleep and d <= through * (1.0 if traits.has("devil_sight") else 1.0 - h.ch.skill_fx("stealth")) * Balance.CELL:
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
	if not visible and traits.has("glow"):
		visible = _glow_vis          # 光る体: 灯りの外でも、見通せれば見える(_tick_traits2 で調べる)
	if visible and not seen_noted and not hidden_form() and not game_floor.arena:
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
				if hidden_form():
					# 擬態・潜んで待つ: すぐそばまで来たら飛びかかる
					for h in game_floor.heroes:
						if not h.down and position.distance_to(h.position) <= radius + h.radius + _lurk_reach():
							_reveal()
							break
				else:
					for h in game_floor.heroes:
						if not h.down and _can_sense(h):
							if traits.has("smell"):
								_cue_seen("sniff")
							game_floor.alert_encounter(enc_id)
							break
		"wander":
			sense_t -= delta
			if sense_t <= 0.0:
				sense_t = 0.2
				for h in game_floor.heroes:
					if not h.down and _can_sense(h):
						game_floor.alert_encounter(enc_id)
						break
			if state == "wander":
				var to := game_floor.spawner.wander_next(self)
				if to.x < INF:
					_steer(delta, to, move_speed() * Spawner.WANDER_SPEED)
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
		open_doors()

## 動きと描画を止める / 戻す(Spawner。仲間から遠い魔物)
func set_dormant(on: bool) -> void:
	if on == dormant:
		return
	dormant = on
	set_physics_process(not on)
	if on:
		visible = false
		self_move = Vector2.ZERO
		intent = Vector2.ZERO

## ワンダリング・モンスターの軽い歩き方に替える / 戻す。眠らせるのと同じく止めるが、位置は Spawner が進める
func set_light(on: bool) -> void:
	light = on
	set_dormant(on)

func open_doors() -> void:
	for d in game_floor.map.doors_near(position, 28.0):
		if d["open"]:
			continue
		if d["type"] == "secret" and not d["found"]:
			continue
		if d["type"] == "locked" and not d["unlocked"]:
			if not traits.has("siege") or state != "chase":
				continue
			# 扉を壊す(攻城の怪物)
			d["unlocked"] = true
			var dp: Vector2 = game_floor.map.center_of(Vector2i(int(d["x"]), int(d["y"])))
			Sfx.cue(game_floor, dp, "ram")
			game_floor.spawn_text(dp + Vector2(0, -18), "扉を壊した", Color("ffb070"))
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
	if squeeze_t > 0.0:
		_squeeze_step(delta)
		return
	if cast_t > 0.0:
		_cast_step(delta)
		return
	if mist_t > 0.0:
		_steer(delta, position - to_t, move_speed() * 1.3)     # 霧になって離れる
		return
	if not spells.is_empty() and _try_cast(dist, seen):
		return
	if web_attack and web_cd <= 0.0 and seen and dist > 60.0 and dist < 200.0 and target.stuck_t <= 0.0:
		_shoot_web(target)
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
	if traits.has("amorph") and _try_squeeze(mc):
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
	if lurk == "water":
		_draw_puddle()
		return
	var off := lunge
	var sc := 1.0
	var base_tint := Color.WHITE
	if lurk == "ceiling":
		# 天井から垂れて待つ: 床に影、上に糸、体は暗く小さく
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2(0, radius * 0.3), radius * 0.8, Color(0, 0, 0, 0.3))
		draw_line(Vector2(0, -radius - 90.0), Vector2(0, -radius - 30.0), Color(0.85, 0.85, 0.8, 0.5), 1.0)
		off += Vector2(0, -radius - 18.0)
		sc = 0.7
		base_tint = Color(0.5, 0.5, 0.56)
	if traits.has("glow") and not hidden_form():
		var tm := Time.get_ticks_msec() / 1000.0
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2.ZERO, radius * 2.4 + sin(tm * 3.0) * 2.0, Color(1.0, 0.75, 0.35, 0.13))
		draw_circle(Vector2.ZERO, radius * 1.5, Color(1.0, 0.85, 0.5, 0.12))
	draw_set_transform(off, 0.0, Vector2(sc, sc))
	var tex := _sprite()
	var sheet := _is_sheet
	if lurk == "shape" and shape_look.get("tex") != null:
		tex = shape_look["tex"]
		sheet = bool(shape_look["sheet"])
	var tint0 := Color(1, 0.6, 0.6) if flash > 0.0 else (Color(0.6, 0.6, 0.7) if stun_t > 0.0 else (DISGUISE_TINT if disguised else base_tint))
	if tex != null and sheet:
		var size_px := maxf(radius * 3.6, 26.0)
		Assets.draw_sheet_frame(self, tex, Assets.sheet_frame(Assets.sheet_dir(face), walk_t, moving), size_px, radius + 5.0, tint0)
		draw_set_transform(Vector2.ZERO)
		_draw_overlays(-(size_px - radius - 5.0) + radius + 5.0 - 10.0)
		return
	if tex != null:
		var fx := 1.0
		if target != null and is_instance_valid(target):
			fx = -1.0 if target.position.x < position.x else 1.0
		var sz := maxf(radius * 2.8, 20.0)
		draw_set_transform(off, 0.0, Vector2(fx * sc, sc))
		draw_texture_rect(tex, Rect2(-sz / 2.0, -sz / 2.0 - radius * 0.2, sz, sz), false, tint0)
		draw_set_transform(Vector2.ZERO)
		_draw_overlays()
		return
	var c := Color.WHITE if flash > 0.0 else color * base_tint
	if stun_t > 0.0:
		c = c.darkened(0.4)
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
	var fv := Vector2.RIGHT
	if target != null and is_instance_valid(target):
		fv = (target.position - position).normalized()
	draw_circle(fv * radius * 0.45 + fv.orthogonal() * 3.0, 1.8, Color.BLACK)
	draw_circle(fv * radius * 0.45 - fv.orthogonal() * 3.0, 1.8, Color.BLACK)
	draw_set_transform(Vector2.ZERO)
	_draw_overlays()

## 水たまりに沈んで待つ: 暗い水面と、ときどき立つ波紋と泡
func _draw_puddle() -> void:
	draw_set_transform(Vector2.ZERO)
	var tm := Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 97) * 0.13
	var r := radius * 1.7 + 6.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, r, Color(0.08, 0.16, 0.24, 0.85))
	draw_circle(Vector2.ZERO, r * 0.82, Color(0.12, 0.24, 0.34, 0.85))
	for k in 2:
		var f := fmod(tm * 0.45 + k * 0.5, 1.0)
		draw_arc(Vector2.ZERO, r * (0.25 + 0.7 * f), 0.0, TAU, 24, Color(0.6, 0.8, 0.95, 0.45 * (1.0 - f)), 1.0)
	draw_set_transform(Vector2.ZERO)
	var bf := fmod(tm * 0.7, 1.0)
	if bf < 0.3:
		draw_circle(Vector2(r * 0.3, -2.0 - bf * 8.0), 1.5, Color(0.75, 0.9, 1.0, 0.8 * (1.0 - bf / 0.3)))

func _draw_overlays(dy: float = 0.0) -> void:
	if disguised or lurk == "water" or lurk == "ceiling":
		return     # 物のふり・潜んで待つ: 名前もHPも出さない
	if lurk == "shape":
		UI.text_center(self, 0.0, radius + 14.0, shape_name, 11, Color(1, 1, 1, 0.8))      # 化けた姿の名前だけ
		return
	if slow_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 20, Color(0.5, 0.8, 1.0, 0.8), 2.0)
	if poison_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 20, Color(0.55, 0.9, 0.35, 0.7), 2.0)
	if stun_t > 0.0:
		UI.text_center(self, 0.0, -radius - 16.0 + dy, "zzz", 12, Color(0.8, 0.9, 1.0))
	if cast_t > 0.0:
		# 詠唱: 足もとに紫の輪が満ちていく。頭上に呪文の名前
		var k := 1.0 - cast_t / MonSpells.CAST_TIME
		draw_arc(Vector2.ZERO, radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color(0.8, 0.55, 1.0, 0.9), 2.5)
		UI.text_center(self, 0.0, -radius - 26.0 + dy, String(MonSpells.def(cast_id).get("name", "")), 12, Color(0.88, 0.75, 1.0))
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
	heat_cd = maxf(0.0, heat_cd - delta)
	vanish_t = maxf(0.0, vanish_t - delta)
	if mist_t > 0.0:
		mist_t -= delta
		if mist_t <= 0.0:
			traits.erase("ghost")
	for sid in spell_cds:
		spell_cds[sid] = maxf(0.0, float(spell_cds[sid]) - delta)
	web_cd = maxf(0.0, web_cd - delta)
	lit_cd = maxf(0.0, lit_cd - delta)
	stench_cd = maxf(0.0, stench_cd - delta)
	gaze_cd = maxf(0.0, gaze_cd - delta)
	_note_cd = maxf(0.0, _note_cd - delta)
	_trait2_t -= delta
	if _trait2_t <= 0.0:
		_trait2_t = 0.25
		_tick_traits2(0.25)
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
	if vanish_t > 0.0 and flash <= 0.0:
		a = minf(a, 0.12)       # 姿消し
	if mist_t > 0.0:
		a = minf(a, 0.4)        # 霧
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

## 擬態・潜んで待つのをやめて、飛びかかる
func _reveal() -> void:
	if not hidden_form():
		return
	var how := "ambush"
	match lurk:
		"water": how = "splash"
		"ceiling": how = "drop"
		"shape": how = "shape"
	if lurk == "water":
		game_floor.add_child(Spark.make(position, radius * 2.2, Color(0.6, 0.85, 1.0), 0.3, true))
	disguised = false
	lurk = ""
	state = "chase"
	shown_alert = 0.7
	surprise_t = 1.0
	_cue_seen(how)
	game_floor.alert_encounter(enc_id)

## 飛びかかる距離(体の縁から)。水たまりと天井は少し遠くから、化けた者はすぐそばまで待つ
func _lurk_reach() -> float:
	match lurk:
		"water": return 56.0
		"ceiling": return 40.0
		"shape": return 12.0
	return 18.0

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
func elem_hit(e: String, spell: bool = false) -> void:
	last_elem = e
	last_spell = spell
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

# ---------- SRD の特徴 第二弾 ----------

## 頭上に一言(同じ魔物では1.5秒に一度)
func _note(t: String, c: Color) -> void:
	if _note_cd > 0.0 or not visible:
		return
	_note_cd = 1.5
	game_floor.spawn_text(position + Vector2(0, -radius - 18), t, c)

## 呪文の眠りや足止めを弾くか(魔法への抵抗。半分は弾く)
func spell_resisted() -> bool:
	if not traits.has("magic_res") or randf() >= 0.5:
		return false
	_note("魔法に抵抗した", Color("c8b0ff"))
	return true

## 0.25秒ごと: 灯り、悪臭、石化の視線、光る体
func _tick_traits2(dt: float) -> void:
	if traits.has("sun") or traits.has("sun_weak"):
		var was := in_light
		in_light = _is_lit()
		if in_light and not was and lit_cd <= 0.0 and state == "chase" and visible:
			lit_cd = 6.0
			Sfx.cue(game_floor, position + Vector2(0, 16), "glare")
			game_floor.spawn_text(position + Vector2(0, -radius - 18), "眩しがる", Color("fff0a0"))
	if hidden_form() or state == "neutral" or game_floor.heroes.is_empty():
		return
	if traits.has("stench"):
		# 悪臭: そばにいる仲間は気分が悪くなる(弱い毒)
		var hit := false
		for h in game_floor.heroes:
			if not h.down and h.position.distance_to(position) <= radius + h.radius + 40.0:
				h.poison(1.2, maxf(0.4, dmg * 0.05))
				hit = true
		if hit and stench_cd <= 0.0 and visible:
			stench_cd = 8.0
			Sfx.cue(game_floor, position, "stench")
	if traits.has("gaze") and state == "chase":
		_gaze(dt)
	if traits.has("glow"):
		_glow_vis = false
		var mc := game_floor.map.cell_of(position)
		for h in game_floor.heroes:
			if h.down or h.position.distance_to(position) > 14.0 * Balance.CELL:
				continue
			var hc := game_floor.map.cell_of(h.position)
			if game_floor.map.los(hc.x, hc.y, mc.x, mc.y):
				_glow_vis = true
				break

## 灯りの中か: 灯りのある部屋か、燐晶の灯油を灯した仲間のそば
func _is_lit() -> bool:
	var map := game_floor.map
	var c := map.cell_of(position)
	if not map.in_bounds(c.x, c.y):
		return false
	var rid: int = map.room_at[map.idx(c.x, c.y)]
	if rid >= 0 and bool(map.room_by_id[rid].get("lit", false)):
		return true
	if game_floor.lamp_on:
		for h in game_floor.heroes:
			if not h.down and h.position.distance_to(position) <= 4.0 * Balance.CELL:
				return true
	return false

## 石化の視線: こちらを向いている仲間は、だんだん石になる。目をそらす(背を向ける)と防げる
func _gaze(dt: float) -> void:
	var mc := game_floor.map.cell_of(position)
	for h in game_floor.heroes:
		if h.down or (h.stuck_t > 0.0 and h.stuck_kind == "stone"):
			continue
		var to: Vector2 = position - h.position
		if to.length() > 6.0 * Balance.CELL or h.facing.dot(to.normalized()) < 0.4:
			continue
		var hc := game_floor.map.cell_of(h.position)
		if not game_floor.map.los(hc.x, hc.y, mc.x, mc.y):
			continue
		if h.stone_m <= 0.0 and gaze_cd <= 0.0:
			gaze_cd = 5.0
			_cue_seen("gaze")
		h.gaze_by(dt * (1.0 if h.controlled else 0.5), display_name)

## 糸を吐く: 当たった仲間は、しばらく動けない
func _shoot_web(h: Hero) -> void:
	web_cd = randf_range(7.0, 10.0)
	var p := Projectile.new()
	p.setup_enemy(game_floor, position, (h.position - position).normalized(), 0.0, Color(0.92, 0.92, 0.88), mon_type())
	p.web = true
	game_floor.add_child(p)
	_cue_seen("web_shot")

## 不定形: 行く手の閉じた扉(鍵が掛かっていても)の下を、くぐり抜ける
func _try_squeeze(mc: Vector2i) -> bool:
	var map := game_floor.map
	var fl: PackedInt32Array = game_floor.flow
	if fl.size() != map.w * map.h:
		return false
	var cur := fl[map.idx(mc.x, mc.y)]
	for dv in FloorMap.DIRS4:
		var dc: Vector2i = mc + dv
		if not map.in_bounds(dc.x, dc.y) or map.tiles[map.idx(dc.x, dc.y)] != FloorMap.DOOR or map.monster_passable(dc.x, dc.y):
			continue
		var bc: Vector2i = dc + dv
		if not map.in_bounds(bc.x, bc.y) or map.opaque(bc.x, bc.y):
			continue
		var bd := fl[map.idx(bc.x, bc.y)]
		if bd >= 0 and (cur < 0 or bd < cur):
			squeeze_to = map.center_of(bc)
			squeeze_t = position.distance_to(squeeze_to) / maxf(10.0, move_speed() * 0.8) + 0.5
			if visible or map.visible[map.idx(dc.x, dc.y)] == 1:
				Sfx.cue(game_floor, map.center_of(dc), "squeeze")
			return true
	return false

func _squeeze_step(delta: float) -> void:
	squeeze_t -= delta
	var to := squeeze_to - position
	if to.length() < 3.0 or squeeze_t <= 0.0:
		squeeze_t = 0.0
		return
	var step := to.normalized() * minf(to.length(), move_speed() * 0.8 * delta)
	intent = to.normalized()
	self_move += step
	position += step

# ---------- 第三弾: 呪文、霧になって逃げる ----------

## 唱える呪文を選んで、詠唱を始める。始めたら true
func _try_cast(dist: float, seen: bool) -> bool:
	if hidden_form() or windup_t > 0.0 or charge_t > 0.0:
		return false
	for sid in spells:
		if float(spell_cds.get(sid, 0.0)) > 0.0:
			continue
		var sp := MonSpells.def(sid)
		var k := String(sp["kind"])
		var reach := float(sp["range"]) * Balance.CELL
		if k == "heal":
			var who := _hurt_ally(reach)
			if who == null:
				continue
			_begin_cast(sid, who.position, null)
			return true
		if k == "blink":
			if dist > radius + target.radius + 30.0 or hp_frac() > 0.7:
				continue
			_begin_cast(sid, position, target)
			return true
		if k == "vanish":
			if vanish_t > 0.0 or dist > reach:
				continue
			_begin_cast(sid, position, target)
			return true
		if not seen or dist > reach or dist < radius + target.radius + 8.0 and k == "bolt":
			continue
		_begin_cast(sid, target.position, target)
		return true
	return false

func _hurt_ally(reach: float) -> Enemy:
	var best: Enemy = null
	var low := 0.7
	for en in game_floor.enemies:
		if en.dead or en.dormant or en.state == "neutral" or position.distance_to(en.position) > reach:
			continue
		if en.hp_frac() < low:
			low = en.hp_frac()
			best = en
	return best

func _begin_cast(sid: String, at: Vector2, tgt: Hero) -> void:
	var sp := MonSpells.def(sid)
	cast_id = sid
	cast_at = at
	cast_tgt = tgt
	cast_t = MonSpells.CAST_TIME
	spell_cds[sid] = float(sp["cd"]) * randf_range(0.9, 1.2)
	_cue_seen("chant")

func _end_cast() -> void:
	cast_t = 0.0
	cast_id = ""
	cast_tgt = null

## 詠唱の間は止まって、狙いを追う。唱え終えたら放つ
func _cast_step(delta: float) -> void:
	if cast_tgt != null and is_instance_valid(cast_tgt) and not cast_tgt.down:
		cast_at = cast_tgt.position
		intent = (cast_at - position).normalized() * 0.01
	cast_t -= delta
	if cast_t <= 0.0:
		var sid := cast_id
		var at := cast_at
		var tgt := cast_tgt
		_end_cast()
		_cast_fire(sid, at, tgt)

func _cast_fire(sid: String, at: Vector2, tgt: Hero) -> void:
	var sp := MonSpells.def(sid)
	var cue := String(sp.get("cue", ""))
	match String(sp["kind"]):
		"bolt":
			var n := int(sp.get("count", 1))
			var base := (at - position).normalized()
			for i in n:
				var d := base.rotated((i - (n - 1) / 2.0) * 0.18)
				var p := Projectile.new()
				p.setup_enemy(game_floor, position + d * radius, d, maxf(1.0, dmg * float(sp["mult"]) * randf_range(0.85, 1.15)), sp["color"], mon_type())
				p.speed = float(sp.get("speed", 300.0))
				p.life = float(sp["range"]) * Balance.CELL * 1.3 / p.speed
				p.elem = String(sp["elem"])
				p.spell = true
				p.chill = float(sp.get("chill", 0.0))
				game_floor.add_child(p)
			_cue_seen(cue)
		"hold":
			if tgt != null and is_instance_valid(tgt) and not tgt.down and not tgt.is_rolling():
				tgt.hold("hold", float(sp["secs"]))
				Sfx.cue(game_floor, tgt.position, cue)
		"sleep", "vine":
			var hit := false
			for h in game_floor.heroes:
				if not h.down and not h.is_rolling() and h.position.distance_to(at) <= float(sp["radius"]):
					h.hold("sleep" if String(sp["kind"]) == "sleep" else "vine", float(sp["secs"]))
					hit = true
			game_floor.add_child(Spark.make(at, float(sp["radius"]), Color(0.8, 0.75, 1.0) if String(sp["kind"]) == "sleep" else Color(0.5, 0.8, 0.4), 0.4, true))
			Sfx.cue(game_floor, at, cue)
			if hit and String(sp["kind"]) == "sleep":
				game_floor.message.emit("%sの眠りの呪文で、仲間が眠った" % display_name, "danger")
		"charm":
			if tgt != null and is_instance_valid(tgt) and not tgt.down:
				tgt.confuse_t = maxf(tgt.confuse_t, float(sp["secs"]))
				Sfx.cue(game_floor, tgt.position, cue)
				game_floor.message.emit("%sは%sに魅入られた。しばらく前後左右が逆になる" % [tgt.ch.name, display_name], "danger")
		"heat":
			if tgt != null and is_instance_valid(tgt) and not tgt.down:
				tgt.damage(maxf(1.0, dmg * float(sp["mult"])), position, true, mon_type())
				Sfx.cue(game_floor, tgt.position, cue)
		"dark":
			for h in game_floor.heroes:
				if not h.down and h.position.distance_to(at) <= float(sp["radius"]):
					h.blind_t = maxf(h.blind_t, float(sp["secs"]))
			game_floor.add_child(Spark.make(at, float(sp["radius"]), Color(0.08, 0.05, 0.12), 0.8, true))
			Sfx.cue(game_floor, at, cue)
			game_floor.darkened.emit()
		"heal":
			var who := _hurt_ally(float(sp["range"]) * Balance.CELL)
			if who != null:
				var n2 := who.max_hp * float(sp["frac"])
				who.hp = minf(float(who.max_hp), who.hp + n2)
				if who.visible:
					Sfx.cue(game_floor, who.position, cue)
					game_floor.spawn_text(who.position + Vector2(0, -who.radius - 8), "+%d" % int(n2), Color("7be08a"))
		"vanish":
			_cue_seen(cue)
			vanish_t = float(sp["secs"])
		"blink":
			var to := _blink_spot(int(sp["cells"]))
			if to.x < INF:
				_cue_seen(cue)
				position = to
				if visible:
					Sfx.cue(game_floor, to, "warp_out")

## 霧の歩み: 仲間から離れた、通れる床(見つからなければ INF)
func _blink_spot(cells: int) -> Vector2:
	var map := game_floor.map
	var mc := map.cell_of(position)
	var away := Vector2.ZERO
	for h in game_floor.heroes:
		if not h.down:
			away += position - h.position
	var best := Vector2(INF, INF)
	var best_s := -INF
	for i in 24:
		var c := mc + Vector2i(randi_range(-cells, cells), randi_range(-cells, cells))
		if not map.in_bounds(c.x, c.y) or not map.monster_passable(c.x, c.y) or not map.los(mc.x, mc.y, c.x, c.y):
			continue
		var p := map.center_of(c)
		var s := (p - position).dot(away.normalized()) + p.distance_to(position) * 0.2
		if s > best_s:
			best_s = s
			best = p
	return best

## 霧になって逃げる(吸血鬼): 一度だけ、倒れる代わりに霧になって壁を抜け、離れていく
func _mist_away() -> void:
	misty_used = true
	hp = maxf(1.0, max_hp * 0.2)
	mist_t = 6.0
	traits["ghost"] = true
	_end_cast()
	_cue_seen("mist")
	_note("霧になった", Color(0.85, 0.85, 0.95))
