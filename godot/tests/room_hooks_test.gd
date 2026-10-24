extends SceneTree
## 部屋の手がかり(ken 10/24): Godot --headless --path godot -s res://tests/room_hooks_test.gd
## 初めて入ると中央に大きく出て消える。物がある手がかりは床に光る印が付き、E で拾えて遺品課に渡せる

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
	_test_table()
	await _test_banner()
	await _test_marks()
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

## まだ入っていない、床のある部屋(階段の部屋は避ける)
func _room(fl: FloorInstance, skip: int = -1) -> Dictionary:
	for r in fl.map.rooms:
		var rid := int(r["id"])
		if rid == skip or fl.visited_rooms.has(rid) or (fl.map.room_cells.get(rid, []) as Array).size() < 4:
			continue
		var ur := fl.map.room_at[fl.map.idx(fl.up_cell.x, fl.up_cell.y)]
		if rid == ur:
			continue
		return r
	return {}

func _test_table() -> void:
	print("[手がかりの表]")
	var html := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/urbs-labyrinthi.html"))
	var missing: Array = []
	for t in RoomHooks.ITEMS:
		if not html.contains(String(t)):
			missing.append(t)
	check(html != "" and missing.is_empty(), "拾える手がかりの文は、どれも生成器の hooks にある %s" % str(missing))
	var ids: Array = []
	for t in RoomHooks.ITEMS:
		var id := String(RoomHooks.ITEMS[t][0])
		check(id == "crystal" or not ItemDB.get_item(id).is_empty(), "「%s」の品 %s がある" % [String(t).left(12), id])
		if not ids.has(id):
			ids.append(id)
	check(ItemIcons.has_icon("relic_permit") and ItemDB.item_name("relic_permit") == "潜行許可証", "潜行許可証の絵と名前がある")
	check(ItemDB.GUILD_ONLY.has("relic_permit") and TownScreen.RELIC_RATE.has("relic_permit"), "潜行許可証は遺品課だけが引き取り、謝礼が出る")
	check(Burden.item_kg("relic_permit") > 0.0, "潜行許可証にも重さがある")
	var lines := Hud.wrap_lines("骨の柱に、黒鉄の潜行許可証が釘で打ちつけてある。封鎖令の日付が、その下に刻んである。", 400.0, 24)
	var fits := true
	for l in lines:
		fits = fits and UI.font().get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= 400.0
	check(lines.size() >= 2 and fits and "".join(lines).length() == 42, "長い手がかりは、幅に収まるように折り返す %s" % str(lines))

func _test_banner() -> void:
	print("[中央に出て消える]")
	var fl: FloorInstance = main.current
	_quiet(fl)
	var r := _room(fl)
	check(not r.is_empty(), "試す部屋がある")
	var text := "誰かの背負い袋が置き去りにされている。中身は荒らされていない。"
	r["hook"] = text
	var rid := int(r["id"])
	var c: int = fl.map.room_cells[rid][0]
	main.hud.banner = {}
	main._enter_room(Vector2i(c % fl.map.w, c / fl.map.w))
	check(String(main.hud.banner.get("text", "")) == text, "初めて入ると、手がかりが画面の中央に出る")
	check(_logs().has(text), "ログにも残す")
	var life := float(main.hud.banner["life"])
	check(life >= 4.0 and life <= 7.5, "長めに出る (%.1f秒)" % life)
	await _step(10)
	check(not main.hud.banner.is_empty(), "すぐには消えない")
	main.hud.banner["age"] = life - 0.05
	await _step(10)
	check(main.hud.banner.is_empty(), "しばらくすると、自然に消える")
	main.hud.banner = {}
	main._enter_room(Vector2i(c % fl.map.w, c / fl.map.w))
	check(main.hud.banner.is_empty(), "二度目に入っても、もう出ない")

func _test_marks() -> void:
	print("[光る印を拾う]")
	var fl: FloorInstance = main.current
	_quiet(fl)
	for r in fl.map.rooms:
		r.erase("hook")
	var r1 := _room(fl)
	var r2 := _room(fl, int(r1["id"]))
	r1["hook"] = "青銅の潜行許可証が二枚、紐で結ばれて梁に掛けてある。"
	r2["hook"] = "鉱車の底に、封蝋のない燐晶が張りつくように残っている。"
	var plain := _room(fl)
	fl.hook_marks = RoomHooks.marks(fl)
	check(fl.hook_marks.size() == 2, "物がある手がかりの部屋だけに印が付く (%d)" % fl.hook_marks.size())
	var again := RoomHooks.marks(fl)
	check(again.size() == 2 and again[0]["cell"] == fl.hook_marks[0]["cell"], "印の場所は、部屋と夜で決まる")
	var mk: Dictionary = fl.hook_marks.filter(func(m): return m["room"] == int(r1["id"]))[0]
	check(fl.map.room_at[fl.map.idx(mk["cell"].x, mk["cell"].y)] == int(r1["id"]), "印は、その部屋の床にある")
	var lead: Hero = main.leader()
	lead.position = mk["pos"] + Vector2(40, 0)
	main._update_hint()
	check(not String(main.hud.hint).contains("拾う"), "離れていると、拾えない")
	lead.position = mk["pos"] + Vector2(6, 0)
	main._update_hint()
	check(String(main.hud.hint).contains("潜行許可証を拾う"), "そばに来ると「E: 潜行許可証を拾う」")
	var n0: int = main.gs.count("relic_permit")
	main.interact()
	check(main.gs.count("relic_permit") == n0 + 2 and bool(mk["taken"]), "E で拾うと、潜行許可証が二枚、持ち物に入る")
	check(_logs().any(func(t): return t.contains("遺品課に届けられる")), "ログに「遺品課に届けられる」")
	check(main.hud.pickups.any(func(p): return String(p["key"]) == "item_relic_permit"), "拾ったものの一覧に絵と名前が出る")
	main._update_hint()
	check(not String(main.hud.hint).contains("拾う"), "拾ったあとは、もう拾えない")
	var mc: Dictionary = fl.hook_marks.filter(func(m): return m["room"] == int(r2["id"]))[0]
	lead.position = mc["pos"]
	var kg0 := float(main.bag_crystal.get("mid", 0.0))
	main.interact()
	check(float(main.bag_crystal.get("mid", 0.0)) > kg0, "燐晶の手がかりは、燐晶を袋に入れる")
	fl.queue_redraw()
	await _step(3)
	check(not plain.is_empty(), "描いても落ちない")
