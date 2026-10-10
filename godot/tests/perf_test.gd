extends SceneTree
## 広い層の処理時間の確認用: godot --headless --path godot -s res://tests/perf_test.gd -- [層]
## 全魔物が仲間を追う最悪の場合で、物理1コマの平均時間を測る。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fno := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 2
	var fl := FloorInstance.create("res://data/floors/f%02d_n00_p4.json" % fno)
	root.add_child(fl)
	var m := fl.map
	var spot := m.center_of(fl.up_cell)
	var heroes: Array = []
	for i in 4:
		var k: String = ["fighter", "cleric", "wizard", "rogue"][i]
		var h := Hero.new()
		h.setup(fl, Character.create(k, "human", k, Jobs.auto_stats(k)))
		h.position = spot + Vector2(i * 14, 0)
		root.add_child(h)
		heroes.append(h)
	fl.heroes = heroes
	fl.leader = heroes[0]
	for e in fl.enemies:
		e.state = "chase"
		e.asleep = false
	var mode := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
	if mode == "nofloor":
		fl.set_physics_process(false)
	elif mode == "noenemy":
		for e in fl.enemies:
			e.set_physics_process(false)
	elif mode == "idle":
		for e in fl.enemies:
			e.state = "idle"
			e.asleep = true
	var t0 := Time.get_ticks_usec()
	var n := 240
	for i in n:
		await physics_frame
	var dt := float(Time.get_ticks_usec() - t0) / 1000.0 / n
	print("第%d層 魔物 %d 落ちているもの %d: 物理1コマ 平均 %.2f ms" % [fno, fl.enemies.size(), fl.ground.entries.size(), dt])
	quit()
