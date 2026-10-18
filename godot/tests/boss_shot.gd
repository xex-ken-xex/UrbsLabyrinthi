extends SceneTree
## 層の主の見た目の確認用: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/boss_shot.gd -- 出力フォルダ 層
## 戦いの前(黄色の名前)、咆哮、モノクロと赤いダメージの数字、吹き飛ばしの構え を撮る。

var main: Node

func _initialize() -> void:
	call_deferred("_run")

func _step(n: int) -> void:
	for i in n:
		await process_frame

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("撮った ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var layer := int(args[1]) if args.size() > 1 else 1
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		var c := Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0]))
		chars.append(c)
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	await _step(3)
	main.enter_floor(LayerBoss.bottom_depth(layer), "up")
	await _step(3)
	var fl: FloorInstance = main.current
	fl.spawner.spawn_pending(fl.boss_enc)
	await _step(2)
	var bosses: Array = fl.enemies.filter(func(e): return e.unique)
	var b: Enemy = bosses[0]
	for e in fl.enemies:
		if e.enc_id == fl.boss_enc:
			e.state = "idle"
			e.asleep = true
	var spot := b.position + Vector2(-150, 0)
	for i in main.heroes.size():
		var h: Hero = main.heroes[i]
		h.position = spot + Vector2(-(i % 2) * 24.0, (i - 1.5) * 24.0)
		h.iframes = 999.0
	main.trail = [main.leader().position]
	main._last_cell = Vector2i(-99, -99)
	await _step(20)
	await _shot(out, "boss_%d_before.png" % layer)
	fl.alert_encounter(fl.boss_enc)
	await _step(14)
	await _shot(out, "boss_%d_roar.png" % layer)
	await _step(90)
	for k in 6:
		for e in bosses:
			if is_instance_valid(e) and not e.dead and e.hp > 60.0:
				e.take_damage(37.0 + k * 3.0, Vector2.ZERO, main.leader())
		main.heroes[k % 4].iframes = 0.0
		main.heroes[k % 4].damage(6.0, b.position)
		main.heroes[k % 4].iframes = 999.0
		await _step(6)
	if is_instance_valid(b) and not b.dead:
		b.blast_cd = 0.0
		b.blast_t = LayerBoss.BLAST_WINDUP * 0.5
	await _step(2)
	await _shot(out, "boss_%d_fight.png" % layer)
	for e in bosses:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(1e9, Vector2.ZERO, main.leader())
	await _step(40)
	await _shot(out, "boss_%d_fallen.png" % layer)
	Journal.best(main.gs, "deepest_floor", LayerBoss.bottom_depth(layer))
	main.open_inventory()
	await process_frame
	main.inventory._set_tab("section")
	await _step(3)
	await _shot(out, "boss_%d_section.png" % layer)
	quit(0)
