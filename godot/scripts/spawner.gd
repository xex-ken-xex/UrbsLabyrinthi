class_name Spawner
extends RefCounted
## 魔物を、近づいたときに出し、遠くでは眠らせる。広い層で魔物が多くても重くならないように。
## - 層の遭遇は、最初は出さずに控えておく。仲間が SPAWN_CELLS マスまで近づくか、その場所が見えたら出す。
## - 仲間から SLEEP_CELLS マスより遠い魔物は眠らせる(動きも描画も止める)。WAKE_CELLS マスまで近づいたら起こす。
## - 起きている魔物の数には上限(cap)がある。上限は FPS を見て上げ下げする。超えたら、遠いものから眠らせる。
##   近い魔物(KEEP_CELLS マス以内)と、見えている魔物は、上限を超えても眠らせない。
## - ワンダリング・モンスターは眠らせない。部屋から部屋へ歩き回る(state "wander")。
##   遠くでは軽い歩き方(light。絵も押し合いも無しで、位置だけを TICK ごとに道なりに進める)で、層を歩き続ける。
## - 吐く夜にいっせいに湧く群れは、順番待ち(queued)に並べて、上限に空きがあるときに一組ずつ出す(DungeonTime)。

const SPAWN_CELLS := 24.0
const WAKE_CELLS := 24.0
const SLEEP_CELLS := 30.0
const KEEP_CELLS := 14.0
const TICK := 0.25
const WANDER_SPEED := 0.5      # 歩き回るときの速さ(追うときの何倍か)
## 起きている魔物の上限。FPS が落ちたら下げ、余裕があれば上げる
const CAP_MIN := 40
const CAP_MAX := 160
const CAP_START := 100
const FPS_LOW := 45.0
const FPS_OK := 57.0
static var cap := CAP_START
static var off := false        # 測る道具やテストで、前のやり方(全部出して、眠らせない)と比べるとき
static var _fps_t := 0.0

var fl: FloorInstance
var pending := {}              # 遭遇の id → 書き出しの遭遇(まだ出していない)
var queued := 0                # 順番待ちのワンダリングの群れ(吐く夜)
var hunt := {}                 # 仲間の居場所を目指して歩くワンダリングの遭遇 id(吐く夜)
var goals := {}                # ワンダリングの遭遇 id → {cell, flow, wait}
var awake := 0                 # 起きている(押し合いと描画をしている)魔物の数
var light_n := 0               # 軽い歩き方をしているワンダリングの数
var asleep_n := 0              # 眠らせている魔物の数
var _t := TICK

func _init(f: FloorInstance) -> void:
	fl = f

## FPS を見て上限を上げ下げする(層をまたいで共通。毎コマ呼ばれる)
static func watch_fps(delta: float) -> void:
	_fps_t += delta
	if _fps_t < 1.0:
		return
	_fps_t = 0.0
	var fps := Engine.get_frames_per_second()
	if fps < FPS_LOW:
		cap = maxi(CAP_MIN, cap - 10)
	elif fps >= FPS_OK:
		cap = mini(CAP_MAX, cap + 5)

## 次のコマで、すぐに出す・眠らせるを決め直す(仲間を置き直したとき。階段で着いた所の魔物が、遅れて湧かないように)
func refresh() -> void:
	_t = TICK

## 上限に空きがあるか(順番待ちの群れを出してよいか)
func has_room() -> bool:
	return awake < cap

func tick(delta: float) -> void:
	for eid in goals:
		var g: Dictionary = goals[eid]
		g["wait"] = maxf(0.0, float(g["wait"]) - delta)
	_t += delta
	if _t < TICK or fl.arena or off:
		return
	var dt := _t
	_t = 0.0
	var hs: Array = []
	for h in fl.heroes:
		if h.is_alive():
			hs.append(h.position)
	if hs.is_empty():
		for h in fl.heroes:
			hs.append(h.position)
	if hs.is_empty():
		return
	for eid in pending.keys():
		if _enc_close(pending[eid], hs):
			spawn_pending(eid)
	_balance(hs)
	for en in fl.enemies:
		if en.light and not en.dead:
			_light_step(en, dt)

## 遭遇を出すか: 近い、見えている、または上限に空きがあって出す距離まで来た
func _enc_close(e: Dictionary, hs: Array) -> bool:
	var m := fl.map
	for t in e["tokens"]:
		var c := Vector2i(int(t["x"]), int(t["y"]))
		var d := _cells_to(m.center_of(c), hs)
		if d <= KEEP_CELLS or m.visible[m.idx(c.x, c.y)] == 1:
			return true
		if d <= SPAWN_CELLS and awake < cap:
			return true
	return false

func spawn_pending(eid: int) -> void:
	var e: Dictionary = pending[eid]
	pending.erase(eid)
	fl.spawn_tokens(e)

## まだ出していない遭遇を、全部出す(測る道具やテスト用)
func spawn_all() -> void:
	for eid in pending.keys():
		spawn_pending(eid)

## まだ出していない魔物がいる部屋(夜に呑まれて放り出される先を選ぶとき、避ける)
func pending_rooms() -> Dictionary:
	var out := {}
	var m := fl.map
	for eid in pending:
		for t in pending[eid]["tokens"]:
			var r := m.room_at[m.idx(int(t["x"]), int(t["y"]))]
			if r >= 0:
				out[r] = true
	return out

func _cells_to(p: Vector2, hs: Array) -> float:
	var best := INF
	for q in hs:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best) / Balance.CELL

## 誰を起こし、誰を眠らせるかを決める
func _balance(hs: Array) -> void:
	var m := fl.map
	var wset := {}
	for eid in fl.wanderers:
		wset[eid] = true
	var others: Array = []
	awake = 0
	light_n = 0
	asleep_n = 0
	for en in fl.enemies:
		if en.dead:
			continue
		var d := _cells_to(en.position, hs)
		var c := m.cell_of(en.position)
		var seen := m.in_bounds(c.x, c.y) and m.visible[m.idx(c.x, c.y)] == 1
		if wset.has(en.enc_id):
			# 見失うほど離れたら、追うのをやめて、また歩き回る
			if en.state == "chase" and d > SLEEP_CELLS:
				en.state = "wander"
				en.target = null
			var go_light: bool = not seen and d > (WAKE_CELLS if en.light else SLEEP_CELLS)
			en.set_light(go_light)
			if go_light:
				light_n += 1
			else:
				awake += 1
			continue
		others.append([d, en, seen])
	others.sort_custom(func(a, b): return a[0] < b[0])
	for o in others:
		var d: float = o[0]
		var en: Enemy = o[1]
		var keep: bool = d <= KEEP_CELLS or o[2]
		var want := keep or (awake < cap and d <= (WAKE_CELLS if en.dormant else SLEEP_CELLS))
		en.set_dormant(not want)
		if want:
			awake += 1
		else:
			asleep_n += 1

# ---------- ワンダリング・モンスターが歩き回る ----------

## 群れの次の行き先を決める。吐く夜の群れは、仲間のいる所を目指す
func _new_goal(eid: int) -> Dictionary:
	var m := fl.map
	var cell := Vector2i(-1, -1)
	if hunt.has(eid) and not fl.heroes.is_empty():
		cell = m.cell_of((fl.leader if fl.leader != null else fl.heroes[0]).position)
	else:
		var rids: Array = m.room_cells.keys()
		for tries in 6:
			if rids.is_empty():
				break
			var cells: Array = m.room_cells[rids[Dice.rng.randi_range(0, rids.size() - 1)]]
			if cells.is_empty():
				continue
			var k: int = cells[Dice.rng.randi_range(0, cells.size() - 1)]
			if m.monster_passable(k % m.w, k / m.w):
				cell = Vector2i(k % m.w, k / m.w)
				break
	var g := {"cell": cell, "flow": PackedInt32Array(), "wait": 0.0}
	if cell.x >= 0:
		g["flow"] = m.compute_flow(cell.x, cell.y, maxi(m.w, m.h) * 3)
	goals[eid] = g
	return g

## 歩き回る魔物の、次に向かう点。着いた・道が無いときは、少し立ち止まって次の行き先を決める(INF を返す)
func wander_next(en: Enemy) -> Vector2:
	var g: Dictionary = goals.get(en.enc_id, {})
	if g.is_empty():
		g = _new_goal(en.enc_id)
	if float(g["wait"]) > 0.0:
		return Vector2(INF, INF)
	var m := fl.map
	var mc := m.cell_of(en.position)
	var gc: Vector2i = g["cell"]
	var nxt := m.flow_step(g["flow"], mc, true) if gc.x >= 0 else Vector2i(-1, -1)
	if nxt.x < 0 or maxi(absi(mc.x - gc.x), absi(mc.y - gc.y)) <= 1:
		g = _new_goal(en.enc_id)
		g["wait"] = 0.5 if hunt.has(en.enc_id) else Dice.rng.randf_range(2.0, 6.0)
		return Vector2(INF, INF)
	return m.center_of(nxt)

## 軽い歩き方: 道なりに、位置だけを進める(壁や押し合いは見ない。扉は開けて通る)
func _light_step(en: Enemy, dt: float) -> void:
	var left := en.move_speed() * WANDER_SPEED * dt
	for i in 4:
		if left <= 0.0:
			break
		var to := wander_next(en)
		if to.x >= INF:
			break
		var dv := to - en.position
		var l := dv.length()
		if l <= left:
			en.position = to
			left -= l
			en.open_doors()
		else:
			en.position += dv / l * left
			left = 0.0
