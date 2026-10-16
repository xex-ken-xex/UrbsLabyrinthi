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
	_test_controls()
	_test_updater()
	_test_talents()
	_test_state()
	await _test_assets()
	await _test_floors()
	await _test_ground()
	await _test_contact()
	await _test_tempo()
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

# ---------- 技能、セーヴ、能力値上昇、特技 ----------

func _test_controls() -> void:
	Controls.setup()
	var miss := 0
	for a in Controls.ACTIONS:
		if InputMap.action_get_events(a[0]).is_empty():
			miss += 1
	check(miss == 0, "すべての操作に、キーかボタンが割り当たっている")
	check(Controls.hint("search") == "F" and Controls.hint("inventory") == "Tab", "画面の説明に出すキー (%s, %s)" % [Controls.hint("search"), Controls.hint("inventory")])
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	check(InputMap.event_is_action(pad, "interact"), "コントローラーの A で調べる")
	check(InputMap.event_is_action(pad, "ui_accept"), "コントローラーの A で画面のボタンを押せる")
	var pb := InputEventJoypadButton.new()
	pb.button_index = JOY_BUTTON_B
	check(InputMap.event_is_action(pb, "ui_cancel"), "コントローラーの B で戻る")
	var st := InputEventJoypadMotion.new()
	st.axis = JOY_AXIS_LEFT_X
	st.axis_value = -1.0
	check(InputMap.event_is_action(st, "move_left"), "左スティックで移動")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	check(not InputMap.event_is_action(esc, "inventory") and InputMap.event_is_action(esc, "ui_cancel"), "Esc は戻る・閉じる専用(持ち物は開かない)")
	var tabk := InputEventKey.new()
	tabk.keycode = KEY_TAB
	tabk.physical_keycode = KEY_TAB
	check(InputMap.event_is_action(tabk, "inventory") and not InputMap.event_is_action(tabk, "ui_focus_next"), "Tab は持ち物だけ(ボタンの焦点送りに取られない)")
	# 割り当てを変えて、保存して、読み直す
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 0.9
	var d := Controls.from_event(rt)
	check(d == {"t": "axis", "a": JOY_AXIS_TRIGGER_RIGHT, "v": 1} and Controls.label(d) == "RT", "RT を押すと、軸の入力として記録する")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	g.pressed = true
	Controls.set_bind("search", "k0", Controls.from_event(g))
	check(Controls.conflicts("search", Controls.binds["search"]["keys"][0]).is_empty(), "G はほかと重ならない")
	Controls.binds = {}
	Controls.setup()
	var gk := InputEventKey.new()
	gk.physical_keycode = KEY_G
	check(InputMap.event_is_action(gk, "search") and Controls.hint("search") == "G", "変えた割り当ては保存され、次の起動でも効く")
	check(not Controls.conflicts("skill1", {"t": "key", "c": KEY_E}).is_empty(), "ほかの操作と同じキーは、重なりとして分かる")
	check(Controls.conflicts("confirm", {"t": "btn", "b": JOY_BUTTON_A}).is_empty(), "決定と調べるは同じ A でよい")
	Controls.reset()
	check(Controls.hint("search") == "F", "初期設定に戻せる")

func _test_updater() -> void:
	check(not Updater.should_check(), "エディタやテストでは、更新を確かめない")
	var os_name := OS.get_name()
	var good := {"tag": "v9", "godot": "4.7.2", "pck": {os_name: {"url": "https://example.com/a.pck", "sha256": "ABC", "size": 3}}}
	var p := Updater.parse_latest(good)
	check(p.get("sha", "") == "abc" and p.get("tag", "") == "v9" and p.get("url", "") == "https://example.com/a.pck", "latest.json から、この OS の .pck を読む")
	check(Updater.parse_latest({"tag": "v9"}).is_empty() and Updater.parse_latest("x").is_empty() and Updater.parse_latest({"pck": {"Other": {}}}).is_empty(), "壊れた latest.json は使わない")
	var ps := Updater.windows_script(1234, "C:\\Users\\ケン's\\a.pck.new", "C:\\Users\\ケン's\\a.pck", "C:\\x\\a.exe", PackedStringArray(["--no-update"]))
	check(ps.contains("Wait-Process -Id 1234") and ps.contains("'C:\\Users\\ケン''s\\a.pck.new'") and ps.contains("-ArgumentList '--','--no-update'"), "Windows の入れ替えの命令(単引用符を重ねる)")

func _test_talents() -> void:
	print("[talents]")
	var pb := [[1, 2], [4, 2], [5, 3], [8, 3], [9, 4], [13, 5], [17, 6], [20, 6]]
	var pb_ok := true
	for e in pb:
		pb_ok = pb_ok and Talents.prof_bonus(e[0]) == e[1]
	check(pb_ok, "習熟ボーナスは 5e と同じ(Lv1 +2、Lv5 +3、Lv9 +4、Lv13 +5、Lv17 +6)")
	var bad := 0
	for cls in Jobs.CLASSES:
		for race in Jobs.RACES:
			var picks := Talents.default_picks(cls, race)
			var c := Character.create("t", race, cls, Jobs.auto_stats(cls))
			if not Talents.picks_valid(cls, picks) or c.profs != picks:
				bad += 1
	check(bad == 0, "おまかせの技能が、6クラス×4種族で正しい (%d件の誤り)" % bad)
	check(not Talents.picks_valid("fighter", ["arcana", "religion", "history", "medicine"]), "クラスの一覧から足りない選び方は通らない")
	check(not Talents.picks_valid("fighter", ["athletics", "athletics", "perception", "survival"]), "同じ技能の重複は通らない")
	check(Talents.picks_valid("fighter", ["athletics", "perception", "arcana", "stealth"]), "クラスから2つ + 自由に2つは通る")
	# 生まれ表: どの前職でも、どのクラスと種族でも、正しい選び方になり、前職の技能が入る(重なった分は別の技能)
	var bbad := 0
	var cover := {}
	for j in Birth.JOBS.size():
		for p in Birth.JOBS[j]["skills"]:
			cover[p] = true
		for cls in Talents.CLASS_PROF:
			for race in ["human", "elf", "dwarf", "halfling"]:
				var b := {"origin": 0, "job": j, "turn": 0, "reason": 0}
				var pk := Birth.apply_to_picks(b, cls, race, Talents.default_picks(cls, race))
				var fixed: Array = Talents.RACE_PROF.get(race, [])
				var ok := Talents.picks_valid(cls, pk)
				for p in Birth.job_skills(b):
					if not pk.has(p) and not fixed.has(p):
						ok = false
				if not ok:
					bbad += 1
	check(bbad == 0, "生まれ表の前職の技能が、12前職×6クラス×4種族で正しく入る (%d件の誤り)" % bbad)
	check(cover.size() == Talents.SKILLS.size(), "18の技能が、どれもいずれかの前職に入っている (%d)" % cover.size())
	var rb := Birth.roll()
	check(Birth.valid(rb) and Birth.text(rb).begins_with(String(Birth.ORIGINS[int(rb["origin"])]["text"])), "生い立ちをふると、一文になる")
	var bc := Character.create("b", "human", "fighter", Jobs.auto_stats("fighter"), "M", [], rb)
	check(Character.from_dict(bc.to_dict()).birth == rb, "生い立ちはセーブに残る")
	check(Character.from_dict({"name": "古い"}).birth.is_empty() and Birth.sanitize({"origin": 99}).is_empty(), "古いセーブや壊れた生い立ちは空になる")
	var elf := Character.create("e", "elf", "wizard", Jobs.auto_stats("wizard"))
	check(elf.proficient("perception") and not elf.profs.has("perception"), "エルフは〈知覚〉に習熟(選ぶ数に入らない)")
	var fi := Character.create("f", "human", "fighter", Jobs.auto_stats("fighter"), "M", ["athletics", "perception", "arcana", "stealth"])
	check(fi.skill_bonus("athletics") == fi.mod("str") + 2 and fi.skill_bonus("religion") == fi.mod("int"), "技能の判定 = 補正 + 習熟 (〈運動〉%+d)" % fi.skill_bonus("athletics"))
	check(fi.save_bonus("str") == fi.mod("str") + 2 and fi.save_bonus("dex") == fi.mod("dex"), "戦士のセーヴは【筋力】【耐久力】に習熟")
	check(fi.lock_bonus() == fi.mod("dex"), "盗賊道具に習熟していないと、解錠は【敏捷】だけ")
	check(fi.passive_perception() == 10 + fi.skill_bonus("perception"), "受動〈知覚〉 = 10 + 〈知覚〉 (%d)" % fi.passive_perception())
	# 盗賊: 盗賊道具と熟達
	var ro := Character.create("r", "halfling", "rogue", Jobs.auto_stats("rogue"))
	check(ro.lock_bonus() == ro.mod("dex") + 2, "盗賊は盗賊道具に習熟 (解錠 %+d)" % ro.lock_bonus())
	var pend := ro.pending()
	check(pend.size() == 2 and pend[0]["kind"] == "expertise", "盗賊は Lv1 で熟達を2つ選べる")
	check(ro.choose("exp1a", "exp:arcana") != "", "習熟していない技能には熟達できない")
	check(ro.choose("exp1a", "exp:thieves_tools") == "" and ro.lock_bonus() == ro.mod("dex") + 4, "盗賊道具に熟達すると解錠 %+d" % ro.lock_bonus())
	check(ro.choose("exp1b", "exp:thieves_tools") != "", "同じものに二度は熟達できない")
	var st0 := ro.skill_bonus("stealth")
	check(ro.choose("exp1b", "exp:stealth") == "" and ro.skill_bonus("stealth") == st0 + 2 and ro.pending().is_empty(), "〈隠密〉に熟達 (%+d → %+d)" % [st0, ro.skill_bonus("stealth")])
	# 能力値上昇と特技
	var f2 := Character.create("f2", "human", "fighter", Jobs.auto_stats("fighter"))
	check(f2.pending().is_empty(), "Lv1 の戦士は、まだ選ぶものが無い")
	f2.gain_xp(int(Balance.XP_LEVELS[3]))
	check(f2.level == 4 and f2.pending().size() == 1 and f2.pending()[0]["key"] == "asi4", "Lv4 で能力値上昇か特技を選べる")
	var str0 := int(f2.stats["str"])
	check(f2.choose("asi4", "abil:str") == "" and int(f2.stats["str"]) == str0 + 2 and int(f2.base_stats["str"]) == str0, "【筋力】+2 (%d → %d)" % [str0, int(f2.stats["str"])])
	f2.gain_xp(int(Balance.XP_LEVELS[5]) - f2.xp)
	check(f2.level == 6 and f2.pending().size() == 1 and f2.pending()[0]["key"] == "asi6", "戦士は Lv6 にも選べる")
	var hp0 := f2.max_hp()
	check(f2.choose("asi6", "feat:tough") == "" and f2.has_feat("tough") and f2.max_hp() == hp0 + int(round(12 * Balance.HP_SCALE)), "特技「頑健」で最大HP +2×Lv (%d → %d)" % [hp0, f2.max_hp()])
	f2.gain_xp(int(Balance.XP_LEVELS[7]) - f2.xp)
	check(f2.choose("asi8", "feat:tough") != "", "同じ特技は二度取れない")
	check(f2.choose("asi8", "abil:dex+dex") != "", "+1 を同じ能力値に二つは置けない")
	var dx := int(f2.stats["dex"])
	var cn := int(f2.stats["con"])
	check(f2.choose("asi8", "abil:dex+con") == "" and int(f2.stats["dex"]) == dx + 1 and int(f2.stats["con"]) == cn + 1, "+1 を二つに分けられる")
	var hi := Character.create("h", "human", "wizard", Jobs.auto_stats("wizard"))
	hi.base_stats["int"] = 19
	hi.recalc_stats()
	hi.gain_xp(int(Balance.XP_LEVELS[3]))
	check(hi.choose("asi4", "abil:int") != "" and hi.choose("asi4", "abil:int+con") == "" and int(hi.stats["int"]) == 20, "能力値は20まで")
	# レベルを下げると、そのレベルより上の選択は効かない(闘技場)
	f2.level = 5
	f2.recalc_stats()
	check(int(f2.stats["str"]) == str0 + 2 and not f2.has_feat("tough") and int(f2.stats["dex"]) == dx, "レベルを下げると、上のレベルの選択は効かない")
	f2.level = 8
	f2.recalc_stats()
	check(f2.has_feat("tough") and int(f2.stats["dex"]) == dx + 1, "レベルを戻すと、また効く")
	var au := Character.create("a", "dwarf", "cleric", Jobs.auto_stats("cleric"))
	au.level = 19
	au.auto_fill_choices()
	au.recalc_stats()
	check(au.pending().is_empty() and int(au.stats["wis"]) <= 20, "自動で全部埋められる (【判断力】%d、特技 %s)" % [int(au.stats["wis"]), au.feats()])
	# 効き目
	check(ro.skill_fx("stealth") > 0.0 and ro.skill_fx("stealth") <= 0.4, "〈隠密〉の効き目 %d%%" % int(ro.skill_fx("stealth") * 100))
	var rn := Character.create("rn", "human", "ranger", Jobs.auto_stats("ranger"))
	check(rn.dealt_mult("beast") > 1.0 and is_equal_approx(rn.dealt_mult("humanoid"), 1.0), "〈自然〉で野獣への与ダメージが上がる (×%.2f)" % rn.dealt_mult("beast"))
	check(rn.taken_mult("beast") < 1.0 and is_equal_approx(rn.taken_mult("undead"), 1.0), "〈動物使い〉で野獣からの被ダメージが減る (×%.2f)" % rn.taken_mult("beast"))
	var cl := Character.create("c", "human", "cleric", Jobs.auto_stats("cleric"))
	check(cl.dealt_mult("undead") > 1.0 and cl.heal_mult() > 1.0, "〈宗教〉でアンデッドに強く、〈医術〉で回復が増える")
	var b0 := fi.roll_cooldown()
	fi.choices["asi4"] = {"take": "feat:mobile"}
	fi.level = 4
	fi.recalc_stats()
	check(fi.roll_cooldown() < b0 and fi.speed() > Balance.HERO_SPEED * 1.05, "特技「身軽」で転がりの待ち時間が縮み、足が速くなる")
	# セーブとロード
	var d := f2.to_dict()
	var f3 := Character.from_dict(d)
	check(f3.profs == f2.profs and f3.has_feat("tough") and int(f3.stats["str"]) == int(f2.stats["str"]) and int(f3.base_stats["str"]) == str0, "技能、選択、能力値がセーブで残る")
	var old := {"name": "古", "race": "human", "cls": "rogue", "level": 3, "xp": 900, "stats": {"str": 9, "dex": 16, "con": 14, "int": 13, "wis": 11, "cha": 12}}
	var o := Character.from_dict(old)
	check(int(o.stats["dex"]) == 16 and Talents.picks_valid("rogue", o.profs) and o.pending().size() == 2, "古いセーブは、能力値そのまま、技能はおまかせ、熟達は未選択で読める")

# ---------- 持ち物と売買、セーブ ----------

func _test_state() -> void:
	print("[game state]")
	var gs := GameState.new()
	var party: Array = []
	for cls in ["fighter", "cleric", "wizard", "rogue"]:
		party.append(Character.create(cls, "human", cls, Jobs.auto_stats(cls)))
	gs.new_game(party)
	var silver0 := gs.bank_silver
	var ls_price := gs.buy_price("longsword")
	check(ls_price <= 220 and ls_price >= int(220 * 0.7), "〈説得〉で値段が下がる(長剣 220 → %d)" % ls_price)
	check(gs.buy("longsword") == "" and gs.count("longsword") == 1 and gs.bank_silver == silver0 - ls_price, "買える")
	check(gs.equip(party[0], "longsword") == "" and party[0].equip["weapon"] == "longsword" and gs.count("shortsword") == 1, "装備すると、古い武器が持ち物へ戻る")
	check(gs.equip(party[2], "plate") != "", "着られない鎧は装備できない")
	var sell0 := gs.bank_silver
	var ss_price := gs.sell_price("shortsword")
	check(ss_price >= ItemDB.sell_price("shortsword"), "〈ペテン〉で買い取りが上がる(%d → %d)" % [ItemDB.sell_price("shortsword"), ss_price])
	check(gs.sell("shortsword") == "" and gs.bank_silver == sell0 + ss_price, "売れる (+%d)" % ss_price)
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
				var inst := FloorInstance.create("res://data/floors/f%02d_n%02d_p%d.json.gz" % [fl, night, party])
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
	check(bad == 0 and count == 4 * Balance.NIGHTS * Balance.MAX_FLOOR, "全%d階が読める (不良 %d)" % [count, bad])
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
		var inst := FloorInstance.create("res://data/floors/f%02d_n00_p4.json.gz" % f)
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
		print("    %d階 %dx%d  燐晶 %d、自生物など %d、遺体 %d、魔物 %d" % [f, inst.map.w, inst.map.h, c, items, corpses, inst.enemies.size()])
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
	var fl := FloorInstance.create("res://data/floors/f%02d_n00_p%d.json.gz" % [floor_no, party_n])
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
			if Contact._passes(bodies[i], bodies[j]):
				continue   # 仲間どうし、仲間と中立の魔物は、すり抜ける
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
	e.max_hp = hp          # 試験では、魔物HPの係数をかけない
	e.hp = float(hp)
	e.state = "chase"
	fl.add_child(e)
	fl.enemies.append(e)
	e.died.connect(fl._on_enemy_died)
	fl.enc_total[999] = fl.enc_total.get(999, 0) + 1
	return e

# ---------- 戦闘のテンポと移動(オープンプレーの意見 A) ----------

func _fake_enemy_speed_probe() -> Enemy:
	var e := Enemy.new()
	e.speed = 100.0
	return e

func _test_tempo() -> void:
	print("[tempo]")
	# 速さの設定
	var keep := GameSettings.speed_index
	GameSettings.set_speed(0)
	GameSettings.load_settings()
	check(GameSettings.speed_index == 0 and is_equal_approx(GameSettings.speed(), 0.7) and GameSettings.speed_name() == "遅い", "ゲームの速さを保存して読み直せる")
	GameSettings.set_speed(keep)
	check(GameSettings.SPEEDS.map(func(x): return x[0]) == ["遅い", "普通", "早い", "超早い"] and GameSettings.DEFAULT_SPEED == 1, "速さは 遅い/普通/早い/超早い、初期値は普通")
	var ek := GameSettings.enemy_speed_index
	var en0 := _fake_enemy_speed_probe()
	GameSettings.set_enemy_speed(3)
	GameSettings.load_settings()
	check(GameSettings.enemy_speed_index == 3 and is_equal_approx(en0.move_speed(), en0.speed * Balance.ENEMY_SPEED_SCALE * 1.3), "魔物の速さの設定を保存して読み直せ、魔物に効く")
	GameSettings.set_enemy_speed(ek)
	en0.free()
	# 版1の操作の割り当ては、Esc を持ち物から外し、コントローラーのスキルを並べ替える
	var saved := Controls.binds.duplicate(true)
	Controls.binds["inventory"]["keys"] = [Controls._k(KEY_TAB), Controls._k(KEY_ESCAPE)]
	Controls.binds["skill1"]["pad"] = Controls._b(JOY_BUTTON_X)
	Controls.binds["guard"]["keys"] = [Controls._k(KEY_SPACE), {}]
	Controls.binds["attack"]["keys"] = [Controls._k(KEY_J), {}]
	Controls._migrate_v1()
	check(Controls.binds["attack"]["keys"][0].get("c", 0) == KEY_SPACE and Controls.binds["guard"]["keys"][0].get("c", 0) == KEY_CTRL, "古い割り当ての Space は攻撃へ、構えは Ctrl へ")
	check(Controls.binds["inventory"]["keys"][1].get("c", 0) != KEY_ESCAPE and Controls.binds["skill1"]["pad"] == Controls._b(JOY_BUTTON_Y), "古い割り当てを読み替える")
	Controls.binds = saved
	Controls.apply()
	var made := _make_floor(4, 1)
	var fl: FloorInstance = made[0]
	var heroes: Array = made[1]
	_clear_enemies(fl)
	var m := fl.map
	# 壁の角: 幅1マスの縦の通路へ、中心から横にずれたまま下へ進んでも入れる
	var entry := Vector2i(-1, -1)
	for y in range(1, m.h - 3):
		for x in range(1, m.w - 1):
			if m.opaque(x, y) or m.opaque(x - 1, y) or m.opaque(x + 1, y):
				continue   # 上は3マス続きの床
			var ok := true
			for k in range(1, 4):
				if m.opaque(x, y + k) or not m.opaque(x - 1, y + k) or not m.opaque(x + 1, y + k):
					ok = false
			if ok:
				entry = Vector2i(x, y)
				break
		if entry.x >= 0:
			break
	check(entry.x >= 0, "幅1マスの縦の通路が見つかる")
	if entry.x >= 0:
		var hero: Hero = heroes[0]
		for h in heroes:
			h.down = h != hero
		fl.heroes = [hero]
		fl.leader = hero
		hero.down = false
		hero.controlled = true
		hero.ch.hp = float(hero.ch.max_hp())
		var worst_y := 1e9
		for off in [-11.0, 11.0]:
			hero.position = m.center_of(entry) + Vector2(off, 0)
			hero.cmd = {"move": Vector2.DOWN, "guard": false, "dodge": false}
			var y0 := hero.position.y
			await _step(40)
			worst_y = minf(worst_y, hero.position.y - y0)
		hero.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
		check(worst_y > 40.0, "壁の角に掛かっても、滑って通路へ入れる (下へ %.1f px)" % worst_y)
	# 仲間どうしは、動いている間すり抜ける
	var spot := _open_spot(fl)
	var a: Hero = heroes[0]
	var b: Hero = heroes[1]
	for h in heroes:
		h.down = not (h == a or h == b)
		h.ch.hp = float(h.ch.max_hp())
	fl.heroes = [a, b]
	fl.leader = a
	a.controlled = true
	b.controlled = true      # 自分では動かない
	a.position = spot
	b.position = spot + Vector2(40, 0)
	a.cmd = {"move": Vector2.RIGHT, "guard": false, "dodge": false}
	b.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
	await _step(40)
	check(a.position.x > b.position.x + 5.0, "動いている仲間は、止まっている仲間をすり抜ける (%.1f / %.1f)" % [a.position.x, b.position.x])
	# 止まると、重ならないように離れる
	a.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
	a.position = b.position + Vector2(3, 0)
	await _step(60)
	check(a.position.distance_to(b.position) > a.radius + b.radius - 2.0, "止まっている仲間どうしは、重ならないように離れる (%.1f)" % a.position.distance_to(b.position))
	# 話し合える魔物(中立)は、すり抜ける
	_clear_enemies(fl)
	fl.heroes = [a]
	a.position = spot
	var nu := _fake_enemy(fl, spot + Vector2(40, 0), 50)
	nu.state = "neutral"
	var nx := nu.position.x
	a.cmd = {"move": Vector2.RIGHT, "guard": false, "dodge": false}
	await _step(40)
	check(a.position.x > nu.position.x + 5.0 and is_equal_approx(nu.hp, 50.0), "中立の魔物はすり抜け、殴らない (%.1f / %.1f)" % [a.position.x, nu.position.x])
	a.cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
	b.controlled = false
	_clear_enemies(fl)
	# 魔物の速さと HP の係数
	var sp0 := Balance.ENEMY_SPEED_SCALE
	var en := _fake_enemy(fl, spot, 10)
	var base := en.speed
	Balance.ENEMY_SPEED_SCALE = 0.5
	check(is_equal_approx(en.body_speed(), base * 0.5), "魔物の速さに係数がかかる")
	Balance.ENEMY_SPEED_SCALE = sp0
	var mon := {"name": "T", "hp": 20, "ac": 10, "size": "M", "type": "beast", "xp": 1, "cr": 0, "speed": {"walk": 30}, "attacks": []}
	var e2 := Enemy.new()
	e2.setup(fl, mon, {"id": 998, "kind": "beast", "attitude": "敵対", "activity": ""}, spot)
	check(e2.max_hp == int(round(20 * Balance.ENEMY_HP_SCALE)), "魔物の最大HPに係数がかかる (%d)" % e2.max_hp)
	e2.free()
	_clear_enemies(fl)
	fl.queue_free()

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
	# 2. 仲間は押し込むだけでは削れない。通常攻撃で削る。魔物は触れると殴ってくる
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
	check(is_equal_approx(en2.hp, 60.0), "押し込むだけでは敵のHPは削れない (60 → %.1f)" % en2.hp)
	h0.atk_cd = 0.0
	check(h0.attack(), "攻撃のボタンで正面へ一撃")
	check(en2.hp < 60.0, "通常攻撃で敵のHPが削れる (60 → %.1f)" % en2.hp)
	check(not h0.attack() and h0.attack_ready_frac() < 0.1, "振ったあとは待ち時間がある")
	await _step(int(Balance.ATTACK_CD * 60.0) + 4)
	check(h0.attack_ready_frac() >= 1.0, "待ち時間が過ぎると、また振れる")
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
	check(is_equal_approx(en3.hp, 300.0), "仲間は触れているだけでは攻撃しない(体当たりの自動攻撃はなし。敵HP 300 → %.1f)" % en3.hp)
	check(dmg_open > 0.0, "魔物は触れていると殴ってくる (%.1f)" % dmg_open)
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
	check(Talents.picks_valid("ranger", make.slots[1]["picks"]), "クラスを替えると、技能がおまかせになる")
	make._on_pick(false, String(make.slots[1]["picks"][0]))
	make._on_start()
	check(main.phase != "town" and make.msg.text.contains("技能"), "技能を選び終えていないと、始められない")
	make._on_auto_picks()
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
	var ls_cost: int = main.gs.buy_price("longsword")
	town._go("smith")
	town.sel_id = "longsword"
	town._fill_shop()
	town._buy(0)
	check(main.gs.party[0].equip["weapon"] == "longsword" and main.gs.bank_silver == bank0 - ls_cost, "鍛冶屋で買って装備する")
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
	# 技能・特技: 能力値上昇を選ぶ
	var fc: Character = main.gs.party[0]
	fc.gain_xp(int(Balance.XP_LEVELS[3]) - fc.xp)
	inv.member = 0
	inv._set_tab("talent")
	check(inv.ids.size() > 0 and String(inv.ids[0]) == "pend:asi4", "技能・特技の一覧の先頭に、選んでいない能力値上昇が出る")
	inv._on_pick(0)
	check(inv.pick_key == "asi4" and inv.ids.has("take:feat:tough") and inv.ids.has("take:abil:str"), "選ぶと、能力値と特技の候補が出る")
	inv._on_pick(inv.ids.find("half"))
	inv._on_pick(inv.ids.find("half1:con"))
	var con0 := int(fc.stats["con"])
	inv._on_pick(inv.ids.find("take:abil:con+wis"))
	inv._take_sel()
	check(int(fc.stats["con"]) == con0 + 1 and fc.pending().is_empty() and inv.pick_key == "", "画面から +1 を二つ選べる (%s)" % inv.msg.text)
	check(inv.ids.has("skill:athletics"), "技能の一覧が出る")
	inv._on_pick(inv.ids.find("skill:athletics"))
	check(inv.detail.text.contains("運動"), "技能の説明が出る")
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
	# 拾ったものを見せる(#20)
	main.hud.pickups.clear()
	var lh: Hero = main.leader()
	main._on_ground_picked({"kind": "crystal", "purity": "mid", "kg": 0.2, "pos": lh.position}, lh)
	main._on_ground_picked({"kind": "crystal", "purity": "mid", "kg": 0.1, "pos": lh.position}, lh)
	main._on_ground_picked({"kind": "item", "id": "potion", "qty": 1, "pos": lh.position}, lh)
	var pops := fl.get_children().filter(func(n): return n is PickupPop)
	check(pops.size() >= 3 and pops.any(func(n): return n.stack > 0), "拾った物の絵が仲間の頭の上へ跳ぶ(重ならないよう積む)")
	var want_kg: float = 0.3 * (1.0 + main.party_skill_fx("sleight"))
	check(main.hud.pickups.size() == 2 and is_equal_approx(float(main.hud.pickups[0]["amount"]), want_kg), "右の知らせは、同じ物をまとめる (%d件、%.2fkg)" % [main.hud.pickups.size(), float(main.hud.pickups[0]["amount"])])
	# 解錠の演出(#21)
	var nfx := fl.get_children().filter(func(n): return n is UnlockFx).size()
	var door := {"x": 1, "y": 1, "type": "locked", "unlocked": false, "lock_dc": 1}
	main._pick_cd = 0.0
	main._pick_lock(door)
	check(fl.get_children().filter(func(n): return n is UnlockFx).size() == nfx + 1, "解錠を試みると、錠前の演出が出る")
	# 階段
	for n in range(1, Balance.MAX_FLOOR):
		main.leader().position = main.current.map.center_of(main.current.down_cell)
		main.interact()
		await _step(2)
		check(main.current.floor_no == n + 1, "%d階 → %d階" % [n, n + 1])
	for n in range(Balance.MAX_FLOOR, 1, -1):
		main.leader().position = main.current.map.center_of(main.current.up_cell)
		main.interact()
		await _step(2)
	check(main.current.floor_no == 1, "1階まで戻れる")
	# 帰還と査定
	main._clear_bag()
	main.bag_silver = 1000
	var bank1: int = main.gs.bank_silver
	var perf := 0
	for c in main.gs.party:
		if c.hp > 0.0:
			perf = maxi(perf, int(c.skill_fx("performance")))
	main.leader().position = main.current.map.center_of(main.current.up_cell)
	main.interact()
	await _step(3)
	check(main.phase == "town" and main.gs.bank_silver == bank1 + 700 + perf and main.gs.day == 1, "街へ戻ると3割が税になり、〈芸能〉で稼ぐ (+%d、うち芸 %d)" % [main.gs.bank_silver - bank1, perf])
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
	await _test_time(main)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	main.queue_free()
	await process_frame

# ---------- 迷宮の時間、休息、ワンダリング ----------

func _test_time(main: Node) -> void:
	print("[time]")
	for c in main.gs.party:
		c.hp = float(c.max_hp())
		c.mp = float(c.max_mp())
	main._on_dive()
	await _step(3)
	var dt: DungeonTime = main.dtime
	var fl: FloorInstance = main.current
	check(dt != null and dt.phase_name() == "朝" and not dt.is_night(), "潜ると朝から始まる")
	_clear_enemies(fl)
	# MP は迷宮では自然に戻らない
	var h0: Hero = main.heroes[0]
	h0.ch.mp = 0.0
	await _step(30)
	check(h0.ch.mp == 0.0, "迷宮では MP が自然に戻らない")
	# 休む: 早送り、回復、6〜8時間で目を覚ます
	for h in main.heroes:
		h.ch.hp = h.ch.max_hp() * 0.3
		h.ch.mp = 0.0
	var wc := Balance.REST_WANDER_CHANCE
	Balance.REST_WANDER_CHANCE = 0.0
	var m0 := dt.minutes
	main.start_rest()
	check(dt.resting and h0.sleep_t > 0.0, "休み始めると、全員が眠る")
	var pos0 := h0.position
	h0.cmd["move"] = Vector2.RIGHT
	for i in 1200:
		await physics_frame
		if not dt.resting:
			break
	var hours := (dt.minutes - m0) / 60.0
	check(not dt.resting and hours >= 5.99 and hours <= 8.01, "6〜8時間で目を覚ます (%.1f時間)" % hours)
	check(h0.position.distance_to(pos0) < 4.0, "眠っている間は動かない")
	check(h0.ch.hp > h0.ch.max_hp() * 0.9 and h0.ch.mp > h0.ch.max_mp() * 0.8, "休むと HP と MP が戻る (HP %d/%d, MP %d/%d)" % [int(h0.ch.hp), h0.ch.max_hp(), int(h0.ch.mp), h0.ch.max_mp()])
	# 中断
	h0.ch.mp = 0.0
	main.start_rest()
	await _step(5)
	dt.stop_rest("中断")
	check(not dt.resting and h0.sleep_t == 0.0 and h0.ch.mp < h0.ch.max_mp() * 0.5, "休むのを中断できる(途中までしか戻らない)")
	Balance.REST_WANDER_CHANCE = wc
	# 敵に追われていると休めない
	var en := _fake_enemy(fl, h0.position + Vector2(60, 0), 50)
	en.state = "chase"
	main.start_rest()
	check(not dt.resting, "敵に追われていると休めない")
	_clear_enemies(fl)
	await _step(2)
	# 寝込みを襲われる
	main.start_rest()
	var n0: int = fl.enemies.size()
	var got := dt.spawn_wanderer(true)
	check(got and fl.enemies.size() > n0 and not dt.resting and h0.sleep_t > 0.0 and h0.sleep_t <= Balance.SURPRISE_TIME, "寝込みを襲われると、休息が終わり、少しの間動けない")
	var near := 1e9
	for e in fl.enemies:
		near = minf(near, e.position.distance_to(h0.position))
	check(near < 11.0 * Balance.CELL, "奇襲の敵は近くに出る (%.0f px)" % near)
	check(not h0.attack(), "動けない間は攻撃できない")
	_clear_enemies(fl)
	fl.wanderers.clear()
	# 起きているときのワンダリングは、見えない離れた所から
	got = dt.spawn_wanderer(false)
	var far := 1e9
	for e in fl.enemies:
		far = minf(far, e.position.distance_to(h0.position))
	check(got and far > 10.0 * Balance.CELL and fl.enemies[0].state == "chase", "ワンダリング・モンスターは離れた所に出て、向かってくる (%.0f px)" % far)
	check(dt._alive_wanderers() == 1, "出たワンダリングを数える")
	_clear_enemies(fl)
	fl.wanderers.clear()
	# 夜: 起きていると、どこかの部屋へ放り出され、朝になる
	var room0: int = fl.map.room_at[fl.map.idx(fl.map.cell_of(h0.position).x, fl.map.cell_of(h0.position).y)]
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + Balance.NIGHT_MIN - 0.01
	await _step(3)
	var room1: int = fl.map.room_at[fl.map.idx(fl.map.cell_of(main.leader().position).x, fl.map.cell_of(main.leader().position).y)]
	check(not dt.is_night() and dt.phase_name() == "朝" and room1 >= 0 and room1 != room0, "夜を迎えると、別の部屋へ放り出され、朝になる (部屋 %d → %d)" % [room0, room1])
	# 夕方から休むと、夜明けまで休み続ける
	Balance.REST_WANDER_CHANCE = 0.0
	dt.minutes = floorf(dt.minutes / 1440.0) * 1440.0 + 18 * 60
	main.start_rest()
	for i in 2000:
		await physics_frame
		if not dt.resting:
			break
	Balance.REST_WANDER_CHANCE = wc
	check(not dt.resting and not dt.is_night() and dt.clock() >= Balance.DAWN_MIN and dt.clock() < Balance.DAWN_MIN + 5.0, "夜にかかる休息は、夜明けまで続く (%02d:%02d)" % [int(dt.clock()) / 60, int(dt.clock()) % 60])
	main.return_to_surface()
	await _step(3)
	check(main.dtime == null, "街へ戻ると、迷宮の時間は片付く")

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
