extends SceneTree
## 層のボス(層の主):  godot --headless --path godot -s res://tests/boss_test.gd
## 層のいちばん下の階の大広間に、名前が黄色のユニークとお供が出る。HP 20倍・巨大・吹き飛ばしの一撃。
## 戦いが始まると咆哮とモノクロ、倒すか階を移ると戻る。倒すと実績・落とし物、7夜は戻らない。

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
	_test_table()
	_test_floors()
	await _test_fight()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _test_table() -> void:
	print("[table]")
	var ds: Array = []
	for L in LayerBoss.layers():
		ds.append(LayerBoss.bottom_depth(int(L)))
	check(ds == [5, 10, 14, 18, 22, 26, 27, 28, 29], "層の主の階は %s" % str(ds))
	check(LayerBoss.layer_at(30) == 0 and LayerBoss.layer_at(4) == 0 and LayerBoss.layer_at(14) == 3, "第30階(竜の巣)と途中の階には出ない")
	for L in LayerBoss.layers():
		var ms := LayerBoss.monsters(int(L), 4)
		var u := ms.filter(func(m): return m.get("unique", false))
		check(u.size() == 1 and u.all(func(m): return String(m["size"]) == "H"),
			"第%d層: ユニーク %d体(巨大)、お供 %d種" % [L, u.size(), ms.size() - u.size()])
	check(LayerBoss.EPITHETS.size() >= 100, "二つ名は %d" % LayerBoss.EPITHETS.size())
	var e1 := LayerBoss.epithets(5, 0, 3)
	check(e1.size() == 3 and e1[0] != e1[1] and e1[1] != e1[2] and e1[0] != e1[2] and e1 == LayerBoss.epithets(5, 0, 3), "同じ層の主の二つ名は重ならず、戻ってくるまで同じ (%s)" % "・".join(e1))
	var differ := 0
	for c in 10:
		if LayerBoss.epithets(1, c, 1) != LayerBoss.epithets(1, c + 1, 1):
			differ += 1
	check(differ >= 7, "戻ってくるたびに、だいたい別の二つ名 (%d/10)" % differ)

func _gs(party: int) -> GameState:
	var gs := GameState.new()
	var chars: Array = []
	for i in party:
		chars.append(Character.create("fighter", "human", "fighter", Jobs.auto_stats("fighter")))
	gs.new_game(chars)
	return gs

func _test_floors() -> void:
	print("[floors]")
	var bad := 0
	var n := 0
	for L in LayerBoss.layers():
		var depth := LayerBoss.bottom_depth(int(L))
		for night in [0, 3, 6]:
			for party in [1, 4]:
				var fl := FloorInstance.create(FloorMap.floor_path(depth, night, party))
				var gs := _gs(party)
				var got := LayerBoss.setup_floor(fl, gs)
				var e: Dictionary = fl.spawner.pending.get(fl.boss_enc, {})
				var room: Dictionary = fl.map.room_by_id.get(int(e.get("roomId", -1)), {})
				var want := 0
				for m in e.get("monsters", []):
					want += int(m["count"])
				var ok: bool = got == int(L) and not room.is_empty() and room.get("big", false) and (e["tokens"] as Array).size() == want \
					and int(fl.enc_total[fl.boss_enc]) == want and String(room["name"]) == String(LayerBoss.def(int(L))["room"])
				if not ok:
					bad += 1
					print("    第%d階 夜%d %d人: got=%d room=%s tokens=%d/%d" % [depth, night, party, got, room.get("name", "?"), (e.get("tokens", []) as Array).size(), want])
				n += 1
				fl.free()
	check(bad == 0, "層の主の階 %d通りすべてで、大広間に層の主の群れを置いた" % n)
	var fl2 := FloorInstance.create(FloorMap.floor_path(13, 0, 4))
	check(LayerBoss.setup_floor(fl2, _gs(4)) == 0 and fl2.boss_layer == 0, "層の主の階でなければ、置かない")
	fl2.free()

func _test_fight() -> void:
	print("[fight]")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(2)
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	main.start_day()
	await _step(3)
	main.enter_floor(5, "up")
	await _step(3)
	var fl: FloorInstance = main.current
	check(fl.boss_layer == 1, "第5階は第1層の主の階")
	fl.spawner.spawn_pending(fl.boss_enc)
	await _step(2)
	var bosses: Array = fl.enemies.filter(func(e): return e.unique)
	check(bosses.size() == 1, "ユニークが1体出た")
	if bosses.is_empty():
		return
	var b: Enemy = bosses[0]
	var normal := maxi(1, int(round(float(b.mon["hp"]) * Balance.ENEMY_HP_SCALE)))
	check(b.max_hp == normal * 20 or abs(b.max_hp - normal * 20) <= 20, "HP はふつうの20倍(%d → %d)" % [normal, b.max_hp])
	check(b.display_name.ends_with(LayerBoss.base_name("giant-rat-diseased", "")) and LayerBoss.EPITHETS.has(b.epithet) and b.size_key == "H" and b.legend == 3 and b.blast, "名前・巨大・伝説的な抵抗・吹き飛ばし")
	# 戦いを始める: 仲間をそばへ
	var lead: Hero = main.leader()
	for h in main.heroes:
		h.position = b.position + Vector2(b.radius + h.radius + 6.0, 0)
	b.visible = true
	fl.alert_encounter(fl.boss_enc)
	await _step(4)
	check(main.boss_fx.active, "気づくと戦いが始まる(咆哮)")
	check(main.boss_fx._roar.showing(), "咆哮の文字が出ている")
	await _step(30)
	check(main.boss_fx.gray_amount() > 0.5, "画面がモノクロになる (%.2f)" % main.boss_fx.gray_amount())
	# ダメージの数字はモノクロの上に赤で
	lead.iframes = 0.0
	lead.damage(5.0, b.position)
	await _step(25)
	var reds: Array = main.boss_fx.world.get_children().filter(func(c): return c is FloatText and (c as FloatText).color == Color("ff2a2a"))
	check(not reds.is_empty(), "ダメージの数字が、モノクロの上に赤で出る")
	# 吹き飛ばしの一撃
	for h in main.heroes:
		h.ch.hp = h.ch.max_hp()
		h.iframes = 0.0
	b.blast_cd = 0.0
	b.target = lead
	b.state = "chase"
	var hp0: float = lead.ch.hp
	var knocked := false
	for i in 90:
		await physics_frame
		if lead.knock.length() > 100.0:
			knocked = true
			break
	check(knocked and lead.ch.hp < hp0, "吹き飛ばしの一撃で、仲間が吹き飛ぶ")
	# 倒す
	for h in main.heroes:
		h.ch.hp = h.ch.max_hp()
	var gs: GameState = main.gs
	var items0: int = fl.ground.entries.filter(func(e): return String(e["kind"]) == "item").size()
	b.take_damage(1e9, Vector2.ZERO, lead)
	await _step(3)
	check(LayerBoss.kills(gs, 1) == 1 and Trophies.has(gs, "boss_1"), "倒すと記録と実績「%s」" % Trophies.name_of("boss_1"))
	check(not main.boss_fx.active and fl.fx_overlay == null and fl.boss_layer == 0, "倒すと、画面が戻る")
	check(fl.ground.entries.filter(func(e): return String(e["kind"]) == "item").size() > items0, "鍛冶の品が落ちた")
	await _step(30)
	check(main.boss_fx.gray_amount() < 0.1, "モノクロが抜ける")
	# 7夜は戻らない
	check(LayerBoss.slain_label(gs, 1) == "第1層の主 討伐済(あと7夜で戻る)" and LayerBoss.slain_label(gs, 2) == "", "迷宮の断面に「%s」" % LayerBoss.slain_label(gs, 1))
	check(LayerBoss.away(gs, 1), "倒した夜から7夜は戻らない")
	gs.day += 6
	check(LayerBoss.away(gs, 1), "6夜あとも、まだいない")
	gs.day += 1
	check(not LayerBoss.away(gs, 1), "7夜あとに戻る")
	# 別の階へ移ると、戦いは終わる
	gs.day += 7
	main.floors.clear()
	main.enter_floor(10, "up")
	await _step(3)
	var fl10: FloorInstance = main.current
	fl10.spawner.spawn_pending(fl10.boss_enc)
	await _step(2)
	var twins: Array = fl10.enemies.filter(func(e): return e.unique)
	check(twins.size() == 1, "第2層の主も1体")
	for e in twins:
		e.visible = true
	fl10.alert_encounter(fl10.boss_enc)
	await _step(4)
	check(main.boss_fx.active, "第2層の主とも戦いが始まる")
	var minion: Array = fl10.enemies.filter(func(e): return not e.unique and e.enc_id == fl10.boss_enc)
	if not minion.is_empty():
		minion[0].take_damage(1e9, Vector2.ZERO, main.leader())
		await _step(3)
		check(main.boss_fx.active and fl10.boss_layer == 2, "お供を倒しただけでは終わらない")
	main.enter_floor(9, "down")
	await _step(3)
	check(not main.boss_fx.active, "別の階へ移ると、戦いは終わる")
