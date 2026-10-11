extends SceneTree
## 階の全体を縮めて撮る(広さと、魔物・燐晶の散らばりの確認用):
##   xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/overview_shot.gd -- 出力フォルダ [階]
func _initialize() -> void:
	get_root().size = Vector2i(1600, 1100)
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var depth := int(args[1]) if args.size() > 1 else 1
	var fl := FloorInstance.create(FloorMap.floor_path(depth, 0, 4))
	root.add_child(fl)
	var m := fl.map
	for i in m.explored.size():
		m.explored[i] = 1
		m.visible[i] = 1
	var C := float(Balance.CELL)
	var zoom := minf(1600.0 / (m.w * C), 1100.0 / (m.h * C))
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Vector2(m.w * C, m.h * C) / 2.0
	root.add_child(cam)
	fl.light_pos = fl.map.center_of(fl.up_cell)
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/overview_d%02d.png" % [out, depth])
	print("階 %d: %dx%d 魔物 %d 落ちているもの %d" % [depth, m.w, m.h, fl.enemies.size(), fl.ground.entries.size()])
	quit()
