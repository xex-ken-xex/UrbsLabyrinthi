extends SceneTree
## 迷宮の中身 その3(設計 §11.5):  godot --headless --path godot -s res://tests/world_test.gd
## 地図屋の印、壁の落書き(七芒星・静印)、闇潜りの野営、日没の鐘。
## 小さな置き物(灯守の詰所、封鎖令の跡、オルドの杭、水鏡の刻み、空の座)と、竪坑のまわりの共有の狩場。

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
	_test_data()
	_test_small()
	_test_shared()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
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
	await _test_read()
	await _test_bell()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _logs() -> Array:
	return main.hud.log_lines.map(func(l): return String(l["text"]))

func _test_data() -> void:
	print("[書き出しの手ざわり]")
	var marks := 0
	var stale := 0
	var junction := true
	var camps := 0
	var camp_ok := true
	var seven := {}     # 層 → [七芒星, 落書き]
	var sig_wall := true
	for depth in range(1, 30):
		for n in [0, 3]:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			var m := f.map
			var layer := f.layer_no
			for p in f.world_props:
				var c := Vector2i(int(p["x"]), int(p["y"]))
				match String(p["kind"]):
					"mark":
						marks += 1
						if p.get("stale", false):
							stale += 1
						var open := 0
						for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if m.monster_passable(c.x + dv.x, c.y + dv.y):
								open += 1
						junction = junction and m.tiles[m.idx(c.x, c.y)] == FloorMap.CORR and open >= 3 and String(p["text"]).begins_with("下り")
					"sigil":
						var s: Array = seven.get(layer, [0, 0])
						s[1] += 1
						if String(p["sign"]) == "seven":
							s[0] += 1
						seven[layer] = s
						sig_wall = sig_wall and m.tiles[m.idx(c.x, c.y - 1)] == FloorMap.ROCK
					"camp":
						camps += 1
						var rid := int(p["room"])
						var busy := false
						for e in m.data["encounters"]:
							if int(e["roomId"]) == rid:
								busy = true
						camp_ok = camp_ok and layer <= 4 and not busy and m.room_at[m.idx(c.x, c.y)] == rid
			f.free()
	check(marks > 0 and junction, "地図屋の印は、骨組みの通路の分かれ目にあって「下り」の矢印 (%d)" % marks)
	check(stale > 0 and stale < marks, "前の夜の印なので、今夜の階段と向きが違う印がある (%d/%d)" % [stale, marks])
	check(sig_wall, "落書きは壁ぎわ(上が岩)の床にある")
	var lo: Array = seven.get(1, [0, 1])
	var hi: Array = seven.get(9, seven.get(8, [0, 1]))
	check(float(hi[0]) / maxf(1.0, hi[1]) > float(lo[0]) / maxf(1.0, lo[1]), "深い層ほど七芒星が多い (第1層 %d/%d、深層 %d/%d)" % [lo[0], lo[1], hi[0], hi[1]])
	check(camps > 0 and camp_ok, "闇潜りの野営は第1〜4層の、魔物のいない部屋にある (%d)" % camps)

func _test_read() -> void:
	print("[近づくと読む]")
	var fl: FloorInstance = null
	var mark: Dictionary = {}
	for depth in range(3, 8):
		main.enter_floor(depth, "up")
		await _step(2)
		fl = main.current
		for p in fl.world_props:
			if String(p["kind"]) == "mark":
				mark = p
				break
		if not mark.is_empty():
			break
	check(not mark.is_empty(), "地図屋の印のある階がある")
	if mark.is_empty():
		return
	var c := Vector2i(int(mark["x"]), int(mark["y"]))
	main.place_party(fl.map.center_of(c))
	await _step(4)
	var hits := _logs().filter(func(t): return t.contains("地図屋の凧旗の印"))
	check(hits.size() == 1, "印のそばに来ると、ログに出る")
	main.place_party(fl.map.center_of(fl.up_cell))
	await _step(4)
	main.place_party(fl.map.center_of(c))
	await _step(4)
	check(_logs().filter(func(t): return t.contains("地図屋の凧旗の印")).size() == 1, "同じ印は二度読まない")
	var seven := FloorProps.line({"kind": "sigil", "sign": "seven"})
	var quiet := FloorProps.line({"kind": "sigil", "sign": "quiet"})
	check(seven.contains("七芒星") and quiet.contains("静印"), "落書きの文: 七芒星と静印")
	check(FloorProps.line({"kind": "camp"}).contains("闇潜り"), "野営の文")
	check(FloorProps.line({"kind": "mark", "text": "下り →", "night": 2}).contains("前の夜"), "印は前の夜のもの")

func _test_bell() -> void:
	print("[日没の鐘]")
	var dt: DungeonTime = main.dtime
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.NIGHT_MIN - 0.02
	for i in 240:
		await physics_frame
		if _logs().any(func(t): return t == DungeonTime.BELL):
			break
	check(_logs().any(func(t): return t == DungeonTime.BELL), "日が落ちると、遠くで鐘が七つ鳴る(ログ)")

func _props_at(depth: int, night: int) -> Array:
	var f := FloorInstance.create(FloorMap.floor_path(depth, night, 4))
	var out: Array = f.world_props.duplicate(true)
	f.free()
	return out

func _test_small() -> void:
	print("[小さな置き物]")
	var count := {}
	for depth in range(1, 31):
		for n in [0, 2, 5]:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			for p in f.world_props:
				var k := String(p["kind"])
				count[k] = int(count.get(k, 0)) + 1
				if k == "blockade":
					var bones := f.ground.entries.filter(func(e): return String(e["kind"]) == "corpse" and String(e.get("why", "")) == "blockade")
					check(bones.size() == 1 and GroundItems.corpse_story(bones[0]).contains("五十年前"), "封鎖令の跡には、取り残された者の遺体がある")
					check(f.layer_no in [3, 4], "封鎖令の跡は錆鉄の層")
				if k == "stake":
					check(f.layer_no <= 2, "オルドの杭は腐葉の層")
				if k == "carving":
					check(f.layer_no in [5, 6], "水鏡の刻みは水鏡の層")
				if k == "seat":
					check(f.floor_no == Balance.MAX_FLOOR, "空の座は第10層(竜の巣の階)")
			f.free()
	print("    数 ", count)
	for k in ["post", "blockade", "stake", "carving", "seat"]:
		check(int(count.get(k, 0)) > 0, "「%s」がある" % k)
	# 骨組みの物(杭・刻み・座)は、夜が変わっても同じ所にある
	var same := true
	for depth in [1, 21, 30]:
		var a: Array = _props_at(depth, 0).filter(func(p): return String(p["kind"]) in ["stake", "carving", "seat"])
		var b: Array = _props_at(depth, 4).filter(func(p): return String(p["kind"]) in ["stake", "carving", "seat"])
		same = same and a.size() > 0 and a.size() == b.size()
		for i in mini(a.size(), b.size()):
			same = same and int(a[i]["x"]) == int(b[i]["x"]) and int(a[i]["y"]) == int(b[i]["y"])
	check(same, "杭・水鏡の刻み・空の座は、夜が変わっても同じ所にある")
	check(FloorProps.line({"kind": "post", "days": 8}).contains("灯守が来ていない"), "芯替えが古い詰所は、灯守が来ていないと分かる")
	check(not FloorProps.line({"kind": "post", "days": 1}).contains("灯守が来ていない"), "芯替えが新しい詰所は、ふつう")

func _test_shared() -> void:
	print("[共有の狩場]")
	var shared := 0
	var below := 0
	var in_pit := true
	for depth in range(1, 27):
		for n in [0, 3]:
			var f := FloorInstance.create(FloorMap.floor_path(depth, n, 4))
			var m := f.map
			var mine := {}
			for e in m.data["encounters"]:
				if not e.get("shared", false):
					if int(e["roomId"]) >= 0:
						for mm in e["monsters"]:
							mine[String(mm["index"])] = true
					continue
				shared += 1
				var kind := String(m.room_by_id[int(e["roomId"])].get("kind", ""))
				in_pit = in_pit and (kind == "pit" or kind == "sump")
			f.free()
	check(shared > 0 and in_pit, "竪坑の脇と底に、共有の狩場の群れがいる (%d)" % shared)
