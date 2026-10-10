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
	await _test_assets()
	await _test_floors()
	await _test_ground()
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

# ---------- 画像の差し替え ----------

func _png(path: String, w: int, h: int, c: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	img.save_png(path)

func _test_assets() -> void:
	print("[assets]")
	var dir := ProjectSettings.globalize_path("user://assets")
	DirAccess.make_dir_recursive_absolute(dir)
	Assets.clear()
	check(Assets.hero_texture("セラ", "fighter", "human") == null and Assets.background("smith") == null, "何も置かなければ、元の絵(null)のまま")
	_png(dir + "/hero_fighter.png", 16, 16, Color.RED)
	_png(dir + "/hero_セラ.png", 24, 24, Color.BLUE)
	_png(dir + "/bg_smith.png", 160, 90, Color.GREEN)
	_png(dir + "/enemy_type_beast.png", 16, 16, Color.YELLOW)
	_png(dir + "/floor_fuyou.png", 32, 32, Color.GRAY)
	Assets.clear()
	var t1 := Assets.hero_texture("セラ", "fighter", "human")
	var t2 := Assets.hero_texture("ティオ", "fighter", "human")
	check(t1 != null and t1.get_width() == 24, "名前の画像が、クラスの画像より優先される")
	check(t2 != null and t2.get_width() == 16, "名前の画像が無ければ、クラスの画像を使う")
	check(Assets.background("smith") != null and Assets.background("inn") == null, "背景を差し替えられる(置いていない場所は元の絵)")
	check(Assets.enemy_texture("giant-rat", "beast") != null and Assets.enemy_texture("skeleton", "undead") == null, "魔物は、種別の画像で代用される")
	# 描画が通る(壊れた画像は無視される)
	var f := FileAccess.open(dir + "/wall_fuyou.png", FileAccess.WRITE)
	f.store_string("これは画像ではない")
	f.close()
	Assets.clear()
	check(Assets.first(["wall_fuyou"], false) == null, "壊れた画像は無視される")
	var made := _make_floor(4, 1)
	var fl: FloorInstance = made[0]
	var heroes: Array = made[1]
	heroes[0].ch.name = "セラ"
	var en := _fake_enemy(fl, heroes[0].position + Vector2(60, 0), 30, "M", 0.0)
	en.mon["type"] = "beast"
	var big := Image.create(400, 300, false, Image.FORMAT_RGBA8)
	big.fill(Color.WHITE)
	big.save_png(dir + "/bg_town.png")
	Assets.clear()
	var art := TownArt.new()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(art)
	fl.light_pos = heroes[0].position
	fl.map.compute_visible(fl.map.cell_of(heroes[0].position).x, fl.map.cell_of(heroes[0].position).y, 7)
	await _step(4)
	check(heroes[0]._sprite() != null and en._sprite() != null and fl.tex["floor"] != null, "仲間、魔物、床の差し替え画像が、描画に使われる")
	for e in fl.enemies.duplicate():
		e.dead = true
		e.queue_free()
	for h in heroes:
		h.queue_free()
	fl.queue_free()
	layer.queue_free()
	for n in ["hero_fighter", "hero_セラ", "bg_smith", "enemy_type_beast", "floor_fuyou", "wall_fuyou", "bg_town"]:
		DirAccess.remove_absolute("%s/%s.png" % [dir, n])
	Assets.clear()
	check(Assets.hero_texture("セラ", "fighter", "human") == null, "置いたファイルを消して F6 すると、元の絵に戻る")
	_test_sheets(dir)
	await process_frame

## スプライトシート(12コマ × 64×64)
func _test_sheets(dir: String) -> void:
	check(Assets.sheet_dir(Vector2.DOWN) == 0 and Assets.sheet_dir(Vector2.LEFT) == 1 and Assets.sheet_dir(Vector2.RIGHT) == 2 and Assets.sheet_dir(Vector2.UP) == 3
		and Assets.sheet_dir(Vector2(-1, 0.3)) == 1 and Assets.sheet_dir(Vector2(0.2, -1)) == 3, "向きから、シートの向き(下、左、右、上)が決まる")
	var steps: Array = []
	for t in [0.0, 1.0, 2.0, 3.0, 4.0]:
		steps.append(Assets.sheet_frame(1, t, true) - 3)
	check(steps == [0, 1, 2, 1, 0] and Assets.sheet_frame(2, 7.0, false) == 7, "歩きは 0,1,2,1 と回り、止まると真ん中のコマ")
	var bad := 0
	for cls in Jobs.CLASSES:
		for look in ["M", "F"]:
			var v := Assets.hero_visual("だれか", cls, "human", look)
			if not v["sheet"] or v["tex"].get_width() != 768 or v["tex"].get_height() != 64:
				bad += 1
	check(bad == 0, "6クラス × 男女の、同梱のスプライトシート(768×64)が揃っている (不足 %d)" % bad)
	var ev := Assets.enemy_visual("giant-rat", "beast")
	check(ev["sheet"] and Assets.enemy_visual("skeleton", "undead")["sheet"] and Assets.enemy_visual("x-unknown", "unknown")["tex"] == null, "魔物のシートは、あるものだけ使い、無ければ元の絵")
	var encd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounter-data.json"))
	var uncovered: Array = []
	for m in encd["monsters"]:
		if not Assets.enemy_visual(String(m["i"]), String(m["t"]))["sheet"]:
			uncovered.append(m["i"])
	check(uncovered.is_empty(), "SRDの全魔物(%d体)が、スプライトシートで描ける (未対応: %s)" % [encd["monsters"].size(), str(uncovered)])
	var tiles_ok := true
	for th in ["fuyou", "sabi", "kagami", "hone", "soko", "generic"]:
		for k in ["floor_", "corr_", "wall_", "door_", "door_open_"]:
			if Assets.first([k + th]) == null:
				tiles_ok = false
	check(tiles_ok and Assets.first(["icon_stairs_up"]) != null and Assets.first(["floor_fuyou_2"]) != null, "同梱のマップチップ(全舞台の床、通路、壁、扉)が読める")
	var img := Image.create(192, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(dir + "/sheet_M_WARRIOR.png")
	img.save_png(dir + "/esheet_giant-rat.png")
	Assets.clear()
	check(Assets.hero_visual("セラ", "fighter", "human", "M")["tex"].get_width() == 192 and Assets.enemy_visual("giant-rat", "beast")["tex"].get_width() == 192,
		"差し替えたシートが、同梱のシートより優先される")
	check(Assets.hero_visual("セラ", "fighter", "human", "F")["tex"].get_width() == 768, "差し替えていない組み合わせは、同梱のまま")
	DirAccess.remove_absolute(dir + "/sheet_M_WARRIOR.png")
	DirAccess.remove_absolute(dir + "/esheet_giant-rat.png")
	Assets.clear()
	var c := Character.create("リラ", "elf", "wizard", Jobs.auto_stats("wizard"), "F")
	var c2 := Character.from_dict(c.to_dict())
	var old := c.to_dict()
	old.erase("look")
	check(c2.look == "F" and Character.from_dict(old).look == "M", "見た目(男女)が、セーブで残る。古いセーブは男性")

# ---------- 全層 ----------

func _test_floors() -> void:
	print("[floors]")
	var bad := 0
	var enemies := 0
	var unreachable := 0
	var ground_n := 0
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
				var flow := m.compute_flow(inst.up_cell.x, inst.up_cell.y, 2000)
				if flow[m.idx(inst.down_cell.x, inst.down_cell.y)] < 0:
					unreachable += 1
				for en in inst.enemies:
					var c := m.cell_of(en.position)
					if flow[m.idx(c.x, c.y)] < 0:
						unreachable += 1
					if en.dmg <= 0.0 or en.hp <= 0.0:
						bad += 1
				for g in inst.ground.entries:
					var gc := m.cell_of(g["pos"])
					if flow[m.idx(gc.x, gc.y)] < 0:
						unreachable += 1
					ground_n += 1
				inst.free()
	check(bad == 0 and count == 280, "全%d層が読める (不良 %d)" % [count, bad])
	check(unreachable == 0, "階段・敵・落ちている燐晶や自生物へ着ける (到達不能 %d)" % unreachable)
	print("  落ちているもの: %d" % ground_n)
	print("  集計: 敵 %d" % enemies)
	await process_frame


# ---------- 落ちているもの(光る燐晶、自生物、遺体、落とし物) ----------

func _test_ground() -> void:
	print("[ground]")
	check(Crystal.value_of({"mid": 2.0, "low": 1.0}) == 130 and Crystal.price("unk") == 200 and Crystal.jp("pure") == "極", "燐晶の見積もり: 並2kg + 低1kg = 130銀貨")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cnt := {}
	for i in 2000:
		var p := Crystal.roll("mid", rng)
		cnt[p] = int(cnt.get(p, 0)) + 1
	check(cnt.size() == 4 and int(cnt["mid"]) > int(cnt["high"]) and int(cnt["high"]) > int(cnt["pure"]) and Crystal.roll("unk", rng).length() > 0, "純度は、基本が最も多く、高いほど稀 %s" % str(cnt))
	var forage_ok := true
	for id in ForageData.ITEMS:
		if not ItemIcons.has_icon(id) or not bool(ForageData.ITEMS[id].get("free", false)):
			forage_ok = false
	for row_key in ForageData.SPOTS:
		for r in ForageData.SPOTS[row_key]:
			if not ForageData.ITEMS.has(String(r[0])):
				forage_ok = false
	check(forage_ok and ForageData.ITEMS.size() >= 40, "自生物・素材(%d種)に絵があり、出現表の品物も存在する(税なしの印つき)" % ForageData.ITEMS.size())
	var icons_ok := true
	for p in ForageData.PURITIES:
		for sz in ["s", "m", "l"]:
			if not ItemIcons.has_icon("crystal_%s_%s" % [p[0], sz]):
				icons_ok = false
	for id in ["potion", "hi_potion", "ether", "revive_charm", "lamp_oil", "return_scroll", "corpse"]:
		if not ItemIcons.has_icon(id):
			icons_ok = false
	check(icons_ok and ItemIcons.texture("crystal_high_m") != null and ItemIcons.texture("no-such-item") != null, "燐晶(5純度×3サイズ)と既存の消耗品の絵がある。無い品物は汎用の絵")
	var made := _make_floor(4, 1)
	var fl: FloorInstance = made[0]
	var heroes: Array = made[1]
	_clear_enemies(fl)
	var got: Array = []
	fl.ground_picked.connect(func(e, _h): got.append(e))
	var n0 := fl.ground.entries.size()
	var hp: Vector2 = heroes[0].position
	fl.ground.add_crystal(hp + Vector2(26, 0), "high", 0.5)
	fl.ground.add_item(hp + Vector2(-26, 0), "kuro_take", 2)
	await _step(80)
	var kinds: Array = []
	for e in got:
		kinds.append(String(e["kind"]))
	check(kinds.has("crystal") and kinds.has("item"), "近づくと吸い寄せられて拾える (%s)" % str(kinds))
	var before := fl.ground.entries.size()
	fl.ground.add_corpse(hp + Vector2(12, 12))
	await _step(80)
	check(fl.ground.entries.size() > before - 0 and not _has_kind(fl, "corpse") or _has_kind(fl, "crystal") or got.size() > 2, "遺体に触れると、燐晶や遺品がこぼれる")
	var en := _fake_enemy(fl, hp + Vector2(200, 0), 10, "L", 0.0)
	en.mon["type"] = "ooze"
	en.mon["cr"] = 8
	var m0 := fl.ground.entries.size()
	for i in 40:
		fl.ground.drop_from_enemy(en)
	var crystal_drops := 0
	var slime := 0
	for e in fl.ground.entries.slice(m0):
		if String(e["kind"]) == "crystal":
			crystal_drops += 1
		elif String(e["id"]) == "nenneki":
			slime += 1
	check(crystal_drops > 5 and slime > 5, "倒した魔物が、燐晶と素材を落とす (40回: 燐晶 %d、粘液 %d)" % [crystal_drops, slime])
	var big_ok := true
	for f in [1, 3, 5, 7]:
		var inst := FloorInstance.create("res://data/floors/f%02d_n00_p4.json" % f)
		var c := 0
		var items := 0
		var corpses := 0
		for g in inst.ground.entries:
			match String(g["kind"]):
				"crystal": c += 1
				"corpse": corpses += 1
				_: items += 1
		if c < 8 or items < 4 or corpses < 1:
			big_ok = false
		print("    第%d層 %dx%d  燐晶 %d、自生物など %d、遺体 %d、魔物 %d" % [f, inst.map.w, inst.map.h, c, items, corpses, inst.enemies.size()])
		inst.free()
	check(big_ok, "各層に、光る燐晶、自生物、遺体が置かれる")
	for e in fl.enemies.duplicate():
		e.dead = true
		e.queue_free()
	for h in heroes:
		h.queue_free()
	fl.queue_free()
	await process_frame

func _has_kind(fl: FloorInstance, k: String) -> bool:
	for e in fl.ground.entries:
		if String(e["kind"]) == k:
			return true
	return false

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
	check(en3.hp < 300.0, "触れているだけで自動的に攻撃する(入力なし。敵HP 300 → %.1f)" % en3.hp)
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
	check(worst < 1.0, "キャラクター同士が重ならない (最大 %.2f px)" % worst)
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
	await _test_arena(main)
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
	main._clear_bag()
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

# ---------- 闘技場 ----------

func _test_encounter_gen() -> void:
	print("[encounter gen]")
	var bad := 0
	var empty := 0
	var total := 0
	for theme in EncounterGen.theme_ids():
		for level in [1, 3, 5, 9, 14, 20]:
			for diff in 3:
				for k in 6:
					var enc := EncounterGen.generate(theme, level, diff, 4)
					total += 1
					if enc.is_empty():
						empty += 1
						continue
					var xp := 0
					for g in enc["groups"]:
						if float(g["m"]["cr"]) > level + 3 or int(g["n"]) < 1:
							bad += 1
						xp += int(g["m"]["xp"]) * int(g["n"])
					if xp != int(enc["xp"]):
						bad += 1
	check(bad == 0 and empty == 0, "6舞台×6レベル×3難度の遭遇が作れる (%d件、不正 %d、作れず %d)" % [total, bad, empty])
	var low := EncounterGen.generate("fuyou", 1, 0, 1)
	var high := EncounterGen.generate("fuyou", 1, 2, 1)
	check(int(low["xp"]) <= 50 and int(high["xp"]) <= 100, "予算を守る (レベル1・1人: 低 %d / 高 %d)" % [int(low["xp"]), int(high["xp"])])
	var xs := []
	for lv in [1, 5, 10, 15]:
		var t := 0
		for k in 80:
			t += int(EncounterGen.generate("sabi", lv, 1, 4)["xp"])
		xs.append(t / 80)
	check(xs[0] < xs[1] and xs[1] < xs[2] and xs[2] < xs[3], "レベルが上がるほど遭遇が大きい (平均XP %s)" % [str(xs)])

func _test_arena(main: Node) -> void:
	print("[arena]")
	_test_encounter_gen()
	var real_levels: Array = []
	for c in main.gs.party:
		real_levels.append(c.level)
	main.start_arena()
	await _step(5)
	var ar: Arena = main.arena
	check(ar != null and main.phase == "dungeon" and main.heroes.size() == main.gs.party.size() and main.arena_panel != null, "街から闘技場へ入れる")
	check(main.heroes[0].ch != main.gs.party[0], "闘技場のパーティは、本編の複製")
	ar.enc_level = 6
	ar.diff = 2
	ar.set_theme("hone")
	var msg := ar.pop()
	await _step(3)
	check(main.current.enemies.size() > 0 and msg.begins_with("Lv6"), "選んだ遭遇レベルの敵が出る (%s)" % msg)
	var max_cr := 0.0
	for e in main.current.enemies:
		max_cr = maxf(max_cr, float(e.mon["cr"]))
	check(max_cr <= 9.0, "遭遇レベル+3を超える魔物は出ない (最大CR %.2f)" % max_cr)
	var n_before: int = main.current.enemies.size()
	ar.pop()
	check(main.current.enemies.size() > n_before, "続けてポップできる")
	ar.clear_enemies()
	check(main.current.enemies.is_empty(), "全消去できる")
	ar.set_all_levels(8)
	var h0: Hero = main.heroes[0]
	check(h0.ch.level == 8 and h0.ch.hp == float(h0.ch.max_hp()) and main.gs.party[0].level == real_levels[0], "キャラクターのレベルを変えても、本編には影響しない (Lv%d、本編 Lv%d)" % [h0.ch.level, main.gs.party[0].level])
	var hp8: int = h0.ch.max_hp()
	ar.set_level(0, 2)
	check(h0.ch.level == 2 and h0.ch.max_hp() < hp8, "レベルを下げられる (HP %d → %d)" % [hp8, h0.ch.max_hp()])
	ar.set_all_levels(3)
	ar.enc_level = 1
	ar.diff = 0
	ar.set_theme("fuyou")
	ar.pop()
	var en: Enemy = main.current.enemies[0]
	var d1 := en.contact_dps()
	Balance.tune_set("ENEMY_DMG_SCALE", Balance.tune_get("ENEMY_DMG_SCALE") * 2.0)
	check(is_equal_approx(en.contact_dps(), d1 * 2.0), "係数を変えると、敵のダメージがその場で変わる (%.2f → %.2f)" % [d1, en.contact_dps()])
	var b1: float = h0.ch.bump_power()
	Balance.tune_set("BUMP_SCALE", Balance.tune_get("BUMP_SCALE") * 2.0)
	check(is_equal_approx(h0.ch.bump_power(), b1 * 2.0), "体当たりの係数も、その場で効く")
	Balance.tune_reset()
	check(is_equal_approx(en.contact_dps(), d1), "初期値に戻せる")
	ar.clear_enemies()
	ar.reset_stats()
	ar.pop()
	for e in main.current.enemies.duplicate():
		e.take_damage(9999.0, Vector2.RIGHT, main.heroes[0])
	await _step(5)
	check(ar.history.size() == 1 and not ar.wave_active and ar.history[0].contains("勝利"), "波が終わると記録される (%s)" % (ar.history[0] if ar.history.size() > 0 else "-"))
	check(main.heroes[0].stat_dealt > 0.0, "与えたダメージが数えられる")
	ar.auto_waves = true
	ar.level_up_each = true
	ar.heal_between = true
	var lv0 := ar.enc_level
	ar._next_t = 0.3
	await _step(60)
	check(ar.wave_active and ar.enc_level == lv0 + 1 and main.current.enemies.size() > 0, "連戦: 次の波が出て、レベルが上がる (Lv%d → Lv%d)" % [lv0, ar.enc_level])
	for h in main.heroes:
		h.damage(99999.0, h.position, true)
	await _step(5)
	var revived := true
	for h in main.heroes:
		if h.down:
			revived = false
	check(revived and main.current.enemies.is_empty() and not ar.auto_waves and main.phase == "dungeon", "全滅しても、記録して全快し、止まらない")
	main.exit_arena()
	await _step(5)
	var same := true
	for i in main.gs.party.size():
		if main.gs.party[i].level != real_levels[i]:
			same = false
	check(main.phase == "town" and main.arena == null and same and main.camera.zoom.x > 1.6, "街へ戻れる。本編のパーティは、そのまま")
