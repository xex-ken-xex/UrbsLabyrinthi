extends SceneTree
## 落ちているものの見た目の確認用: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/ground_shot.gd -- 出力フォルダ [層]
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var fno := int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 1
	var fl := FloorInstance.create("res://data/floors/f%02d_n00_p1.json" % fno)
	root.add_child(fl)
	for e in fl.enemies.duplicate():
		e.queue_free()
	fl.enemies.clear()
	var m := fl.map
	# 燐晶が一番多く固まっている所
	var best := Vector2.ZERO
	var bn := -1
	for g in fl.ground.entries:
		if String(g["kind"]) != "crystal":
			continue
		var n := 0
		for h in fl.ground.entries:
			if (h["pos"] as Vector2).distance_to(g["pos"]) < 150.0:
				n += 1
		if n > bn:
			bn = n
			best = g["pos"]
	# 遺体と自生物を、すぐそばに並べる
	fl.ground.add_corpse(best + Vector2(-60, 40))
	var i := 0
	for id in ["kuro_take", "tomoshi_take", "hikari_goke", "iki_take", "zui_mitsu", "shinju_gai", "potion", "relic_gear"]:
		fl.ground.add_item(best + Vector2(-60 + i * 22, 70), id)
		i += 1
	var c := m.cell_of(best)
	m.compute_visible(c.x, c.y, 11)
	for k in m.visible.size():
		if m.visible[k] == 1:
			m.explored[k] = 1
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.4, 2.4)
	cam.position = best + Vector2(0, 20)
	root.add_child(cam)
	fl.light_pos = best
	for k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/ground_f%02d.png" % [out, fno])
	quit()
