extends SceneTree
## 魔物の出し方(Spawner):  godot --headless --path godot -s res://tests/spawner_test.gd
## 層の遭遇は近づくまで出さない、遠い魔物は眠らせる、起きている魔物の上限、
## ワンダリング・モンスターは眠らずに歩き回り続ける(遠くでは軽い歩き方)、吐く夜の順番待ち、記録と再開、FPS の表示の設定。

var fails := 0
var main: Node

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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
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
	await _test_pending()
	await _test_sleep()
	await _test_cap()
	await _test_wander()
	await _test_queue()
	_test_save()
	_test_setting()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _far_from_all(fl: FloorInstance, cells: float) -> Vector2:
	## どの遭遇・魔物からも cells マス以上離れた、部屋の床(見つからなければ INF)
	var m := fl.map
	for rid in m.room_cells:
		for k in m.room_cells[rid]:
			var c := Vector2i(k % m.w, k / m.w)
			if not m.monster_passable(c.x, c.y):
				continue
			var p := m.center_of(c)
			var ok := true
			for eid in fl.spawner.pending:
				for t in fl.spawner.pending[eid]["tokens"]:
					if p.distance_to(m.center_of(Vector2i(int(t["x"]), int(t["y"])))) < cells * Balance.CELL:
						ok = false
			for e in fl.enemies:
				if p.distance_to(e.position) < cells * Balance.CELL:
					ok = false
			if ok:
				return p
	return Vector2(INF, INF)

func _test_pending() -> void:
	print("層の遭遇は、近づくまで出さない")
	var fl: FloorInstance = main.current
	var n_enc: int = (fl.map.data["encounters"] as Array).size()
	var tokens := 0
	for e in fl.map.data["encounters"]:
		tokens += (e["tokens"] as Array).size()
	check(fl.spawner.pending.size() + _spawned_encounters(fl) == n_enc, "遭遇は全部、控えか出したかのどちらか (%d)" % n_enc)
	check(fl.enemies.size() < tokens, "入った直後は、全部は出ていない (%d / %d体)" % [fl.enemies.size(), tokens])
	var total := 0
	for eid in fl.enc_total:
		total += int(fl.enc_total[eid])
	check(total == tokens, "出していない遭遇も、数は数えてある (%d)" % total)
	# 控えている遭遇のそばへ行くと、出てくる
	var eid: int = fl.spawner.pending.keys()[0]
	var t0: Dictionary = fl.spawner.pending[eid]["tokens"][0]
	var at := fl.map.center_of(Vector2i(int(t0["x"]), int(t0["y"])))
	main.place_party(_near_floor(fl, at, 10))
	await _step(40)
	check(not fl.spawner.pending.has(eid), "近づくと、その遭遇が出る")
	var found := 0
	for e in fl.enemies:
		if e.enc_id == eid:
			found += 1
	check(found == int(fl.enc_total[eid]), "書き出しの数だけ出る (%d)" % found)
	check(main.random_room_pos(fl, -1).x < INF, "放り出される部屋は、まだ選べる")

func _near_floor(fl: FloorInstance, at: Vector2, cells: int) -> Vector2:
	## at から道のりで cells マスほどの床(なければ at)
	var m := fl.map
	var c := m.cell_of(at)
	var flow := m.compute_flow(c.x, c.y, cells + 2)
	for i in flow.size():
		if flow[i] == cells:
			return m.center_of(Vector2i(i % m.w, i / m.w))
	return at

func _spawned_encounters(fl: FloorInstance) -> int:
	var ids := {}
	for e in fl.enemies:
		ids[e.enc_id] = true
	for e in fl.map.data["encounters"]:
		if not fl.spawner.pending.has(int(e["id"])) and int(fl.enc_dead.get(int(e["id"]), 0)) > 0:
			ids[int(e["id"])] = true
	return ids.size()

func _test_sleep() -> void:
	print("遠い魔物は眠らせ、近づくと起こす")
	var fl: FloorInstance = main.current
	var some: Array = fl.enemies.filter(func(e): return not e.dead)
	check(not some.is_empty(), "出ている魔物がいる (%d)" % some.size())
	if some.is_empty():
		return
	var en: Enemy = some[0]
	var back := en.position
	var far := _far_from_all(fl, Spawner.SLEEP_CELLS + 2.0)
	if far.x >= INF:
		check(false, "遠い所が見つからない")
		return
	main.place_party(far)
	await _step(40)
	check(en.dormant and not en.is_physics_processing() and not en.visible, "遠くの魔物は、動きも描画も止まる")
	check(en.position == back, "眠っている間は、動かない")
	main.place_party(_near_floor(fl, back, 8))
	await _step(40)
	check(not en.dormant and en.is_physics_processing(), "近づくと起きる")

func _test_cap() -> void:
	print("起きている魔物の上限")
	var fl: FloorInstance = main.current
	var lead: Vector2 = main.leader().position
	# 仲間のまわり(16〜22マス)に、魔物を並べて出す
	var made: Array = []
	var m := fl.map
	var c := m.cell_of(lead)
	var flow := m.compute_flow(c.x, c.y, 30)
	var spots: Array = []
	for i in flow.size():
		var p := m.center_of(Vector2i(i % m.w, i / m.w))
		var d := p.distance_to(lead) / Balance.CELL
		if flow[i] > 0 and d > Spawner.KEEP_CELLS + 1.0 and d < Spawner.WAKE_CELLS - 1.0 and m.visible[i] == 0:
			spots.append(p)
	check(spots.size() >= 6, "並べる場所がある (%d)" % spots.size())
	var line := EncounterGen.mon_line({"m": EncounterGen.data()["monsters"][0], "n": 1, "world": ""})
	for k in mini(6, spots.size()):
		made.append_array(fl.spawn_encounter([line], "beast", spots[k * spots.size() / 6], "", "chase"))
	var keep_cap := Spawner.cap
	Spawner.cap = 2
	Spawner._fps_t = -1e9        # FPS を見て上限を上げ下げする係を、しばらく止める
	await _step(40)
	var near := 0
	for e in fl.enemies:
		var ec := m.cell_of(e.position)
		var seen: bool = m.visible[m.idx(ec.x, ec.y)] == 1
		if not e.dead and not e.dormant and not e.light and (seen or main.heroes.any(func(h): return e.position.distance_to(h.position) <= Spawner.KEEP_CELLS * Balance.CELL)):
			near += 1
	var up := fl.enemies.filter(func(e): return not e.dead and not e.dormant).size()
	check(up <= maxi(2, near), "上限を超えたら、遠いものから眠らせる (起きている %d、近いか見えている %d)" % [up, near])
	check(made.any(func(e): return e.dormant), "上限を超えた分は眠る")
	Spawner.cap = keep_cap
	Spawner._fps_t = 0.0
	await _step(40)
	check(made.all(func(e): return e.dead or not e.dormant), "上限が上がれば、また起きる")
	for e in made:
		if not e.dead:
			fl.enemies.erase(e)
			e.queue_free()
	await _step(2)
	# FPS を見る係: 呼んでも上限は範囲の中
	Spawner.watch_fps(1.1)
	check(Spawner.cap >= Spawner.CAP_MIN and Spawner.cap <= Spawner.CAP_MAX, "上限は %d〜%d の間 (%d)" % [Spawner.CAP_MIN, Spawner.CAP_MAX, Spawner.cap])

func _test_wander() -> void:
	print("ワンダリング・モンスターは、眠らずに歩き回る")
	var fl: FloorInstance = main.current
	var tries := 0
	while fl.wanderers.is_empty() and tries < 20:
		main.dtime.spawn_wanderer(false, true)
		tries += 1
	check(not fl.wanderers.is_empty(), "ワンダリングが出る")
	var eid: int = fl.wanderers[-1]
	var group: Array = fl.enemies.filter(func(e): return e.enc_id == eid)
	check(group.all(func(e): return e.state == "wander"), "出たときは、歩き回っている(すぐには追ってこない)")
	# 遠くへ行くと、軽い歩き方になる。眠らずに、位置が進む
	var far := _far_from_all(fl, Spawner.SLEEP_CELLS + 4.0)
	var en: Enemy = group[0]
	if far.x < INF:
		main.place_party(far)
	# 仲間から遠いワンダリングを選ぶ
	await _step(10)
	var lights: Array = fl.enemies.filter(func(e): return e.light)
	check(not lights.is_empty(), "遠くのワンダリングは、軽い歩き方になる (%d体)" % lights.size())
	if not lights.is_empty():
		en = lights[0]
	var p0 := en.position
	var moved := false
	for i in 30:
		await _step(30)
		if en.position.distance_to(p0) > Balance.CELL * 2.0:
			moved = true
			break
	check(moved, "遠くでも、歩き回り続ける (%.0fpx)" % en.position.distance_to(p0))
	check(not en.visible and not en.is_physics_processing(), "遠くでは、描画も押し合いもしない")
	var g: Dictionary = fl.spawner.goals.get(en.enc_id, {})
	check(not g.is_empty() and (g["cell"] as Vector2i).x >= 0, "行き先の部屋がある")
	# 近づくと、ふつうの歩き方に戻る
	main.place_party(_near_floor(fl, en.position, 6))
	await _step(40)
	check(not en.light and en.is_physics_processing(), "近づくと、ふつうに歩く(気づけば追ってくる) state=%s" % en.state)
	# 追っていても、見失うほど離れたら、また歩き回る
	en.state = "chase"
	var far2 := _far_from_all(fl, Spawner.SLEEP_CELLS + 4.0)
	if far2.x < INF:
		main.place_party(far2)
		await _step(40)
		check(en.dead or en.state == "wander", "見失うと、また歩き回る (%s)" % en.state)

func _test_queue() -> void:
	print("吐く夜の群れは、順番待ちから一組ずつ")
	var fl: FloorInstance = main.current
	var before := fl.wanderers.size()
	fl.spawner.queued = 2
	main.dtime._queue_t = 0.0
	for i in 200:
		main.dtime._drain_queue(0.05)
	check(fl.spawner.queued == 0, "順番待ちが空になる")
	check(fl.wanderers.size() >= before + 1, "群れが出る (%d → %d)" % [before, fl.wanderers.size()])
	var hunting := false
	for eid in fl.wanderers.slice(before):
		if fl.spawner.hunt.has(eid):
			hunting = true
	check(hunting, "吐く夜の群れは、仲間のいる所を目指す")
	var eid2: int = fl.wanderers[-1]
	var en: Enemy = null
	for e in fl.enemies:
		if e.enc_id == eid2:
			en = e
	if en != null:
		fl.spawner.goals.erase(eid2)
		fl.spawner.wander_next(en)
		var g: Dictionary = fl.spawner.goals[eid2]
		check(g["cell"] == fl.map.cell_of(fl.leader.position), "行き先は、仲間のいるマス")

func _test_save() -> void:
	print("記録と再開")
	var fl: FloorInstance = main.current
	var snap := DiveSave.floor_snap(fl)
	var fresh := FloorInstance.create_from_dict(fl.map.data)
	DiveSave.floor_apply(fresh, snap)
	check(fresh.spawner.pending.size() == fl.spawner.pending.size(), "まだ出していない遭遇は、控えのまま (%d)" % fresh.spawner.pending.size())
	check(fresh.enemies.size() == fl.enemies.filter(func(e): return not e.dead).size(), "出ていた魔物は戻る (%d)" % fresh.enemies.size())
	check(fresh.spawner.hunt.size() == fl.spawner.hunt.size(), "仲間を目指す群れも戻る")
	var states := {}
	for e in fresh.enemies:
		states[e.state] = true
	check(not fl.wanderers.is_empty() and (states.has("wander") or states.has("chase")), "歩き回る魔物の状態も戻る %s" % [states.keys()])
	# 前の記録(控えの欄が無い)は、全部出したあととみなす
	snap.erase("pending")
	var old := FloorInstance.create_from_dict(fl.map.data)
	DiveSave.floor_apply(old, snap)
	check(old.spawner.pending.is_empty(), "前の記録なら、控えは無い")
	fresh.free()
	old.free()

func _test_setting() -> void:
	print("FPS の表示")
	var keep := GameSettings.show_fps
	GameSettings.set_show_fps(true)
	GameSettings.load_settings()
	check(GameSettings.show_fps, "出す設定が残る")
	GameSettings.set_show_fps(false)
	GameSettings.load_settings()
	check(not GameSettings.show_fps, "出さない設定が残る")
	GameSettings.set_show_fps(keep)
