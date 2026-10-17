extends SceneTree
## 燐の流れ(PR 4):  godot --headless --path godot -s res://tests/flow_test.gd
## 層ごとの燐晶の量(数理モデルの kg_floor)、吐く夜に下の層から上がる魔物、放っておいた遺体が骨亡者になって降りる、
## 全滅して失った物が溜まり場に積もり取り戻せる、第7層から下の吐く夜の竜の気配(熱い縁、焦げた遺体、硫黄の華)。

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
	_test_kg()
	_test_below()
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
	await _test_risen()
	await _test_exhale_below()
	await _test_sump()
	await _test_hot()
	await _test_wipe()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

## 階に置かれる燐晶(宝の山 + 露頭)の7夜の平均が、層の目安 kg_floor × CRYSTAL_SCALE に近い
func _test_kg() -> void:
	print("[層ごとの燐晶の量]")
	for layer in range(1, 11):
		var L := PhosFlow.layer_info(layer)
		check(not L.is_empty(), "第%d層の目安がある" % layer)
		if L.is_empty():
			continue
		var depth := 0
		for i in range(1, Balance.MAX_FLOOR + 1):
			if int(Abyss.floor_info(i).get("layer", 0)) == layer:
				depth = i
				break
		var sum := 0.0
		var nights := 4
		for n in nights:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			for e in f.ground.entries:
				if String(e["kind"]) == "crystal" and not e.get("sump", false):
					sum += float(e["kg"])
			f.free()
		var avg := sum / nights / Balance.CRYSTAL_SCALE
		var target := float(L["kg_floor"])
		check(absf(avg - target) <= target * 0.25, "第%d層(第%d階): 平均 %.0fkg、目安 %.0fkg(×%.1f で %.1fkg が床に)" % [layer, depth, avg, target, Balance.CRYSTAL_SCALE, avg * Balance.CRYSTAL_SCALE])

func _test_below() -> void:
	print("[下の層]")
	var f := FloorInstance.create(FloorMap.floor_path(10, 0, 4))      # 第2層
	var b := PhosFlow.below(f, 1)
	check(String(b.get("theme", "")) == "sabi" and int(b["level"]) == 3, "第2層の下は錆鉄の坑道(レベル3) %s" % str(b))
	f.free()
	f = FloorInstance.create(FloorMap.floor_path(1, 0, 4))           # 第1層
	b = PhosFlow.below(f, 1)
	check(String(b.get("theme", "")) == "fuyou" and int(b["level"]) == 2, "第1層の下は同じ腐葉で、少し強い(レベル2) %s" % str(b))
	f.free()
	f = FloorInstance.create(FloorMap.floor_path(29, 0, 4))          # 第9層
	b = PhosFlow.below(f, 9)
	check(int(b.get("level", 99)) <= 9 + PhosFlow.BELOW_LEVEL_MAX, "第9層の下(竜の巣の層)の群れは、強すぎない %s" % str(b))
	f.free()
	f = FloorInstance.create(FloorMap.floor_path(30, 0, 4))
	check(PhosFlow.below(f, 15).is_empty(), "竜の巣の層の下は無い")
	f.free()

## 放っておいた遺体は、次の夜、一つ下の階に骨亡者の群れになって出る。調べた遺体は起き上がらない
func _test_risen() -> void:
	print("[骨亡者が降りてくる]")
	var gs: GameState = main.gs
	var fl: FloorInstance = main.current
	var corpses: Array = []
	for e in fl.ground.entries:
		if String(e["kind"]) == "corpse":
			corpses.append(e)
	check(not corpses.is_empty(), "第1階に遺体がある (%d)" % corpses.size())
	fl.map.explored.fill(0)
	check(PhosFlow.unattended(fl) == 0, "見つけていない遺体は放っておいたことにならない")
	for e in corpses:
		var c: Vector2i = fl.map.cell_of(e["pos"])
		fl.map.explored[fl.map.idx(c.x, c.y)] = 1
	var u := PhosFlow.unattended(fl)
	check(u == corpses.size(), "見つけて調べなかった遺体を数える (%d)" % u)
	var risen := PhosFlow.end_dive(gs, main.floors)
	check(risen == u and gs.flow["risen"].has("2"), "潜行が終わると、第2階に骨亡者が降りる(%d体ぶん)" % risen)
	var r: Dictionary = gs.flow["risen"].get("2", {})
	check(int(r.get("day", -1)) == gs.day + 1 and int(r.get("n", 0)) >= 1 and int(r["n"]) <= PhosFlow.RISEN_MAX, "次の夜に、%d体" % int(r.get("n", 0)))
	# 調べた遺体は起き上がらない
	gs.flow["risen"].clear()
	for e in corpses:
		e["searched"] = true
	check(PhosFlow.end_dive(gs, main.floors) == 0 and gs.flow["risen"].is_empty(), "調べた遺体は起き上がらない")
	for e in corpses:
		e["searched"] = false
	# 次の夜、第2階に着くと、骨亡者が歩き回っている
	gs.flow["risen"] = {"2": {"n": 3, "day": gs.day}}
	main.enter_floor(2, "up")
	await _step(3)
	var f2: FloorInstance = main.current
	var bones := 0
	for en in f2.enemies:
		if not en.dead and String(en.display_name) == "骨亡者" and f2.wanderers.has(en.enc_id):
			bones += 1
	check(bones == 3, "第2階に着くと、骨亡者が3体歩き回っている (%d)" % bones)
	var w_before := f2.wanderers.size()
	main.enter_floor(1, "down")
	main.enter_floor(2, "up")
	await _step(2)
	check(main.current.wanderers.size() == w_before, "同じ夜に戻っても、二度は降りてこない")
	gs.flow["risen"].clear()

## 吐く夜の夜の間は、ワンダリング・モンスターに一つ下の層の魔物が混じる。静かな夜は混じらない
func _test_exhale_below() -> void:
	print("[吐く夜に下の層の魔物が上がる]")
	var fl: FloorInstance = main.current
	var dt: DungeonTime = main.dtime
	fl.exhale = false
	var n_below := 0
	for i in 20:
		_spawn(dt)
	for en in fl.enemies:
		if en.mon.get("below", false):
			n_below += 1
	check(n_below == 0, "静かな夜は、下の層の魔物は出ない")
	fl.exhale = true
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.NIGHT_MIN + 30.0
	check(dt.exhaling(), "吐く夜の夜")
	for i in 30:
		_spawn(dt)
	var groups := {}
	for en in fl.enemies:
		if en.mon.get("below", false):
			groups[en.enc_id] = true
	check(groups.size() >= 5, "吐く夜は、下の層から上がってきた群れが混じる (%d組)" % groups.size())
	for en in fl.enemies.duplicate():
		en.dead = true
	fl.wanderers.clear()
	fl.exhale = false
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + 1440.0 + Balance.DIVE_START_MIN

func _spawn(dt: DungeonTime) -> void:
	var fl: FloorInstance = main.current
	fl.wanderers.clear()       # 上限を外して、何組も出す
	dt.spawn_wanderer(false, true, false)

## 全滅して失った物は、溜まり場に積もり、拾うと取り戻せる
func _test_sump() -> void:
	print("[溜まり場で取り戻す]")
	var gs: GameState = main.gs
	check(not PhosFlow.to_sump(gs, 27, {"potion": 1}, {}), "第7層で失った物は、溜まり場へは落ちない")
	check(PhosFlow.to_sump(gs, 5, {"potion": 2, "longsword": 1}, {"low": 0.8}), "第1層で失った物は、溜まり場へ落ちる")
	var units := 0
	for r in gs.flow["sump"]:
		units += int(r["n"])
	check(units == 3 and absf(float(gs.flow["sump_kg"].get("low", 0.0)) - 0.4) < 0.01, "品3つと、燐晶の半分 (%d、%.2fkg)" % [units, float(gs.flow["sump_kg"].get("low", 0.0))])
	PhosFlow.to_sump(gs, 5, {"relic_tag": 100}, {})
	units = 0
	for r in gs.flow["sump"]:
		units += int(r["n"])
	check(units == PhosFlow.SUMP_MAX, "溜まり場は%d品まで(古いものから流れて消える) (%d)" % [PhosFlow.SUMP_MAX, units])
	gs.flow["sump"] = [{"id": "potion", "n": 2, "day": gs.day, "room": 0}, {"id": "longsword", "n": 1, "day": gs.day, "room": 0}]
	gs.flow["sump_kg"] = {"low": 0.4}
	main.enter_floor(PhosFlow.SUMP_FLOOR, "up")
	await _step(2)
	var fl: FloorInstance = main.current
	var lost: Array = []
	var kg := 0.0
	for e in fl.ground.entries:
		if e.get("sump", false):
			if String(e["kind"]) == "crystal":
				kg += float(e["kg"])
			else:
				lost.append(e)
	check(lost.size() == 3 and absf(kg - 0.4) < 0.01, "第26階の溜まり場に、失くした品が3つと燐晶 %.2fkg" % kg)
	var room_ok := true
	for e in lost:
		var c: Vector2i = fl.map.cell_of(e["pos"])
		var rid := fl.map.room_at[fl.map.idx(c.x, c.y)]
		if rid < 0 or String(fl.map.room_by_id[rid].get("kind", "")) != "sump":
			room_ok = false
	check(room_ok, "品は溜まり場の部屋の中にある")
	check(PhosFlow.sump_has_lost(fl, PhosFlow.sump_rooms(fl)[0]), "部屋に入ると「見覚えのある品」とログに出る")
	var had := gs.count("longsword")
	for e in lost:
		if String(e["id"]) == "longsword":
			main._on_ground_picked(e, main.leader())
			fl.ground.entries.erase(e)
	check(gs.count("longsword") == had + 1, "拾うと持ち物に戻る")
	var left := 0
	for r in gs.flow["sump"]:
		left += int(r["n"])
	check(left == 2, "拾った分だけ、溜まり場から減る (%d)" % left)
	gs.flow["sump"] = []
	gs.flow["sump_kg"] = {}

## 第7層から下の吐く夜: 焦げた遺体、縁の硫黄の華、夜の間は縁が熱い
func _test_hot() -> void:
	print("[竜の気配]")
	var gs: GameState = main.gs
	main.floors.erase(27)
	var saved_day := gs.day
	gs.day = 2         # 第三節の夜(吐く夜)
	main.enter_floor(27, "up")
	await _step(2)
	var fl: FloorInstance = main.current
	check(fl.exhale and PhosFlow.hot_floor(fl), "第27階の吐く夜は、竜の気配がする")
	var scorched := 0
	var sulfur := 0
	for e in fl.ground.entries:
		if String(e["kind"]) == "corpse" and e.get("scorched", false):
			scorched += 1
		if String(e["id"]) == "iou_hana":
			sulfur += 1
	check(scorched >= 1, "焦げた遺体がある (%d / 遺体 %d)" % [scorched, fl.ground.entries.filter(func(e): return String(e["kind"]) == "corpse").size()])
	check(sulfur >= int(PhosFlow.SULFUR_N[0]), "縦穴の縁に硫黄の華 (%d)" % sulfur)
	check(ItemDB.item_name("iou_hana") == "硫黄の華" and ItemIcons.texture("iou_hana") != null, "硫黄の華は品物で、絵がある")
	var dt: DungeonTime = main.dtime
	dt.resting = false
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.DIVE_START_MIN + 60.0
	await _step(2)
	check(not fl.hot, "昼の間は、縁は熱くない")
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.NIGHT_MIN + 30.0
	dt.update(0.0)
	await _step(1)
	check(fl.hot, "吐く夜の夜の間は、縁が熱い")
	var lead: Hero = main.leader()
	var sh: Dictionary = fl.map.data["shaft"]
	var C := float(Balance.CELL)
	lead.position = Vector2((float(sh["x"]) - 0.5) * C, (float(sh["y"]) + float(sh["h"]) / 2.0) * C)
	check(fl.abyss.on_rim(lead.position), "先頭は縁に立っている")
	lead.iframes = 0.0
	lead.ch.hp = lead.ch.max_hp()
	var hp0 := lead.ch.hp
	for i in 30:
		PhosFlow.heat(main, fl, 0.1)
	check(lead.ch.hp < hp0, "熱い縁に立つと焼ける (%.0f → %.0f)" % [hp0, lead.ch.hp])
	check(fl.visited_rooms.has("hot"), "初めて焼けたとき、ログに一行")
	lead.iframes = 1e9
	lead.ch.hp = lead.ch.max_hp()
	gs.day = saved_day
	main.floors.erase(27)
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + 1440.0 + Balance.DIVE_START_MIN

## 第1層で全滅すると、装備と持ち物が溜まり場へ落ちる
func _test_wipe() -> void:
	print("[全滅して失った物]")
	var gs: GameState = main.gs
	main.enter_floor(3, "up")
	await _step(2)
	gs.flow["sump"] = []
	gs.add_item("potion", 2)
	var equipped := 0
	for c in gs.party:
		for slot in c.equip:
			if String(c.equip[slot]) != "":
				equipped += 1
	main.dive_insured = false
	for h in main.heroes:
		h.down = true
		h.ch.hp = 0.0
	main._check_wipe()
	var units := 0
	for r in gs.flow["sump"]:
		units += int(r["n"])
	check(units >= mini(PhosFlow.SUMP_MAX, equipped + 2), "失った装備と持ち物が溜まり場へ (%d品、装備は%d)" % [units, equipped])
	var lines := ""
	for o in main.hud.overlay:
		lines += String(o.get("text", ""))
	check(lines.contains("溜まり場"), "全滅の報告に、溜まり場の一行")
