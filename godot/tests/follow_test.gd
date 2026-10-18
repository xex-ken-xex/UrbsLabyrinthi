extends SceneTree
## 仲間が角や細い通路で引っかからずについて来るか(ken 10/18): Godot --headless --path godot -s res://tests/follow_test.gd
## 細い通路の曲がり角で、リーダーが見えない所に仲間を置き、リーダーのそばまで来られるかを、いくつもの場所で確かめる
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "human"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	for i in 5:
		await physics_frame
	var fl: FloorInstance = main.current
	_clear(fl)
	var m: FloorMap = fl.map
	# 通路のマスのうち、縦横どちらか一方にしか続かない細い所(幅1マス)で、道のり6〜9マス先が見えない場所を探す
	var cases: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tries := 0
	while cases.size() < 12 and tries < 4000:
		tries += 1
		var x := rng.randi_range(1, m.w - 2)
		var y := rng.randi_range(1, m.h - 2)
		if m.tiles[m.idx(x, y)] != FloorMap.CORR:
			continue
		var fw := m.compute_flow(x, y, 12)
		for k in 200:
			var fx := rng.randi_range(maxi(1, x - 9), mini(m.w - 2, x + 9))
			var fy := rng.randi_range(maxi(1, y - 9), mini(m.h - 2, y + 9))
			var d := fw[m.idx(fx, fy)]
			if d >= 6 and d <= 9 and m.tiles[m.idx(fx, fy)] == FloorMap.CORR and not m.los(fx, fy, x, y):
				cases.append([Vector2i(x, y), Vector2i(fx, fy)])
				break
	check(cases.size() >= 6, "細い通路の曲がり角を見つけた (%d か所)" % cases.size())
	var lead: Hero = main.leader()
	var fol: Hero = main.heroes[1]
	var ok_n := 0
	for cs in cases:
		lead.position = m.center_of(cs[0])
		fol.position = m.center_of(cs[1])
		main.trail = [lead.position]
		main._refresh_view()      # リーダーまでの道のり(flow)を、置いた場所で作り直す
		var reached := false
		for f in 360:       # 6秒
			await physics_frame
			lead.position = m.center_of(cs[0])
			if fol.position.distance_to(lead.position) < 48.0:
				reached = true
				break
		if reached:
			ok_n += 1
		else:
			print("    届かない: リーダー %s 仲間 %s → %s" % [str(cs[0]), str(cs[1]), str(m.cell_of(fol.position))])
	check(ok_n == cases.size(), "どの曲がり角でも、仲間がリーダーのそばまで来る (%d / %d)" % [ok_n, cases.size()])
	# 角の外: 仲間が、リーダーの斜め後ろの壁の角にいる(ken の絵の場所)。リーダーは細い通路を奥へ進む
	var corners: Array = []
	for y in range(2, m.h - 2):
		for x in range(2, m.w - 2):
			if corners.size() >= 12:
				break
			if not m.monster_passable(x, y):
				continue
			for d in [Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var dx: int = x + d.x
				var dy: int = y + d.y
				var o1 := m.monster_passable(dx, y)
				var o2 := m.monster_passable(x, dy)
				# 斜めの先が幅1の通路(縦に続く)で、角の片方が壁
				if m.monster_passable(dx, dy) and o1 != o2 and m.monster_passable(dx, dy + d.y) and m.monster_passable(dx, dy + 2 * d.y) \
						and not m.monster_passable(dx - 1, dy + d.y) and not m.monster_passable(dx + 1, dy + d.y) and rng.randf() < 0.3:
					corners.append([Vector2i(x, y), Vector2i(dx, dy), d])
					break
	check(corners.size() >= 4, "細い通路の入り口の角を見つけた (%d か所)" % corners.size())
	var ok2 := 0
	for cs in corners:
		var dv: Vector2i = cs[2]
		var start: Vector2i = cs[1] + Vector2i(0, dv.y)
		fol.position = m.center_of(cs[0])
		lead.position = m.center_of(start)
		main.trail = [lead.position]
		main._refresh_view()
		var reached := false
		var goal := Vector2.ZERO
		for f in 300:
			# リーダーは通路の中で止まり、来た道(通路の奥)を向いている。仲間の行き先は、リーダーの向こう側
			lead.position = m.center_of(start)
			lead.facing = Vector2(0, -dv.y)
			await physics_frame
			goal = fol.follow_pos
			if f > 30 and fol.position.distance_to(goal) < 20.0:
				reached = true
				break
		if reached:
			ok2 += 1
		else:
			print("    角で止まった: 仲間 %s → %s、行き先 %s" % [str(cs[0]), str(m.cell_of(fol.position)), str(m.cell_of(goal))])
	check(ok2 == corners.size(), "角の外にいても、細い通路の奥のリーダーについて来る (%d / %d)" % [ok2, corners.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _clear(fl: FloorInstance) -> void:
	fl.spawner.pending.clear()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
