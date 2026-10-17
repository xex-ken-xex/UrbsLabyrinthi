extends SceneTree
## 縦穴のまわりの見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/abyss_shot.gd -- 出力フォルダ
## abyss_1.png 第1階の縁から覗く(腐葉 → 錆鉄)、abyss_2.png 第23階(水鏡 → 骨)、abyss_3.png 第28階(骨 → 竜の巣は真っ黒)、
## abyss_rope.png 縄梯子の選び、abyss_section.png 持ち物の画面の「迷宮の断面」
func _initialize() -> void:
	call_deferred("_run")

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
	var n := 1
	for depth in [1, 23, 28]:
		if depth != 1:
			main.enter_floor(depth, "up")
		var fl: FloorInstance = main.current
		var sh: Dictionary = fl.map.data["shaft"]
		# 西の縁に立つ(縦穴が画面の右半分に収まる)
		main.place_party(fl.map.center_of(Vector2i(int(sh["x"]) - 1, int(sh["y"]) + 6)))
		for i in 90:
			main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
			await physics_frame
		main.hud.overlay = []
		main.camera.zoom = Vector2.ONE * 0.8     # 縦穴(20m四方)が画面に収まるように引く
		await physics_frame
		await _shot(out + "/abyss_%d.png" % n)
		n += 1
	var fl2: FloorInstance = main.current
	main.place_party(fl2.map.center_of(fl2.ropes[0]))
	for i in 3:
		await physics_frame
	main.interact()
	await _shot(out + "/abyss_rope.png")
	main._on_rope_choice("")
	main.open_inventory()
	await process_frame
	main.inventory._set_tab("section")
	await _shot(out + "/abyss_section.png")
	quit()
