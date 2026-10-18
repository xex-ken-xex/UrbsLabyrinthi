extends SceneTree
## 冒険日記帳と実績:  godot --headless --path godot -s res://tests/journal_test.gd
## 魔物を見かける・倒すと日記帳に載る、記録に残る、実績を取ると知らせる、持ち物の画面の二つの欄。

var fails := 0
var main: Node

func check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _initialize() -> void:
	call_deferred("_run")

func _step(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_test_catalog()
	await _test_dungeon()
	_test_state()
	await _test_screen()
	await _test_town()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _new_game() -> void:
	if main != null:
		main.queue_free()
		await _step(2)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)

func _test_catalog() -> void:
	print("[catalog]")
	check(Journal.layer_ids().size() == 10 and Journal.layer(1)["mons"].size() > 10, "層は10、第1層の魔物は %d種" % Journal.layer(1)["mons"].size())
	var first := String(Journal.layer(1)["mons"][0])
	check(String(Journal.mon(first).get("name", "")) != "" and (Journal.mon(first)["layers"] as Array).any(func(x): return int(x) == 1), "層の魔物に、名前と出る層がある (%s)" % first)
	check(Trophies.ids().size() == Trophies.LIST.size() + 9 and not Trophies.ids().has("layer_all_2") and Trophies.name_of("layer_all_1") == "第1〜2層 狩り尽くし",
		"実績は %d。顔ぶれが同じ第1層と第2層の狩り尽くしは一つ" % Trophies.ids().size())

func _test_dungeon() -> void:
	print("[dungeon]")
	await _new_game()
	main._set_screen(null)
	main.start_day()
	await _step(5)
	var gs: GameState = main.gs
	check(Journal.stat(gs, "deepest") == 1, "第1層に着いたことが残る")
	main.current.spawner.spawn_all()      # 層の魔物は、近づくまで出ないので、先に全部出す
	var en: Enemy = null
	for e in main.current.enemies:
		if not e.dead:
			en = e
			break
	var idx := String(en.mon["index"])
	main._on_enemy_seen(en)
	check(Journal.seen(gs, idx) == 1 and String(gs.journal["first"].get(idx, "")).contains("第1層"), "見かけた魔物が日記帳に載る (%s)" % idx)
	main._on_enemy_seen(en)
	check(Journal.seen(gs, idx) == 2 and Journal.seen_species(gs) == 1, "同じ種類は、数だけ増える")
	en.take_damage(99999.0, Vector2.RIGHT, main.heroes[0])
	await _step(3)
	check(Journal.killed(gs, idx) == 1 and Trophies.has(gs, "first_kill"), "倒すと数えられ、実績「初めての獲物」を取る")
	check(main.current.get_children().any(func(n): return n is Sfx and (n as Sfx).text == "パンパカパーン!"), "実績を取ると、パンパカパーン!")
	main.current.stat.emit("mimic_bite")
	check(Trophies.has(gs, "mimic"), "ミミックに張りつかれると、実績「宝箱に噛まれた」")
	var other: Enemy = null
	for e in main.current.enemies:
		if not e.dead and String(e.mon["index"]) != idx:
			other = e
			break
	if other != null:
		other.seen_noted = false
		other.disguised = false
		var m: FloorMap = main.current.map
		var c := m.cell_of(other.position)
		m.visible[m.idx(c.x, c.y)] = 1
		other._physics_process(0.016)
		check(Journal.seen(gs, String(other.mon["index"])) >= 1, "魔物が見えると、日記帳に知らせる")

func _test_state() -> void:
	print("[state]")
	var gs: GameState = main.gs
	for id in Journal.layer(1)["mons"]:
		Journal.kill(gs, String(id))
	var won := Trophies.evaluate(gs)
	check(won.has("layer_all_1") and Journal.layer_progress(gs, 1).x == Journal.layer_progress(gs, 1).y, "第1層の魔物を全種倒すと、実績「第1層 狩り尽くし」")
	check(not won.has("layer_all_2") or Journal.layer_progress(gs, 2).x == Journal.layer_progress(gs, 2).y, "ほかの層は、全種倒すまで取れない")
	var rid := ""
	for r in Cooking.recipes():
		if (r["in"] as Dictionary).keys().all(func(k): return ItemDB.ITEMS.has(String(k))):
			rid = String(r["id"])
			for k in r["in"]:
				gs.add_item(String(k), int(r["in"][k]))
			break
	var res := Cooking.cook(gs, rid, 20)
	check(bool(res.get("ok", false)) and Journal.stat(gs, "cook_great") == 1 and Trophies.evaluate(gs).has("good_meal"), "上出来に作ると、実績「美味しいご飯が炊けた」")
	var d := gs.to_dict()
	var g2 := GameState.new()
	g2.journal = Journal.sanitize(JSON.parse_string(JSON.stringify(d))["journal"])
	check(Journal.killed(g2, String(Journal.layer(1)["mons"][0])) >= 1 and Trophies.has(g2, "layer_all_1") and Journal.stat(g2, "cook_great") == 1, "記録に残る")
	check(Journal.sanitize("壊れた").has("seen") and Journal.sanitize({}).has("trophies"), "古い記録・壊れた記録でも、空の日記帳になる")

func _test_screen() -> void:
	print("[screen]")
	main.open_inventory()
	await _step(2)
	var inv: InventoryScreen = main.inventory
	inv._set_tab("journal")
	check(inv.item_list.item_count > 100 and inv.ids.has("hdr:1"), "冒険日記帳の欄に、層ごとの魔物が並ぶ (%d行)" % inv.item_list.item_count)
	var unseen := ""
	for id in Journal.layer(5)["mons"]:
		if Journal.seen(main.gs, String(id)) == 0:
			unseen = String(id)
			break
	var i := inv.ids.find(unseen)
	check(i >= 0 and inv.item_list.get_item_text(i).contains("？？？"), "見かけていない魔物は ？？？")
	inv._on_pick(inv.ids.find("giant-rat") if Journal.seen(main.gs, "giant-rat") > 0 else inv.ids.find(String(Journal.layer(1)["mons"][0])))
	check(inv.detail.text.contains("倒した") and inv.detail.text.contains("第1層"), "選ぶと、見かけた数・倒した数・出る層が出る")
	inv._set_tab("trophy")
	check(inv.item_list.item_count == Trophies.ids().size() and inv.item_list.get_item_text(inv.ids.find("first_kill")).begins_with("★"), "実績の欄: 取ったものは ★")
	inv._on_pick(inv.ids.find("layer_all_9"))
	check(inv.detail.text.contains("まだ解除していない") and inv.detail.text.contains("種"), "まだの実績は、進み具合が出る (%s)" % inv.detail.text.replace("\n", " | ").left(300))
	main.close_inventory()
	await _step(2)

func _test_town() -> void:
	print("[town]")
	var gs: GameState = main.gs
	main.go_town(["テスト"])
	await _step(3)
	var town := main.screen as TownScreen
	check(town != null, "街へ戻れる")
	gs.bank_silver = 5000
	town._buy_house()
	check(Trophies.has(gs, "home") and town.msg.text.contains("パンパカパーン!"), "家を買うと、帯に実績の一行 (%s)" % town.msg.text.right(40))
	Journal.bump(gs, "wipes")
	main.go_town([])
	await _step(3)
	var rep: Array = (main.screen as TownScreen).report
	check(rep.any(func(l): return String(l).contains("灯手隊の世話")), "街へ戻った報告に、取った実績の一行")
