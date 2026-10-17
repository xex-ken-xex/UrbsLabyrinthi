extends SceneTree
## 魔物の特徴 第二弾の見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/traits2_shot.gd -- 出力フォルダ
## traits2_1.png 水たまりに沈んだ鰐、天井の大蜘蛛、冒険者に化けたドッペルゲンガー、光る火吹き甲虫
## traits2_2.png 石化した仲間とバジリスク、蜘蛛の巣と糸に絡まった仲間、灯りで眩しがるワイト
func _initialize() -> void:
	call_deferred("_run")

func _line(index: String) -> Dictionary:
	for m in EncounterGen.data()["monsters"]:
		if String(m["i"]) == index:
			return EncounterGen.mon_line({"m": m, "n": 1, "world": ""})
	return {}

func _spawn(ar: Arena, index: String, pos: Vector2, state: String) -> Enemy:
	var en := Enemy.new()
	en.setup(ar.fl, _line(index), {"id": 900, "kind": "beast"}, pos)
	en.state = state
	if state != "idle":
		en.disguised = false
		en.lurk = ""
	en.died.connect(ar.fl._on_enemy_died)
	ar.fl.add_child(en)
	ar.fl.enemies.append(en)
	return en

func _shot(path: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	main.show_make()
	await process_frame
	main.screen._on_start()
	await process_frame
	main.start_arena()
	for i in 5:
		await physics_frame
	var ar: Arena = main.arena
	ar.set_all_levels(5)
	ar.set_theme("fuyou")
	for h in main.heroes:
		h.position = Vector2(220, 250) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	_spawn(ar, "crocodile", Vector2(520, 170), "idle")
	_spawn(ar, "giant-spider", Vector2(640, 330), "idle")
	_spawn(ar, "doppelganger", Vector2(470, 380), "idle")
	var fb := _spawn(ar, "giant-fire-beetle", Vector2(720, 160), "chase")
	fb.speed = 1.0
	for i in 30:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		await physics_frame
	await _shot(out + "/traits2_1.png")
	ar.clear_enemies()
	var map := ar.fl.map
	for c in [Vector2i(14, 9), Vector2i(15, 10), Vector2i(16, 9), Vector2i(15, 8), Vector2i(17, 10)]:
		ar.fl.webs[map.idx(c.x, c.y)] = true
	ar.fl.queue_redraw()
	var h0: Hero = main.heroes[0]
	var h1: Hero = main.heroes[1]
	h0.position = Vector2(260, 200)
	h1.position = Vector2(map.center_of(Vector2i(14, 9)))
	var bs := _spawn(ar, "basilisk", Vector2(420, 200), "chase")
	bs.speed = 1.0
	var wt := _spawn(ar, "wight", Vector2(330, 400), "chase")
	wt.speed = 1.0
	for i in 200:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		h0.facing = Vector2.RIGHT
		if i == 150:
			h1.hold("web", 3.0)
		if h0.stuck_kind == "stone" and h0.stuck_t > 0.0 and i > 150:
			break
		await physics_frame
	wt.lit_cd = 0.0
	wt.in_light = false
	h1.position = Vector2(map.center_of(Vector2i(15, 10)))
	h1.hold("web", 3.0)
	for i in 20:
		await physics_frame
	await _shot(out + "/traits2_2.png")
	print("saved")
	quit()
