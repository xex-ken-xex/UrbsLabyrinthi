extends SceneTree
## 魔物の特徴 第三弾の見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/traits3_shot.gd -- 出力フォルダ
## traits3_1.png 詠唱するメイジ(紫の輪と呪文の名前、ブツブツ…)、絡みつく蔓、魅了された仲間
## traits3_2.png 金縛りの仲間、跳ね返す成竜(フンッ!)、効かない炎の精霊、霧になる吸血鬼
func _initialize() -> void:
	call_deferred("_run")

func _line(index: String) -> Dictionary:
	for m in EncounterGen.data()["monsters"]:
		if String(m["i"]) == index:
			return EncounterGen.mon_line({"m": m, "n": 1, "world": ""})
	return {}

func _spawn(ar: Arena, index: String, pos: Vector2) -> Enemy:
	var en := Enemy.new()
	en.setup(ar.fl, _line(index), {"id": 900, "kind": "beast"}, pos)
	en.state = "chase"
	en.disguised = false
	en.lurk = ""
	en.speed = 1.0
	en.died.connect(ar.fl._on_enemy_died)
	ar.fl.add_child(en)
	ar.fl.enemies.append(en)
	return en

func _shot(path: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _idle(main: Node, n: int) -> void:
	for i in n:
		main.leader().cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		await physics_frame

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	main.show_make()
	await process_frame
	main.screen._on_start()
	await process_frame
	main.start_arena()
	for i in 5:
		await physics_frame
	var ar: Arena = main.arena
	ar.set_all_levels(5)
	ar.set_theme("fuyou")
	var h0: Hero = main.heroes[0]
	var h1: Hero = main.heroes[1]
	for h in main.heroes:
		h.iframes = 1e9
	h0.position = Vector2(240, 250)
	h1.position = Vector2(250, 330)
	var dr := _spawn(ar, "dryad", Vector2(420, 380))
	dr.spells = ["vine"]
	dr.spell_cds = {"vine": 0.0}
	var lm := _spawn(ar, "lamia", Vector2(430, 180))
	lm.spells = ["charm"]
	lm.spell_cds = {"charm": 0.0}
	await _idle(main, 70)
	var mg := _spawn(ar, "mage", Vector2(420, 260))
	mg.spells = ["fire_bolt"]
	mg.spell_cds = {"fire_bolt": 0.0}
	await _idle(main, 26)
	await _shot(out + "/traits3_1.png")
	ar.clear_enemies()
	h0.stuck_t = 0.0
	h1.stuck_t = 0.0
	h0.confuse_t = 0.0
	h1.confuse_t = 0.0
	h0.position = Vector2(240, 250)
	h1.position = Vector2(250, 330)
	var cf := _spawn(ar, "cult-fanatic", Vector2(400, 330))
	cf.spells = ["hold"]
	cf.spell_cds = {"hold": 0.0}
	var dg := _spawn(ar, "adult-red-dragon", Vector2(560, 200))
	var fe := _spawn(ar, "fire-elemental", Vector2(380, 160))
	var vp := _spawn(ar, "vampire-vampire", Vector2(560, 380))
	await _idle(main, 70)
	dg.apply_stun(1.0)
	fe.elem_hit("fire", true)
	fe.take_damage(10.0, Vector2.RIGHT, h0)
	vp.take_damage(99999.0, Vector2.RIGHT, null)
	await _idle(main, 14)
	await _shot(out + "/traits3_2.png")
	print("saved")
	quit()
