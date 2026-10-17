extends SceneTree
## 魔物の SRD の特徴(MonTraits)の動き:  godot --headless --path godot -s res://tests/traits_test.gd
## 闘技場で一体ずつ出して、群れで囲む・擬態・突進・すり抜け・しぶとさ・再生・死に際の破裂・張りつき・錆を確かめる。

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
	await _test_pack()
	await _test_swarm()
	await _test_mimic()
	await _test_charge()
	await _test_ghost()
	await _test_fortitude()
	await _test_regen()
	await _test_burst()
	await _test_on_hit()
	await _test_senses()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

## data の魔物の行
func _line(index: String, n: int = 1) -> Dictionary:
	for m in EncounterGen.data()["monsters"]:
		if String(m["i"]) == index:
			return EncounterGen.mon_line({"m": m, "n": n, "world": ""})
	return {}

## 仲間を全快させ、0番を pos に、ほかの3人は遠くの隅に倒れた状態で置く(動きに混ざらないように)
func _reset(pos: Vector2) -> Hero:
	ar.clear_enemies()
	ar.heal_all()
	for i in main.heroes.size():
		var h: Hero = main.heroes[i]
		h.knock = Vector2.ZERO
		h.stuck_t = 0.0
		h.rust = 0
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

## 闘技場に一体(か群れ)を出す。state は idle(気づく前)か chase
func _spawn(index: String, pos: Vector2, n: int = 1, state: String = "chase") -> Array:
	var out: Array = []
	var line := _line(index, 1)
	for i in n:
		var en := Enemy.new()
		en.setup(ar.fl, line, {"id": 900, "kind": "beast"}, pos + Vector2(0.0, i * 30.0))
		en.state = state
		en.disguised = en.disguised and state == "idle"
		en.died.connect(ar.fl._on_enemy_died)
		ar.fl.add_child(en)
		ar.fl.enemies.append(en)
		out.append(en)
	return out

func _test_flags() -> void:
	print("[flags]")
	check(MonTraits.flags_for(_line("giant-rat")).has_all(["smell", "pack"]), "巨大ネズミ: 鋭い嗅覚と、群れで囲む")
	check(MonTraits.flags_for(_line("mimic")).has_all(["mimic", "grapple"]), "ミミック: 擬態と、張りつく")
	check(MonTraits.flags_for(_line("zombie")).has("fortitude") and MonTraits.con_mod(_line("zombie")) == 3, "ゾンビ: しぶとさ(耐久 +3)")
	check(MonTraits.flags_for(_line("minotaur")).has_all(["charge", "reckless"]), "ミノタウロス: 突進と捨て身")
	var fl := FloorMap.read_json(FloorMap.floor_path(1, 0, 4)) as Dictionary
	var m0: Dictionary = fl["encounters"][0]["monsters"][0]
	check(not m0.has("traits") and MonTraits.flags_for(m0) == MonTraits.flags_for(_line(String(m0["index"]))), "層のデータの魔物も、index から特徴を引ける (%s)" % m0["index"])

func _test_pack() -> void:
	print("[pack]")
	var h0 := _reset(Vector2(400, 256))
	var rats := _spawn("giant-rat", Vector2(380, 256), 1)
	await _step(20)
	var r0: Enemy = rats[0]
	var solo := r0.contact_dps()
	check(not r0._pack_on, "一匹だけなら、囲んでいない")
	var r1: Enemy = _spawn("giant-rat", Vector2(420, 256), 1)[0]
	r1.target = h0
	r0.target = h0
	await _step(20)
	check(r0._pack_on and is_equal_approx(r0.contact_dps(), solo * 1.3), "二匹が同じ相手に触れると、1.3倍痛い (%.2f → %.2f)" % [solo, r0.contact_dps()])
	var far := _reset(Vector2(200, 256))
	var a: Enemy = _spawn("giant-rat", Vector2(560, 236), 1)[0]
	var b: Enemy = _spawn("giant-rat", Vector2(560, 276), 1)[0]
	a.target = far
	b.target = far
	var ga := a._flank_goal()
	var gb := b._flank_goal()
	check(ga.distance_to(gb) > 1.0 or int(a.get_instance_id() % 5) == int(b.get_instance_id() % 5), "群れは、それぞれ別の向きから回り込む")

func _test_swarm() -> void:
	print("[swarm]")
	_reset(Vector2(100, 400))
	var sw: Enemy = _spawn("swarm-of-rats", Vector2(500, 250))[0]
	var rat: Enemy = _spawn("giant-rat", Vector2(560, 250))[0]
	check(Contact._passes(sw, rat) and not Contact._passes(rat, _spawn("giant-rat", Vector2(600, 250))[0]), "群れは、ほかの魔物とすり抜ける")
	var full := sw.contact_dps()
	sw.hp = sw.max_hp * 0.4
	check(is_equal_approx(sw.contact_dps(), full * 0.5), "群れは、HPが半分を切ると弱まる")

func _test_mimic() -> void:
	print("[mimic]")
	var h0 := _reset(Vector2(200, 256))
	var mm: Enemy = _spawn("mimic", Vector2(400, 256), 1, "idle")[0]
	await _step(15)
	check(mm.disguised and mm.state == "idle" and mm.contact_dps() == 0.0, "ミミックは、気づかれるまで物のふり")
	h0.position = Vector2(400 - mm.radius - h0.radius - 10.0, 256)
	await _step(15)
	check(not mm.disguised and mm.state == "chase" and mm.surprise_t > 0.0, "すぐそばまで来ると、飛びかかる(不意打ち)")
	check(mm.contact_dps() > 0.0, "飛びかかった直後は、体当たりが痛い")
	var gr: Enemy = _spawn("gray-ooze", Vector2(500, 300), 1, "idle")[0]
	gr.take_damage(1.0, Vector2.RIGHT, h0)
	check(not gr.disguised, "擬態は、攻撃されても解ける")

func _test_charge() -> void:
	print("[charge]")
	var h0 := _reset(Vector2(200, 256))
	var mt: Enemy = _spawn("minotaur", Vector2(360, 256))[0]
	mt.charge_cd = 0.0
	var hp0 := h0.ch.hp
	var wound := false
	var charged := false
	for i in 90:
		await physics_frame
		h0.position = Vector2(200, 256)
		if mt.windup_t > 0.0 or mt.charge_t > 0.0:
			charged = true
		if h0.ch.hp < hp0:
			wound = true
			break
	check(charged, "離れていると、構えて突進する")
	check(wound and mt.charge_cd > 0.0, "突進が当たると痛く、しばらく突進しない")
	var h1 := _reset(Vector2(200, 256))
	var bo: Enemy = _spawn("minotaur", Vector2(360, 256))[0]
	bo.charge_cd = 0.0
	var lost := 0.0
	var went := false
	for i in 90:
		var hp1 := h1.ch.hp
		await physics_frame
		h1.position = Vector2(200, 256)
		if bo.charge_t > 0.0:
			went = true
			h1.roll_t = 0.2        # 転がっている間は、当たらない
		elif went:
			break
		lost += maxf(0.0, hp1 - h1.ch.hp)
	check(went and lost == 0.0 and bo.charge_cd > 0.0, "転がってかわせば、突進は当たらない")

func _test_ghost() -> void:
	print("[ghost]")
	var h0 := _reset(Vector2(400, 256))
	var gh: Enemy = _spawn("specter", Vector2(40, 256))[0]
	gh._steer(0.5, Vector2(-200, 256), 60.0)
	var c := ar.fl.map.cell_of(gh.position)
	check(ar.fl.map.opaque(c.x, c.y), "すり抜ける魔物は、壁の中へ入れる")
	gh.position = Vector2(400, 40)
	check(gh._can_sense(h0), "壁越しでも、相手に気づく")

func _test_fortitude() -> void:
	print("[fortitude]")
	var h0 := _reset(Vector2(100, 400))
	var zb: Enemy = _spawn("zombie", Vector2(500, 256))[0]
	zb.con = 40
	zb.take_damage(zb.hp + 5.0, Vector2.RIGHT, h0)
	check(not zb.dead and zb.hp == 1.0, "ゾンビは、倒れても起き上がることがある")
	zb.fort_cd = 0.0
	zb.elem_hit("radiant")
	zb.take_damage(10.0, Vector2.RIGHT, h0)
	check(zb.dead, "光(聖撃)には耐えられない")
	var bo: Enemy = _spawn("boar", Vector2(500, 300))[0]
	bo.hp = 3.0
	bo.take_damage(4.0, Vector2.RIGHT, h0)
	var once := not bo.dead
	bo.take_damage(5.0, Vector2.RIGHT, h0)
	check(once and bo.dead, "猪は、一度だけ踏みとどまる")

func _test_regen() -> void:
	print("[regen]")
	var h0 := _reset(Vector2(100, 400))
	var tr: Enemy = _spawn("troll", Vector2(600, 256))[0]
	tr.stun_t = 5.0
	tr.hp -= 40.0
	var hp0 := tr.hp
	await _step(60)
	check(tr.hp > hp0 + 1.0, "トロルは、傷が塞がっていく (%.1f → %.1f)" % [hp0, tr.hp])
	tr.elem_hit("fire")
	tr.take_damage(1.0, Vector2.RIGHT, h0)
	var hp1 := tr.hp
	await _step(60)
	check(is_equal_approx(tr.hp, hp1) and tr.regen_stop_t > 0.0, "火で焼くと、しばらく再生しない")
	check(Jobs.SKILLS["fireball"].get("elem", "") == "fire" and Jobs.SKILLS["smite"].get("elem", "") == "radiant", "火球は火、聖撃は光")

func _test_burst() -> void:
	print("[burst]")
	var h0 := _reset(Vector2(300, 256))
	var mg: Enemy = _spawn("magmin", Vector2(330, 256))[0]
	var hp0 := h0.ch.hp
	mg.take_damage(9999.0, Vector2.RIGHT, h0)
	check(mg.dead and h0.ch.hp < hp0, "マグミンは、死に際に弾けて、まわりを焼く")

func _test_on_hit() -> void:
	print("[on hit]")
	var h0 := _reset(Vector2(300, 256))
	var mm: Enemy = _spawn("mimic", Vector2(600, 256))[0]
	mm.on_hit_hero(h0)
	check(h0.stuck_t > 0.0 and h0.stuck_kind == "glue", "ミミックに当たると、張りつかれる")
	var go: Enemy = _spawn("gray-ooze", Vector2(600, 300))[0]
	go.on_hit_hero(h0)
	check(h0.rust == 1, "グレイ・ウーズに当たると、鎧が錆びる")
	go.on_hit_hero(h0)
	check(h0.rust == 1, "錆は、続けてはかからない")
	var fs: Enemy = _spawn("flying-snake", Vector2(600, 340))[0]
	fs.on_hit_hero(h0)
	check(fs.flyby_t > 0.0, "空飛ぶヘビは、当てて離れる")
	var h1 := _reset(Vector2(300, 256))
	var en: Enemy = _spawn("flying-snake", Vector2(300 + h1.radius + 4.0, 256))[0]
	var before := h1.ch.hp
	h1.receive_contact(1.0, en.position, en)
	check(h1.ch.hp < before and en.flyby_t > 0.0, "体当たりが当たると、特徴の動きが起きる")

func _test_senses() -> void:
	print("[senses]")
	var h0 := _reset(Vector2(100, 256))
	var rat: Enemy = _spawn("giant-rat", Vector2(100 + 9.5 * 32.0, 256), 1, "idle")[0]
	var zb: Enemy = _spawn("zombie", Vector2(100 + 9.5 * 32.0, 300), 1, "idle")[0]
	check(rat._can_sense(h0) and not zb._can_sense(h0), "鋭い嗅覚の魔物は、遠くから気づく")
