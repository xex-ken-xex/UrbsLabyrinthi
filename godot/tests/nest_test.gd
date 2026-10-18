extends SceneTree
## 迷宮の中身 その2(設計 §11.1 / §11.4):  godot --headless --path godot -s res://tests/nest_test.gd
## 巣は一画の奥に多い、巣の手前の見張り(気づくと巣へ走って ピィーッ! で群れを起こす)、各階の主の間(倒すとまわりの巣が散る)、
## 罠の場所の理由(落とし穴は縦穴のそば、など。階段と縄梯子のそばには置かない)。

var fails := 0
var main: Node
var logs: Array = []

func check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _initialize() -> void:
	call_deferred("_run")

func _step(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_test_data()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	await _step(5)
	for h in main.heroes:
		h.iframes = 1e9
	Spawner.off = true      # 魔物はこのテストで出す(遠くでも眠らせない)
	await _test_sentry()
	await _test_master()
	Spawner.off = false
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _near_tile(m: FloorMap, c: Vector2i, tiles: Array, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if m.in_bounds(c.x + dx, c.y + dy) and m.tiles[m.idx(c.x + dx, c.y + dy)] in tiles:
				return true
	return false

func _test_data() -> void:
	print("[書き出しの中身]")
	var sentries := 0
	var on_corr := true
	var masters := 0
	var master_floors := 0
	var named := 0
	var master_role := true
	var calm := true
	var pits := 0
	var pits_rim := 0
	var deep_sum := [0.0, 0.0]      # 巣のある部屋 / 巣のない部屋の、骨組みからの深さ(合計)
	var deep_n := [0, 0]
	for depth in [3, 7, 12, 19, 27]:
		for n in 3:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			var m := f.map
			var d: Dictionary = m.data
			var floor_masters := 0
			for e in d["encounters"]:
				for t in e["tokens"]:
					if t.get("sentry", false):
						sentries += 1
						var c := Vector2i(int(t["x"]), int(t["y"]))
						on_corr = on_corr and m.tiles[m.idx(c.x, c.y)] == FloorMap.CORR and m.room_at[m.idx(c.x, c.y)] < 0
				if e.get("master", false):
					floor_masters += 1
					for mm in e["monsters"]:
						if mm.get("world_name", "") != "":
							named += 1
							break
					master_role = master_role and String(m.room_by_id[int(e["roomId"])].get("role", "")) == "master"
			masters += floor_masters
			if floor_masters == 1:
				master_floors += 1
			var stops: Array = [f.up_cell, f.down_cell] + f.ropes
			for t in f.traps:
				var c := Vector2i(int(t["x"]), int(t["y"]))
				for s in stops:
					if s.x >= 0 and _cheb(c, s) <= 2:
						calm = false
				if String(t.get("fx", "")) == "pit":
					pits += 1
					if _near_tile(m, c, [FloorMap.VOID], 3):
						pits_rim += 1
			f.free()
	check(sentries > 0, "巣の手前に見張りがいる (%d体)" % sentries)
	check(on_corr, "見張りは部屋の外の通路に立つ")
	check(master_floors == 15, "どの階にも主の間が一つ (%d/15)" % master_floors)
	check(named == masters and master_role, "主はその層の看板の魔物(呼び名つき)で、部屋は「主の間」 (%d/%d)" % [named, masters])
	check(calm, "階段と縄梯子の2マス以内に罠は無い")
	# 落とし穴の場所は、数が少ないので全部の階で数える(場所に理由をつける前は 31%)
	pits = 0
	pits_rim = 0
	for depth in range(1, 30):
		for n in [0, 3, 6]:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			for t in f.traps:
				if String(t.get("fx", "")) == "pit":
					pits += 1
					if _near_tile(f.map, Vector2i(int(t["x"]), int(t["y"])), [FloorMap.VOID], 3):
						pits_rim += 1
			f.free()
	check(pits > 0 and pits_rim >= pits * 0.45, "落とし穴の半分ほどは縦穴のそば (%d/%d)" % [pits_rim, pits])

## 見張りが気づくと、群れを起こさずに巣へ走り、着いたら ピィーッ! で群れを起こす。走っている間に倒せば、巣は起きない
func _test_sentry() -> void:
	print("[見張り]")
	var fl: FloorInstance = null
	var enc: Dictionary = {}
	for depth in range(1, 6):
		main.enter_floor(depth, "up")
		await _step(2)
		fl = main.current
		for e in fl.map.data["encounters"]:
			if (e["tokens"] as Array).any(func(t): return t.get("sentry", false)) and String(e.get("kind", "")) != "mindless":
				enc = e
				break
		if not enc.is_empty():
			break
	check(not enc.is_empty(), "見張りのいる巣がある")
	if enc.is_empty():
		return
	logs.clear()
	fl.message.connect(func(t: String, _k: String): logs.append(t))
	var eid := int(enc["id"])
	# 仲間は遠くに置く(巣の群れが自分で気づかないように)
	var rc: Array = fl.map.room_by_id[int(enc["roomId"])]["center"]
	var nest := Vector2i(int(rc[0]), int(rc[1]))
	var far := fl.map.center_of(fl.up_cell)
	for rid in fl.map.room_cells:
		var k: int = fl.map.room_cells[rid][0]
		var c := Vector2i(k % fl.map.w, k / fl.map.w)
		if _cheb(c, nest) > 40:
			far = fl.map.center_of(c)
			break
	main.place_party(far)
	await _step(2)
	fl.spawner.pending.erase(eid)
	fl.spawn_tokens(enc)
	var mine: Array = fl.enemies.filter(func(en): return en.enc_id == eid)
	var sentry: Enemy = null
	for en in mine:
		if en.sentry:
			sentry = en
	check(sentry != null and sentry.nest_cell == nest and not sentry.asleep, "見張りは巣の部屋を覚え、眠らずに立っている")
	if sentry == null:
		return
	sentry._start_warn()
	await _step(3)
	var others := mine.filter(func(en): return en != sentry and not en.sentry)
	check(sentry.state == "warn", "気づいた見張りは、巣へ走る")
	check(others.all(func(en): return en.state == "idle"), "走っている間は、巣の群れはまだ起きていない")
	var p0 := sentry.position
	var woke := false
	for i in 600:
		await physics_frame
		if sentry.state != "warn":
			woke = true
			break
	check(woke and sentry.position.distance_to(p0) > 8.0, "見張りが巣まで走った (%.0f px)" % sentry.position.distance_to(p0))
	check(others.all(func(en): return not is_instance_valid(en) or en.state == "chase"), "見張りが着くと、巣の群れが起きる")
	var cues := fl.get_children().filter(func(n): return n is Sfx and String(n.text) == "ピィーッ!")
	check(cues.size() == 1, "擬音 ピィーッ! が一つ")
	check(logs.any(func(t): return t.contains("笛") or t.contains("見張り")), "ログで知らせる (%s)" % [logs])
	# もう一度: 走っている見張りを倒すと、巣は起きない
	for en in fl.enemies.duplicate():
		if en.enc_id == eid:
			en.queue_free()
			fl.enemies.erase(en)
	await process_frame
	fl.spawn_tokens(enc)
	mine = fl.enemies.filter(func(en): return en.enc_id == eid)
	for en in mine:
		if en.sentry:
			sentry = en
	sentry._start_warn()
	await _step(2)
	sentry._die()
	await _step(30)
	check(mine.filter(func(en): return is_instance_valid(en) and not en.sentry).all(func(en): return en.state == "idle"), "走る見張りを倒せば、巣は起きない")
	# 殴られた見張りも、群れを起こさずに巣へ走る
	for en in fl.enemies.duplicate():
		if en.enc_id == eid:
			en.queue_free()
			fl.enemies.erase(en)
	await process_frame
	fl.spawn_tokens(enc)
	mine = fl.enemies.filter(func(en): return en.enc_id == eid)
	for en in mine:
		if en.sentry:
			sentry = en
	sentry.max_hp = 999
	sentry.hp = 999.0
	sentry.take_damage(1.0, Vector2.RIGHT, null)
	await _step(2)
	check(sentry.state == "warn" and mine.filter(func(en): return not en.sentry).all(func(en): return en.state == "idle"), "殴られた見張りも、まず巣へ走る")
	for en in fl.enemies.duplicate():
		if en.enc_id == eid:
			en.queue_free()
			fl.enemies.erase(en)

## 主の間の主を倒すと、まわりのまだ出ていない巣が散る(遠くも少し)
func _test_master() -> void:
	print("[主の間]")
	main.enter_floor(7, "up")
	await _step(2)
	var fl: FloorInstance = main.current
	check(fl.master_enc >= 0, "主の間の主がいる")
	if fl.master_enc < 0:
		return
	logs.clear()
	fl.message.connect(func(t: String, _k: String): logs.append(t))
	var enc: Dictionary = fl.spawner.pending[fl.master_enc]
	var mc := fl.room_center(int(enc["roomId"]))
	var same: Array = []
	for eid in fl.spawner.pending:
		var e: Dictionary = fl.spawner.pending[eid]
		var rid := int(e.get("roomId", -1))
		if eid != fl.master_enc and rid >= 0 and not e.get("lair", false) and Vector2(fl.room_center(rid) - mc).length() <= FloorInstance.MASTER_REACH:
			same.append(eid)
	var total0: int = fl.spawner.pending.size()
	fl.spawner.pending.erase(fl.master_enc)
	fl.spawn_tokens(enc)
	var bosses: Array = fl.enemies.filter(func(en): return en.enc_id == int(enc["id"]))
	var m0 := int(Journal.stat(main.gs, "master"))
	for en in bosses:
		en._die()
	await _step(2)
	check(not same.is_empty() and same.all(func(eid): return not fl.spawner.pending.has(eid)), "主のまわりの巣は散った (%d組)" % same.size())
	check(fl.spawner.pending.size() < total0 - 1, "控えの巣が減った (%d → %d)" % [total0 - 1, fl.spawner.pending.size()])
	check(logs.any(func(t): return t.begins_with("主が倒れた")), "ログで知らせる (%s)" % [logs])
	check(int(Journal.stat(main.gs, "master")) == m0 + 1, "倒した主を数える")
	check(fl.master_enc == -1, "二度は散らない")
