extends SceneTree
## 保存まわりの見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/save_shot.gd -- 出力フォルダ
## save_menu.png 持ち物の「記録をつける」 / save_title.png 記録したあとのタイトル(「保存しました。」と記録の中身)
## 注意: user:// の記録を書き換える
func _initialize() -> void:
	call_deferred("_run")

func _shot(path: String) -> void:
	for i in 3:
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
	for k in [["fighter", "human", "セラ"], ["cleric", "dwarf", "ティオ"], ["wizard", "elf", "ミラ"]]:
		var c := Character.create(k[2], k[1], k[0], Jobs.auto_stats(k[0]))
		chars.append(c)
	chars[0].level = 4
	chars[1].level = 3
	chars[2].level = 3
	main.gs.new_game(chars)
	main.gs.day = 5
	main._set_screen(null)
	main.start_day()
	for i in 10:
		await physics_frame
	main.enter_floor(3, "up")
	for i in 5:
		await physics_frame
	main.open_inventory()
	await _shot(out + "/save_menu.png")
	main.inventory._on_save()
	for i in 5:
		await process_frame
	await _shot(out + "/save_title.png")
	quit(0)
