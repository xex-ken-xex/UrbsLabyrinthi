extends SceneTree
## 迷宮の中身 その1(設計 §11):  godot --headless --path godot -s res://tests/content_test.gd
## 部屋の描写、遺体の死んだ理由と等級、120年前の遠征隊、水ぎわの自生物。

var fails := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_corpses()
	_test_ranks()
	_test_water()
	_test_flavor()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _corpses(f: FloorInstance) -> Array:
	return f.ground.entries.filter(func(e): return String(e["kind"]) == "corpse")

func _test_corpses() -> void:
	print("[遺体の死んだ理由]")
	var whys := {}
	var near_trap := true
	var off_nest := true
	var on_dead_end := true
	var rim_ok := true
	for depth in [3, 7, 12]:
		for n in 3:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			var m := f.map
			for e in _corpses(f):
				var why := String(e.get("why", ""))
				whys[why] = int(whys.get(why, 0)) + 1
				var c: Vector2i = m.cell_of(e["pos"])
				match why:
					"trap":
						var best := 99
						for t in f.traps:
							best = mini(best, maxi(absi(int(t["x"]) - c.x), absi(int(t["y"]) - c.y)))
						near_trap = near_trap and best <= 3
					"nest":
						var rid := m.room_at[m.idx(c.x, c.y)]
						off_nest = off_nest and e.has("nest") and rid != int(e["nest"])
					"dead_end":
						on_dead_end = on_dead_end and m.tiles[m.idx(c.x, c.y)] == FloorMap.CORR
					"rim":
						rim_ok = rim_ok and String(e["look"]) == "bones"
				if not GroundItems.corpse_story(e).begins_with("認識票は"):
					check(false, "遺体の身の上に等級がある: %s" % GroundItems.corpse_story(e))
			f.free()
	print("    理由の内訳 ", whys)
	for k in ["trap", "nest", "rim", "dead_end", ""]:
		check(int(whys.get(k, 0)) > 0, "理由「%s」の遺体がある (%d)" % [k if k != "" else "なし", int(whys.get(k, 0))])
	check(near_trap, "罠で死んだ遺体は、罠の3マス以内")
	check(off_nest, "巣の手前の遺体は、巣の部屋の外にある")
	check(on_dead_end, "行き止まりの遺体は通路の上")
	check(rim_ok, "縁の遺体は骨")
	var e := {"rank": "青銅", "why": "trap"}
	check(GroundItems.corpse_story(e) == "認識票は青銅等級。" + String(GroundItems.CORPSE_WHY["trap"]), "調べると等級と理由がログに出る")

func _test_ranks() -> void:
	print("[等級と遠征隊]")
	check(GroundItems.rank_of(1) == "灰" and GroundItems.rank_of(2) == "灰" and GroundItems.rank_of(3) == "青銅" and GroundItems.rank_of(6) == "銀" and GroundItems.rank_of(7) == "黒鉄" and GroundItems.rank_of(10) == "黒鉄", "層の等級: 灰・青銅・銀・黒鉄")
	var exp := 0
	var total := 0
	for depth in [27, 28, 29]:
		for n in 4:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			for e in _corpses(f):
				total += 1
				if e.get("expedition", false):
					exp += 1
			f.free()
	check(exp > 0, "骨の層に120年前の遠征隊の遺体がある (%d/%d)" % [exp, total])
	var f1 := FloorInstance.create(FloorMap.floor_path(1, 0, 4))
	var none := true
	for e in _corpses(f1):
		if e.get("expedition", false) or String(e.get("why", "")) == "rim":
			none = false
	check(none, "第1階には遠征隊も、縁から落ちた遺体も無い")
	f1.free()

func _test_water() -> void:
	print("[水ぎわの自生物]")
	var wet := 0
	var all := 0
	for n in 3:
		var f := FloorInstance.create(FloorMap.floor_path(19, n, 4))
		var m := f.map
		for e in f.ground.entries:
			if String(e["kind"]) != "item" or not (String(e["id"]) in ["mizukagami_so", "mizu_hiru", "shinju_gai", "mekura_uo", "shizuku_goke", "sui_sho_mo"]):
				continue
			all += 1
			var c: Vector2i = m.cell_of(e["pos"])
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if m.in_bounds(c.x + dx, c.y + dy):
						var t := m.tiles[m.idx(c.x + dx, c.y + dy)]
						near = near or t == FloorMap.WATER or t == FloorMap.SHALLOW
			if near:
				wet += 1
		f.free()
	check(all > 0 and wet >= all * 0.8, "水鏡の層の水ぎわの自生物は、水のそばにある (%d/%d)" % [wet, all])

func _test_flavor() -> void:
	print("[部屋の描写]")
	var main_script: GDScript = load("res://scripts/main.gd")
	var f := FloorInstance.create(FloorMap.floor_path(3, 0, 4))
	var r: Dictionary = f.map.rooms[3]
	var a: String = main_script.room_flavor(f, r)
	var b: String = main_script.room_flavor(f, r)
	check(a != "" and a == b, "部屋の描写がある。同じ部屋は同じ描写: %s" % a)
	var differ := false
	for i in range(4, 12):
		if main_script.room_flavor(f, f.map.rooms[i]) != a:
			differ = true
	check(differ, "部屋ごとに描写が違う")
	var lit_ok := true
	for rr in f.map.rooms:
		if bool(rr.get("lit", false)) and not String(main_script.room_flavor(f, rr)).contains("灯守の灯"):
			lit_ok = false
	check(lit_ok, "灯のある部屋は、灯守の灯が描写に入る")
	f.free()
