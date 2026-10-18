extends SceneTree
## 魔法の武器・防具・品(ken 10/18「魔法武器防具アイテムを増やす」): Godot --headless --path godot -s res://tests/magic_items_test.gd

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
	_test_data()
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	await _test_dungeon()
	await _test_use()
	main.start_arena()
	await _step(3)
	ar = main.arena
	ar.set_all_levels(5)
	await _test_weapons()
	await _test_defense()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _test_data() -> void:
	print("[品の定義]")
	var ok := true
	var kinds := {}
	for id in ItemDB.MAGIC_ITEMS:
		var it: Dictionary = ItemDB.ITEMS.get(id, {})
		if it.is_empty() or not it.get("magic", false) or int(it.get("mlayer", 0)) < 1 or int(it.get("price", 0)) <= 0 or String(it.get("desc", "")) == "":
			ok = false
		kinds[String(it.get("kind", ""))] = int(kinds.get(String(it.get("kind", "")), 0)) + 1
	check(ok and ItemDB.MAGIC_ITEMS.size() >= 20, "魔法の品が %d種(どれも魔法の印、出はじめる層、値段、説明がある)" % ItemDB.MAGIC_ITEMS.size())
	check(int(kinds.get("weapon", 0)) >= 8 and int(kinds.get("armor", 0)) >= 3 and int(kinds.get("acc", 0)) >= 7 and int(kinds.get("consumable", 0)) >= 2, "武器・防具・装飾品・消耗品がそろう %s" % str(kinds))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shallow := true
	var deep := {}
	for i in 300:
		var a := ItemDB.roll_magic(1, rng)
		if int(ItemDB.ITEMS[a]["mlayer"]) > 1:
			shallow = false
		deep[ItemDB.roll_magic(10, rng)] = true
	check(shallow, "第1層では、第1層から出る品だけ")
	check(deep.size() >= 15, "深い層では、ほとんどの品が出る (%d種)" % deep.size())
	var gear_only := true
	for i in 100:
		if String(ItemDB.ITEMS[ItemDB.roll_magic(10, rng, ["weapon", "armor", "acc"])]["kind"]) == "consumable":
			gear_only = false
	check(gear_only, "種類を絞れる(層の主は武器・防具・装飾品だけ)")
	check(ItemDB.PLUS_ITEMS.has("m1_longsword") and ItemDB.PLUS_ITEMS.has("m3_plate") and ItemDB.item_name("m2_longsword") == "長剣+2"
		and is_equal_approx(float(ItemDB.ITEMS["m2_longsword"]["power"]), float(ItemDB.ITEMS["longsword"]["power"]) + 2.0)
		and int(ItemDB.ITEMS["m3_plate"]["ac"]) == int(ItemDB.ITEMS["plate"]["ac"]) + 3 and ItemDB.is_magic("m1_spear"), "ふつうの武器・防具の+1〜+3がある(長剣+2 は威力+2、板金鎧+3 は防御+3)")
	var plus_shallow := true
	var plus_seen := {}
	for i in 400:
		var a2 := ItemDB.roll_magic_drop(2, rng)
		if ItemDB.PLUS_ITEMS.has(a2):
			plus_seen[int(ItemDB.PLUS_ITEMS[a2]["plus"])] = true
		if int(ItemDB.ITEMS[a2]["mlayer"]) > 2:
			plus_shallow = false
	var deep_plus := {}
	for i in 400:
		var a3 := ItemDB.roll_magic_drop(9, rng)
		if ItemDB.PLUS_ITEMS.has(a3):
			deep_plus[int(ItemDB.PLUS_ITEMS[a3]["plus"])] = true
	check(plus_shallow and plus_seen.keys() == [1] and deep_plus.has(3), "落とし物の半分は+N。第2層では+1だけ、深い層では+3も出る")
	check(ItemDB.grade("m1_longsword") == "plus1" and ItemDB.grade("m2_longsword") == "magic" and ItemDB.grade("flame_tongue") == "magic"
		and ItemDB.grade("m3_plate") == "legend" and ItemDB.grade("sun_blade") == "legend" and ItemDB.grade("longsword") == "",
		"名前の色: +1 は薄緑、名のある品と+2 は青、+3 と第6層からの品は黄色(ken 10/18)")
	check(ItemDB.name_color("longsword", Color.RED) == Color.RED and ItemDB.name_color("m3_plate", Color.RED).r > 0.9 and ItemDB.name_color("flame_tongue", Color.RED).b > 0.9
		and ItemDB.name_color("m1_spear", Color.RED).g > 0.9, "色は黄・青・薄緑。ふつうの品はもとの色")
	var in_gear := false
	for i in 400:
		if ItemDB.is_magic(ItemDB.roll_gear(10, rng)):
			in_gear = true
	check(not in_gear, "ふつうの装備の落とし物には混ざらない")
	check(ItemDB.SHOPS["magic"].has("fire_bead") and ItemDB.SHOPS["magic"].has("fire_res_draught") and ItemDB.SHOPS["magic"].has("ring_feather")
		and not ItemDB.SHOPS["smith"].any(func(x): return ItemDB.is_magic(x)), "書院で、火球の珠・耐火の水薬・羽落ちの指輪だけ売る")
	check(ItemDB.detail("flame_tongue").contains("傷の種類: 火") and ItemDB.detail("mace_disruption").contains("亡者に ×1.6") and ItemDB.detail("fireproof_plate").contains("火の傷が半分")
		and ItemDB.detail("ring_regen").contains("[魔法の品]"), "説明に、効き目と魔法の品の印")
	check(ItemIcons.has_icon("fire_bead") and ItemIcons.has_icon("fire_res_draught"), "魔法の消耗品に絵がある")
	check(CreditsScreen.SRD_JA.contains("魔法の品") and CreditsScreen.SRD_CHANGES.contains("magic items"), "クレジットの SRD の改変の記述に、魔法の品を足した")
	var c := Character.create("fighter", "human", "fighter", Jobs.auto_stats("fighter"))
	var ac0 := c.armor_class()
	c.equip["acc"] = "ring_protection"
	check(c.armor_class() == ac0 + 2, "守りの指輪で防御+2")
	var l0 := c.light_bonus()
	c.equip["weapon"] = "sun_blade"
	check(c.light_bonus() == l0 + 2, "陽光の剣は、持つだけで灯りが2マス広がる(武器の fx)")
	c.equip["armor"] = "chain_mail"
	var s_heavy := c.speed()
	c.equip["armor"] = "mithral_mail"
	check(c.speed() > s_heavy and c.armor_class() > 0, "真銀の鎖帷子は、重装でも足が遅くならない")
	check(ItemDB.can_equip("elven_chain", "wizard") == false and ItemDB.can_equip("elven_chain", "rogue"), "森人の鎖の胴着は軽装(盗賊が着られる)")
	check(c.resists("") == false and not c.resists("fire"), "耐性の無い装備では、火は半分にならない")
	c.equip["weapon"] = "frost_brand"
	check(c.resists("fire"), "霜の刃を持つと、火に強くなる")

func _test_dungeon() -> void:
	print("[迷宮: 羽落ち・落とし物・拾う]")
	main.start_day()
	await _step(5)
	var fl: FloorInstance = main.current
	fl.traps.clear()
	fl.trap_at.clear()
	fl.spawner.pending.clear()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
	var lead: Hero = main.leader()
	lead.ch.equip["acc"] = "ring_feather"
	for h in main.heroes:
		h.ch.hp = h.ch.max_hp()
	main._fall_down()
	await _step(3)
	var l2: Hero = main.leader()
	var others_hurt := false
	for h in main.heroes:
		if h != l2 and h.ch.hp < h.ch.max_hp():
			others_hurt = true
	check(l2.ch.hp == l2.ch.max_hp() and others_hurt, "落とし穴: 羽落ちの指輪の人だけ傷を負わない")
	check(main.current.get_children().any(func(n): return n is Sfx and (n as Sfx).text == "ふわり"), "羽落ちの指輪で「ふわり」")
	fl = main.current
	var n0: int = fl.ground.entries.size()
	LayerBoss.drop_loot(fl, 2, l2.position + Vector2(40, 0))
	var mid := LayerBoss.last_magic
	check(mid != "" and ItemDB.is_magic(mid) and int(ItemDB.ITEMS[mid]["mlayer"]) <= 2 and String(ItemDB.ITEMS[mid]["kind"]) != "consumable"
		and fl.ground.entries.any(func(e): return String(e.get("id", "")) == mid) and fl.ground.entries.size() >= n0 + 3,
		"層の主は、魔法の品を必ず一つ落とす (%s)" % mid)
	main._on_ground_picked({"kind": "item", "id": "ring_protection", "qty": 1, "pos": l2.position}, l2)
	check(main.gs.count("ring_protection") == 1, "拾うと持ち物に入る")
	check(fl.get_children().any(func(n): return n is Sfx and (n as Sfx).text == "シャラーン"), "魔法の品を拾うと「シャラーン」")

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
		h.poison_t = 0.0
		h.iframes = 0.0
		h.buffs.clear()
		h.controlled = i == 0
		h.cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		if i > 0:
			h.position = Vector2(48.0 + i * 30.0, 48.0)
			h.down = true
	var h0: Hero = main.heroes[0]
	h0.position = pos
	h0._note_cd = 0.0
	main.active = 0
	main.current.leader = h0
	return h0

func _spawn(index: String, pos: Vector2) -> Enemy:
	var f: FloorInstance = ar.fl if ar != null else main.current
	var en := Enemy.new()
	en.setup(f, _line(index, 1), {"id": 900, "kind": "beast"}, pos)
	en.state = "idle"
	en.disguised = false
	en.lurk = ""
	en.died.connect(f._on_enemy_died)
	f.add_child(en)
	f.enemies.append(en)
	return en

func _hit_loss(h: Hero, en: Enemy, amount: float) -> float:
	en.hp = float(en.max_hp)
	var hp0: float = en.hp
	en.take_damage(amount, Vector2.RIGHT, h)
	return hp0 - en.hp

func _test_weapons() -> void:
	print("[魔法の武器]")
	var c0 := Vector2(400, 300)
	var h := _reset(c0)
	var z := _spawn("zombie", c0 + Vector2(30, 0))
	await _step(1)
	h.ch.equip["weapon"] = "mace"
	var plain := _hit_loss(h, z, 6.0)
	h.ch.equip["weapon"] = "mace_disruption"
	var holy := _hit_loss(h, z, 6.0)
	check(holy > plain * 1.5, "破邪の鎚矛は亡者によく効く (%.1f → %.1f)" % [plain, holy])
	var g := _spawn("goblin", c0 + Vector2(0, 60))
	await _step(1)
	var g1 := _hit_loss(h, g, 6.0)
	h.ch.equip["weapon"] = "mace"
	check(absf(_hit_loss(h, g, 6.0) - g1) < 0.01, "亡者でなければ、ふつうの鎚矛と同じ")
	ar.clear_enemies()
	await _step(1)

	h = _reset(c0)
	var tr := _spawn("troll", c0 + Vector2(26, 0))
	await _step(1)
	h.ch.equip["weapon"] = "flame_tongue"
	h.atk_cd = 0.0
	var n := h._swing_hit(Vector2.RIGHT, 1.0, 1.0, 1.0, 0.2)
	check(n == 1 and tr.regen_stop_t > 0.0, "炎の舌で斬ると、トロールの再生が止まる")
	check(h.weapon_magic() and h.weapon_elem() == "fire", "炎の舌は魔法の武器で、傷は火")
	ar.clear_enemies()
	await _step(1)

	h = _reset(c0)
	var z2 := _spawn("zombie", c0 + Vector2(26, 0))
	await _step(1)
	h.ch.equip["weapon"] = "life_stealer"
	h.ch.hp = h.ch.max_hp() * 0.5
	var hp0: float = h.ch.hp
	z2.hp = float(z2.max_hp)
	h.atk_cd = 0.0
	h._swing_hit(Vector2.RIGHT, 1.0, 1.0, 1.0, 0.2)
	check(h.ch.hp > hp0, "命吸いの剣で斬ると、癒える (%.1f → %.1f)" % [hp0, h.ch.hp])
	ar.clear_enemies()
	await _step(1)
	h = _reset(c0)
	var gb := _spawn("goblin", c0 + Vector2(26, 0))
	await _step(1)
	h.ch.equip["weapon"] = "venom_dagger"
	var got := false
	for i in 40:
		gb.hp = float(gb.max_hp) * 10.0
		gb.poison_t = 0.0
		gb.position = c0 + Vector2(26, 0)
		h.atk_cd = 0.0
		h._swing_hit(Vector2.RIGHT, 0.2, 1.0, 0.0, 0.2)
		if gb.poison_t > 0.0:
			got = true
			break
	check(got, "毒蛇の短剣は、ときどき毒にする")
	ar.clear_enemies()
	await _step(1)

func _test_defense() -> void:
	print("[魔法の防具と装飾品]")
	var h := _reset(Vector2(400, 300))
	h.ch.equip["armor"] = "leather"
	h.ch.equip["acc"] = ""
	h.ch.hp = h.ch.max_hp()
	h.damage(10.0, h.position + Vector2(1, 0), true, "", "fire")
	var plain: float = h.ch.max_hp() - h.ch.hp
	h.ch.hp = h.ch.max_hp()
	h.iframes = 0.0
	h.ch.equip["armor"] = "fireproof_plate"
	h.damage(10.0, h.position + Vector2(1, 0), true, "", "fire")
	var half: float = h.ch.max_hp() - h.ch.hp
	check(absf(half - plain * 0.5) < 0.01, "耐火の胸甲で、火の傷が半分 (%.1f → %.1f)" % [plain, half])
	h.ch.hp = h.ch.max_hp()
	h.iframes = 0.0
	h.damage(10.0, h.position + Vector2(1, 0), true, "", "cold")
	check(absf((h.ch.max_hp() - h.ch.hp) - plain) < 0.01, "火でない傷は、そのまま")
	h.ch.equip["armor"] = "leather"
	h.buffs["fire_res"] = {"t": 10.0, "v": 0.5}
	h.ch.hp = h.ch.max_hp()
	h.iframes = 0.0
	h.damage(10.0, h.position + Vector2(1, 0), true, "", "fire")
	check(absf((h.ch.max_hp() - h.ch.hp) - plain * 0.5) < 0.01, "耐火の水薬の間も、火の傷が半分")
	h.buffs.clear()
	h.ch.equip["acc"] = "periapt_poison"
	h.ch.hp = h.ch.max_hp()
	h.poison(5.0, 3.0)
	h.damage(10.0, h.position + Vector2(1, 0), true, "", "poison")
	check(h.poison_t <= 0.0 and h.ch.hp == h.ch.max_hp(), "毒除けの護符で、毒も毒の傷も効かない")
	h.ch.equip["acc"] = "ring_regen"
	h.ch.hp = h.ch.max_hp() * 0.5
	var r0: float = h.ch.hp
	await _step(60)
	check(h.ch.hp > r0, "再生の指輪で、迷宮の中でも傷が塞がる (%.2f → %.2f)" % [r0, h.ch.hp])
	h.ch.equip["acc"] = ""

func _test_use() -> void:
	print("[魔法の消耗品]")
	var h: Hero = main.leader()
	h.facing = Vector2.RIGHT
	var g := _spawn("goblin", h.position + Vector2(3.0 * Balance.CELL, 0))
	var far := _spawn("goblin", h.position + Vector2(0, 9.0 * Balance.CELL))
	await _step(1)
	g.hp = float(g.max_hp) * 10.0
	var g0: float = g.hp
	var f0: float = far.hp
	main.gs.add_item("fire_bead", 1)
	main.open_inventory()
	await process_frame
	check(main.use_special("fire_bead", h.ch), "火球の珠を投げられる")
	main.close_inventory()
	await process_frame
	check(g.hp < g0 and far.hp == f0, "前の魔物だけ焼ける (%.0f → %.0f)" % [g0, g.hp])
	check(main.current.get_children().any(func(n): return n is Sfx and (n as Sfx).text == "ボウッ"), "閉じたら「ボウッ」")
	main.open_inventory()
	await process_frame
	check(main.use_special("fire_res_draught", h.ch) and h.buff("fire_res") < 1.0, "耐火の水薬を飲むと、火に強くなる")
	main.close_inventory()
	await process_frame
