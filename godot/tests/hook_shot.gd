extends SceneTree
## 部屋の手がかりの見た目(中央の一文と、床の光る印): xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/hook_shot.gd -- 出力フォルダ
func _initialize() -> void:
	call_deferred("_run")

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
	main._set_screen(null)
	main.start_day()
	for i in 5:
		await physics_frame
	for h in main.heroes:
		h.iframes = 1e9
	Spawner.off = true
	var mk := {}
	for depth in range(1, 31):
		for night in [0, 1, 2]:
			main.gs.day = night
			main.floors.clear()
			main.enter_floor(depth, "up")
			if not main.current.hook_marks.is_empty():
				mk = main.current.hook_marks[0]
				break
		if not mk.is_empty():
			break
	var fl: FloorInstance = main.current
	var c: Vector2i = mk["cell"]
	main.place_party(fl.map.center_of(fl.map.nearest_walkable(c + Vector2i(3, 1))))
	await _hold(main, 30)
	fl.visited_rooms.erase(int(mk["room"]))
	main._enter_room(c)
	main._refresh_view()
	main.camera.zoom = Vector2.ONE * 1.6
	await _hold(main, 50)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/hook_banner.png")
	quit()
