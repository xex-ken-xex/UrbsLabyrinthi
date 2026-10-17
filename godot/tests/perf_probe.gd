extends SceneTree
## 重さの比べ: godot --headless --path godot -s res://tests/perf_probe.gd
## 1層目に4人で入り、ワンダリング・モンスターを20組まで出して、物理1コマの時間を測る。
## 前のやり方(層の魔物を全部出し、眠らせず、ワンダリングはすぐ追ってくる)と、Spawner のやり方を比べる。
## 数字は、実時間で3秒のあいだに回せたコマの数(画面の FPS にあたる。--headless なので描画は無し)。
var main: Node

func _initialize() -> void:
	call_deferred("_run")

func _measure(label: String) -> void:
	for i in 30:
		await physics_frame
	# 実時間で3秒、何コマ回せたか(画面の FPS にあたる。物理は遅れると取り返すので、重いと FPS が落ちる)
	var t0 := Time.get_ticks_usec()
	var n := 0
	var ph0 := Engine.get_physics_frames()
	while Time.get_ticks_usec() - t0 < 3000000:
		await process_frame
		n += 1
	var secs := (Time.get_ticks_usec() - t0) / 1000000.0
	var phys := float(Engine.get_physics_frames() - ph0)
	var fl: FloorInstance = main.current
	var alive := 0
	var chase := 0
	for e in fl.enemies:
		if not e.dead:
			alive += 1
			if e.state == "chase":
				chase += 1
	var sp := fl.spawner
	print("%-24s 魔物 %3d(追う %3d / 動 %3d 歩く %3d 眠 %3d 未出 %2d組)  %.0f FPS(物理 %.0f回/秒)" % [label, alive, chase,
		sp.awake, sp.light_n, sp.asleep_n, sp.pending.size(), n / secs, phys / secs])

func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	for i in 10:
		await physics_frame
	for h in main.heroes:
		h.iframes = 1e9

func _run() -> void:
	for old in [true, false]:
		Spawner.off = old
		Spawner.cap = Spawner.CAP_START
		print("---- %s ----" % ("前のやり方" if old else "Spawner"))
		await _start()
		if old:
			main.current.spawner.spawn_all()
		await _measure("層に入った直後")
		for k in [10, 20, 30]:
			while main.current.wanderers.size() < k:
				main.dtime.spawn_wanderer(false, true)
			if old:
				for e in main.current.enemies:
					if e.state == "wander":
						e.state = "chase"
			for i in 300:
				await physics_frame
			await _measure("ワンダリング %d組" % k)
		for e in main.current.enemies:
			if e.state == "wander":
				e.state = "chase"
		for i in 600:
			await physics_frame
		await _measure("30組がみな追ってくる")
		main.queue_free()
		await process_frame
		await process_frame
	quit()
