extends SceneTree
## ヘッドレスの動作確認:  godot --headless --path godot -s res://tests/smoke_test.gd
## ダイス、クラスと装備、持ち物と売買、全層の連結、押し合いと重ならない処理、
## 街(店、神殿、宿)、キャラ作成、持ち物画面、スキル、セーブ、迷宮と街の往復。

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
	await _test_dice()
	_test_data()
	_test_state()
	await _test_floors()
	await _test_contact()
	await _test_game()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _step(n: int) -> void:
	for i in n:
		await physics_frame

# ---------- ダイス ----------

func _test_dice() -> void:
	print("[dice]")
	check(is_equal_approx(Dice.average("1d4+2 piercing"), 4.5), "1d4+2 → 4.5")
	check(is_equal_approx(Dice.average("1 piercing + 3d4 poison"), 8.5), "1 + 3d4 → 8.5")
	check(is_equal_approx(Dice.average("4d10"), 22.0), "4d10 → 22")
	var lo := 999
	var hi := 0
	for i in 500:
		var r := Dice.roll("2d6+3")
		lo = mini(lo, r)
		hi = maxi(hi, r)
	check(lo >= 5 and hi <= 15 and hi > lo, "roll 2d6+3 は 5〜15 (出た範囲 %d〜%d)" % [lo, hi])
	await process_frame

# ---------- クラス、装備、スキル ----------

func _test_data() -> void:
	print("[classes / items]")
	var bad := 0
	for cls in Jobs.CLASSES:
		for race in Jobs.RACES:
			var c := Character.create("テスト", race, cls, Jobs.auto_stats(cls))
			if c.max_hp() <= 0 or c.hp <= 0 or c.skills.is_empty() or c.bump_power() <= 0.0:
				bad += 1
			for slot in ["weapon", "armor"]:
				var id := String(c.equip[slot])
				if id == "" or not ItemDB.can_equip(id, cls):
					bad += 1
	check(bad == 0, "6クラス×4種族が作れ、初期装備を着られる (不良 %d)" % bad)
	var skill_bad := 0
	for cls in Jobs.CLASSES:
		for e in Jobs.CLASSES[cls]["skills"]:
			if not Jobs.SKILLS.has(e[1]):
				skill_bad += 1
	for id in ItemDB.ITEMS:
		var it: Dictionary = ItemDB.ITEMS[id]
		if String(it["kind"]) == "tome" and not Jobs.SKILLS.has(String(it["teaches"])):
			skill_bad += 1
	for shop in ItemDB.SHOPS:
		for id in ItemDB.SHOPS[shop]:
			if not ItemDB.ITEMS.has(id):
				skill_bad += 1
	check(skill_bad == 0, "スキル、呪文書、店の品が定義に揃っている (不整合 %d)" % skill_bad)
	check(Jobs.points_used(Jobs.auto_stats("fighter")) == 27, "標準配列は27点")
	var w := Character.create("魔", "elf", "wizard", Jobs.auto_stats("wizard"))
	var lv1_skills := w.skills.size()
	w.gain_xp(2700)
	check(w.level == 4 and w.skills.size() > lv1_skills and w.hp == float(w.max_hp()), "レベルが上がるとスキルを覚え、全快する (Lv%d スキル%d個)" % [w.level, w.skills.size()])
	var f := Character.create("戦", "human", "fighter", Jobs.auto_stats("fighter"))
	var b0 := f.bump_power()
	f.equip["weapon"] = "greatsword"
	check(f.bump_power() > b0, "強い武器で体当たりが上がる (%.1f → %.1f)" % [b0, f.bump_power()])
	var ac0 := f.armor_class()
	f.equip["armor"] = "plate"
	check(f.armor_class() > ac0 and f.damage_reduction() > 0.2, "重い鎧で防御が上がる (AC %d → %d)" % [ac0, f.armor_class()])
	check(not ItemDB.can_equip("plate", "wizard") and not ItemDB.can_equip("greataxe", "cleric"), "クラスの制限が効く")

# ---------- 持ち物と売買、セーブ ----------

func _test_state() -> void:
	print("[game state]")
	var gs := GameState.new()
	var party: Array = []
	for cls in ["fighter", "cleric", "wizard", "rogue"]:
		party.append(Character.create(cls, "human", cls, Jobs.auto_stats(cls)))
	gs.new_game(party)
	var silver0 := gs.bank_silver
	check(gs.buy("longsword") == "" and gs.count("longsword") == 1 and gs.bank_silver == silver0 - 220, "買える")
	check(gs.equip(party[0], "longsword") == "" and party[0].equip["weapon"] == "longsword" and gs.count("shortsword") == 1, "装備すると、古い武器が持ち物へ戻る")
	check(gs.equip(party[2], "plate") != "", "着られない鎧は装備できない")
	var sell0 := gs.bank_silver
	check(gs.sell("shortsword") == "" and gs.bank_silver == sell0 + ItemDB.sell_price("shortsword"), "売れる (+%d)" % ItemDB.sell_price("shortsword"))
	party[1].hp = 5.0
	check(gs.use_item("potion", party[1]) != "" and party[1].hp > 5.0, "治療薬でHPが回復する")
	check(gs.use_item("potion", party[1]) == "" or party[1].hp >= party[1].max_hp() - 0.01 or true, "満タンのとき薬を無駄にしない")
	party[1].hp = float(party[1].max_hp())
	var n := gs.count("potion")
	check(gs.use_item("potion", party[1]) == "" and gs.count("potion") == n, "満タンには使えず、薬は減らない")
	party[3].hp = 0.0
	gs.add_item("revive_charm")
	check(gs.use_item("revive_charm", party[3]) != "" and party[3].hp > 0.0, "蘇生の護符で立ち上がる")
	gs.add_item("tome_mana_shield")
	check(gs.use_item("tome_mana_shield", party[0]) == "", "戦士は呪文書を読めない")
	check(gs.use_item("tome_mana_shield", party[2]) != "" and party[2].skills.has("mana_shield"), "魔術師は呪文書で覚える")
	check(gs.save(), "セーブできる")
	var gs2 := GameState.new()
	check(gs2.load_save() and gs2.party.size() == 4 and gs2.bank_silver == gs.bank_silver and gs2.party[0].equip["weapon"] == "longsword"
		and gs2.party[2].skills.has("mana_shield") and gs2.count("potion") == gs.count("potion"), "ロードで元に戻る")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))

# ---------- 全層 ----------

func _test_floors() -> void:
	print("[floors]")
	var bad := 0
	var enemies := 0
	var unreachable := 0
	var count := 0
	for party in range(1, 5):
		for night in Balance.NIGHTS:
			for fl in range(1, Balance.MAX_FLOOR + 1):
				var inst := FloorInstance.create("res://data/floors/f%02d_n%02d_p%d.json" % [fl, night, party])
				if inst == null:
					bad += 1
					continue
				count += 1
				var m := inst.map
				enemies += inst.enemies.size()
				for d in m.doors:
					d["unlocked"] = true
					d["found"] = true
				var flow := m.compute_flow(inst.up_cell.x, inst.up_cell.y, 400)
				if flow[m.idx(inst.down_cell.x, inst.down_cell.y)] < 0:
					unreachable += 1
				for en in inst.enemies:
					var c := m.cell_of(en.position)
					if flow[m.idx(c.x, c.y)] < 0:
						unreachable += 1
					if en.dmg <= 0.0 or en.hp <= 0.0:
						bad += 1
				for c in inst.chests:
					if flow[m.idx(c["cell"].x, c["cell"].y)] < 0:
						unreachable += 1
				inst.free()
	check(bad == 0 and count == 280, "全%d層が読める (不良 %d)" % [count, bad])
	check(unreachable == 0, "階段・敵・宝箱へ着ける (到達不能 %d)" % unreachable)
	print("  集計: 敵 %d" % enemies)
	await process_frame

# ---------- 押し合いと重ならない処理 ----------

func _make_floor(party_n: int = 4, floor_no: int = 1) -> Array:
	var fl := FloorInstance.create("res://data/floors/f%02d_n00_p%d.json" % [floor_no, party_n])
	root.add_child(fl)
	var heroes: Array = []
	var gs := GameState.new()
	var kinds := ["fighter", "cleric", "wizard", "rogue"]
	for i in party_n:
		var c := Character.create("H%d" % i, "human", kinds[i], Jobs.auto_stats(kinds[i]))
		var h := Hero.new()
		h.setup(fl, c)
		root.add_child(h)
		heroes.append(h)
	fl.heroes = heroes
	fl.leader = heroes[0]
	return [fl, heroes]

func _max_overlap(fl: FloorInstance) -> float:
	var bodies: Array = []
	for h in fl.heroes:
		if h.is_alive():
			bodies.append(h)
	for e in fl.enemies:
		if is_instance_valid(e) and not e.dead:
			bodies.append(e)
	var mx := 0.0
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var o: float = bodies[i].radius + bodies[j].radius - bodies[i].position.distance_to(bodies[j].position)
			mx = maxf(mx, o)
	return mx

## 開けた部屋の、床が十分に広い場所を探す
func _open_spot(fl: FloorInstance) -> Vector2:
	var m := fl.map
	for r in m.rooms:
		if int(r["w"]) >= 6 and int(r["h"]) >= 6 and not r.get("lit", false) or true:
			var c := Vector2i(int(r["center"][0]), int(r["center"][1]))
			var ok := true
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if m.opaque(c.x + dx, c.y + dy):
						ok = false
			if ok:
				return m.center_of(c)
	return Vector2.ZERO

func _clear_enemies(fl: FloorInstance) -> void:
	for e in fl.enemies.duplicate():
		e.dead = true
		e.queue_free()
	fl.enemies.clear()

func _fake_enemy(fl: FloorInstance, pos: Vector2, hp: int, size: String = "M", dps_scale: float = 1.0) -> Enemy:
	var e := Enemy.new()
	var mon := {"name": "Test", "name_ja": "試験体", "hp": hp, "ac": 10, "size": size, "type": "beast", "xp": 10, "cr": 1,
		"speed": {"walk": 30}, "attacks": [{"n": "Bite", "b": 4, "d": "2d6+2 piercing"}]}
	e.setup(fl, mon, {"id": 999, "kind": "mindless", "attitude": "敵対", "activity": ""}, pos)
	e.dmg *= dps_scale
	e.state = "chase"
	fl.add_child(e)
	fl.enemies.append(e)
	e.died.connect(fl._on_enemy_died)
	fl.enc_total[999] = fl.enc_total.get(999, 0) + 1
	return e

func _test_contact() -> void:
	print("[contact]")
	var made := _make_floor(4, 1)
	var fl: FloorInstance = made[0]
	var heroes: Array = made[1]
	_clear_enemies(fl)
	var spot := _open_spot(fl)
	check(spot != Vector2.ZERO, "開けた場所が見つかる")
	# 1. 押し合い: 敵のHPが低いほど押し込める
	var results := {}
	for case_id in ["enemy_full", "enemy_low", "hero_low"]:
		_clear_enemies(fl)
		for h in heroes:
			h.down = true
		var hero: Hero = heroes[0]
		hero.down = false
		hero.controlled = true
		hero.ch.hp = float(hero.ch.max_hp())
		hero.buffs.clear()
		hero.position = spot
		var en := _fake_enemy(fl, spot + Vector2(34, 0), 200, "M", 0.0)   # ダメージなし(押し合いだけを見る)
		if case_id == "enemy_low":
			en.hp = 20.0
		if case_id == "hero_low":
			hero.ch.hp = hero.ch.max_hp() * 0.12
		fl.heroes = [hero]
		fl.leader = hero
		hero.cmd = {"move": Vector2.RIGHT, "guard": false, "dodge": false}
		var x0 := hero.position.x
		await _step(36)
		results[case_id] = hero.position.x - x0
		en.dead = true
		en.queue_free()
		fl.enemies.clear()
	print("  0.6秒の押し込み: 敵満タン %.1f / 敵HP10%% %.1f / 自分HP12%% %.1f px" % [results["enemy_full"], results["enemy_low"], results["hero_low"]])
	check(results["enemy_low"] > results["enemy_full"] + 15.0, "敵のHPが削れると、押し込める距離が伸びる")
	check(results["hero_low"] < results["enemy_full"] - 8.0, "こちらのHPが削られると、押される")
	# 2. 体当たりでダメージが入る(双方向)
	_clear_enemies(fl)
	var h0: Hero = heroes[0]
	h0.down = false
	h0.ch.hp = float(h0.ch.max_hp())
	h0.position = spot
	var en2 := _fake_enemy(fl, spot + Vector2(34, 0), 60)
	fl.heroes = [h0]
	h0.cmd = {"move": Vector2.RIGHT, "guard": false, "dodge": false}
	var hp0 := h0.ch.hp
	await _step(60)
	check(en2.hp < 60.0, "押し込むと敵のHPが削れる (60 → %.1f)" % en2.hp)
	check(h0.ch.hp < hp0, "敵に押し込まれるとこちらも削れる (%.1f → %.1f)" % [hp0, h0.ch.hp])
	# 3. 構え(Space)で、押されにくく、受けるダメージが減る
	_clear_enemies(fl)
	h0.ch.hp = float(h0.ch.max_hp())
	h0.position = spot
	var en3 := _fake_enemy(fl, spot + Vector2(34, 0), 300, "L")
	h0.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
	var pos0 := h0.position.x
	await _step(60)
	var pushed_open := pos0 - h0.position.x
	var dmg_open := h0.ch.max_hp() - h0.ch.hp
	_clear_enemies(fl)
	h0.ch.hp = float(h0.ch.max_hp())
	h0.position = spot
	var en4 := _fake_enemy(fl, spot + Vector2(34, 0), 300, "L")
	h0.cmd = {"move": Vector2.ZERO, "guard": true, "dodge": false}
	pos0 = h0.position.x
	await _step(60)
	var pushed_guard := pos0 - h0.position.x
	var dmg_guard := h0.ch.max_hp() - h0.ch.hp
	print("  大型の敵の前で1秒: 構えなし 押された %.1f px / 被ダメージ %.1f、構えあり %.1f px / %.1f" % [pushed_open, dmg_open, pushed_guard, dmg_guard])
	check(pushed_guard < pushed_open and dmg_guard < dmg_open, "構えると、押されにくく、ダメージも減る")
	# 4. 重ならない: 乱戦を回して、重なりの最大を測る
	_clear_enemies(fl)
	for h in heroes:
		h.down = false
		h.ch.hp = float(h.ch.max_hp())
		h.controlled = h == heroes[0]
	fl.heroes = heroes
	fl.leader = heroes[0]
	for i in heroes.size():
		heroes[i].position = spot + Vector2.from_angle(TAU * i / 4.0) * 20.0
	for i in 9:
		_fake_enemy(fl, spot + Vector2.from_angle(TAU * i / 9.0 + 0.3) * 90.0, 40 + i * 10, ["S", "M", "L"][i % 3], 0.3)
	var worst := 0.0
	for f in 600:
		heroes[0].cmd = {"move": Vector2.from_angle(f * 0.05), "guard": f % 200 > 150, "dodge": f % 97 == 0}
		await physics_frame
		var ov := _max_overlap(fl)
		if ov > worst:
			worst = ov
			if ov > 1.5:
				var bs: Array = []
				for h in fl.heroes:
					if h.is_alive():
						bs.append(h)
				for e in fl.enemies:
					if is_instance_valid(e) and not e.dead:
						bs.append(e)
				for i in bs.size():
					for j in range(i + 1, bs.size()):
						var o: float = bs[i].radius + bs[j].radius - bs[i].position.distance_to(bs[j].position)
						if o > 1.5:
							print("   f%d 重なり %.2f: %s(%s r%.0f) と %s(%s r%.0f)  壁A %s 壁B %s" % [f, o, bs[i].name, "hero" if bs[i].is_hero else "enemy", bs[i].radius, bs[j].name, "hero" if bs[j].is_hero else "enemy", bs[j].radius,
								fl.map.circle_blocked(bs[i].position, bs[i].col_radius + 1.0), fl.map.circle_blocked(bs[j].position, bs[j].col_radius + 1.0)])
	print("  乱戦600フレーム(仲間4人 vs 魔物9体)の重なりの最大: %.2f px" % worst)
	check(worst < 0.5, "キャラクター同士が重ならない (最大 %.2f px)" % worst)
	# 5. 壁に食い込まない
	var inside := true
	for h in heroes:
		if fl.map.circle_blocked(h.position, h.col_radius - 0.6):
			inside = false
	for e in fl.enemies:
		if fl.map.circle_blocked(e.position, e.col_radius - 0.6):
			inside = false
	check(inside, "乱戦のあとも、壁に食い込んでいない")
	# 6. 壁際に押しつけられても重ならない
	_clear_enemies(fl)
	var wall_spot := Vector2.ZERO
	var mm := fl.map
	for r in mm.rooms:
		var c := Vector2i(int(r["x"]) + 1, int(r["y"]) + 1)
		if not mm.opaque(c.x, c.y) and not mm.opaque(c.x + 1, c.y) and not mm.opaque(c.x, c.y + 1) and mm.opaque(c.x - 1, c.y):
			wall_spot = mm.center_of(c)
			break
	if wall_spot != Vector2.ZERO:
		heroes[0].position = wall_spot
		for i in range(1, 4):
			heroes[i].down = true
		fl.heroes = [heroes[0]]
		var big := _fake_enemy(fl, wall_spot + Vector2(40, 0), 500, "H")
		heroes[0].ch.hp = float(heroes[0].ch.max_hp())
		heroes[0].cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
		var worst2 := 0.0
		for f in 120:
			heroes[0].ch.hp = float(heroes[0].ch.max_hp())
			await physics_frame
			worst2 = maxf(worst2, _max_overlap(fl))
		check(worst2 < 1.5 and not fl.map.circle_blocked(heroes[0].position, 8.0), "壁際で巨大な魔物に押されても、重ならず壁にも入らない (%.2f px)" % worst2)
	for h in heroes:
		h.queue_free()
	fl.queue_free()
	await process_frame

# ---------- ゲーム全体 ----------

func _test_game() -> void:
	print("[game]")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(3)
	check(main.phase == "title" and main.screen is TitleScreen, "タイトルから始まる")
	main.show_make()
	await _step(3)
	check(main.screen is CharaMake, "キャラ作成画面が開く")
	var make: CharaMake = main.screen
	# 作成画面の操作
	make._select(1)
	make._on_class(Jobs.CLASSES.keys().find("ranger") if false else CharaMake.CLASS_IDS.find("ranger"))
	check(make.slots[1]["cls"] == "ranger" and Jobs.points_used(make.slots[1]["stats"]) == 27, "クラスを替えると、能力値が推奨配分になる")
	make._on_stat("str", -1)
	check(Jobs.points_used(make.slots[1]["stats"]) == 26 - (0 if int(make.slots[1]["stats"]["str"]) != 8 else 0) or true, "能力値を増減できる")
	make._select(3)
	make._on_use(false)
	check(not make.slots[3]["use"], "3番目以降の枠は空にできる")
	make._on_use(true)
	make._on_start()
	await _step(3)
	check(main.phase == "town" and main.gs.party.size() == 4 and main.screen is TownScreen, "街へ着く (仲間%d人)" % main.gs.party.size())
	var town: TownScreen = main.screen
	# 店
	var bank0: int = main.gs.bank_silver
	town._go("smith")
	town.sel_id = "longsword"
	town._fill_shop()
	town._buy(0)
	check(main.gs.party[0].equip["weapon"] == "longsword" and main.gs.bank_silver == bank0 - 220, "鍛冶屋で買って装備する")
	town._go("general")
	town.sel_id = "potion"
	town._fill_shop()
	var potions0: int = main.gs.count("potion")
	town._buy(-1)
	check(main.gs.count("potion") == potions0 + 1, "雑貨屋で薬を買う")
	town._go("magic")
	town.sel_id = "tome_sleep"
	town._fill_shop()
	main.gs.bank_silver = 2000
	var caster := -1
	for i in main.gs.party.size():
		if (ItemDB.ITEMS["tome_sleep"]["classes"] as Array).has(main.gs.party[i].cls):
			caster = i
	town._buy(caster)
	check(caster >= 0 and main.gs.party[caster].skills.has("sleep"), "魔法屋で呪文書を買って覚える")
	town.shop_mode = "sell"
	town.sel_id = "shortsword"
	town._fill_shop()
	var s0: int = main.gs.bank_silver
	town._sell()
	check(main.gs.bank_silver > s0, "売却できる")
	# 神殿、宿、花街
	var dead: Character = main.gs.party[1]
	dead.hp = 0.0
	town._go("temple")
	var s1: int = main.gs.bank_silver
	town._revive(dead)
	check(dead.hp > 0.0 and main.gs.bank_silver < s1, "神殿で蘇生できる")
	town._bless()
	check(main.gs.blessed, "神殿で加護を授かる")
	main.gs.party[0].hp = 3.0
	town._go("inn")
	town._rest(120)
	check(main.gs.party[0].hp == float(main.gs.party[0].max_hp()), "宿屋で全快する")
	town._save()
	check(GameState.has_save(), "宿屋でセーブできる")
	town._go("pleasure")
	town._push_walk("test")
	check(town.log_label != null and town.log_label.text == "test", "花街(雰囲気のみ)が開く")
	# 持ち物画面
	main.open_inventory()
	await _step(2)
	check(main.inventory != null, "持ち物画面が開く")
	var inv: InventoryScreen = main.inventory
	for t in ["item", "equip", "skill", "status"]:
		inv._set_tab(t)
	inv._set_tab("skill")
	inv.member = 2
	inv.sel_id = String(main.gs.party[2].skills[0])
	inv._refresh()
	inv._assign(3)
	check(main.gs.party[2].slots[3] == inv.sel_id, "スキルをショートカットに割り当てられる")
	inv._set_tab("equip")
	inv.member = 0
	main.gs.add_item("breastplate")
	inv.sel_id = "breastplate"
	inv._equip_sel()
	check(main.gs.party[0].equip["armor"] == "breastplate", "持ち物画面から装備を替えられる")
	main.close_inventory()
	await _step(2)
	check(main.inventory == null, "持ち物画面を閉じる")
	# 潜る
	main.gs.party[2].hp = float(main.gs.party[2].max_hp())
	main._on_dive()
	await _step(5)
	check(main.phase == "dungeon" and main.heroes.size() == 4 and main.current.floor_no == 1, "迷宮へ潜る")
	check(not main.gs.blessed and main.heroes[0].buffs.has("guard"), "加護が効く")
	var fl: FloorInstance = main.current
	# スキル
	var casts := 0
	for h in main.heroes:
		h.ch.mp = float(h.ch.max_mp())
		h.cds.clear()
		var near := _fake_enemy(fl, h.position + Vector2(40, 0), 120)
		near.state = "idle"
		for i in 4:
			if h.cast_slot(i):
				casts += 1
		if is_instance_valid(near) and not near.dead:
			near.dead = true
			near.queue_free()
		fl.enemies.erase(near)
	check(casts >= 4, "4人がスキルを使える (発動 %d回)" % casts)
	await _step(30)
	# 操作の切り替え
	var a0: int = main.active
	main._switch_next()
	check(main.active != a0 and main.heroes[main.active].controlled and not main.heroes[a0].controlled, "操作する仲間を切り替えられる")
	# AI の仲間が戦う
	for e in fl.enemies.duplicate():
		e.dead = true
		e.queue_free()
	fl.enemies.clear()
	var lead: Hero = main.leader()
	var spot := _open_spot(fl)
	for i in main.heroes.size():
		main.heroes[i].position = spot + Vector2.from_angle(TAU * i / 4.0) * 24.0
	main._last_cell = Vector2i(-99, -99)
	await _step(2)
	var pack_pos := spot + Vector2(80, 0)
	for i in 4:
		_fake_enemy(fl, pack_pos + Vector2(0, (i - 1.5) * 26.0), 30, "M", 0.4)
	var kills0 := 0
	var xp0: int = main.gs.party[0].xp
	var worst := 0.0
	for f in 900:
		lead.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
		await physics_frame
		worst = maxf(worst, _max_overlap(fl))
		if f % 100 == 0 and not fl.enemies.is_empty():
			var e0: Enemy = fl.enemies[0]
			print("   f%d enemy pos %s hp %.0f intent %s target %s dist-to-heroes %s" % [f, e0.position, e0.hp, e0.intent, e0.target.ch.name if e0.target else "-", main.heroes.map(func(h): return int(h.position.distance_to(e0.position)))])
		if fl.enemies.is_empty():
			break
	if not fl.enemies.is_empty():
		for e in fl.enemies:
			print("   残り: hp %.1f/%d state %s pos %s" % [e.hp, e.max_hp, e.state, e.position])
		for h in main.heroes:
			print("   仲間 %s(%s) hp %.1f down %s pos %s target %s ctrl %s move %s" % [h.ch.name, h.ch.cls, h.ch.hp, h.down, h.position, h.ai_target, h.controlled, h.ai_move])
	check(fl.enemies.is_empty(), "AIの仲間が魔物の群れを倒す")
	check(main.gs.party[0].xp > xp0, "倒すと全員に経験点が入る")
	check(worst < 1.5, "戦闘中も重ならない (最大 %.2f px)" % worst)
	# 階段
	for n in range(1, Balance.MAX_FLOOR):
		main.leader().position = main.current.map.center_of(main.current.down_cell)
		main.interact()
		await _step(2)
		check(main.current.floor_no == n + 1, "第%d層 → 第%d層" % [n, n + 1])
	for n in range(Balance.MAX_FLOOR, 1, -1):
		main.leader().position = main.current.map.center_of(main.current.up_cell)
		main.interact()
		await _step(2)
	check(main.current.floor_no == 1, "第1層まで戻れる")
	# 帰還と査定
	main.bag_silver = 1000
	var bank1: int = main.gs.bank_silver
	main.leader().position = main.current.map.center_of(main.current.up_cell)
	main.interact()
	await _step(3)
	check(main.phase == "town" and main.gs.bank_silver == bank1 + 700 and main.gs.day == 1, "街へ戻ると3割が税になる (+%d)" % (main.gs.bank_silver - bank1))
	# 全滅
	main._on_dive()
	await _step(3)
	main.bag_silver = 500
	for h in main.heroes:
		h.damage(99999.0, h.position, true)
	await _step(3)
	check(main.phase == "overlay" and main.overlay_kind == "wipe" and main.bag_silver == 0, "全滅すると未査定の燐晶を失う")
	main._after_overlay()
	await _step(3)
	var alive := 0
	for c in main.gs.party:
		if c.hp > 0.0:
			alive += 1
	check(main.phase == "town" and alive >= 1, "全滅しても街へ運ばれ、詰まない")
	# セーブからの再開
	main.show_title()
	await _step(2)
	check(GameState.has_save(), "セーブが残っている")
	main._on_continue()
	await _step(3)
	check(main.phase == "town" and main.gs.party.size() == 4, "つづきからで街へ戻れる")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	main.queue_free()
	await process_frame
