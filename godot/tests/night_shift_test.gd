extends SceneTree
## 夜の鐘のあと、迷宮の一画が組み替わる(ken 10/19): Godot --headless --path godot -s res://tests/night_shift_test.gd

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

func _logs() -> Array:
	return main.hud.log_lines.map(func(l): return String(l["text"]))

func _cued(text: String) -> bool:
	return main.current.get_children().any(func(n): return n is Sfx and (n as Sfx).text == text)

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
	await _test_seen()
	await _test_far()
	await _test_bell()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	DiveSave.clear()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _quiet(fl: FloorInstance) -> void:
	fl.traps.clear()
	fl.trap_at.clear()
	fl.spawner.pending.clear()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()

## 次の夜で形が変わるマスのそばの、変わらない床(見える所で組み替わる)
func _spot(om: FloorMap, nm: FloorMap) -> Vector2i:
	for y in range(2, om.h - 2):
		for x in range(2, om.w - 2):
			var i := om.idx(x, y)
			if om.tiles[i] != nm.tiles[i] or (om.tiles[i] != FloorMap.ROOM and om.tiles[i] != FloorMap.CORR):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var j := om.idx(x + d.x, y + d.y)
				if om.tiles[j] != nm.tiles[j]:
					return Vector2i(x, y)
	return Vector2i(-1, -1)

func _test_seen() -> void:
	print("[見える所で組み替わる]")
	var old: FloorInstance = main.current
	_quiet(old)
	var nm := FloorMap.load_file(main.floor_path(old.floor_no, main.gs.day + 1))
	var spot := _spot(old.map, nm)
	check(spot.x >= 0, "次の夜の書き出しでは、形の変わるマスがある")
	main.place_party(old.map.center_of(spot))
	main._refresh_view()
	await _step(2)
	main.gs.add_item("potion", 1)
	main.drop_item("potion")
	var unchanged := -1
	for i in old.map.tiles.size():
		if old.map.tiles[i] == nm.tiles[i] and old.map.explored[i] == 1:
			unchanged = i
			break
	main._make_floor(old.floor_no + 1)
	var exh: bool = old.exhale
	main.recombine_at_night()
	await _step(2)
	var fl: FloorInstance = main.current
	check(fl != old and main.night_shift == 1, "鐘のあと、いまの階が次の夜の形に替わる")
	var diff := 0
	for i in fl.map.tiles.size():
		if fl.map.tiles[i] != nm.tiles[i]:
			diff += 1
	check(diff == 0, "替わった形は、次の夜の書き出しと同じ")
	check(fl.exhale == exh, "夜の性格(静か・吐く)は、そのまま")
	check(main.floors.size() == 1 and main.floors.has(fl.floor_no), "ほかの階は、次に入ったとき次の夜の形で作り直す")
	check(_cued("ゴゴゴ…"), "見える所が組み替わると「ゴゴゴ…」")
	check(_logs().any(func(t): return t.contains("まわりの通路が組み替わった")), "ログにも一行")
	check(unchanged < 0 or fl.map.explored[unchanged] == 1, "組み替わらなかった所の地図は覚えている")
	check(fl.ground.entries.any(func(e): return String(e.get("id", "")) == "potion" and e.get("dropped", false)), "足もとに置いた物は残る")
	var lc := fl.map.cell_of(main.leader().position)
	var t := fl.map.tiles[fl.map.idx(lc.x, lc.y)]
	check(t == FloorMap.ROOM or t == FloorMap.CORR, "仲間は床の上にいる")
	check(main.leader().game_floor == fl, "仲間は新しい形の階にいる")

func _test_far() -> void:
	print("[見えない所で組み替わる]")
	var fl: FloorInstance = main.current
	_quiet(fl)
	fl.map.visible.fill(0)
	var n0: int = main.night_shift
	main.recombine_at_night()
	await _step(2)
	if main.current == fl:
		check(main.night_shift == n0 + 1, "形が変わらない夜は、階をそのままにする")
	else:
		check(not _cued("ゴゴゴ…") and _logs().any(func(t): return t.contains("どこかの一画が組み替わった")), "見えない所なら、擬音ではなくログだけ")

func _test_bell() -> void:
	print("[鐘から組み換えまで]")
	_quiet(main.current)
	main.hud.log_lines.clear()
	var n0: int = main.night_shift
	var dt: DungeonTime = main.dtime
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.NIGHT_MIN - 0.02
	for i in 240:
		await physics_frame
		if main.night_shift > n0:
			break
	await _step(2)
	var logs := _logs()
	var bell := logs.find(DungeonTime.BELL)
	var shift := -1
	for i in logs.size():
		if String(logs[i]).contains("組み替わ"):
			shift = i
			break
	check(main.night_shift == n0 + 1 and bell >= 0, "日が落ちると鐘が鳴り、迷宮が組み替わる")
	check(shift < 0 or bell < shift, "鐘のログが先、組み換えのログが後")
	check(logs.filter(func(t): return t == DungeonTime.BELL).size() == 1, "鐘は一度だけ")
	main.save_dive()
	check(int(DiveSave.read().get("nights", -1)) == main.night_shift, "迎えた夜の数を、迷宮の記録に残す")
