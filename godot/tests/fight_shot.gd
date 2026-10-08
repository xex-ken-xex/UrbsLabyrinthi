extends SceneTree
## 戦闘の見た目の確認用: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/fight_shot.gd -- 出力フォルダ
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var fl := FloorInstance.create("res://data/floors/f01_n00_p4.json")
	root.add_child(fl)
	for e in fl.enemies.duplicate():
		e.dead = true
		e.queue_free()
	fl.enemies.clear()
	var m := fl.map
	var spot := Vector2.ZERO
	for r in m.rooms:
		var c := Vector2i(int(r["center"][0]), int(r["center"][1]))
		var ok := true
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if m.opaque(c.x + dx, c.y + dy):
					ok = false
		if ok:
			spot = m.center_of(c)
			break
	var heroes: Array = []
	for i in 4:
		var k: String = ["fighter", "cleric", "wizard", "rogue"][i]
		var h := Hero.new()
		h.setup(fl, Character.create(k, "human", k, Jobs.auto_stats(k)))
		h.position = spot + Vector2(-30, (i - 1.5) * 24.0)
		root.add_child(h)
		heroes.append(h)
	heroes[0].controlled = true
	fl.heroes = heroes
	fl.leader = heroes[0]
	for i in 3:
		var e := Enemy.new()
		e.setup(fl, {"name": "Rat", "name_ja": "洞窟鼠", "hp": 40, "ac": 12, "size": "S", "type": "beast", "xp": 25, "cr": 0.125, "speed": {"walk": 30}, "attacks": [{"n": "Bite", "b": 4, "d": "1d4+2 piercing"}]},
			{"id": 1, "kind": "beast", "attitude": "敵対", "activity": ""}, spot + Vector2(40, (i - 1) * 26.0))
		e.state = "chase"
		fl.add_child(e)
		fl.enemies.append(e)
		e.died.connect(fl._on_enemy_died)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.2, 2.2)
	cam.position = spot
	root.add_child(cam)
	fl.light_pos = spot
	m.compute_visible(m.cell_of(spot).x, m.cell_of(spot).y, 8)
	fl.queue_redraw()
	for i in 40:
		await physics_frame
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/fight_a.png")
	print("saved")
	quit()
