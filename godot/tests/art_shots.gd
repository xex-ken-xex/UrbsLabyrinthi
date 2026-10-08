extends SceneTree
## 街の背景絵の確認用:  xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/art_shots.gd -- 出力フォルダ
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var art := TownArt.new()
	layer.add_child(art)
	await process_frame
	for st in ["town", "smith", "general", "magic", "temple", "inn", "pleasure"]:
		art.set_style(st)
		art.t = 3.0
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/art_%s.png" % [out, st])
	print("saved")
	quit()
