extends SceneTree
## 燐の流れの見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/flow_shot.gd -- 出力フォルダ
## flow_hot.png 第27階の吐く夜(縦穴の縁の陽炎、焦げた遺体、硫黄の華)、flow_sump.png 第26階の溜まり場(失くした物が積もっている)
func _initialize() -> void:
	call_deferred("_run")

func _shot(path: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _hold(main: Node, n: int) -> void:
	for i in n:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		await physics_frame

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main.gs.day = 2         # 第三節の夜(吐く夜)
	main._set_screen(null)
	main.start_day()
	for i in 5:
		await physics_frame
	for h in main.heroes:
		h.iframes = 1e9
	# 第27階の吐く夜の夜: 縁の陽炎と、焦げた遺体、硫黄の華
	main.enter_floor(27, "up")
	var fl: FloorInstance = main.current
	var dt: DungeonTime = main.dtime
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.NIGHT_MIN - 1.0
	var sh: Dictionary = fl.map.data["shaft"]
	var at := Vector2i(int(sh["x"]) - 2, int(sh["y"]) + 6)
	for e in fl.ground.entries:
		if String(e["kind"]) == "corpse":
			e["pos"] = fl.map.center_of(at + Vector2i(-2, 2))     # 焦げた遺体を一つ、画面に入れる
			e["scorched"] = true
			break
	main.place_party(fl.map.center_of(at))
	await _hold(main, 90)
	main.camera.zoom = Vector2.ONE * 0.8
	await _hold(main, 10)
	await _shot(out + "/flow_hot.png")
	# 第26階の溜まり場
	main.gs.day = 3
	main.floors.clear()
	main.gs.flow["sump"] = [{"id": "longsword", "n": 1, "day": 2, "room": 0}, {"id": "potion", "n": 3, "day": 2, "room": 0}, {"id": "chain_mail", "n": 1, "day": 2, "room": 0}]
	main.gs.flow["sump_kg"] = {"mid": 0.8}
	main.enter_floor(26, "up")
	var f26: FloorInstance = main.current
	var room: Dictionary = PhosFlow.sump_rooms(f26)[0]
	main.place_party(f26.map.center_of(f26.map.free_cell_in_room(room, [])) + Vector2(0, 70))
	await _hold(main, 60)
	main.camera.zoom = Vector2.ONE * 1.2
	await _hold(main, 10)
	await _shot(out + "/flow_sump.png")
	quit()
