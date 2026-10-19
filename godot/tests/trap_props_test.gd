extends SceneTree
## 罠の新しい仕掛け(暴走する鉱車・沈む渡し石・壁龕の頭蓋)と地物の絵(ken 10/19): Godot --headless --path godot -s res://tests/trap_props_test.gd

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

func _cued(fl: FloorInstance, text: String) -> bool:
	return fl.get_children().any(func(n): return n is Sfx and (n as Sfx).text == text)

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	await _step(5)
	_test_data()
	await _test_cart()
	await _test_sink()
	await _test_gaze()
	await _test_draw()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	DiveSave.clear()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

## 書き出した階: 鉱車は軌条の上、沈む石は浅瀬の上、頭蓋は行き止まりの壁龕。地物の絵がそろっている
func _test_data() -> void:
	print("[置き場所]")
	var pics := {}
	var carts := 0
	var cart_on_rail := 0
	var rails := 0
	var sinks := 0
	var sink_wet := 0
	var gazes := 0
	var gaze_ok := 0
	for night in 3:
		for f in range(1, Balance.MAX_FLOOR + 1):
			var fl := FloorInstance.create(main.floor_path(f, night))
			for p in fl.decor:
				pics[String(p["kind"])] = true
				if String(p["kind"]) == "rail":
					rails += 1
			for t in fl.traps:
				var c := Vector2i(int(t["x"]), int(t["y"]))
				match String(t["fx"]):
					"cart":
						carts += 1
						if not FloorProps.rail_at(fl, c).is_empty():
							cart_on_rail += 1
					"sink":
						sinks += 1
						if fl.map.tiles[fl.map.idx(c.x, c.y)] == FloorMap.SHALLOW:
							sink_wet += 1
					"gaze":
						gazes += 1
						var open := 0
						for d in FloorMap.DIRS4:
							if not fl.map.opaque(c.x + d.x, c.y + d.y):
								open += 1
						if t["st"] == "revealed" and t.has("face") and open == 1:
							gaze_ok += 1
			fl.free()
	check(rails > 0 and pics.has("cart"), "錆鉄に軌条と止まったトロッコがある (軌条 %d)" % rails)
	check(carts > 0 and cart_on_rail == carts, "暴走する鉱車の罠は、どれも軌条の上 (%d/%d)" % [cart_on_rail, carts])
	check(sinks > 0 and sink_wet == sinks, "沈む渡し石は、どれも浅瀬の上 (%d/%d)" % [sink_wet, sinks])
	check(gazes > 0 and gaze_ok == gazes, "壁龕の頭蓋は行き止まりにあり、隠れておらず、向きを持つ (%d/%d)" % [gaze_ok, gazes])
	var want := ["spring", "shrooms", "pump", "pump_sunk", "altar", "choir"]
	var missing := want.filter(func(k): return not pics.has(k))
	check(missing.is_empty(), "地物の絵(湧き水・茸の畝・揚水機・沈んだ揚水機・骨の祭壇・聖歌席)がどれも置かれる %s" % [missing])

## いまの階の、横にまっすぐ歩ける6マス以上の床(無ければ x = -1)
func _straight(fl: FloorInstance) -> Array:
	var m := fl.map
	for y in range(2, m.h - 2):
		var run := 0
		for x in range(1, m.w - 1):
			if not m.opaque(x, y) and m.tiles[m.idx(x, y)] != FloorMap.DOOR:
				run += 1
				if run >= 8:
					return [Vector2i(x - 7, y), Vector2i(x, y)]
			else:
				run = 0
	return [Vector2i(-1, -1), Vector2i(-1, -1)]

func _quiet(fl: FloorInstance) -> void:
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
	fl.spawner.pending.clear()
	for h in main.heroes:
		h.ch.hp = 500.0
		h.down = false
		h.stuck_t = 0.0
		h.fear_t = 0.0
		h.iframes = 0.0
		h.roll_t = 0.0
		h.knock = Vector2.ZERO

func _trap(fl: FloorInstance, c: Vector2i, fx: String) -> Dictionary:
	var t: Dictionary = fl.traps[0].duplicate()
	t["x"] = c.x
	t["y"] = c.y
	t["fx"] = fx
	t["st"] = "revealed"
	t["damage"] = "2d10"
	t["kind"] = "save"
	t["save"] = {"ability": "敏捷力", "dc": 99}
	t.erase("face")
	return t

func _dummy(fl: FloorInstance, pos: Vector2, type: String = "beast") -> Enemy:
	var e := Enemy.new()
	var mon := {"name": "Test", "name_ja": "試験体", "hp": 400, "ac": 10, "size": "M", "type": type, "xp": 10, "cr": 1,
		"speed": {"walk": 30}, "attacks": [{"n": "Bite", "b": 4, "d": "1d4 piercing"}]}
	e.setup(fl, mon, {"id": 998, "kind": "beast", "attitude": "敵対", "activity": ""}, pos)
	e.max_hp = 400
	e.hp = 400.0
	e.state = "idle"
	e.speed = 0.0
	e.dmg = 0.0
	e.asleep = true
	fl.add_child(e)
	fl.enemies.append(e)
	e.died.connect(fl._on_enemy_died)
	return e

func _test_cart() -> void:
	print("[暴走する鉱車]")
	var fl: FloorInstance = main.current
	_quiet(fl)
	var ab := _straight(fl)
	var a: Vector2i = ab[0]
	var b: Vector2i = ab[1]
	check(a.x >= 0, "試す床がある")
	var rail := {"kind": "rail", "x": a.x, "y": a.y, "x2": b.x, "y2": b.y}
	fl.decor.append(rail)
	var tc := a + Vector2i(2, 0)
	var t := _trap(fl, tc, "cart")
	var tf := TrapFx.make(fl, t, null)
	check(tf.start == fl.map.center_of(b) and tf.end == fl.map.center_of(a), "鉱車は軌条の遠いほうの端から、もう一方の端へ走る")
	tf.free()
	main.leader().position = main.random_room_pos(fl, -1)
	var en := _dummy(fl, fl.map.center_of(a + Vector2i(4, 0)))
	main._trigger_trap(t, en)
	await _step(2)
	check(_cued(fl, "ガタンゴトン…"), "踏むと「ガタンゴトン…」")
	await _step(120)
	check(en.hp < 400.0, "軌条の上の魔物が轢かれる (%.0f)" % en.hp)
	check(_cued(fl, "ガシャーン!"), "端まで走ると「ガシャーン!」")
	fl.decor.erase(rail)
	en.queue_free()
	fl.enemies.clear()

func _test_sink() -> void:
	print("[沈む渡し石]")
	var fl: FloorInstance = main.current
	_quiet(fl)
	var lead: Hero = main.leader()
	var tc := fl.map.cell_of(lead.position)
	var t := _trap(fl, tc, "sink")
	main._trigger_trap(t, lead)
	await _step(2)
	check(_cued(fl, "グラッ") and lead.stuck_t <= 0.0, "踏むと石が「グラッ」と傾く(まだ落ちない)")
	await _step(40)
	check(_cued(fl, "ザブン!") and lead.stuck_kind == "prone" and lead.stuck_t > 0.0 and lead.ch.hp < 500.0, "一拍おいて「ザブン!」、水に落ちて転ぶ")
	var light: float = lead.stuck_t
	# 重い鎧だと、起き上がるのに手間取る
	_quiet(fl)
	lead.ch.equip["armor"] = "plate"
	var t2 := _trap(fl, tc, "sink")
	main._trigger_trap(t2, lead)
	await _step(42)
	check(lead.stuck_t > light + 0.6, "重い鎧なら、水から上がるのに手間取る (%.1f秒 / 軽い鎧 %.1f秒)" % [lead.stuck_t, light])
	lead.ch.equip["armor"] = ""
	# すぐ降りれば落ちない
	_quiet(fl)
	var t3 := _trap(fl, tc, "sink")
	main._trigger_trap(t3, lead)
	await _step(1)
	lead.position += Vector2(Balance.CELL * 2.0, 0)
	for h in main.heroes:
		if fl.map.cell_of(h.position) == tc:
			h.position += Vector2(Balance.CELL * 2.0, 0)
	await _step(40)
	check(lead.stuck_t <= 0.0, "沈む前に降りれば、落ちない")
	# 水に棲む魔物は落ちない
	_quiet(fl)
	main.leader().position = main.random_room_pos(fl, -1)
	var fish := _dummy(fl, fl.map.center_of(tc))
	fish.traits["aquatic"] = true
	var t4 := _trap(fl, tc, "sink")
	main._trigger_trap(t4, fish)
	await _step(42)
	check(fish.hp == 400.0, "水に棲む魔物は、沈む石で落ちない")
	fish.queue_free()
	fl.enemies.clear()

func _test_gaze() -> void:
	print("[壁龕の頭蓋]")
	var fl: FloorInstance = main.current
	_quiet(fl)
	var ab := _straight(fl)
	var a: Vector2i = ab[0]
	var t := _trap(fl, a, "gaze")
	t["face"] = "e"
	var gz := TrapFx.make(fl, t, null)
	fl.add_child(gz)
	check(gz.line.size() >= 7 and gz.line.has(a + Vector2i(5, 0)), "視線は通路をまっすぐ届く (%dマス)" % gz.line.size())
	var lead: Hero = main.leader()
	for h in main.heroes:
		h.position = main.random_room_pos(fl, -1)
	lead.position = fl.map.center_of(a + Vector2i(4, 0))
	await _step(3)
	check(_cued(fl, "ギラッ") and lead.fear_t <= 0.0, "視線の先に立つと、目が光る「ギラッ」(まだ射すくめない)")
	await _step(40)
	check(_cued(fl, "ギンッ!") and lead.fear_t > 0.0 and lead.ch.hp < 500.0, "一拍おいて「ギンッ!」、射すくめられて怯える")
	# 光っている間に視線から外れれば、無事
	_quiet(fl)
	gz.tick = 0.0
	gz.glare_t = -1.0
	lead.position = fl.map.center_of(a + Vector2i(3, 0))
	await _step(3)
	lead.position = main.random_room_pos(fl, -1)
	await _step(40)
	check(lead.fear_t <= 0.0, "目が光っている間に視線から外れれば、射すくめられない")
	# 不死者は平気、ほかの魔物は射すくめられて逃げる
	_quiet(fl)
	gz.tick = 0.0
	gz.glare_t = -1.0
	var bone := _dummy(fl, fl.map.center_of(a + Vector2i(2, 0)), "undead")
	var beast := _dummy(fl, fl.map.center_of(a + Vector2i(3, 0)))
	lead.position = fl.map.center_of(a + Vector2i(5, 0))
	await _step(45)
	check(bone.hp == 400.0 and beast.hp < 400.0 and beast.state == "flee", "視線の先の魔物も射すくめられる(不死者は平気)")
	# 解除すると止まる
	_quiet(fl)
	t["st"] = "disarmed"
	gz.tick = 0.0
	lead.position = fl.map.center_of(a + Vector2i(4, 0))
	await _step(45)
	check(lead.fear_t <= 0.0, "解除した頭蓋は、もう光らない")
	gz.queue_free()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()

## 地物の絵と軌条を、いまの階に置いて描いても止まらない
func _test_draw() -> void:
	print("[地物の絵]")
	var fl: FloorInstance = main.current
	var lc: Vector2i = fl.map.cell_of(main.leader().position)
	check(FloorProps.decor({"rooms": [{"feature": {"name": "骨の祭壇", "desc": "", "x": 3, "y": 4}}]}) == [{"kind": "altar", "x": 3, "y": 4}], "部屋の地物「骨の祭壇」は、祭壇の絵になる")
	var n0: int = fl.decor.size()
	for k in ["spring", "shrooms", "pump", "pump_sunk", "altar", "choir", "cart"]:
		fl.decor.append({"kind": k, "x": lc.x, "y": lc.y, "axis": "h"})
	fl.decor.append({"kind": "rail", "x": lc.x - 2, "y": lc.y, "x2": lc.x + 2, "y2": lc.y})
	fl.map.explored[fl.map.idx(lc.x, lc.y)] = 1
	fl.queue_redraw()
	await _step(3)
	check(fl.decor.size() == n0 + 8, "絵を描いても止まらない")
	fl.decor.resize(n0)
