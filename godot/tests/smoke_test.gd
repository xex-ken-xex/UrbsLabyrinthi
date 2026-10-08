extends SceneTree
## ヘッドレスの動作確認:  godot --headless --path godot -s res://tests/smoke_test.gd
## 1. ダイス式の解釈  2. 書き出した全140層の読み込みと連結  3. 実際にゲームを回して潜る・戦う・死ぬ・戻る

var fails := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_dice()
	await _test_floors()
	await _test_game()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _test_dice() -> void:
	print("[dice]")
	check(is_equal_approx(Dice.average("1d4+2 piercing"), 4.5), "1d4+2 → 4.5")
	check(is_equal_approx(Dice.average("1 piercing + 3d4 poison"), 8.5), "1 + 3d4 → 8.5")
	check(is_equal_approx(Dice.average("4d10"), 22.0), "4d10 → 22")
	check(is_equal_approx(Dice.average("2d6+3 slashing"), 10.0), "2d6+3 → 10")
	var lo := 999
	var hi := 0
	for i in 500:
		var r := Dice.roll("2d6+3")
		lo = mini(lo, r)
		hi = maxi(hi, r)
	check(lo >= 5 and hi <= 15 and hi > lo, "roll 2d6+3 は 5〜15 (出た範囲 %d〜%d)" % [lo, hi])
	await process_frame

func _test_floors() -> void:
	print("[floors]")
	var bad := 0
	var enemies := 0
	var chests := 0
	var traps := 0
	var unreachable := 0
	for night in Balance.NIGHTS:
		for fl in range(1, Balance.MAX_FLOOR + 1):
			var path := "res://data/floors/f%02d_n%02d.json" % [fl, night]
			var inst := FloorInstance.create(path)
			if inst == null:
				bad += 1
				continue
			var m := inst.map
			enemies += inst.enemies.size()
			chests += inst.chests.size()
			traps += inst.traps.size()
			# 上り階段から、施錠・隠し扉を開けた前提で、下り階段へ着けるか
			for d in m.doors:
				d["unlocked"] = true
				d["found"] = true
			var flow := m.compute_flow(inst.up_cell.x, inst.up_cell.y, 400)
			if flow[m.idx(inst.down_cell.x, inst.down_cell.y)] < 0:
				unreachable += 1
			for en in inst.enemies:
				var c := m.cell_of(en.position)
				if flow[m.idx(c.x, c.y)] < 0:
					unreachable += 1
				if en.dmg <= 0.0 or en.hp <= 0:
					bad += 1
			for c in inst.chests:
				if flow[m.idx(c["cell"].x, c["cell"].y)] < 0:
					unreachable += 1
			inst.free()
	check(bad == 0, "全層が読める・敵の数値が正 (不良 %d)" % bad)
	check(unreachable == 0, "階段・敵・宝箱へ着ける (到達不能 %d)" % unreachable)
	print("  集計: 敵 %d / 宝箱 %d / 罠 %d (140層)" % [enemies, chests, traps])
	await process_frame

func _step(n: int) -> void:
	for i in n:
		await physics_frame

func _test_game() -> void:
	print("[game]")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(5)
	check(main.current != null and main.current.floor_no == 1, "第1層から始まる")
	var pl: Player = main.player
	# 歩く
	pl.scripted_input = {"move": Vector2.ZERO}
	var p0 := pl.position
	var free_dir := Vector2.ZERO
	for dv in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if not main.current.map.circle_blocked(pl.position + dv * 40.0, Balance.PLAYER_RADIUS):
			free_dir = dv
			break
	pl.scripted_input = {"move": free_dir}
	await _step(20)
	check(pl.position.distance_to(p0) > 20.0, "移動できる")
	# 壁を抜けない
	var m: FloorMap = main.current.map
	var inside := true
	for i in 120:
		pl.scripted_input = {"move": Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized(), "dodge": i % 15 == 0}
		await physics_frame
		if m.circle_blocked(pl.position, Balance.PLAYER_RADIUS - 0.5):
			inside = false
	check(inside, "ランダムに動いても壁に食い込まない")
	pl.scripted_input = {"move": Vector2.ZERO}
	# 最寄りの敵に突っ込んで戦う
	var fl: FloorInstance = main.current
	var target: Enemy = null
	var bd := 1e9
	for en in fl.enemies:
		var d: float = en.position.distance_to(pl.position)
		if d < bd:
			bd = d
			target = en
	check(target != null, "第1層に敵がいる")
	if target != null:
		pl.position = target.position + Vector2(30, 0)
		if m.circle_blocked(pl.position, Balance.PLAYER_RADIUS):
			pl.position = target.position + Vector2(-30, 0)
		pl.hp = pl.max_hp
		var xp0 := pl.xp
		var killed := [false]
		target.died.connect(func(_e): killed[0] = true)
		for i in 600:
			if killed[0] or pl.down:
				break
			var to := (target.position - pl.position)
			pl.facing = to.normalized()
			pl.scripted_input = {"move": to.normalized() * (1.0 if to.length() > 38.0 else 0.0), "attack": to.length() < 52.0}
			await physics_frame
		check(killed[0] or pl.down, "戦闘が決着する (敵死亡=%s プレイヤー倒れ=%s)" % [killed[0], pl.down])
		if killed[0]:
			check(pl.xp > xp0, "倒すとXPが入る (+%d)" % (pl.xp - xp0))
	# 罠
	pl.down = false
	pl.hp = pl.max_hp
	phase_reset(main)
	if not fl.traps.is_empty():
		var t: Dictionary = fl.traps[0]
		var hp0 := pl.hp
		pl.position = m.center_of(Vector2i(int(t["x"]), int(t["y"])))
		main._last_cell = Vector2i(-99, -99)
		await _step(3)
		check(t["st"] == "triggered", "罠を踏むと作動する (%s)" % t["name"])
		print("       HP %d → %d" % [hp0, pl.hp])
	# 階段で全層を下る
	pl.scripted_input = {"move": Vector2.ZERO}
	for n in range(1, Balance.MAX_FLOOR):
		phase_reset(main)
		pl.position = main.current.map.center_of(main.current.down_cell)
		main.interact()
		await _step(2)
		check(main.current.floor_no == n + 1, "第%d層 → 第%d層" % [n, n + 1])
	pl.position = main.current.map.center_of(main.current.down_cell)
	main.interact()
	check(main.current.floor_no == Balance.MAX_FLOOR, "第%d層の先は未踏で止まる" % Balance.MAX_FLOOR)
	# 登って地上へ
	for n in range(Balance.MAX_FLOOR, 1, -1):
		pl.position = main.current.map.center_of(main.current.up_cell)
		main.interact()
		await _step(2)
	check(main.current.floor_no == 1, "上り階段で第1層まで戻れる")
	# 宝を取って地上へ → 税
	main.bag_silver = 1000
	pl.position = main.current.map.center_of(main.current.up_cell)
	main.interact()
	check(main.phase == "overlay" and main.bank_silver == 700, "地上で3割が税になる (預け金 %d)" % main.bank_silver)
	main.continue_after_overlay()
	await _step(3)
	check(main.day == 1 and main.phase == "play" and main.bag_silver == 0, "次の夜に潜れる")
	var f_night1: String = main.current.map.data["meta"]["night_label"]
	print("       2日目: ", f_night1)
	# 死亡
	main.bag_silver = 500
	main.player.hp = 0
	main.player.down = true
	main._on_player_downed()
	check(main.bag_silver == 0 and main.bank_silver == 700, "力尽きると未査定の燐晶を失い、預け金は残る")
	main.continue_after_overlay()
	await _step(3)
	check(not main.player.down and main.player.hp == main.player.max_hp, "復帰するとHP全快")
	main.queue_free()
	await process_frame

func phase_reset(main: Node) -> void:
	main.phase = "play"
