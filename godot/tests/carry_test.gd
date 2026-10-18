extends SceneTree
## 倒れた仲間を背負う、持ち物の重さと捨てる、縄梯子の転落(ken 10/18): Godot --headless --path godot -s res://tests/carry_test.gd
const M := preload("res://scripts/main.gd")
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	print("[重さの決まり]")
	check(Burden.item_kg("relic_coins") == 2.0 and Burden.item_kg("relic_tag") == 2.0, "遺品は 2kg")
	check(Burden.item_kg("plate") == 12.0 and Burden.item_kg("leather") == 4.0 and Burden.item_kg("dagger") < Burden.item_kg("greataxe"), "鎧は重装 12kg・軽装 4kg、武器は重い物ほど重い")
	check(Burden.mult_for(20.0, 20.0) == 1.0 and is_equal_approx(Burden.mult_for(30.0, 20.0), 20.0 / 30.0) and Burden.mult_for(100.0, 20.0) == Burden.MIN_SPEED, "持てる重さまでは足はそのまま、超えたら重さの割合で遅く(半分まで)")
	check(M.rope_dc(5.0) == 12 and M.rope_dc(15.0) == 16, "縄梯子の難しさが上がった(5m で 12、15m で 16)")
	var f1: float = M.rope_fall_m(15.0, 1, 1)
	check(f1 == 15.0 and f1 * M.ROPE_FALL_DMG == 90.0, "縄梯子で出目1なら上から下まで落ち、落ちた高さ×6 の傷(15m で 90)")
	var ok_up := true
	for i in 50:
		var u: float = M.rope_fall_m(15.0, 5, -1)
		ok_up = ok_up and u >= 0.5 and u <= 15.0 * 0.35 + 0.25
	check(ok_up, "登りで滑ると、少し滑り落ちる")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "human"], ["rogue", "human"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	for i in 5:
		await physics_frame
	var fl: FloorInstance = main.current
	_clear(fl)

	print("[倒れた仲間を背負う]")
	var lead: Hero = main.leader()
	var cl: Hero = main.heroes[1]
	var ro: Hero = main.heroes[2]
	var room := fl.map.center_of(fl.up_cell)
	main.place_party(room)
	ro.position = room + Vector2(400, 400)       # 遠くへ(背負いに来ないように)
	cl.damage(9999.0, cl.position + Vector2(0, 1), true)
	check(cl.down, "仲間が倒れた")
	main.interact()
	check(lead.carrying == null or lead.carrying == cl, "(操作している仲間が背負うか、まだ届かない)")
	lead.set_down()
	cl.position = lead.position + Vector2(12, 0)
	var p0: float = lead.buff("power")
	var s0: float = lead._speed_now()
	main.interact()
	check(lead.carrying == cl and cl.carried_by == lead, "そばで E を押すと、倒れた仲間を背負う")
	check(is_equal_approx(lead.buff("power"), p0 * Hero.CARRY_MULT) and is_equal_approx(lead._speed_now(), s0 * Hero.CARRY_MULT), "背負っている間は、足の速さと攻撃力が半分")
	lead.position += Vector2(30, 0)
	main._update_carry_and_load(0.0)
	check(cl.position.distance_to(lead.position) < 14.0, "背負った仲間は、背中に載って一緒に動く")
	var n0: int = main.floors.size()
	var floor0: int = fl.floor_no
	# 背負っていない仲間がいると、階段を使えない
	lead.set_down()
	check(main._left_behind().has(cl) and main._left_behind_says(), "倒れた仲間を置いたままでは、階を移れない")
	lead.position = fl.map.center_of(fl.down_cell)
	var dc: Vector2i = fl.down_cell
	var flw := fl.map.compute_flow(dc.x, dc.y, 12)
	var body_c := Vector2i(-1, -1)
	var help_c := Vector2i(-1, -1)
	for i in flw.size():
		if flw[i] == 5 and body_c.x < 0:
			body_c = Vector2i(i % fl.map.w, i / fl.map.w)
	for i in flw.size():
		var cc := Vector2i(i % fl.map.w, i / fl.map.w)
		if flw[i] >= 3 and flw[i] <= 7 and help_c.x < 0 and absi(cc.x - body_c.x) + absi(cc.y - body_c.y) == 2:
			help_c = cc
	cl.position = fl.map.center_of(body_c)
	main.interact()
	check(main.current.floor_no == floor0, "置いていく仲間がいるうちは、下り階段で降りない")
	# 仲間(操作していない)は、魔物が見えなければ倒れた仲間を背負いに行く
	ro.position = fl.map.center_of(help_c if help_c.x >= 0 else body_c)
	main._refresh_view()
	var picked := false
	for f in 240:
		await physics_frame
		lead.position = fl.map.center_of(fl.down_cell)
		if cl.carried_by == ro:
			picked = true
			break
	check(picked, "操作していない仲間が、倒れた仲間を背負いに行く")
	ro.position = lead.position + Vector2(10, 0)
	main._update_carry_and_load(0.0)
	main.interact()
	check(main.current.floor_no == floor0 + 1, "全員を連れていれば、階段を降りられる (%d → %d)" % [floor0, main.current.floor_no])
	check(cl.carried_by == ro, "背負ったまま、下の階へ")
	ro.damage(9999.0, ro.position + Vector2(0, 1), true)
	check(ro.carrying == null and cl.carried_by == null, "背負っている人が倒れたら、下ろす")
	cl.revive(0.5)
	ro.revive(0.5)
	var haunts := 0
	for eid in main.current.spawner.pending:
		if int(eid) >= FloorInstance.ROPE_ENC_ID:
			haunts += 1
	check(main.current.ropes.is_empty() or haunts > 0, "縄梯子の下に、落ちてくる者を待つ魔物がいる (%d 組)" % haunts)
	var rope_dead := 0
	for g in main.current.ground.entries:
		if String(g["kind"]) == "corpse" and String(g.get("why", "")) == "rope":
			rope_dead += 1
	check(main.current.floor_no <= 1 or main.current.ropes.is_empty() or rope_dead > 0, "縄梯子の下には、落ちた者の遺体がある (%d 体)" % rope_dead)
	fl = main.current
	_clear(fl)

	print("[持ち物の重さと捨てる]")
	main._update_carry_and_load(1.0)
	check(Burden.speed_mult == 1.0, "ふつうの荷なら、足はそのまま (%s)" % main.burden_text())
	main.gs.add_item("relic_tools", 40)
	main._load_t = 0.0
	main._update_carry_and_load(0.1)
	check(Burden.speed_mult < 1.0 and main.burden_text().contains("重すぎる"), "遺品をたくさん持つと重すぎて、足が遅くなる (%s)" % main.burden_text())
	var heavy_cue := false
	for n in main.current.get_children():
		if n is Sfx and (n as Sfx).text == "ズシッ":
			heavy_cue = true
	check(heavy_cue, "重すぎになったとき「ズシッ」")
	var before: int = main.gs.count("relic_tools")
	var line: String = main.drop_item("relic_tools")
	var e: Dictionary = main.current.ground.entries[-1]
	check(main.gs.count("relic_tools") == before - 1 and line.contains("足もと") and String(e["id"]) == "relic_tools" and e.get("hold", false), "迷宮では、捨てた品は足もとに置かれる")
	for f in 30:
		await physics_frame
	check(main.current.ground.entries.has(e), "捨てたばかりの品は、そばにいるうちは拾わない")
	main.gs.remove_item("relic_tools", main.gs.count("relic_tools"))
	main._load_t = 0.0
	main._update_carry_and_load(0.1)
	check(Burden.speed_mult == 1.0, "荷が軽くなれば、足が戻る")

	print("[縄梯子]")
	if fl.ropes.is_empty():
		check(false, "この階に縄梯子が無い")
	else:
		var rc: Vector2i = fl.ropes[0]
		for h in main.heroes:
			h.position = fl.map.center_of(rc)
		var mons: Array = fl.spawn_encounter([{"index": "rat", "name": "Rat", "name_ja": "ネズミ", "world_name": "洞窟鼠", "count": 1, "cr": 0, "xp": 10, "ac": 10, "hp": 1, "size": "T", "type": "beast", "speed": {"walk": 20}, "attacks": []}], "beast", main.leader().position + Vector2(60, 0), "", "idle")
		main.open_rope_menu(rc)
		check(main.rope_menu == null, "魔物がいるときは、縄梯子を使えない")
		for m in mons:
			m.queue_free()
			fl.enemies.erase(m)
		main.open_rope_menu(rc)
		check(main.rope_menu != null, "魔物がいなければ、縄梯子の選ぶ画面が出る")
		if main.rope_menu != null:
			main._on_rope_choice("")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

## 魔物と罠を除く(測る邪魔をしないように)
func _clear(fl: FloorInstance) -> void:
	fl.traps.clear()
	fl.trap_at.clear()
	fl.spawner.pending.clear()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
