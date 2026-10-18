class_name DungeonTime
extends RefCounted
## 迷宮の中の時間。時計は無い世界なので、太陽と月で見せる(Hud)。
## 起きている間はゆっくり、休んでいる間は速く進む。10分ごとにワンダリング・モンスターを振る。
## 夜になったとき起きていると、吐息に呑まれて、どこかの部屋へ放り出される(暗転はしない)。
## 吐く夜(層の meta.exhale)は違う。日が落ちると迷宮が魔物を大量に吐き出し、夜明けまで階段が塞がる(呑まれはしない)。
## 休むと HP と MP が戻る(迷宮では、ほかに自然には戻らない)。6〜8時間で目を覚ますか、中断で終わる。
## 満腹度も、ここで減らす(起きていると16時間で空。休んでいると3分の1の速さ)。空腹だと、その人の頭上で腹が鳴る。

## 日没の鐘(設計 §11.5)。街の鐘が、迷宮の中でも遠く七つ聞こえる。画面の外の出来事なのでログだけ
const BELL := "遠くで、街の鐘が七つ鳴った。日が落ちる。"

var main: Node                 # Main
var minutes := float(Balance.DIVE_START_MIN)    # 潜り始めからの通しの分(0時起点。日をまたぐと 1440 を超える)
var resting := false
var rest_end := 0.0            # 目を覚ます時刻(通しの分)
var rest_from := 0.0
var _wander_acc := 0.0
var _queue_t := 0.0

func _init(m: Node) -> void:
	main = m

## その日の中の時刻(0〜1439)
func clock() -> float:
	return fmod(minutes, 1440.0)

func is_night() -> bool:
	var c := clock()
	return c >= Balance.NIGHT_MIN or c < Balance.DAWN_MIN

## 「朝」「昼」「夕方」「夜」。解像度は低めでよい
func phase_name() -> String:
	var c := clock()
	if is_night():
		return "夜"
	if c < 10 * 60:
		return "朝"
	if c < 16 * 60:
		return "昼"
	return "夕方"

func update(delta: float) -> void:
	var rate := Balance.REST_RATE if resting else Balance.CLOCK_RATE
	var was_night := is_night()
	var dm := rate * delta
	if resting:
		dm = minf(dm, rest_end - minutes)
		_recover(dm)
	_digest(dm, delta)
	minutes += dm
	_drain_queue(delta)
	var fl: FloorInstance = main.current
	if fl != null:
		var hot := exhaling() and PhosFlow.hot_floor(fl)      # 竜の気配: 吐く夜の夜の間、縦穴の縁が熱い(第7層から下)
		if hot != fl.hot:
			fl.hot = hot
			fl.queue_redraw()
		if hot and not resting:
			PhosFlow.heat(main, fl, delta)
	_wander_acc += dm
	while _wander_acc >= Balance.WANDER_EVERY:
		_wander_acc -= Balance.WANDER_EVERY
		if _roll_wander():
			return
	if resting and minutes >= rest_end - 0.001:
		if is_night():
			# 夜の間に目を覚ましても、動けば吐息に呑まれる。夜明けまで休み続ける
			rest_end = _next_dawn()
		else:
			stop_rest("目を覚ました。%d時間ほど休んだ。" % int(round((minutes - rest_from) / 60.0)))
	elif not was_night and is_night():
		if exhaling():
			_exhale()
		elif not resting:
			_nightfall()
		else:
			main.log_msg(BELL, Color("d8c8a0"))
	elif was_night and not is_night() and main.current != null and main.current.exhale:
		main.log_msg("夜が明けた。階段を塞いでいた吐息が、引いていく。", Color("e8dcb0"))

func _next_dawn() -> float:
	var day0 := floorf(minutes / 1440.0) * 1440.0
	var dawn := day0 + Balance.DAWN_MIN
	return dawn if dawn > minutes else dawn + 1440.0

# ---------- 休息 ----------

## 休み始める。休めないときは理由を返す(休めたら "")
func start_rest() -> String:
	if resting:
		return ""
	var why := chased_reason()
	if why != "":
		return why
	resting = true
	rest_from = minutes
	rest_end = minutes + 60.0 * Dice.rng.randi_range(int(Balance.REST_HOURS[0]), int(Balance.REST_HOURS[1]))
	for h in main.heroes:
		if not h.down:
			h.sleep_t = 1e9
			h.cmd["move"] = Vector2.ZERO
	return ""

## 休んだり料理したりできない理由(できれば "")
func chased_reason() -> String:
	if main.leader().down:
		return "休めない"
	var lead_pos: Vector2 = main.leader().position
	for e in main.current.enemies:
		if not e.dead and e.state == "chase" and e.position.distance_to(lead_pos) < 14.0 * Balance.CELL:
			return "敵に追われていて、休めない"
	return ""

func stop_rest(msg: String, color: Color = Color("e8dcb0")) -> void:
	if not resting:
		return
	resting = false
	for h in main.heroes:
		h.sleep_t = 0.0
	if msg != "":
		main.log_msg(msg, color)

## dm 分ぶん、HP と MP を戻す。7時間でおよそ全快(魔力の泉は MP が 1.5 倍。寝つきの料理は 1.3 倍)
func _recover(dm: float) -> void:
	var f := dm / (7.0 * 60.0)
	for h in main.heroes:
		if h.down:
			continue
		var c: Character = h.ch
		var sl := maxf(1.0, c.meal_v("sleep"))
		c.hp = minf(c.max_hp(), c.hp + c.max_hp() * f * sl)
		c.mp = minf(c.max_mp(), c.mp + c.max_mp() * f * sl * (1.5 if c.has_feat("mana_well") else 1.0))

# ---------- 満腹 ----------

## dm 分ぶん、満腹度を減らす。息吹の料理は HP を少しずつ戻す。空腹なら腹が鳴る(実時間の delta で間引く)
func _digest(dm: float, delta: float) -> void:
	for h in main.heroes:
		if h.down:
			continue
		var c: Character = h.ch
		var rate := Cooking.BELLY_PER_MIN * (Cooking.BELLY_REST_MULT if resting else 1.0)
		var slow := c.meal_v("belly")
		if slow > 0.0:
			rate *= slow
		c.belly = maxf(0.0, c.belly - rate * dm)
		if not resting:
			var rg := c.meal_v("regen")
			if rg > 0.0:
				c.hp = minf(c.max_hp(), c.hp + c.max_hp() * rg * dm)
		if not c.meal.is_empty() and not c.meal_active():
			c.meal = {}
			c.clamp_resources()       # 料理の効き目が切れて、最大HP・MPが下がったとき
		if resting or h.sleep_t > 0.0 or c.hunger() == "ok" or c.hunger() == "full":
			continue
		h.growl_t -= delta
		if h.growl_t <= 0.0:
			var starving := c.hunger() == "starving"
			h.growl_t = Dice.rng.randf_range(12.0, 20.0) if starving else Dice.rng.randf_range(28.0, 45.0)
			Sfx.cue(main.current, h.position, "growl_hard" if starving else "growl")

# ---------- ワンダリング・モンスター ----------

func _alive_wanderers() -> int:
	var n := 0
	for eid in main.current.wanderers:
		if main.current.group_dead_fraction(eid) < 1.0:
			n += 1
	return n

## 寝込みを襲われたら true(休息はそこで終わる)
func _roll_wander() -> bool:
	var fl: FloorInstance = main.current
	if fl == null or fl.arena or _alive_wanderers() >= (Balance.EXHALE_WANDER_MAX if exhaling() else Balance.WANDER_MAX):
		return false
	var p := Balance.REST_WANDER_CHANCE if resting else Balance.WANDER_CHANCE
	if exhaling():
		p *= Balance.EXHALE_WANDER_MULT
	if Dice.rng.randf() >= p:
		return false
	var ambush := resting
	# 吐く夜の間に出る群れは、仲間のいる所を目指して歩いてくる
	return spawn_wanderer(ambush, false, exhaling()) and ambush

## ワンダリングの群れを一つ出す。寝込みなら近く(奇襲。すぐ襲ってくる)。起きていれば、見えない離れた所に出て、
## 部屋から部屋へ歩き回る(Spawner)。hunt なら、仲間のいる所を目指して歩く(吐く夜)。出せたら true
func spawn_wanderer(ambush: bool, quiet: bool = false, hunt: bool = false) -> bool:
	var fl: FloorInstance = main.current
	var meta: Dictionary = fl.map.data["meta"]
	var party_n := 0
	for h in main.heroes:
		if not h.down:
			party_n += 1
	var level := int(meta.get("party", {}).get("level", 1))
	var theme := String(meta.get("theme", "generic"))
	var activity := "うろついている"
	# 燐の流れ: 吐く夜のワンダリングには、一つ下の層の魔物が混じる(PhosFlow)
	if exhaling() and Dice.rng.randf() < PhosFlow.BELOW_P:
		var b := PhosFlow.below(fl, level)
		if not b.is_empty():
			theme = String(b["theme"])
			level = int(b["level"])
			activity = "下の層から上がってきた"
	var enc := EncounterGen.generate(theme, level, 0 if Dice.rng.randf() < 0.6 else 1, maxi(1, party_n))
	if enc.is_empty():
		return false
	var lines: Array = []
	for g in enc["groups"]:
		var line := EncounterGen.mon_line(g)
		if activity != "うろついている":
			line["below"] = true          # 一つ下の層から上がってきた(燐の流れ)
		lines.append(line)
	var made := _place_group(lines, String(enc["kind"]), activity, ambush)
	if made.is_empty():
		return false
	fl.wanderers.append(made[0].enc_id)
	if hunt:
		fl.spawner.hunt[made[0].enc_id] = true
	if ambush:
		stop_rest("")
		for h in main.heroes:
			if not h.down:
				h.sleep_t = Balance.SURPRISE_TIME
		main.log_msg("寝込みを襲われた!", Color("ff6a5a"))
	elif not quiet:
		main.log_msg(["どこかで、足音がした。", "遠くで、何かがうごめく気配がする。", "風向きが変わった。何かが近づいてくる。"][Dice.rng.randi_range(0, 2)], Color(0.85, 0.75, 0.7))
	return true

## 決まった魔物の群れを、見えない離れた所に、歩き回るワンダリングとして出す(燐の流れで降りてきた骨亡者など)。出せたら true
func spawn_group(lines: Array, kind: String, activity: String) -> bool:
	if lines.is_empty() or main.current == null or main.current.arena:
		return false
	var made := _place_group(lines, kind, activity, false)
	if made.is_empty():
		return false
	main.current.wanderers.append(made[0].enc_id)
	return true

## 群れを置く。寝込みなら近く(すぐ襲ってくる)、そうでなければ見えない離れた所で歩き回る。置いた魔物を返す
func _place_group(lines: Array, kind: String, activity: String, ambush: bool) -> Array:
	var fl: FloorInstance = main.current
	var lead: Hero = main.leader()
	var at := _spawn_cell(fl, fl.map.cell_of(lead.position), 4 if ambush else 14, 9 if ambush else 40)
	if at.x < 0:
		return []
	return fl.spawn_encounter(lines, kind, fl.map.center_of(at), activity, "chase" if ambush else "wander")

## 仲間からの道のり(マス)が lo〜hi で、いま見えていない床を選ぶ
func _spawn_cell(fl: FloorInstance, from: Vector2i, lo: int, hi: int) -> Vector2i:
	var m := fl.map
	var flow := m.compute_flow(from.x, from.y, hi + 2)
	var cands: Array = []
	for i in flow.size():
		var d := flow[i]
		if d < lo or d > hi:
			continue
		if lo > 6 and m.visible[i] == 1:
			continue
		cands.append(i)
	if cands.is_empty():
		return Vector2i(-1, -1)
	var k: int = cands[Dice.rng.randi_range(0, cands.size() - 1)]
	return Vector2i(k % m.w, k / m.w)

# ---------- 夜 ----------

## いま吐く夜の夜の間か(魔物が湧き、階段が塞がっている)
func exhaling() -> bool:
	var fl: FloorInstance = main.current
	return fl != null and not fl.arena and fl.exhale and is_night()

## 階段が使えないか(吐く夜の夜の間)
func stairs_sealed() -> bool:
	return exhaling()

## 吐く夜に日が落ちた。迷宮が魔物を吐き出し、階段が塞がる。休んでいても起きていても同じ(呑まれはしない)
func _exhale() -> void:
	var fl: FloorInstance = main.current
	# いっせいに出すと重いので、順番待ちに並べて、起きている魔物の上限に空きがあるときに一組ずつ出す
	fl.spawner.queued += Balance.EXHALE_BURST
	_queue_t = 0.0
	Sfx.cue(fl, main.leader().position, "exhale")
	main.log_msg(BELL, Color("d8c8a0"))
	main.log_msg("日が落ちた。今夜は吐く夜だ。迷宮が、魔物を吐き出した。", Color("ff8a6a"))
	main.log_msg("階段は吐息に塞がれた。夜明けまで、この層から出られない。(%d組が湧き出してくる)" % Balance.EXHALE_BURST, Color("ff9a8a"))
	if not PhosFlow.layer_info(fl.layer_no + 1).is_empty():
		main.log_msg("吐息に乗って、下の層の魔物も上がってくる。", Color("ffb08a"))

## 順番待ちの群れ(吐く夜)を、上限に空きがあれば、EXHALE_QUEUE_EVERY 秒に一組ずつ出す。仲間のいる所を目指して歩く
func _drain_queue(delta: float) -> void:
	var fl: FloorInstance = main.current
	if fl == null or fl.spawner.queued <= 0:
		return
	_queue_t -= delta
	if _queue_t > 0.0 or not fl.spawner.has_room():
		return
	_queue_t = Balance.EXHALE_QUEUE_EVERY
	fl.spawner.queued -= 1
	spawn_wanderer(false, true, true)

## 起きたまま夜を迎えた。吐息に呑まれ、夜明けにどこかの部屋で目を覚ます(回復はしない)
func _nightfall() -> void:
	var fl: FloorInstance = main.current
	var m := fl.map
	var pc := m.cell_of(main.leader().position)
	main.log_msg(BELL, Color("d8c8a0"))
	main.log_msg("日が落ちた。吐息が満ちて、意識が遠のく…", Color("b8a8e8"))
	var at: Vector2 = main.random_room_pos(fl, m.room_at[m.idx(pc.x, pc.y)])
	if at.x >= INF:
		return
	main.place_party(at)
	minutes = _next_dawn()
	main.log_msg("気がつくと、見知らぬ部屋で朝を迎えていた。", Color("e8dcb0"))
