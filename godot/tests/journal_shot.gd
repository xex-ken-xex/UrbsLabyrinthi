extends SceneTree
## 冒険日記帳と実績の見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/journal_shot.gd -- 出力フォルダ
## journal.png 冒険日記帳の欄 / trophies.png 実績の欄 / trophy_fx.png 迷宮で実績を取ったとき
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
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	for i in 10:
		await physics_frame
	var gs: GameState = main.gs
	# 第1層の魔物の半分ほどを見かけて、そのうちいくつかを倒したことにする
	var mons: Array = Journal.layer(1)["mons"]
	for i in mons.size():
		if i % 2 == 0:
			Journal.see(gs, String(mons[i]), 1)
			if i % 4 == 0:
				for k in i + 1:
					Journal.kill(gs, String(mons[i]))
	Journal.best(gs, "deepest", 1)
	Trophies.evaluate(gs)
	var en: Enemy = null
	for e in main.current.enemies:
		if not e.dead:
			en = e
			break
	gs.journal["trophies"].erase("seen_25")
	Journal.bump(gs, "cook_great")
	main._check_trophies()
	for i in 20:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		await physics_frame
	await _shot(out + "/trophy_fx.png")
	main.open_inventory()
	await process_frame
	main.inventory._set_tab("journal")
	main.inventory._on_pick(main.inventory.ids.find(String(mons[4])))
	await _shot(out + "/journal.png")
	main.inventory._set_tab("trophy")
	main.inventory._on_pick(main.inventory.ids.find("layer_all_1"))
	await _shot(out + "/trophies.png")
	print("saved")
	quit()
