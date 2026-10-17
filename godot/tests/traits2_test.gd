extends SceneTree
## 魔物の SRD の特徴 第二弾:  godot --headless --path godot -s res://tests/traits2_test.gd
## 闘技場で: 光に弱い・水たまり・天井・化ける・魔法への抵抗・雷を吸う・石化の視線・悪臭・光る体・糸を吐く。
## 迷宮で: 蜘蛛の巣(張る、絡まる、揺れで気づく)、扉の下をくぐる、燐晶の灯油の灯り。

var fails := 0
var main: Node
var ar: Arena

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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_arena()
	await _step(3)
	ar = main.arena
	ar.set_all_levels(5)
	_test_flags()
	await _test_sun()
	await _test_water()
	await _test_ceiling()
	await _test_shape()
	await _test_magic()
	await _test_gaze()
	await _test_stench()
	await _test_web_shot()
	await _test_dungeon()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _line(index: String, n: int = 1) -> Dictionary:
	for m in EncounterGen.data()["monsters"]:
		if String(m["i"]) == index:
			return EncounterGen.mon_line({"m": m, "n": n, "world": ""})
	return {}

func _reset(pos: Vector2) -> Hero:
	ar.clear_enemies()
	ar.heal_all()
	for i in main.heroes.size():
		var h: Hero = main.heroes[i]
		h.knock = Vector2.ZERO
		h.stuck_t = 0.0
		h.stone_m = 0.0
		h.poison_t = 0.0
		h.iframes = 0.0
		h.controlled = i == 0
		h.cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		if i > 0:
			h.position = Vector2(48.0 + i * 30.0, 48.0)
			h.down = true
	var h0: Hero = main.heroes[0]
	h0.position = pos
	main.active = 0
	main.current.leader = h0
	return h0

func _spawn(index: String, pos: Vector2, state: String = "chase", fl: FloorInstance = null) -> Enemy:
	var f: FloorInstance = ar.fl if fl == null else fl
	var en := Enemy.new()
	en.setup(f, _line(index, 1), {"id": 900, "kind": "beast"}, pos)
	en.state = state
	if state != "idle":
		en.disguised = false
		en.lurk = ""
	en.died.connect(f._on_enemy_died)
	f.add_child(en)
	f.enemies.append(en)
	return en

func _cued(fl: FloorInstance, text: String) -> bool:
	return fl.get_children().any(func(n): return n is Sfx and (n as Sfx).text == text)

func _test_flags() -> void:
	print("[flags]")
	check(MonTraits.flags_for(_line("wight")).has("sun") and MonTraits.flags_for(_line("shadow")).has_all(["sun_weak", "amorph"]), "ワイト: 光に弱い / シャドウ: 光にとても弱く、不定形")
	check(MonTraits.flags_for(_line("giant-spider")).has_all(["climb", "webwalk", "websense"]), "大蜘蛛: 天井を這い、巣を張り、揺れで気づく")
	check(MonTraits.flags_for(_line("crocodile")).has("amphib") and MonTraits.flags_for(_line("quipper")).has("aquatic"), "鰐は水陸、ピラニアは水の中")
	check(MonTraits.flags_for(_line("doppelganger")).has("shape") and MonTraits.flags_for(_line("imp")).has_all(["shape", "magic_res"]), "ドッペルゲンガーは化け、インプは魔法にも強い")
	check(MonTraits.flags_for(_line("basilisk")).has("gaze") and MonTraits.flags_for(_line("ghast")).has("stench"), "バジリスクは石化の視線、ガストは悪臭")
	check(MonTraits.flags_for(_line("flesh-golem")).has("absorb_lightning") and MonTraits.flags_for(_line("giant-fire-beetle")).has("glow"), "フレッシュ・ゴーレムは雷を吸い、火吹き甲虫は光る")

func _test_sun() -> void:
	print("[sun]")
	_reset(Vector2(200, 256))
	var wt := _spawn("wight", Vector2(400, 256))
	await _step(20)
	check(wt.in_light and is_equal_approx(wt.trait_dmg_mult(), 0.7), "灯りのある部屋(闘技場)では、光に弱い魔物が弱る (%.2f)" % wt.trait_dmg_mult())
	check(_cued(ar.fl, "ジリッ"), "灯りに入ると、ジリッ")
	var sh := _spawn("shadow", Vector2(400, 300))
	await _step(10)
	var hp0 := sh.hp
	sh.take_damage(4.0, Vector2.RIGHT, null)
	var lit_lost := hp0 - sh.hp
	sh.in_light = false
	var hp1 := sh.hp
	sh.take_damage(4.0, Vector2.RIGHT, null)
	check(sh.in_light == false and is_equal_approx(lit_lost, (hp1 - sh.hp) * 1.3), "シャドウは灯りの中で、受ける傷も深い (%.1f / %.1f)" % [lit_lost, hp1 - sh.hp])

func _test_water() -> void:
	print("[water]")
	var h0 := _reset(Vector2(150, 256))
	var cr := _spawn("crocodile", Vector2(450, 256), "idle")
	await _step(10)
	check(cr.lurk == "water" and cr.contact_dps() == 0.0 and cr.hidden_form(), "鰐は水たまりに沈んで待つ")
	h0.position = Vector2(450 - cr.radius - h0.radius - 40.0, 256)
	await _step(15)
	check(cr.lurk == "" and cr.state == "chase" and cr.surprise_t > 0.0, "近づくと、飛び出してくる")
	check(_cued(ar.fl, "ザバッ!"), "飛び出すと、ザバッ!")
	var qp := _spawn("quipper", Vector2(450, 400))
	var cr2 := _spawn("crocodile", Vector2(450, 420))
	check(qp.move_speed() < qp.speed * Balance.ENEMY_SPEED_SCALE * GameSettings.enemy_speed() * 0.75 and is_equal_approx(cr2.move_speed(), cr2.speed * Balance.ENEMY_SPEED_SCALE * GameSettings.enemy_speed()),
		"水の中だけの魔物は陸で鈍く、水陸の鰐はそのまま")

func _test_ceiling() -> void:
	print("[ceiling]")
	var h0 := _reset(Vector2(150, 256))
	var sp := _spawn("giant-spider", Vector2(450, 256), "idle")
	await _step(10)
	check(sp.lurk == "ceiling" and sp.hidden_form(), "大蜘蛛は天井から垂れて待つ")
	h0.position = Vector2(450 - sp.radius - h0.radius - 30.0, 256)
	await _step(15)
	check(sp.lurk == "" and sp.state == "chase" and _cued(ar.fl, "ストン"), "真下に来ると、ストンと落ちてくる")

func _test_shape() -> void:
	print("[shape]")
	var h0 := _reset(Vector2(150, 256))
	var dp := _spawn("doppelganger", Vector2(450, 256), "idle")
	var im := _spawn("imp", Vector2(450, 360), "idle")
	await _step(10)
	check(dp.lurk == "shape" and dp.shape_name == "迷い込んだ冒険者" and dp.shape_look.get("tex") != null, "ドッペルゲンガーは、迷い込んだ冒険者に化けて待つ")
	check(im.lurk == "shape" and im.shape_name == "大鼠", "小さなインプは、鼠に化ける")
	main.heroes[1].down = false
	main.heroes[1].position = Vector2(400, 256)
	main.heroes[1]._ai_think()
	check(main.heroes[1].ai_target != dp, "仲間は、化けた魔物を狙わない")
	main.heroes[1].down = true
	dp.take_damage(1.0, Vector2.RIGHT, h0)
	check(dp.lurk == "" and dp.state == "chase" and _cued(ar.fl, "ニタァ…"), "殴ると正体を現す(ニタァ…)")

func _test_magic() -> void:
	print("[magic]")
	var h0 := _reset(Vector2(150, 256))
	var a := _spawn("bearded-devil", Vector2(450, 200))
	var b := _spawn("bearded-devil", Vector2(450, 300))
	var ha := a.hp
	a.take_damage(10.0, Vector2.RIGHT, null)
	var hb := b.hp
	b.elem_hit("", true)       # 魔力の傷(火は、この悪魔には効かない)
	b.take_damage(10.0, Vector2.RIGHT, null)
	check(is_equal_approx(hb - b.hp, (ha - a.hp) * 0.5), "魔法に強い魔物は、呪文の傷が半分 (%.1f / %.1f)" % [hb - b.hp, ha - a.hp])
	var res := 0
	for i in 200:
		if b.spell_resisted():
			res += 1
	check(res > 60 and res < 140, "呪文の眠りや足止めを、半分ほど弾く (%d/200)" % res)
	var fg := _spawn("flesh-golem", Vector2(450, 400))
	fg.hp = fg.max_hp * 0.5
	var g0 := fg.hp
	fg.elem_hit("lightning", true)
	fg.take_damage(10.0, Vector2.RIGHT, h0)
	check(fg.hp > g0, "フレッシュ・ゴーレムは、雷で癒える")
	check(String(Jobs.SKILLS["thunder"].get("elem", "")) == "lightning" and String(Jobs.SKILLS["frost"].get("elem", "")) == "cold", "雷光は雷、氷結は冷気")

func _test_gaze() -> void:
	print("[gaze]")
	var h0 := _reset(Vector2(150, 256))
	var bs := _spawn("basilisk", Vector2(300, 256))
	bs.speed = 1.0
	h0.facing = Vector2.RIGHT
	var stoned := false
	var glared := false
	for i in 300:
		await physics_frame
		h0.facing = Vector2.RIGHT
		glared = glared or _cued(ar.fl, "ギロッ")
		if h0.stuck_t > 0.0 and h0.stuck_kind == "stone":
			stoned = true
			break
	await _step(2)
	check(stoned and glared and _cued(ar.fl, "ピキピキッ"), "見つめ合うと、ギロッ → ピキピキッで石になる")
	var hp0 := h0.ch.hp
	h0.damage(10.0, h0.position + Vector2.RIGHT, true)
	check(is_equal_approx(hp0 - h0.ch.hp, 5.0), "石になっている間は、受ける傷が半分")
	var h1 := _reset(Vector2(150, 256))
	var bs2 := _spawn("basilisk", Vector2(300, 256))
	bs2.speed = 1.0
	var ok := true
	for i in 300:
		await physics_frame
		h1.facing = Vector2.LEFT
		if h1.stuck_kind == "stone" and h1.stuck_t > 0.0:
			ok = false
	check(ok and h1.stone_m == 0.0, "目をそらしていれば、石にならない")

func _test_stench() -> void:
	print("[stench]")
	var h0 := _reset(Vector2(300, 256))
	var gh := _spawn("ghast", Vector2(340, 256))
	gh.speed = 1.0
	await _step(30)
	check(h0.poison_t > 0.0 and _cued(ar.fl, "モワァ…"), "ガストのそばにいると、モワァ…と気分が悪くなる(毒)")

func _test_web_shot() -> void:
	print("[web shot]")
	var h0 := _reset(Vector2(150, 256))
	var sp := _spawn("giant-spider", Vector2(300, 256))
	sp.web_cd = 0.0
	sp.speed = 1.0
	var caught := false
	for i in 120:
		await physics_frame
		if h0.stuck_t > 0.0 and h0.stuck_kind == "web":
			caught = true
			break
	check(caught and _cued(ar.fl, "ビュッ") and _cued(ar.fl, "ネバッ"), "大蜘蛛は糸を吐き(ビュッ)、当たると絡まる(ネバッ)")

func _test_dungeon() -> void:
	print("[dungeon]")
	var probe := FloorInstance.create(FloorMap.floor_path(1, 0, 3))
	check(probe.webs.size() >= 3, "巣を張る魔物の部屋には、蜘蛛の巣がある (%d)" % probe.webs.size())
	probe.free()
	main.gs.new_game(main.gs.party.duplicate())
	main._set_screen(null)
	main.start_day()
	await _step(5)
	var fl: FloorInstance = main.current
	var h0: Hero = main.leader()
	for h in main.heroes:
		h.controlled = h == h0
	main.scripted_input = true
	var map := fl.map
	# 灯りの無い部屋を探す
	var cell := Vector2i(-1, -1)
	for r in map.rooms:
		if not bool(r.get("lit", false)) and int(r["w"]) >= 4 and int(r["h"]) >= 4:
			cell = Vector2i(int(r["x"]) + 1, int(r["y"]) + 1)
			if not map.opaque(cell.x, cell.y) and not map.opaque(cell.x + 2, cell.y):
				break
	for h in main.heroes:
		h.position = map.center_of(cell)
	var wt := _spawn("wight", map.center_of(cell + Vector2i(2, 0)), "chase", fl)
	wt.speed = 1.0
	fl.lamp_on = false
	main.light_t = 0.0
	await _step(15)
	check(not wt.in_light, "灯りの無い部屋では、光に弱い魔物も弱らない")
	main.light_t = 60.0
	await _step(15)
	check(fl.lamp_on and wt.in_light, "燐晶の灯油を灯すと、そばの光に弱い魔物が弱る")
	wt.queue_free()
	fl.enemies.erase(wt)
	main.light_t = 0.0
	# 蜘蛛の巣: 踏むと絡まり、遠くの巣の主が気づく
	var owner_sp := _spawn("giant-wolf-spider", map.center_of(cell) + Vector2(18 * Balance.CELL, 0), "idle", fl)
	var hc := map.cell_of(h0.position)
	fl.webs[map.idx(hc.x, hc.y)] = true
	await _step(3)
	check(h0.stuck_kind == "web" and h0.stuck_t > 0.0 and not fl.webs.has(map.idx(hc.x, hc.y)), "巣を踏むと絡まり、巣は破れる")
	check(owner_sp.state == "chase" and owner_sp.lurk == "" and owner_sp.target == h0, "巣の揺れで、遠くの巣の主が気づいて来る")
	owner_sp.queue_free()
	fl.enemies.erase(owner_sp)
	h0.stuck_t = 0.0
	var d := DiveSave.floor_snap(fl)
	check((d["webs"] as Array).size() == fl.webs.size(), "蜘蛛の巣は、迷宮の記録に残る")
	# 不定形: 鍵の掛かった扉の下をくぐる
	var door: Dictionary = {}
	for dd in map.doors:
		if dd["type"] == "locked":
			var dc := Vector2i(int(dd["x"]), int(dd["y"]))
			var ax := Vector2i(1, 0) if dd["axis"] == "ew" else Vector2i(0, 1)
			if not map.opaque(dc.x + ax.x * 2, dc.y + ax.y * 2) and not map.opaque(dc.x - ax.x, dc.y - ax.y) and not map.opaque(dc.x + ax.x, dc.y + ax.y):
				door = dd
				break
	if door.is_empty():
		check(false, "鍵の掛かった扉が見つからない")
		return
	door["open"] = false
	door["unlocked"] = false
	var dcell := Vector2i(int(door["x"]), int(door["y"]))
	var axv := Vector2i(1, 0) if door["axis"] == "ew" else Vector2i(0, 1)
	for h in main.heroes:
		h.position = map.center_of(dcell + axv * 2)
		h.stuck_t = 0.0
	fl.update_flow(dcell + axv * 2)
	var oz := _spawn("gray-ooze", map.center_of(dcell - axv), "chase", fl)
	oz.target = h0
	var through := false
	for i in 240:
		await physics_frame
		for h in main.heroes:
			h.position = map.center_of(dcell + axv * 2)
		var oc := map.cell_of(oz.position)
		if Vector2(oc - dcell).dot(Vector2(axv)) >= 1.0:
			through = true
			break
	check(through and not door["open"], "灰色の粘体は、鍵の掛かった扉の下をくぐる")
	var zb := _spawn("zombie", map.center_of(dcell - axv), "chase", fl)
	zb.target = h0
	var zthrough := false
	for i in 120:
		await physics_frame
		if Vector2(map.cell_of(zb.position) - dcell).dot(Vector2(axv)) >= 1.0:
			zthrough = true
	check(not zthrough, "ほかの魔物は、鍵の掛かった扉を通れない")
