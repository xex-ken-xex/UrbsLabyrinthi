extends SceneTree
## 戦い方「ぶつかる / キー」(ken 11/1): Godot --headless --path godot -s res://tests/bump_attack_test.gd

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
	for k in [["fighter", "human"], ["cleric", "dwarf"], ["rogue", "halfling"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)
	main._set_screen(null)
	var keep := GameSettings.bump_attack
	_test_setting()
	main.start_arena()
	await _step(3)
	ar = main.arena
	await _test_bump()
	GameSettings.set_bump_attack(keep)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	DiveSave.clear()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _test_setting() -> void:
	print("[設定]")
	var cf := ConfigFile.new()
	cf.load(GameSettings.PATH)
	var had := cf.has_section_key("game", "bump_attack")
	var old: Variant = cf.get_value("game", "bump_attack", true) if had else null
	if had:
		cf.erase_section_key("game", "bump_attack")
		cf.save(GameSettings.PATH)
	GameSettings.load_settings()
	check(GameSettings.bump_attack, "既定は「ぶつかる」")
	GameSettings.set_bump_attack(false)
	GameSettings.load_settings()
	check(not GameSettings.bump_attack, "「キー」を保存して読み直せる")
	GameSettings.set_bump_attack(true)
	GameSettings.load_settings()
	check(GameSettings.bump_attack, "「ぶつかる」に戻せる")
	if had:
		GameSettings.set_bump_attack(bool(old))

## 仲間を一人だけにして、試験体を右隣に置く
func _setup(hp: float = 300.0, state: String = "chase") -> Array:
	ar.clear_enemies()
	ar.heal_all()
	for i in main.heroes.size():
		var h: Hero = main.heroes[i]
		h.controlled = i == 0
		h.cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		h.knock = Vector2.ZERO
		if i > 0:
			h.position = Vector2(48.0 + i * 30.0, 48.0)
			h.down = true
	var h0: Hero = main.heroes[0]
	h0.down = false
	h0.position = ar.fl.map.center_of(ar.fl.up_cell) + Vector2(0, 64)
	h0.atk_cd = 0.0
	h0.iframes = 1e9
	main.active = 0
	ar.fl.leader = h0
	var e := Enemy.new()
	var mon := {"name": "Test", "name_ja": "試験体", "hp": int(hp), "ac": 10, "size": "M", "type": "beast", "xp": 10, "cr": 1,
		"speed": {"walk": 0}, "attacks": [{"n": "Bite", "b": 4, "d": "1d2 piercing"}]}
	e.setup(ar.fl, mon, {"id": 999, "kind": "mindless", "attitude": "敵対", "activity": ""}, h0.position + Vector2(h0.radius + 12.0, 0))
	e.max_hp = int(hp)
	e.hp = hp
	e.state = state
	e.dmg = 0.0
	ar.fl.add_child(e)
	ar.fl.enemies.append(e)
	e.position = h0.position + Vector2(h0.radius + e.radius + 1.0, 0)
	return [h0, e]

func _test_bump() -> void:
	print("[ぶつかって殴る]")
	GameSettings.bump_attack = true
	var pe := _setup()
	var h0: Hero = pe[0]
	var en: Enemy = pe[1]
	h0.cmd = {"move": Vector2.RIGHT, "attack": false, "dodge": false}
	await _step(40)
	check(en.hp < 300.0, "「ぶつかる」なら、押し込むと自動で殴る (300 → %.1f)" % en.hp)
	var hp1 := en.hp
	await _step(int(Balance.ATTACK_CD * 60.0) * 2 + 8)
	check(en.hp < hp1, "触れている間は、待ち時間ごとに殴り続ける (%.1f → %.1f)" % [hp1, en.hp])
	# 背を向けて離れようとしているときは振らない
	pe = _setup()
	h0 = pe[0]
	en = pe[1]
	h0.cmd = {"move": Vector2.LEFT, "attack": false, "dodge": false}
	await _step(20)
	check(is_equal_approx(en.hp, 300.0), "離れようとしているときは殴らない")
	# 立ち止まって触れているだけでも殴る(魔物が寄ってきたとき)
	pe = _setup()
	h0 = pe[0]
	en = pe[1]
	await _step(20)
	check(en.hp < 300.0, "立ち止まっていても、触れている魔物は殴る (%.1f)" % en.hp)
	# 話し合える魔物(中立)は、すり抜けるだけで殴らない
	pe = _setup(300.0, "neutral")
	h0 = pe[0]
	en = pe[1]
	h0.cmd = {"move": Vector2.RIGHT, "attack": false, "dodge": false}
	await _step(30)
	check(is_equal_approx(en.hp, 300.0), "話し合える魔物は、ぶつかっても殴らない(すり抜ける)")
	h0.atk_cd = 0.0
	h0.facing = (en.position - h0.position).normalized()
	h0.attack()
	check(en.hp < 300.0 or en.position.distance_to(h0.position) > 40.0, "殴るなら攻撃キーで")
	# 溜めている間は振らない
	pe = _setup()
	h0 = pe[0]
	en = pe[1]
	h0.cmd = {"move": Vector2.ZERO, "attack": true, "dodge": false}
	await _step(2)
	var hp_after_tap := en.hp
	await _step(int((Balance.CHARGE_START + 0.3) * 60.0))
	check(h0.charging() and is_equal_approx(en.hp, hp_after_tap), "溜めている間は、ぶつかっても振らない")
	h0.cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
	await _step(3)
	# キーの一撃・技は「ぶつかる」でも使える
	pe = _setup()
	h0 = pe[0]
	en = pe[1]
	check(h0.attack() and en.hp < 300.0, "「ぶつかる」でも、攻撃キーの一撃は使える")
	# キーだけ
	GameSettings.bump_attack = false
	pe = _setup()
	h0 = pe[0]
	en = pe[1]
	h0.cmd = {"move": Vector2.RIGHT, "attack": false, "dodge": false}
	await _step(40)
	check(is_equal_approx(en.hp, 300.0), "「キー」なら、押し込んでも殴らない")
	h0.atk_cd = 0.0
	check(h0.attack() and en.hp < 300.0, "「キー」でも、攻撃キーで殴れる")
	GameSettings.bump_attack = true
	# 操作していない仲間は、これまでどおり自分で殴る(設定に関わらない)
	pe = _setup()
	h0 = pe[0]
	en = pe[1]
	h0.controlled = false
	GameSettings.bump_attack = false
	await _step(40)
	check(en.hp < 300.0, "操作していない仲間は、設定に関わらず自分で殴る")
	GameSettings.bump_attack = true
