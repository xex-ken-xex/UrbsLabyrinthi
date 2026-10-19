class_name TrapFx
extends Node2D
## 動きのある罠。踏むと予兆が出て、少し間をおいて発動する。セーヴは振らず、そのとき範囲にいたかどうかで決まる。
## 転がり(無敵の間)や走り抜けで避けられる。仲間も魔物も巻き込む(魔物を誘い込める)。
## 振り子と噴き口と壁龕の頭蓋(PERIODIC)は隠れておらず、層にいる間ずっと動いている。
## どの罠がどれかは、地図の生成器(docs/urbs-labyrinthi.html の罠表)の fx が決める。

## 予兆のある罠(踏むとこのノードが動き出す)
const MOVING := ["explode", "spikes", "boulder", "cart", "sink", "collapse", "log", "censer", "fire", "darts", "bolt", "crush", "net", "gas", "fog"]
## ずっと動いている罠(層を作ったときに置く)
const PERIODIC := ["pendulum", "flame", "gaze"]
## 踏んだ瞬間の擬音(予兆)
const START_CUE := {"explode": "click", "spikes": "click", "boulder": "rumble", "cart": "cart_run", "sink": "stone_tilt", "collapse": "creak", "log": "creak", "censer": "creak",
	"fire": "click", "darts": "click", "bolt": "click", "crush": "grind", "net": "", "gas": "gas", "fog": "gas"}

const C := float(Balance.CELL)
const FUSE := 0.8              # 爆発の罠の導火(秒)
const BLAST_R := 2.5           # 爆発の半径(マス)
const SPIKE_DELAY := 0.5
const DROP := {"collapse": [0.7, 1.5], "log": [0.6, 0.8], "censer": [0.6, 1.0]}    # 落ちるもの: [影が出てから落ちるまで(秒), 半径(マス)]
const BOULDER_SPEED := 230.0
const CRUSH_TIME := 2.2
const NET_DELAY := 0.35
const CLOUD := {"gas": [1.6, 5.0], "fog": [2.0, 6.0]}     # [半径(マス), 残る秒]
const PENDULUM_PERIOD := 2.2
const FLAME_CYCLE := 3.4       # 噴き口: 0〜0.7 予兆、0.7〜1.9 炎、あとは止む
const SINK_DELAY := 0.45       # 沈む渡し石: 踏んでから沈むまで(すぐ降りれば落ちない)
const SINK_DOWN := 1.2         # 水に落ちて起き上がるまで(秒)。重い鎧なら HEAVY_SINK
const HEAVY_SINK := 2.4
const GAZE_REACH := 7          # 壁龕の頭蓋の視線が届くマス
const GAZE_WIND := 0.55        # 目が光ってから射すくめるまで(視線から外れれば無事)
const GAZE_REST := 3.0         # 射すくめたあと、次に光るまで
const GAZE_FEAR := 3.0         # 怯えて攻撃できない秒

var fl: FloorInstance
var t: Dictionary
var kind := ""
var age := 0.0
var origin := Vector2.ZERO
var base := 2.0                # 一撃の素のダメージ(Balance.TRAP_DMG_SCALE をかけたあと)
var hit := {}                  # すでに当たった体(一度だけ当たる罠)
var done := false              # 発動しおえた(あとは消えるまでの絵だけ)
var aim := Vector2.ZERO        # 狙い(踏んだ者の位置)
var dir := Vector2.RIGHT
var reach := 0.0
var start := Vector2.ZERO
var end := Vector2.ZERO
var darts: Array = []          # {p, v, live}
var fired := 0
var band: Array = []           # 迫る壁: 壁ぎわのマス(Vector2i)
var room_center := Vector2.ZERO
var zone_t := 0.0              # 瓦礫や燃えさしの残り秒
var tick := 0.0
var last_hit := {}             # 体 → 当たった時刻(振り子、噴き口)
var saved := {}                # 煙: セーヴに成功した体
var _cue_ms := -10000
var line: Array = []           # 壁龕の頭蓋: 視線の届くマス(Vector2i)
var glare_t := -1.0            # 壁龕の頭蓋: 目が光ってからの秒(光っていなければ負)

## 罠を動かす。victim は踏んだ者(わざと発動させたときは null)
static func make(floor_inst: FloorInstance, trap: Dictionary, victim: Body) -> TrapFx:
	var f := TrapFx.new()
	f.fl = floor_inst
	f.t = trap
	f.kind = String(trap.get("fx", ""))
	f.origin = floor_inst.map.center_of(Vector2i(int(trap["x"]), int(trap["y"])))
	f.aim = victim.position if victim != null else f.origin
	if trap.has("damage"):
		f.base = maxf(1.0, Dice.roll(String(trap["damage"])) * Balance.TRAP_DMG_SCALE)
	f.z_index = 2
	f._prepare()
	return f

func _prepare() -> void:
	match kind:
		"boulder": _prepare_boulder()
		"cart": _prepare_cart()
		"gaze": _prepare_gaze()
		"fire", "darts", "bolt": _prepare_wall()
		"crush": _prepare_crush()
		"pendulum": _prepare_pendulum()
		"flame":
			age = fmod(float(int(t.get("id", 0))) * 1.37, FLAME_CYCLE)     # 噴き口ごとに、間をずらす

# ---------- 体 ----------

func _bodies() -> Array:
	var out: Array = []
	for h in fl.heroes:
		if is_instance_valid(h) and not h.down:
			out.append(h)
	for e in fl.enemies:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out

## 転がっている最中(無敵)の仲間には当たらない
static func dodging(b: Body) -> bool:
	return b is Hero and ((b as Hero).iframes > 0.0 or (b as Hero).roll_t > 0.0)

## 罠のダメージを与える。当たったら true。push は押し出す強さ(画素/秒)
func hurt(b: Body, mult: float, from: Vector2, push: float = 0.0) -> bool:
	if dodging(b) or not b.is_alive():
		return false
	var n := base * mult
	if b is Hero:
		var h := b as Hero
		h.damage(n * (1.0 - h.ch.skill_fx("survival")), from, true)
	else:
		(b as Enemy).take_damage(n * Balance.TRAP_MON_MULT, b.position - from, null)
	if push > 0.0 and b.is_alive():
		var away := (b.position - from)
		if away.length() < 0.5:
			away = Vector2.from_angle(Dice.rng.randf() * TAU)
		b.knock = away.normalized() * push / maxf(0.5, b.body_mass() * 0.7)
	return true

func _say(text: String) -> void:
	fl.message.emit(text, "danger")

func _seen(p: Vector2) -> bool:
	var c := fl.map.cell_of(p)
	return fl.map.in_bounds(c.x, c.y) and fl.map.visible[fl.map.idx(c.x, c.y)] == 1

## 近くに仲間がいるときだけ、擬音を出す(ずっと動いている罠が、遠くで鳴り続けないように)
func _cue_near(p: Vector2, id: String, cells: float = 7.0, gap_ms: int = 0) -> void:
	if Time.get_ticks_msec() - _cue_ms < gap_ms:
		return
	for h in fl.heroes:
		if is_instance_valid(h) and h.position.distance_to(p) <= cells * C:
			_cue_ms = Time.get_ticks_msec()
			Sfx.cue(fl, p, id)
			return

# ---------- 毎フレーム ----------

func _physics_process(delta: float) -> void:
	if fl == null or fl.map == null:
		return
	age += delta
	match kind:
		"explode": _explode()
		"spikes": _spikes()
		"boulder", "cart": _boulder(delta)
		"sink": _sink()
		"gaze": _gaze(delta)
		"collapse", "log", "censer": _drop(delta)
		"fire": _fire(delta)
		"darts", "bolt": _darts(delta)
		"crush": _crush()
		"net": _net()
		"gas", "fog": _cloud(delta)
		"pendulum": _pendulum()
		"flame": _flame(delta)
		_: queue_free()
	queue_redraw()

func _explode() -> void:
	if age >= 0.15 and not hit.has("fuse"):
		hit["fuse"] = true
		Sfx.cue(fl, origin, "fuse")
	if not done and age >= FUSE:
		done = true
		Sfx.cue(fl, origin, "boom")
		fl.shake.emit(0.45)
		var R := BLAST_R * C
		for b in _bodies():
			var d: float = b.position.distance_to(origin)
			if d <= R + b.radius:
				hurt(b, lerpf(1.0, 0.5, clampf(d / R, 0.0, 1.0)), origin, 300.0)
		# 落ちている燐晶や自生物は、焼けて消える(遺体は残る)
		var burned := 0
		for i in range(fl.ground.entries.size() - 1, -1, -1):
			var e: Dictionary = fl.ground.entries[i]
			if String(e["kind"]) != "corpse" and (e["pos"] as Vector2).distance_to(origin) <= R:
				fl.ground.entries.remove_at(i)
				burned += 1
		if burned > 0 and _seen(origin):
			_say("落ちていたものが、爆風で焼けた。")
		fl.alert_radius(origin, 12.0)
		fl.queue_redraw()
	if age >= FUSE + 0.5:
		queue_free()

func _spikes() -> void:
	if not done and age >= SPIKE_DELAY:
		done = true
		Sfx.cue(fl, origin, "spikes")
		for b in _bodies():
			if b.position.distance_to(origin) <= C * 0.6 + b.radius * 0.6:
				hurt(b, 1.0, origin + Vector2(0, 4))
	if age >= SPIKE_DELAY + 0.9:
		queue_free()

# 転がる大岩: 罠のマスを通る、長いほうのまっすぐな床の端から端へ
func _run(c: Vector2i, d: Vector2i) -> int:
	var n := 0
	while n < 14:
		var nx := c.x + d.x * (n + 1)
		var ny := c.y + d.y * (n + 1)
		if not fl.map.in_bounds(nx, ny) or fl.map.opaque(nx, ny):
			break
		n += 1
	return n

func _prepare_boulder() -> void:
	var c := fl.map.cell_of(origin)
	var h := _run(c, Vector2i(-1, 0)) + _run(c, Vector2i(1, 0))
	var v := _run(c, Vector2i(0, -1)) + _run(c, Vector2i(0, 1))
	var axis := Vector2i(1, 0) if h >= v else Vector2i(0, 1)
	var a := _run(c, -axis)
	var b := _run(c, axis)
	# 遠いほうの端から転がってくる(気づいてから逃げる間がある)
	var from_neg := a >= b
	var s := c - axis * a if from_neg else c + axis * b
	var e := c + axis * b if from_neg else c - axis * a
	start = fl.map.center_of(s)
	end = fl.map.center_of(e)
	dir = (end - start).normalized() if end != start else Vector2.RIGHT
	reach = 0.0

func _boulder(delta: float) -> void:
	const WAIT := 0.4
	if age < WAIT:
		return
	var total := start.distance_to(end)
	if not done:
		reach = minf(total, reach + BOULDER_SPEED * delta)
		var p := start + dir * reach
		for b in _bodies():
			if hit.has(b):
				continue
			if b.position.distance_to(p) <= 14.0 + b.radius:
				hit[b] = true
				var side := Vector2(-dir.y, dir.x)
				if side.dot(b.position - p) < 0.0:
					side = -side
				if hurt(b, 1.0, p - side * 8.0, 0.0):
					b.knock = (side * 260.0 + dir * 120.0) / maxf(0.5, b.body_mass() * 0.7)
					Sfx.cue(fl, b.position, "smash")
		if reach >= total:
			done = true
			zone_t = 0.6
			Sfx.cue(fl, end, "cart_crash" if kind == "cart" else "smash")    # 鉱車は軌条の端で ガシャーン!
			fl.shake.emit(0.2)
	else:
		zone_t -= delta
		if zone_t <= 0.0:
			queue_free()

# 暴走する鉱車: 罠のマスを通る軌条の、遠いほうの端から走ってくる(軌条が無ければ大岩と同じ)
func _prepare_cart() -> void:
	var c := fl.map.cell_of(origin)
	var rail := FloorProps.rail_at(fl, c)
	if rail.is_empty():
		_prepare_boulder()
		return
	var a := Vector2i(int(rail["x"]), int(rail["y"]))
	var b := Vector2i(int(rail["x2"]), int(rail["y2"]))
	var from_a := (a - c).length_squared() >= (b - c).length_squared()
	start = fl.map.center_of(a if from_a else b)
	end = fl.map.center_of(b if from_a else a)
	dir = (end - start).normalized() if end != start else Vector2.RIGHT
	reach = 0.0

# 沈む渡し石: 踏んで一拍おいて石が沈む。そのとき石の上にいた者は水に落ちて転ぶ(重い鎧は起き上がるのに手間取る)。
# 水に棲む魔物は落ちない
func _sink() -> void:
	if not done and age >= SINK_DELAY:
		done = true
		Sfx.cue(fl, origin, "plunge")
		for b in _bodies():
			if b.position.distance_to(origin) > C * 0.6 + b.radius * 0.4 or dodging(b):
				continue
			if b is Enemy and ((b as Enemy).has_trait("aquatic") or (b as Enemy).has_trait("amphib")):
				continue
			hurt(b, 0.4, origin + Vector2(0, 4))
			var heavy := false
			if b is Hero:
				var arm: Dictionary = (b as Hero).ch.equip_item("armor")
				heavy = not arm.is_empty() and String(arm.get("type", "")) == "heavy"
			knock_down(b, HEAVY_SINK if heavy else SINK_DOWN)
			if heavy and _seen(origin):
				_say("%sは重い鎧のせいで、水からなかなか上がれない。" % (b as Hero).ch.name)
	if age >= SINK_DELAY + 1.4:
		queue_free()

func _drop(delta: float) -> void:
	var spec: Array = DROP[kind]
	var R := float(spec[1]) * C
	if not done and age >= float(spec[0]):
		done = true
		match kind:
			"collapse":
				Sfx.cue(fl, origin, "rubble")
				fl.shake.emit(0.25)
				zone_t = 20.0
			"log":
				Sfx.cue(fl, origin, "thud")
				fl.shake.emit(0.15)
				zone_t = 0.8
			"censer":
				Sfx.cue(fl, origin, "clang")
				zone_t = 8.0
		for b in _bodies():
			if b.position.distance_to(origin) <= R + b.radius * 0.5:
				if hurt(b, 1.0, origin, 70.0 if kind == "collapse" else 0.0) and kind == "log":
					TrapFx.knock_down(b, 1.2)
	elif done:
		zone_t -= delta
		tick -= delta
		match kind:
			"collapse":       # 瓦礫: 通りにくい
				for b in _bodies():
					if b.position.distance_to(origin) <= R:
						TrapFx.slow(b, "mire", 0.5, 0.2)
			"censer":         # くすぶる香: 踏むと焼ける
				if tick <= 0.0:
					tick = 0.5
					for b in _bodies():
						if b.position.distance_to(origin) <= R:
							hurt(b, 0.12, b.position + Vector2(0, 4))
		if zone_t <= 0.0:
			queue_free()

## 罠のマスから、いちばん近い壁(火を吐く像、矢の穴がある)
func _prepare_wall() -> void:
	var c := fl.map.cell_of(origin)
	var best := 99
	var bd := Vector2i(0, -1)
	for d in FloorMap.DIRS4:
		var n := _run(c, d)
		if n < best:
			best = n
			bd = d
	dir = -Vector2(bd)                       # 壁から罠のほうへ
	start = origin - dir * (best + 0.5) * C   # 壁の面
	reach = (best + 4.0) * C

func _in_cone(p: Vector2) -> bool:
	var v := p - start
	var d := v.length()
	return d <= reach and d > 2.0 and absf(v.angle_to(dir)) <= 0.45

func _fire(delta: float) -> void:
	const WARN := 0.45
	const BURN := 2.0
	if age < WARN:
		return
	if not done:
		done = true
		Sfx.cue(fl, start + dir * C, "flame")
	tick -= delta
	if tick <= 0.0 and age < WARN + BURN:
		tick = 0.25
		for b in _bodies():
			if _in_cone(b.position):
				hurt(b, 0.25, start)
	if age >= WARN + BURN + 0.3:
		queue_free()

func _darts(delta: float) -> void:
	const WARN := 0.35
	var n := 1 if kind == "bolt" else 4
	if age >= WARN + fired * 0.12 and fired < n:
		if fired == 0:
			Sfx.cue(fl, start + dir * C * 0.5, "dart", dir)
		fired += 1
		var tgt := aim
		# 狙いは、踏んだ者のいまの位置(いなければ罠のマス)
		var best := 1e9
		for b in _bodies():
			var d: float = b.position.distance_to(origin)
			if d < best and d < 2.5 * C:
				best = d
				tgt = b.position
		var v := (tgt - start).normalized().rotated(Dice.rng.randf_range(-0.12, 0.12))
		darts.append({"p": start + v * 4.0, "v": v * 380.0, "live": true, "life": 1.2})
	var any := false
	for dd in darts:
		if not dd["live"]:
			continue
		any = true
		dd["life"] = float(dd["life"]) - delta
		dd["p"] = (dd["p"] as Vector2) + (dd["v"] as Vector2) * delta
		var p: Vector2 = dd["p"]
		var c := fl.map.cell_of(p)
		if float(dd["life"]) <= 0.0 or (fl.map.opaque(c.x, c.y) and p.distance_to(start) > C * 0.6):
			dd["live"] = false
			continue
		for b in _bodies():
			if dodging(b):
				continue
			if b.position.distance_to(p) < b.radius + 3.0:
				dd["live"] = false
				if hurt(b, 1.0 if kind == "bolt" else 0.3, p - (dd["v"] as Vector2).normalized() * 8.0) and kind == "darts":
					TrapFx.poison(b, 6.0, maxf(0.5, base * 0.06))
				break
	if fired >= n and not any:
		queue_free()

func _prepare_crush() -> void:
	var rid := int(t.get("roomId", -1))
	var m := fl.map
	if rid < 0 or not m.room_cells.has(rid):
		kind = "spikes"         # 部屋でなければ、ただの棘の床にする
		return
	var sum := Vector2.ZERO
	var cells: Array = m.room_cells[rid]
	for k in cells:
		var c := Vector2i(int(k) % m.w, int(k) / m.w)
		sum += m.center_of(c)
		for d in FloorMap.DIRS4:
			if m.in_bounds(c.x + d.x, c.y + d.y) and m.tiles[m.idx(c.x + d.x, c.y + d.y)] == FloorMap.ROCK:
				band.append(c)
				break
	room_center = sum / maxf(1.0, cells.size())

func _crush() -> void:
	if not done and age >= CRUSH_TIME:
		done = true
		Sfx.cue(fl, room_center, "crush")
		fl.shake.emit(0.35)
		var in_band := {}
		for c in band:
			in_band[c] = true
		for b in _bodies():
			if in_band.has(fl.map.cell_of(b.position)):
				hurt(b, 1.2, b.position + (b.position - room_center).normalized() * 10.0, 0.0)
				b.knock = (room_center - b.position).normalized() * 220.0 / maxf(0.5, b.body_mass() * 0.7)
	if age >= CRUSH_TIME + 0.5:
		queue_free()

func _net() -> void:
	if not done and age >= NET_DELAY:
		done = true
		Sfx.cue(fl, origin, "net")
		fl.alert_radius(origin, 8.0)            # 網の鈴が鳴る
		for b in _bodies():
			if b.position.distance_to(origin) <= C * 0.9 + b.radius * 0.5 and not dodging(b):
				TrapFx.hold(b, "net", 3.0)
	if age >= NET_DELAY + 0.4:
		queue_free()

func _cloud(delta: float) -> void:
	var spec: Array = CLOUD[kind]
	var R := float(spec[0]) * C
	tick -= delta
	if tick <= 0.0:
		tick = 1.0 if kind == "gas" else 0.2
		for b in _bodies():
			if b.position.distance_to(origin) > R:
				continue
			if kind == "fog":
				TrapFx.slow(b, "chill", 0.6, 0.4)
				continue
			if saved.has(b):
				continue
			# 煙は予兆が無いので、いままでどおり【耐久力】セーヴ
			var dc := int((t.get("save", {}) as Dictionary).get("dc", 12))
			var ok := false
			if b is Hero:
				var h := b as Hero
				ok = h.ch.roll_d20() + h.ch.save_bonus("con") >= dc
			else:
				ok = Dice.d20() + TrapFx.mon_save(b as Enemy) >= dc
			if ok:
				saved[b] = true
			else:
				TrapFx.hold(b, "sleep", 3.0)
	if age >= float(spec[1]):
		queue_free()

# ---------- ずっと動いている罠 ----------

func _prepare_pendulum() -> void:
	var c := fl.map.cell_of(origin)
	var h := _run(c, Vector2i(-1, 0)) + _run(c, Vector2i(1, 0))
	var v := _run(c, Vector2i(0, -1)) + _run(c, Vector2i(0, 1))
	dir = Vector2.RIGHT if h >= v else Vector2.DOWN        # 通路の向き。刃はこれを横切って揺れる
	age = fmod(float(int(t.get("id", 0))) * 0.73, PENDULUM_PERIOD)

func _off() -> bool:
	return String(t.get("st", "")) == "disarmed"

func _blade() -> Vector2:
	var side := Vector2(-dir.y, dir.x)
	return origin + side * sin(age / PENDULUM_PERIOD * TAU) * 1.3 * C

func _pendulum() -> void:
	if _off():
		return
	var s := sin(age / PENDULUM_PERIOD * TAU)
	if absf(s) < 0.08:
		_cue_near(origin, "swing", 7.0, 600)
	if absf(s) > 0.42:
		return
	var bp := _blade()
	var side := Vector2(-dir.y, dir.x)
	var vel := side * cos(age / PENDULUM_PERIOD * TAU)
	for b in _bodies():
		if b is Hero and int(t.get("safe_until", 0)) > Time.get_ticks_msec():
			continue
		var rel: Vector2 = b.position - bp
		if absf(rel.dot(dir)) > C * 0.55 or absf(rel.dot(side)) > 7.0 + b.radius:
			continue
		if age - float(last_hit.get(b, -9.0)) < PENDULUM_PERIOD * 0.4:
			continue
		last_hit[b] = age
		if hurt(b, 1.0, bp - vel * 8.0, 0.0):
			b.knock = vel.normalized() * 230.0 / maxf(0.5, b.body_mass() * 0.7)

# 壁龕の頭蓋: 行き止まりの壁龕から、通路をまっすぐ見つめる。視線の先に仲間が立つと目が光り(ギラッ)、
# 一拍おいてまだ立っていれば射すくめる(ギンッ!。恐怖と、少しの死霊の傷)。視線の先の魔物も射すくめられる(不死者は平気)
func _prepare_gaze() -> void:
	var c := fl.map.cell_of(origin)
	var v: Vector2i = {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}.get(String(t.get("face", "s")), Vector2i(0, 1))
	dir = Vector2(v)
	line = [c]
	for n in GAZE_REACH:
		var q := c + v * (n + 1)
		if not fl.map.in_bounds(q.x, q.y) or fl.map.opaque(q.x, q.y):
			break
		line.append(q)

func _in_gaze(b: Body) -> bool:
	return line.has(fl.map.cell_of(b.position))

func _skull() -> Vector2:
	return origin - dir * C * 0.38

func _gaze(delta: float) -> void:
	if _off():
		glare_t = -1.0
		return
	tick -= delta
	if glare_t < 0.0:
		if tick > 0.0:
			return
		for h in fl.heroes:
			if is_instance_valid(h) and not h.down and _in_gaze(h) and int(t.get("safe_until", 0)) <= Time.get_ticks_msec():
				glare_t = 0.0
				Sfx.cue(fl, _skull() + Vector2(0, -10), "skull_glint")
				return
		return
	glare_t += delta
	if glare_t < GAZE_WIND:
		return
	glare_t = -1.0
	var struck := false
	for b in _bodies():
		if not _in_gaze(b) or dodging(b):
			continue
		if b is Hero and int(t.get("safe_until", 0)) > Time.get_ticks_msec():
			continue
		if b is Enemy and (b as Enemy).mon_type() == "undead":
			continue
		struck = true
		hurt(b, 0.35, _skull())
		if b is Hero:
			(b as Hero).fear_t = maxf((b as Hero).fear_t, GAZE_FEAR)
		elif (b as Enemy).kind != "mindless":
			(b as Enemy).state = "flee"
			(b as Enemy).timer = GAZE_FEAR
	if struck:
		Sfx.cue(fl, _skull() + Vector2(0, -12), "skull_gaze")
		tick = GAZE_REST
	else:
		tick = 0.8         # 視線から外れた(光っただけ)

func _flame(delta: float) -> void:
	if _off():
		return
	var ph := fmod(age, FLAME_CYCLE)
	if ph < 0.7 or ph > 1.9:
		hit.clear()
		return
	if not hit.has("cue"):
		hit["cue"] = true
		_cue_near(origin, "jet")
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.3
	for b in _bodies():
		if b is Hero and int(t.get("safe_until", 0)) > Time.get_ticks_msec():
			continue
		if b.position.distance_to(origin) <= C * 0.62 + b.radius * 0.4:
			hurt(b, 0.25, origin + Vector2(0, 6))

# ---------- 状態(仲間にも魔物にも) ----------

static func mon_save(e: Enemy) -> int:
	return 2 + int(float(e.mon.get("cr", 0)) / 3.0)

## 動けなくする(網、眠り、転倒など)
static func hold(b: Body, why: String, secs: float) -> void:
	if b is Hero:
		(b as Hero).hold(why, secs)
	elif b is Enemy:
		if why == "net" and (b as Enemy).has_trait("webwalk"):
			return        # 巣を歩く魔物は、網に絡まらない
		(b as Enemy).apply_stun(secs * 0.8, {"sleep": "sleep", "prone": "prone", "net": "hold", "teeth": "hold", "glue": "hold", "web": "hold"}.get(why, "stun"))
		if why == "sleep" and (b as Enemy).stun_t > 0.0:
			b.game_floor.spawn_text(b.position + Vector2(0, -b.radius - 14), "z", Color(0.8, 0.85, 1.0))

static func knock_down(b: Body, secs: float) -> void:
	hold(b, "prone", secs)

static func slow(b: Body, key: String, v: float, secs: float) -> void:
	if b is Hero:
		var h := b as Hero
		h.buffs[key] = {"t": maxf(secs, float(h.buffs.get(key, {"t": 0.0})["t"])), "v": v}
	elif b is Enemy:
		(b as Enemy).apply_slow(secs, v)

static func poison(b: Body, secs: float, dps: float) -> void:
	if b is Hero:
		(b as Hero).poison(secs, dps)
	elif b is Enemy:
		(b as Enemy).poison(secs, dps * Balance.TRAP_MON_MULT)

# ---------- 描画 ----------

func _draw() -> void:
	var tm := Time.get_ticks_msec() / 1000.0
	match kind:
		"explode":
			var R := BLAST_R * C
			if not done:
				var f := clampf(age / FUSE, 0.0, 1.0)
				var blink := 0.5 + 0.5 * sin(tm * 30.0)
				draw_circle(origin, R * f, Color(1.0, 0.2, 0.1, 0.12 + 0.1 * blink))
				draw_arc(origin, R, 0.0, TAU, 40, Color(1.0, 0.3, 0.2, 0.55 + 0.35 * blink), 2.0)
				draw_circle(origin, 4.0 + 2.0 * blink, Color(1.0, 0.85, 0.4))
			else:
				var k := clampf((age - FUSE) / 0.5, 0.0, 1.0)
				draw_circle(origin, R * (0.6 + 0.5 * k), Color(1.0, 0.75, 0.3, 0.75 * (1.0 - k)))
				draw_circle(origin, R * 0.5 * (1.0 - k), Color(1.0, 1.0, 0.85, 0.9 * (1.0 - k)))
		"spikes":
			var up := done
			var k := clampf(age / SPIKE_DELAY, 0.0, 1.0)
			draw_circle(origin, C * 0.6, Color(0.9, 0.3, 0.2, 0.15 + 0.2 * k))
			for i in 5:
				var p := origin + Vector2.from_angle(i * TAU / 5.0 + 0.3) * C * 0.28
				var hgt := 12.0 if up else 3.0 * k
				draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(0, -hgt)]), Color(0.85, 0.85, 0.9))
		"boulder":
			if age < 0.4:
				return
			var p := start + dir * reach
			var a := 1.0 if not done else clampf(zone_t / 0.6, 0.0, 1.0)
			draw_circle(p + Vector2(0, 5), 14.0, Color(0, 0, 0, 0.35 * a))
			draw_circle(p, 14.0, Color(0.48, 0.42, 0.36, a))
			draw_arc(p, 14.0, 0.0, TAU, 20, Color(0.2, 0.17, 0.14, a), 2.0)
			var r := reach / 14.0
			draw_line(p + Vector2.from_angle(r) * 10.0, p - Vector2.from_angle(r) * 10.0, Color(0.3, 0.26, 0.22, a), 2.0)
		"cart":
			if age < 0.4:
				return
			var pc := start + dir * reach
			var ac := 1.0 if not done else clampf(zone_t / 0.6, 0.0, 1.0)
			FloorProps.draw_cart(self, pc, absf(dir.y) > absf(dir.x), 1.0, ac)
			if not done:
				for n in 3:
					var back := pc - dir * (C * 0.55 + n * 7.0)
					var sd := Vector2(-dir.y, dir.x) * (n - 1) * 6.0
					draw_line(back + sd, back + sd - dir * 8.0, Color(0.9, 0.85, 0.7, 0.5), 1.5)
		"sink":
			var ks := clampf(age / SINK_DELAY, 0.0, 1.0)
			if not done:
				var wob := sin(tm * 40.0) * 2.0 * ks
				draw_circle(origin + Vector2(wob, ks * 3.0), C * 0.2 * (1.0 - 0.3 * ks), Color(0.82, 0.8, 0.74))
			else:
				var kr := clampf((age - SINK_DELAY) / 1.4, 0.0, 1.0)
				for n in 3:
					var rr := C * (0.2 + 0.35 * fmod(kr + n * 0.3, 1.0))
					draw_arc(origin, rr, 0.0, TAU, 18, Color(0.75, 0.9, 1.0, 0.7 * (1.0 - kr)), 1.5)
				for n in 6:
					var drop := origin + Vector2.from_angle(n * TAU / 6.0) * C * 0.4 * kr + Vector2(0, -16.0 * sin(kr * PI))
					draw_circle(drop, 1.8, Color(0.75, 0.9, 1.0, 1.0 - kr))
		"gaze":
			if not _explored():
				return
			var sk := _skull()
			var a8 := 0.4 if _off() else 1.0
			draw_circle(sk, 7.5, Color(0.88, 0.84, 0.72, a8))
			draw_rect(Rect2(sk + Vector2(-4, 4), Vector2(8, 4)), Color(0.8, 0.76, 0.64, a8))
			var eye := Color(0.12, 0.1, 0.1, a8)
			if glare_t >= 0.0:
				var g := clampf(glare_t / GAZE_WIND, 0.0, 1.0)
				eye = Color(1.0, 0.2 + 0.2 * sin(tm * 30.0), 0.15)
				for q in line:
					var qc: Vector2 = fl.map.center_of(q)
					draw_rect(Rect2(qc - Vector2(C, C) * 0.5, Vector2(C, C)), Color(1.0, 0.15, 0.1, 0.08 + 0.14 * g))
			draw_circle(sk + Vector2(-2.6, -1), 1.9, eye)
			draw_circle(sk + Vector2(2.6, -1), 1.9, eye)
		"collapse", "log", "censer":
			var spec: Array = DROP[kind]
			var R := float(spec[1]) * C
			if not done:
				var k := clampf(age / float(spec[0]), 0.0, 1.0)
				draw_circle(origin, R * (0.4 + 0.6 * k), Color(0, 0, 0, 0.25 + 0.35 * k))
				for i in 6:
					var q := origin + Vector2(sin(i * 2.1) * R * 0.7, -40.0 * (1.0 - k) + cos(i * 1.7) * R * 0.5)
					draw_rect(Rect2(q, Vector2(3, 3)), Color(0.6, 0.55, 0.5, 0.8))
			elif kind == "collapse":
				var a := clampf(zone_t / 2.0, 0.0, 1.0)
				for i in 14:
					var q := origin + Vector2(sin(i * 2.39) , cos(i * 2.39)) * R * fmod(i * 0.37, 1.0)
					draw_circle(q, 3.0 + fmod(i * 1.3, 3.0), Color(0.45, 0.4, 0.35, 0.9 * a))
			elif kind == "censer":
				var a2 := clampf(zone_t / 1.5, 0.0, 1.0)
				for i in 10:
					var q2 := origin + Vector2(sin(i * 2.39), cos(i * 2.39)) * R * fmod(i * 0.41, 1.0)
					draw_circle(q2, 2.5, Color(1.0, 0.5 + 0.3 * sin(tm * 6.0 + i), 0.2, 0.85 * a2))
			else:
				var a3 := clampf(zone_t / 0.8, 0.0, 1.0)
				var side := Vector2(R, 0)
				draw_line(origin - side, origin + side, Color(0.42, 0.3, 0.2, a3), 10.0)
		"fire":
			draw_circle(start + dir * 4.0, 5.0, Color(1.0, 0.4, 0.2, 0.9))
			if age < 0.45:
				draw_line(start, start + dir.rotated(0.45) * reach, Color(1, 0.4, 0.2, 0.5), 1.5)
				draw_line(start, start + dir.rotated(-0.45) * reach, Color(1, 0.4, 0.2, 0.5), 1.5)
			elif age < 2.45:
				var pts := PackedVector2Array([start])
				for i in 9:
					var a4 := -0.45 + 0.9 * i / 8.0
					pts.append(start + dir.rotated(a4) * reach * (0.85 + 0.15 * sin(tm * 20.0 + i)))
				draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.5))
				var pts2 := PackedVector2Array([start])
				for i in 7:
					var a5 := -0.3 + 0.6 * i / 6.0
					pts2.append(start + dir.rotated(a5) * reach * 0.55)
				draw_colored_polygon(pts2, Color(1.0, 0.85, 0.3, 0.55))
		"darts", "bolt":
			for dd in darts:
				if dd["live"]:
					var p2: Vector2 = dd["p"]
					var v2: Vector2 = (dd["v"] as Vector2).normalized()
					draw_line(p2 - v2 * 9.0, p2, Color(0.85, 0.85, 0.8), 2.0)
					draw_circle(p2, 1.8, Color(0.5, 0.9, 0.4) if kind == "darts" else Color.WHITE)
		"crush":
			var k2 := clampf(age / CRUSH_TIME, 0.0, 1.0)
			var col := Color(0.9, 0.25, 0.2, 0.15 + 0.4 * k2) if not done else Color(0.4, 0.35, 0.3, 0.7 * (1.0 - (age - CRUSH_TIME) / 0.5))
			for c in band:
				draw_rect(Rect2(Vector2(c) * C, Vector2(C, C)), col)
		"net":
			var k3 := clampf(age / NET_DELAY, 0.0, 1.0)
			var R2 := C * 0.9
			if not done:
				draw_circle(origin, R2 * k3, Color(0, 0, 0, 0.3))
			else:
				for i in 5:
					var o := -R2 + R2 * 2.0 * i / 4.0
					draw_line(origin + Vector2(o, -R2), origin + Vector2(o, R2), Color(0.75, 0.65, 0.45, 0.8), 1.0)
					draw_line(origin + Vector2(-R2, o), origin + Vector2(R2, o), Color(0.75, 0.65, 0.45, 0.8), 1.0)
		"gas", "fog":
			var spec2: Array = CLOUD[kind]
			var R3 := float(spec2[0]) * C
			var a6 := clampf(age / 0.4, 0.0, 1.0) * clampf((float(spec2[1]) - age) / 1.0, 0.0, 1.0)
			var cc := Color(0.75, 0.6, 0.85) if kind == "gas" else Color(0.8, 0.9, 1.0)
			for i in 9:
				var q3 := origin + Vector2(sin(i * 2.39 + tm * 0.4), cos(i * 2.39 + tm * 0.3)) * R3 * 0.55
				draw_circle(q3, R3 * 0.5, Color(cc.r, cc.g, cc.b, 0.13 * a6))
		"pendulum":
			if not _explored():
				return
			var side2 := Vector2(-dir.y, dir.x)
			var piv := origin + side2 * 0.0
			var bp := _blade()
			var a7 := 0.35 if _off() else 1.0
			draw_line(piv - dir * C * 0.45, piv + dir * C * 0.45, Color(0.3, 0.3, 0.32, 0.6 * a7), 1.0)
			draw_line(bp - dir * C * 0.42, bp + dir * C * 0.42, Color(0.82, 0.82, 0.88, a7), 5.0)
			draw_line(bp - dir * C * 0.42 + side2 * 2.5, bp + dir * C * 0.42 + side2 * 2.5, Color(1, 1, 1, 0.6 * a7), 1.5)
		"flame":
			if not _explored():
				return
			draw_circle(origin, 6.0, Color(0.15, 0.1, 0.08, 0.9))
			if _off():
				return
			var ph := fmod(age, FLAME_CYCLE)
			if ph < 0.7:
				for i in 3:
					draw_circle(origin + Vector2(sin(tm * 9.0 + i * 2.0) * 5.0, -ph * 10.0 - i * 3.0), 1.5, Color(1.0, 0.6, 0.2, ph / 0.7))
			elif ph < 1.9:
				var fl2 := 0.8 + 0.2 * sin(tm * 25.0)
				draw_circle(origin, C * 0.62 * fl2, Color(1.0, 0.45, 0.1, 0.55))
				draw_circle(origin + Vector2(0, -4), C * 0.38 * fl2, Color(1.0, 0.85, 0.35, 0.7))

func _explored() -> bool:
	var c := fl.map.cell_of(origin)
	return fl.map.explored[fl.map.idx(c.x, c.y)] != 0
