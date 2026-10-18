extends SceneTree
## 潜行許可証の等級(ken 10/16、10/18): Godot --headless --path godot -s res://tests/permit_test.gd
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	print("[等級の決まり]")
	var gs := GameState.new()
	var party: Array = []
	for cls in ["fighter", "cleric", "rogue"]:
		party.append(Character.create(cls, "human", cls, Jobs.auto_stats(cls)))
	gs.new_game(party)
	check(gs.permit == 0 and Permit.rank_name(gs) == "灰" and Permit.max_layer(gs) == 2, "はじめは灰等級、第2層まで")
	check(Permit.NAMES == GroundItems.RANKS, "等級の名前は、遺体の認識票と同じ")
	check(Permit.layer_of(10) == 2 and Permit.layer_of(11) == 3 and Permit.layer_of(30) == 10, "階の通し番号から層が分かる(第10階は第2層、第11階は第3層)")
	check(Permit.allows_floor(gs, 10) and not Permit.allows_floor(gs, 11), "灰等級では、第3層の階に入れない")
	check(Permit.renew(gs) == "" and gs.permit == 0, "層の主を倒していなければ、上がらない")
	gs.journal["trophies"]["boss_2"] = 1
	var line := Permit.renew(gs)
	check(gs.permit == 1 and line.contains("青銅等級") and Permit.allows_floor(gs, 14) and not Permit.allows_floor(gs, 19), "第2層の主を倒すと青銅等級(第4層まで) %s" % line)
	gs.journal["trophies"]["boss_6"] = 1
	Permit.renew(gs)
	check(gs.permit == 3 and Permit.max_layer(gs) == 10 and Permit.next_hint(gs) == "", "第6層の主で黒鉄等級(竜の巣まで)")
	check(gs.save(), "記録できる")
	var gs2 := GameState.new()
	check(gs2.load_save() and gs2.permit == 3, "等級を記録する")
	var old := gs.to_dict()
	old.erase("permit")
	old["journal"]["trophies"] = {}
	old["journal"]["stats"]["deepest"] = 5
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(gs2.load_save() and gs2.permit == 2, "等級の無い古い記録は、もう着いた層まで潜れる等級にする(第5層 → 銀)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))

	print("[迷宮で]")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "human"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	for i in 5:
		await physics_frame
	main.enter_floor(10, "up")
	for i in 3:
		await physics_frame
	var fl: FloorInstance = main.current
	check(fl.floor_no == 10, "第2層のいちばん下の階へ")
	fl.traps.clear()
	fl.trap_at.clear()
	fl.spawner.pending.clear()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
	main.place_party(fl.map.center_of(fl.down_cell))
	main._update_hint()
	check(String(main.hud.hint).contains("許可証"), "下り階段の案内に、入れないと出る (%s)" % main.hud.hint)
	main.interact()
	await physics_frame
	var said := false
	for l in main.hud.log_lines:
		said = said or String(l["text"]).contains("灰等級の許可証では入れない")
	check(main.current.floor_no == 10 and said, "灰等級では、第3層へ降りられない")
	if not fl.ropes.is_empty():
		main.place_party(fl.map.center_of(fl.ropes[0]))
		main.open_rope_menu(fl.ropes[0])
		var has_down := false
		if main.rope_menu != null:
			for b in main.rope_menu.find_children("*", "Button", true, false):
				has_down = has_down or (b as Button).text.contains("下りる")
			main._on_rope_choice("")
		check(not has_down, "縄梯子でも、第3層へは下りられない")
	main.gs.journal["trophies"]["boss_2"] = 1
	main.go_town(["テスト"])
	for i in 3:
		await process_frame
	var town := main.screen as TownScreen
	check(main.gs.permit == 1 and town.report.any(func(l): return String(l).contains("青銅等級")), "層の主を倒して街へ戻ると、窓口で青銅等級に書き換わる")
	var stamp := false
	for n in town.find_children("*", "", true, false):
		if n is Sfx and (n as Sfx).text == "ポンッ":
			stamp = true
	check(stamp, "書き換えると「ポンッ」")
	town._go("guild")
	await process_frame
	var txt := ""
	for l in town.content.find_children("*", "Label", true, false):
		txt += (l as Label).text
	check(txt.contains("許可証課") and txt.contains("青銅等級(第4層まで)") and txt.contains("第4層の主を倒せば"), "坑口館で、いまの等級と次の条件が見える")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
