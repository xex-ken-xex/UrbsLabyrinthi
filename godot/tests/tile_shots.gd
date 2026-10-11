extends SceneTree
## マップチップの見た目の確認用: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/tile_shots.gd -- 出力フォルダ
## 舞台ごと(第1、3、5、7、10層)に、部屋と通路を探索済みにして撮る。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	for fno in [1, 3, 5, 7, 10]:
		var fl := FloorInstance.create("res://data/floors/f%02d_n00_p1.json.gz" % fno)
		root.add_child(fl)
		for e in fl.enemies.duplicate():
			e.queue_free()
		fl.enemies.clear()
		var m := fl.map
		var c := Vector2i(int(m.rooms[0]["center"][0]), int(m.rooms[0]["center"][1]))
		for i in m.explored.size():
			m.explored[i] = 0
		m.compute_visible(c.x, c.y, 12)
		for i in m.visible.size():
			if m.visible[i] == 1:
				m.explored[i] = 1
		var cam := Camera2D.new()
		cam.zoom = Vector2(1.6, 1.6)
		cam.position = m.center_of(c)
		root.add_child(cam)
		fl.light_pos = m.center_of(c)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/tile_f%02d.png" % [out, fno])
		cam.queue_free()
		fl.queue_free()
		await process_frame
	quit()
