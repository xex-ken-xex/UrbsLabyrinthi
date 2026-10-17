extends SceneTree
## 魔物の特徴の見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/traits_shot.gd -- 出力フォルダ
## traits_1.png 物のふりのミミックとグレイ・ウーズ、闇にまぎれるシャドウ / traits_2.png 突進の構え(ドドドッ)と飛びかかり(ガバッ!)
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
	en.disguised = en.disguised and state == "idle"
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
	ar.set_theme("sabi")
	for h in main.heroes:
		h.position = Vector2(260, 250) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	_spawn(ar, "mimic", Vector2(560, 180), "idle")
	_spawn(ar, "gray-ooze", Vector2(480, 420), "idle")
	_spawn(ar, "shadow", Vector2(680, 330), "idle")
	for i in 30:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		await physics_frame
	await _shot(out + "/traits_1.png")
	ar.clear_enemies()
	var mt := _spawn(ar, "minotaur", Vector2(420, 250), "chase")
	mt.charge_cd = 0.0
	var mm := _spawn(ar, "mimic", Vector2(300, 380), "idle")
	main.heroes[1].position = Vector2(300, 350)
	for i in 10:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		await physics_frame
	await _shot(out + "/traits_2.png")
	print("saved")
	quit()
