extends SceneTree
## 闘技場の見た目の確認用: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/arena_shot.gd -- 出力フォルダ
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.show_make()
	await process_frame
	main.screen._on_start()
	await process_frame
	main.start_arena()
	for i in 5:
		await physics_frame
	var ar: Arena = main.arena
	ar.set_all_levels(5)
	ar.enc_level = 5
	ar.diff = 1
	ar.set_theme("sabi")
	ar.pop()
	ar.pop()
	for i in 150:
		main.leader().cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
		await physics_frame
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/arena.png")
	print("saved")
	quit()
