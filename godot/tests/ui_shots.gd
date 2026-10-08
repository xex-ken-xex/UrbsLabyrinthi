extends SceneTree
## 画面の確認用:  xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/ui_shots.gd -- 出力フォルダ
## タイトル、キャラ作成、街と各店、持ち物、迷宮の戦闘を撮る。

var out := "/tmp"
var main: Node

func _initialize() -> void:
	call_deferred("_run")

func shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/ui_%s.png" % [out, name])

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	await shot("title")
	main.show_make()
	await shot("make")
	var make: CharaMake = main.screen
	make._select(2)
	await shot("make2")
	make._on_start()
	await process_frame
	var town: TownScreen = main.screen
	await shot("town")
	town._go("smith")
	town.sel_id = "longsword"
	town._fill_shop()
	await shot("smith")
	town._go("magic")
	town.sel_id = "tome_sleep"
	town._fill_shop()
	await shot("magic")
	town._go("temple")
	main.gs.party[1].hp = 0.0
	town._refresh_all()
	await shot("temple")
	town._go("inn")
	await shot("inn")
	town._go("pleasure")
	town._push_walk(TownScreen.WALK_LINES[0])
	town._push_walk(TownScreen.FORTUNES[1])
	await shot("pleasure")
	town._go("general")
	await shot("general")
	main.open_inventory()
	main.inventory._set_tab("equip")
	main.inventory.sel_id = "dagger"
	main.gs.add_item("dagger")
	main.inventory._refresh()
	await shot("inventory")
	main.inventory._set_tab("skill")
	main.inventory.member = 2
	main.inventory.sel_id = String(main.gs.party[2].skills[0])
	main.inventory._refresh()
	await shot("skills")
	main.close_inventory()
	main.gs.party[1].hp = float(main.gs.party[1].max_hp())
	main._on_dive()
	for i in 5:
		await physics_frame
	var fl: FloorInstance = main.current
	# 敵の群れのそばまで歩いて、戦わせる
	var m := fl.map
	var best: Enemy = null
	for e in fl.enemies:
		if best == null or e.position.distance_to(main.leader().position) < best.position.distance_to(main.leader().position):
			best = e
	var flow := m.compute_flow(m.cell_of(best.position).x, m.cell_of(best.position).y, 400)
	var lead: Hero = main.leader()
	for i in 1500:
		var c := m.cell_of(lead.position)
		if lead.position.distance_to(best.position) < 90.0:
			break
		var nx := m.flow_step(flow, c, true)
		if nx.x >= 0:
			lead.cmd = {"move": (m.center_of(nx) - lead.position).normalized(), "guard": false, "dodge": false}
		await physics_frame
	lead.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
	for i in 50:
		await physics_frame
	await shot("fight")
	for i in 70:
		lead.cmd = {"move": (best.position - lead.position).normalized() if is_instance_valid(best) and not best.dead else Vector2.ZERO, "guard": false, "dodge": false}
		await physics_frame
	await shot("fight2")
	print("saved")
	quit()
