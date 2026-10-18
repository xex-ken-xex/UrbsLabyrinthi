extends SceneTree
## 迷宮の手ざわりの見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/world_shot.gd -- 出力フォルダ
## world_mark.png 地図屋の凧旗の印、world_sigil.png 壁の落書き、world_camp.png 闇潜りの野営
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

func _find(main: Node, kind: String) -> Dictionary:
	for depth in range(1, 15):
		for night in [0, 1, 2, 3]:
			main.gs.day = night
			main.floors.clear()
			main.enter_floor(depth, "up")
			for p in main.current.world_props:
				if String(p["kind"]) == kind:
					return p
	return {}

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
	for kind in ["mark", "sigil", "camp"]:
		var p := _find(main, kind)
		if p.is_empty():
			continue
		var c := Vector2i(int(p["x"]), int(p["y"]))
		main.place_party(main.current.map.center_of(c + (Vector2i(2, 2) if kind == "sigil" else Vector2i(0, 2))))
		await _hold(main, 40)
		main._refresh_view()
		main.current.queue_redraw()
		main.camera.zoom = Vector2.ONE * 1.6
		await _hold(main, 6)
		await _shot(out + "/world_%s.png" % kind)
	quit()
