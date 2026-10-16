class_name DungeonTime
extends RefCounted
## 迷宮の中の時間。時計は無い世界なので、太陽と月で見せる(Hud)。
## 起きている間はゆっくり、休んでいる間は速く進む。10分ごとにワンダリング・モンスターを振る。
## 夜になったとき起きていると、吐息に呑まれて、どこかの部屋へ放り出される(暗転はしない)。
## 休むと HP と MP が戻る(迷宮では、ほかに自然には戻らない)。6〜8時間で目を覚ますか、中断で終わる。

var main: Node                 # Main
var minutes := float(Balance.DIVE_START_MIN)    # 潜り始めからの通しの分(0時起点。日をまたぐと 1440 を超える)
var resting := false
var rest_end := 0.0            # 目を覚ます時刻(通しの分)
var rest_from := 0.0
var _wander_acc := 0.0

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
	minutes += dm
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
	elif not resting and not was_night and is_night():
		_nightfall()

func _next_dawn() -> float:
	var day0 := floorf(minutes / 1440.0) * 1440.0
	var dawn := day0 + Balance.DAWN_MIN
	return dawn if dawn > minutes else dawn + 1440.0

# ---------- 休息 ----------

## 休み始める。休めないときは理由を返す(休めたら "")
func start_rest() -> String:
	if resting:
		return ""
	if main.leader().down:
		return "休めない"
	var lead_pos: Vector2 = main.leader().position
	for e in main.current.enemies:
		if not e.dead and e.state == "chase" and e.position.distance_to(lead_pos) < 14.0 * Balance.CELL:
			return "敵に追われていて、休めない"
	resting = true
	rest_from = minutes
	rest_end = minutes + 60.0 * Dice.rng.randi_range(int(Balance.REST_HOURS[0]), int(Balance.REST_HOURS[1]))
	for h in main.heroes:
		if not h.down:
			h.sleep_t = 1e9
			h.cmd["move"] = Vector2.ZERO
	return ""

func stop_rest(msg: String, color: Color = Color("e8dcb0")) -> void:
	if not resting:
		return
	resting = false
	for h in main.heroes:
		h.sleep_t = 0.0
	if msg != "":
		main.log_msg(msg, color)

## dm 分ぶん、HP と MP を戻す。7時間でおよそ全快(魔力の泉は MP が 1.5 倍)
func _recover(dm: float) -> void:
	var f := dm / (7.0 * 60.0)
	for h in main.heroes:
		if h.down:
			continue
		var c: Character = h.ch
		c.hp = minf(c.max_hp(), c.hp + c.max_hp() * f)
		c.mp = minf(c.max_mp(), c.mp + c.max_mp() * f * (1.5 if c.has_feat("mana_well") else 1.0))

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
	if fl == null or fl.arena or _alive_wanderers() >= Balance.WANDER_MAX:
		return false
	var p := Balance.REST_WANDER_CHANCE if resting else Balance.WANDER_CHANCE
	if Dice.rng.randf() >= p:
		return false
	var ambush := resting
	return spawn_wanderer(ambush) and ambush

## ワンダリングの群れを一つ出す。寝込みなら近く(奇襲)、起きていれば見えない離れた所から歩いてくる。出せたら true
func spawn_wanderer(ambush: bool) -> bool:
	var fl: FloorInstance = main.current
	var meta: Dictionary = fl.map.data["meta"]
	var party_n := 0
	for h in main.heroes:
		if not h.down:
			party_n += 1
	var level := int(meta.get("party", {}).get("level", 1))
	var enc := EncounterGen.generate(String(meta.get("theme", "generic")), level, 0 if Dice.rng.randf() < 0.6 else 1, maxi(1, party_n))
	if enc.is_empty():
		return false
	var lead: Hero = main.leader()
	var at := _spawn_cell(fl, fl.map.cell_of(lead.position), 4 if ambush else 14, 9 if ambush else 40)
	if at.x < 0:
		return false
	var lines: Array = []
	for g in enc["groups"]:
		lines.append(EncounterGen.mon_line(g))
	var made: Array = fl.spawn_encounter(lines, String(enc["kind"]), fl.map.center_of(at), "うろついている")
	if made.is_empty():
		return false
	fl.wanderers.append(made[0].enc_id)
	if ambush:
		stop_rest("")
		for h in main.heroes:
			if not h.down:
				h.sleep_t = Balance.SURPRISE_TIME
		main.log_msg("寝込みを襲われた!", Color("ff6a5a"))
	else:
		main.log_msg(["どこかで、足音がした。", "遠くで、何かがうごめく気配がする。", "風向きが変わった。何かが近づいてくる。"][Dice.rng.randi_range(0, 2)], Color(0.85, 0.75, 0.7))
	return true

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

## 起きたまま夜を迎えた。吐息に呑まれ、夜明けにどこかの部屋で目を覚ます(回復はしない)
func _nightfall() -> void:
	var fl: FloorInstance = main.current
	var m := fl.map
	var here := m.room_at[m.idx(m.cell_of(main.leader().position).x, m.cell_of(main.leader().position).y)]
	var rooms: Array = []
	for r in m.rooms:
		var rid := int(r["id"])
		if rid == here or not m.room_cells.has(rid) or (m.room_cells[rid] as Array).is_empty():
			continue
		var occupied := false
		for e in fl.enemies:
			var ec := m.cell_of(e.position)
			if not e.dead and m.in_bounds(ec.x, ec.y) and m.room_at[m.idx(ec.x, ec.y)] == rid:
				occupied = true
				break
		if not occupied:
			rooms.append(rid)
	main.log_msg("日が落ちた。吐息が満ちて、意識が遠のく…", Color("b8a8e8"))
	if rooms.is_empty():
		return
	var cells: Array = m.room_cells[rooms[Dice.rng.randi_range(0, rooms.size() - 1)]]
	var c: int = cells[cells.size() / 2]
	main.place_party(m.center_of(Vector2i(c % m.w, c / m.w)))
	minutes = _next_dawn()
	main.log_msg("気がつくと、見知らぬ部屋で朝を迎えていた。", Color("e8dcb0"))
