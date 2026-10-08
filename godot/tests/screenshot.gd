extends SceneTree
## 画面の確認用:  xvfb-run godot --path godot -s res://tests/screenshot.gd -- 出力フォルダ [層]
## 層の番号を渡すと、その層に降りて撮る。

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var floor_no := int(args[1]) if args.size() > 1 else 1
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	var pl: Player = main.player
	for n in range(1, floor_no):
		main.enter_floor(n + 1, "up")
	pl.scripted_input = {"move": Vector2.ZERO}
	# 最寄りの部屋(出口のある方)へ少し歩かせる
	var m: FloorMap = main.current.map
	var flow := m.compute_flow(main.current.down_cell.x, main.current.down_cell.y, 400)
	for i in 240:
		var c := m.cell_of(pl.position)
		var nx := m.flow_step(flow, c, true)
		if nx.x >= 0:
			var to := m.center_of(nx) - pl.position
			pl.scripted_input = {"move": to.normalized()}
		await physics_frame
	pl.scripted_input = {"move": Vector2.ZERO}
	for i in 20:
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/shot_f%02d.png" % [out, floor_no])
	print("saved ", img.get_size())
	quit()
