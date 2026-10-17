extends SceneTree
## 魔物の SRD の特徴 第三弾:  godot --headless --path godot -s res://tests/traits3_test.gd
## 闘技場で: ダメージの耐性・無効・弱点、状態の無効、伝説的な抵抗、変わらぬ体、霧になって逃げる、熱い体、
## 呪文(詠唱、魔法の矢、金縛り、眠り、魅了、癒し、霧の歩み、姿消し、闇、灼熱の金属、詠唱の途切れ)、冒険日記帳の覚え書き。

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
	await _test_resist()
	await _test_conditions()
	await _test_misty_heated()
	await _test_spells()
	_test_journal()
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
		h.confuse_t = 0.0
		h.blind_t = 0.0
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
	for c in main.current.get_children():
		if c is Sfx or c is Projectile:
			c.queue_free()
	return h0

func _spawn(index: String, pos: Vector2, state: String = "chase") -> Enemy:
	var f: FloorInstance = ar.fl
	var en := Enemy.new()
	en.setup(f, _line(index, 1), {"id": 900, "kind": "beast"}, pos)
	en.state = state
	en.disguised = false
	en.lurk = ""
	en.died.connect(f._on_enemy_died)
	f.add_child(en)
	f.enemies.append(en)
	return en

func _cued(text: String) -> bool:
	return ar.fl.get_children().any(func(n): return n is Sfx and (n as Sfx).text == text)

func _test_flags() -> void:
	print("[flags]")
	check(MonTraits.flags_for(_line("mage")).has("caster") and MonTraits.flags_for(_line("adult-red-dragon")).has("legend"), "メイジは呪文を唱え、成竜は伝説的な抵抗を持つ")
	check(MonTraits.flags_for(_line("drow")).has_all(["fey_anc", "caster"]) and MonTraits.flags_for(_line("flesh-golem")).has("immutable"), "ドラウは妖精の血、フレッシュ・ゴーレムは変わらぬ体")
	check(MonTraits.flags_for(_line("vampire-vampire")).has("misty") and MonTraits.flags_for(_line("azer")).has("heated") and MonTraits.flags_for(_line("imp")).has("devil_sight"),
		"吸血鬼は霧になり、エイザーは熱く、インプは悪魔の目")
	var sk: Dictionary = MonTraits.damage_mods(_line("skeleton"))["mult"]
	check(is_equal_approx(float(sk.get("bludgeoning", 0)), MonTraits.VULNERABLE) and float(sk.get("poison", 1)) == 0.0, "スケルトンは叩く傷に弱く、毒が効かない")
	var wt: Dictionary = MonTraits.damage_mods(_line("wight"))["mult"]
	check(is_equal_approx(float(wt.get("nm_piercing", 0)), MonTraits.RESIST) and is_equal_approx(float(wt.get("necrotic", 0)), MonTraits.RESIST), "ワイトは魔力の無い武器と死霊の傷に強い")
	var fg: Dictionary = MonTraits.damage_mods(_line("flesh-golem"))["mult"]
	check(is_equal_approx(float(fg.get("nm_slashing", 0)), MonTraits.IMMUNE_WEAPON), "武器への無効は %.2f倍に和らげる" % MonTraits.IMMUNE_WEAPON)

func _hit_with(en: Enemy, h: Hero, weapon: String) -> float:
	h.ch.equip["weapon"] = weapon
	var hp0 := en.hp
	en.take_damage(10.0, Vector2.RIGHT, h)
	return hp0 - en.hp

func _test_resist() -> void:
	print("[resist]")
	var h0 := _reset(Vector2(150, 256))
	var keep := String(h0.ch.equip.get("weapon", ""))
	var sk := _spawn("skeleton", Vector2(400, 256))
	sk.max_hp = 9999
	sk.hp = 9999.0
	var blunt := _hit_with(sk, h0, "mace")
	var sword := _hit_with(sk, h0, "shortsword")
	check(is_equal_approx(blunt, sword * MonTraits.VULNERABLE), "スケルトンはメイス(叩く)が %.1f倍効く (%.1f / %.1f)" % [MonTraits.VULNERABLE, blunt, sword])
	await _step(2)
	var wt := _spawn("wight", Vector2(400, 300))
	wt.max_hp = 9999
	wt.hp = 9999.0
	var plain := _hit_with(wt, h0, "dagger")
	var magic := _hit_with(wt, h0, "shadow_dagger")
	check(is_equal_approx(plain, magic * MonTraits.RESIST), "ワイトに魔力の無い短剣は半分、珍しい短剣はそのまま (%.1f / %.1f)" % [plain, magic])
	var fe := _spawn("fire-elemental", Vector2(400, 200))
	var hp0 := fe.hp
	fe.elem_hit("fire", true)
	fe.take_damage(20.0, Vector2.RIGHT, h0)
	check(fe.hp == hp0, "炎の精霊に火は効かない")
	await _step(2)
	check(_cued("効かない") or ar.fl.get_children().any(func(n): return n is FloatText and (n as FloatText).text == "効かない"), "頭上に「効かない」")
	sk.poison(5.0, 3.0)
	check(sk.poison_t <= 0.0, "スケルトンに毒は効かない")
	h0.ch.equip["weapon"] = keep

func _test_conditions() -> void:
	print("[conditions]")
	_reset(Vector2(150, 256))
	var dr := _spawn("drow", Vector2(400, 200))
	dr.apply_stun(2.0, "sleep")
	check(dr.stun_t <= 0.0, "ドラウは眠らない(妖精の血)")
	dr.apply_stun(1.0)
	check(dr.stun_t > 0.0, "気絶はする")
	var aa := _spawn("animated-armor", Vector2(400, 300))
	aa.apply_stun(1.0)
	check(aa.stun_t <= 0.0, "動く鎧は気絶しない(麻痺が効かない)")
	var fg := _spawn("flesh-golem", Vector2(450, 250))
	fg.apply_slow(3.0)
	check(fg.slow_t <= 0.0, "フレッシュ・ゴーレムは足止めが効かない(変わらぬ体)")
	var dg := _spawn("adult-red-dragon", Vector2(500, 256))
	for i in 3:
		dg.apply_stun(1.0)
	check(dg.stun_t <= 0.0 and dg.legend == 0, "成竜は気絶を3回まで跳ね返す")
	await _step(1)
	check(_cued("フンッ!"), "跳ね返すと、フンッ!")
	dg.apply_stun(1.0)
	check(dg.stun_t > 0.0, "4回目は効く")

func _test_misty_heated() -> void:
	print("[misty / heated]")
	var h0 := _reset(Vector2(150, 256))
	var vp := _spawn("vampire-vampire", Vector2(200, 256))
	vp.take_damage(99999.0, Vector2.RIGHT, null)
	check(not vp.dead and vp.mist_t > 0.0 and vp.has_trait("ghost"), "吸血鬼は倒れる代わりに霧になる")
	await _step(2)
	check(_cued("シュウゥ…"), "霧になると、シュウゥ…")
	var p0 := vp.position
	await _step(60)
	check(vp.position.distance_to(h0.position) > p0.distance_to(h0.position), "霧になって離れていく")
	vp.mist_t = 0.01
	await _step(3)
	check(not vp.has_trait("ghost"), "霧が晴れると、壁は抜けない")
	vp.take_damage(99999.0, Vector2.RIGHT, null)
	check(vp.dead, "二度目は倒れる")
	_reset(Vector2(150, 256))
	h0.ch.equip["weapon"] = "shortsword"
	var az := _spawn("azer", Vector2(185, 256))
	var hp0 := h0.ch.hp
	az.take_damage(5.0, Vector2.RIGHT, h0)
	check(h0.ch.hp < hp0, "エイザーを殴ると、火傷する (%.1f → %.1f)" % [hp0, h0.ch.hp])
	await _step(1)
	check(_cued("ジュッ"), "火傷すると、ジュッ")

## 魔物に一つだけ呪文を持たせて、唱えるまで待つ
func _cast(index: String, sid: String, pos: Vector2, frames: int = 150) -> Enemy:
	var en := _spawn(index, pos)
	en.spells = [sid]
	en.spell_cds = {sid: 0.0}
	en.speed = 1.0
	for i in frames:
		await physics_frame
		if en.cast_t <= 0.0 and float(en.spell_cds[sid]) > 0.0:
			break
	await _step(2)
	return en

func _test_spells() -> void:
	print("[spells]")
	var h0 := _reset(Vector2(150, 256))
	var mg := _spawn("mage", Vector2(330, 256))
	mg.spells = ["magic_missile"]
	mg.spell_cds = {"magic_missile": 0.0}
	mg.speed = 1.0
	var chanted := false
	var named := false
	for i in 20:
		await physics_frame
		chanted = chanted or _cued("ブツブツ…")
		named = named or mg.cast_t > 0.0
	check(chanted and named, "唱える前に、ブツブツ…と詠唱する")
	var shots := 0
	for i in 120:
		await physics_frame
		shots = maxi(shots, ar.fl.get_children().filter(func(n): return n is Projectile and (n as Projectile).spell).size())
	check(shots == 3, "魔法の矢は3本飛ぶ (%d)" % shots)
	# 気絶で詠唱が途切れる
	mg.spell_cds["magic_missile"] = 0.0
	for i in 30:
		await physics_frame
		if mg.cast_t > 0.0:
			break
	mg.apply_stun(1.0)
	check(mg.cast_t <= 0.0, "気絶すると、詠唱が途切れる")
	h0 = _reset(Vector2(150, 256))
	await _cast("cult-fanatic", "hold", Vector2(310, 256))
	check(h0.stuck_t > 0.0 and h0.stuck_kind == "hold" and _cued("ピタッ"), "金縛り: 動けなくなる(ピタッ)")
	h0 = _reset(Vector2(150, 256))
	await _cast("dust-mephit", "sleep", Vector2(310, 256))
	check(h0.stuck_t > 0.0 and h0.stuck_kind == "sleep" and _cued("ふわぁ…"), "眠りの呪文: 眠る(ふわぁ…)")
	h0 = _reset(Vector2(150, 256))
	await _cast("lamia", "charm", Vector2(310, 256))
	check(h0.confuse_t > 0.0 and _cued("ぽわわん"), "魅了: 前後左右が逆になる(ぽわわん)")
	h0 = _reset(Vector2(150, 256))
	await _cast("dryad", "vine", Vector2(310, 256))
	check(h0.stuck_t > 0.0 and h0.stuck_kind == "vine" and _cued("シュルシュルッ"), "絡みつく蔓: 絡まる(シュルシュルッ)")
	h0 = _reset(Vector2(150, 256))
	await _cast("drow", "dark", Vector2(310, 256))
	check(h0.blind_t > 0.0 and _cued("ドロォ…"), "闇: 見える範囲が狭まる(ドロォ…)")
	h0 = _reset(Vector2(150, 256))
	var hp0 := h0.ch.hp
	await _cast("magma-mephit", "heat", Vector2(310, 256))
	check(h0.ch.hp < hp0 and _cued("ジリジリッ"), "灼熱の金属: 火傷する(ジリジリッ)")
	h0 = _reset(Vector2(150, 256))
	var gb := _spawn("goblin", Vector2(330, 300))
	gb.hp = gb.max_hp * 0.3
	var low := gb.hp
	await _cast("acolyte", "heal", Vector2(330, 220))
	check(gb.hp > low, "癒し: 傷ついた魔物を癒す (%.1f → %.1f)" % [low, gb.hp])
	h0 = _reset(Vector2(150, 256))
	var hg := await _cast("green-hag", "vanish", Vector2(310, 256))
	await _step(2)
	check(hg.vanish_t > 0.0 and hg.modulate.a < 0.2 and _cued("スッ…"), "姿消し: ほとんど見えなくなる(スッ…)")
	h0 = _reset(Vector2(150, 256))
	var mg2 := _spawn("mage", Vector2(150 + 28, 256))
	mg2.hp = mg2.max_hp * 0.4
	mg2.spells = ["blink"]
	mg2.spell_cds = {"blink": 0.0}
	mg2.speed = 1.0
	var p0 := mg2.position
	for i in 90:
		await physics_frame
		if mg2.position.distance_to(p0) > Balance.CELL * 2.0:
			break
	check(mg2.position.distance_to(h0.position) > Balance.CELL * 2.0, "霧の歩み: 詰め寄られると、離れた所へ跳ぶ (%.0fpx)" % mg2.position.distance_to(h0.position))

func _test_journal() -> void:
	print("[journal]")
	var t := Journal.resist_text("skeleton")
	check(t.contains("よく効く: 叩く") and t.contains("効かない: 毒"), "日記帳の覚え書き: %s" % t)
	var w := Journal.resist_text("wight")
	check(w.contains("突く(魔力の無い武器)"), "魔力の無い武器への耐性も載る: %s" % w)
