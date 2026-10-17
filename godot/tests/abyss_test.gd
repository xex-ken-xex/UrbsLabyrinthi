extends SceneTree
## 縦穴のまわり(PR 3):  godot --headless --path godot -s res://tests/abyss_test.gd
## 断面のデータ、縦穴を覗く(下の階の重なり、一度だけの擬音とログと実績)、縄梯子(下りる・登る、〈運動〉、外すと傷)、
## 竪坑の底の溜まり場、迷宮の断面の欄。

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
		await process_frame

func _run() -> void:
	_test_data()
	_test_floors()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	await _step(5)
	for h in main.heroes:
		h.iframes = 1e9
	await _test_peer()
	await _test_rope()
	await _test_section_tab()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _test_data() -> void:
	print("[断面のデータ]")
	var fs: Array = Abyss.data().get("floors", [])
	check(fs.size() == Balance.MAX_FLOOR, "section.json に全%d階" % fs.size())
	var mono := true
	for i in range(1, fs.size()):
		if float(fs[i]["top_m"]) < float(fs[i - 1]["top_m"]) + float(fs[i - 1]["h_m"]) - 0.01:
			mono = false
	check(mono, "階は上から順に重なる(深さが減らない)")
	var bottom := float(fs[-1]["top_m"]) + float(fs[-1]["h_m"])
	check(bottom > 190.0 and bottom < 210.0, "いちばん下は約200m (%.1fm)" % bottom)
	check(bool(fs[-1]["lair"]) and not bool(fs[-2]["lair"]), "竜の巣は第30階だけ")
	var w := int(Abyss.data()["well"])
	check((fs[0]["well"] as Array).size() == 2 * w + 1 and String(fs[0]["well"][w])[w] == "O", "縦穴のまわりの窓の真ん中は虚空")
	check(String(fs[0]["row"]).length() == int(fs[0]["w"]), "断面の一列は地図の幅")

func _test_floors() -> void:
	print("[階]")
	var f1 := FloorInstance.create(FloorMap.floor_path(1, 0, 4))
	check(f1.ropes.size() == 2, "第1階の縦穴の縁に縄梯子が2本 (%d)" % f1.ropes.size())
	check(f1.abyss != null and f1.abyss._ok, "第1階の縦穴は覗ける")
	var ok_cells := true
	for c in f1.ropes:
		if f1.map.solid(c.x, c.y):
			ok_cells = false
	check(ok_cells, "縄梯子は歩けるマス(縁の回廊の角)にある")
	f1.free()
	var f30 := FloorInstance.create(FloorMap.floor_path(30, 0, 4))
	check(f30.ropes.is_empty() and not f30.abyss._ok, "竜の巣の階には縄梯子も覗く穴も無い")
	f30.free()
	var f26 := FloorInstance.create(FloorMap.floor_path(26, 0, 4))
	var sumps := 0
	var near_items := 0
	for r in f26.map.rooms:
		if String(r.get("kind", "")) != "sump":
			continue
		sumps += 1
		var rr := Rect2(float(r["x"]) * Balance.CELL - 48.0, float(r["y"]) * Balance.CELL - 48.0, float(r["w"]) * Balance.CELL + 96.0, float(r["h"]) * Balance.CELL + 96.0)
		for e in f26.ground.entries:
			if rr.has_point(e["pos"]):
				near_items += 1
	check(sumps >= 3, "第26階(第6層のいちばん下)に竪坑の底の溜まり場 (%d)" % sumps)
	check(near_items >= sumps * 7, "溜まり場に、落ちてきた物が積もっている (%d)" % near_items)
	f26.free()

## 覗く度合いが落ち着くまで待つ(画面の無いテストでは、フレームの間隔がまちまち)
func _settle(fl: FloorInstance) -> void:
	for i in 600:
		await process_frame
		if fl.abyss.peer <= 0.0 or fl.abyss.peer >= 1.0:
			if i > 3:
				return

func _rim_pos(fl: FloorInstance) -> Vector2:
	var sh: Dictionary = fl.map.data["shaft"]
	return fl.map.center_of(Vector2i(int(sh["x"]) + 6, int(sh["y"]) - 1))

func _test_peer() -> void:
	print("[縦穴を覗く]")
	var fl: FloorInstance = main.current
	var lead: Hero = main.leader()
	check(not fl.abyss.visible, "縁にいないときは描かない")
	main.place_party(_rim_pos(fl))
	await _settle(fl)
	check(fl.abyss.visible and fl.abyss.peer >= 1.0, "縁に立つと、下の階が見える")
	check(fl.abyss.seen_once and Journal.stat(main.gs, "abyss") == 1, "初めて覗くと数えられる")
	check(Trophies.has(main.gs, "abyss"), "実績「深淵を覗く者」")
	var cues := 0
	for c in fl.get_children():
		if c is Sfx and (c as Sfx).text == "ヒュウゥ…":
			cues += 1
	check(cues == 1, "擬音 ヒュウゥ… が一つ")
	main.place_party(fl.map.center_of(fl.up_cell))
	await _settle(fl)
	check(not fl.abyss.visible, "縁を離れると消える")
	main.place_party(_rim_pos(fl))
	await _settle(fl)
	check(Journal.stat(main.gs, "abyss") == 1, "二度目は数えない(擬音とログも一度だけ)")
	var img_ok := fl.abyss._hole.size.x > 0.0
	check(img_ok, "縦穴の矩形がある")

func _test_rope() -> void:
	print("[縄梯子]")
	check(main.rope_dc(5.0) == 10 and main.rope_dc(15.0) == 14, "縄梯子の難易度は階の高さで決まる(5m 10、15m 14)")
	var fl: FloorInstance = main.current
	var rc: Vector2i = fl.ropes[0]
	main.place_party(fl.map.center_of(rc))
	await _step(3)
	main._update_hint()
	check(String(main.hud.hint).contains("縄梯子"), "縄梯子のそばで案内が出る (%s)" % main.hud.hint)
	main.interact()
	await _step(2)
	check(main.rope_menu != null and main.phase == "menu", "E で、下りるか登るかを選ぶ")
	var off: Vector2i = rc - fl.map.shaft_center
	var hp0 := 0.0
	for h in main.heroes:
		h.iframes = 0.0
		hp0 += h.ch.hp
	main._on_rope_choice("down")
	await _step(3)
	check(main.current.floor_no == 2, "下りると第2階へ (%d)" % main.current.floor_no)
	var at: Vector2i = main.current.map.cell_of(main.leader().position) - main.current.map.shaft_center
	check(absi(at.x - off.x) <= 2 and absi(at.y - off.y) <= 2, "下の階の同じ縁の角に着く (%s / %s)" % [at, off])
	check(Journal.stat(main.gs, "rope") == 1, "縄梯子を使った回数を数える")
	# 何度も下りて、外した者が傷を負うことを確かめる(難易度の高い骨の層)
	var hurt := false
	for i in 12:
		for h in main.heroes:
			h.ch.hp = h.ch.max_hp()
			h.down = false
			h.iframes = 0.0
		var before := 0.0
		for h in main.heroes:
			before += h.ch.hp
		main.enter_floor(27, "up")
		main.climb_rope(1, main.current.ropes[0])
		await _step(2)
		var after := 0.0
		for h in main.heroes:
			after += h.ch.hp
		if after < before:
			hurt = true
			break
	check(hurt, "〈運動〉を外すと、落ちて傷を負う")
	main.enter_floor(5, "up")
	main.climb_rope(-1, main.current.ropes[1])
	await _step(2)
	check(main.current.floor_no == 4, "登ると上の階へ")
	main.enter_floor(29, "up")
	main.climb_rope(1, main.current.ropes[0])
	await _step(2)
	check(main.current.floor_no == 30, "第29階の縄梯子は竜の巣の階へ下りる")
	for h in main.heroes:
		h.iframes = 1e9

func _test_section_tab() -> void:
	print("[迷宮の断面]")
	main.open_inventory()
	await _step(2)
	var iv: InventoryScreen = main.inventory
	iv._set_tab("section")
	await _step(2)
	check(iv.section_view.visible and iv.section_view.here == 30, "断面の欄に、いまの階の印 (%d)" % iv.section_view.here)
	check(iv.item_list.item_count == Balance.MAX_FLOOR, "階の一覧が全%d階" % iv.item_list.item_count)
	check(iv.section_view.known >= 30, "着いた最も深い階を覚えている (%d)" % iv.section_view.known)
	iv._on_pick(4)
	check(iv.section_view.selected == 5 and iv.detail.text.contains("第1層 5/5階"), "一覧で選んだ階を断面で囲む")
	main.close_inventory()
	await _step(2)
