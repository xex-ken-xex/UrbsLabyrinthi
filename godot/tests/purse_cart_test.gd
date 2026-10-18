extends SceneTree
## 所持金と預金、遺体カート、頭上の HP の棒、持ち物の重さの表記(ken 10/18): Godot --headless --path godot -s res://tests/purse_cart_test.gd
const M := preload("res://scripts/main.gd")
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	print("[所持金と預金]")
	var gs := GameState.new()
	var party: Array = []
	for cls in ["fighter", "cleric", "rogue"]:
		party.append(Character.create(cls, "human", cls, Jobs.auto_stats(cls)))
	gs.new_game(party)
	check(gs.silver == 300 and gs.bank_silver == 0, "はじめは所持金 300、預金 0")
	check(gs.deposit(250) == 200 and gs.silver == 100 and gs.bank_silver == 200, "預けるのは 100銀貨 単位(250 なら 200)")
	check(gs.deposit(50) == 0 and gs.silver == 100, "100 に満たなければ預けられない")
	check(gs.withdraw(1000) == 200 and gs.bank_silver == 0 and gs.silver == 300, "引き出すのも 100 単位(預金より多くは出ない)")
	gs.silver = 0
	gs.bank_silver = 5000
	check(gs.buy("potion") != "" and gs.count("potion") == 3, "店で使えるのは所持金だけ(預金があっても買えない)")
	gs.silver = 500
	check(gs.buy("potion") == "" and gs.bank_silver == 5000 and gs.silver < 500, "所持金で買う(預金は減らない)")
	var bank0 := gs.bank_silver
	gs.quests = [{"id": "potion", "n": 1, "reward": 120, "client": "誰か"}]
	check(gs.deliver_quest(0) == 120 and gs.bank_silver == bank0 + 120, "依頼の報酬は預金に入る")
	check(gs.save(), "記録できる")
	var gs2 := GameState.new()
	check(gs2.load_save() and gs2.silver == gs.silver and gs2.bank_silver == gs.bank_silver, "所持金と預金を分けて記録する")
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	var old := gs.to_dict()
	old.erase("silver")
	old["bank"] = 777
	f.store_string(JSON.stringify(old))
	f.close()
	check(gs2.load_save() and gs2.silver == 0 and gs2.bank_silver == 777, "所持金の無い古い記録は、預け金を全部預金として読む")
	check(GameState.save_summary().has("silver"), "タイトルの「つづきから」に所持金も出す")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.scripted_input = true
	var chars: Array = []
	for k in [["fighter", "human"], ["cleric", "human"], ["rogue", "human"]]:
		chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
	main.gs.new_game(chars)

	print("[坑口館の預金課]")
	main.go_town(["テスト"])
	for i in 3:
		await process_frame
	var town := main.screen as TownScreen
	town._go("guild")
	await process_frame
	var labels := ""
	for b in town.content.find_children("*", "Button", true, false):
		labels += (b as Button).text + " "
	check(labels.contains("100 預ける") and labels.contains("全部預ける") and labels.contains("100 引き出す"), "坑口館に預ける・引き出すボタンがある")
	check(town.silver_label.text.contains("所持金") and town.silver_label.text.contains("預金"), "街の上に所持金と預金 (%s)" % town.silver_label.text)
	main.gs.silver = 350
	main.gs.bank_silver = 0
	town._bank(1000)
	check(main.gs.silver == 50 and main.gs.bank_silver == 300 and town.msg.text.contains("預かった"), "全部預ける(100 単位、端数は手もとに) %s" % town.msg.text.right(30))
	town._bank(-100)
	check(main.gs.silver == 150 and main.gs.bank_silver == 200, "100 引き出す")
	main.gs.add_item("relic_tag", 1)
	var b1: int = main.gs.bank_silver
	var s1: int = main.gs.silver
	town._hand_relic("relic_tag", 1)
	check(main.gs.bank_silver > b1 and main.gs.silver == s1, "遺品の謝礼は預金へ")

	main.gs.bank_silver = 30
	main.gs.silver = 100
	check(main.gs.pay_at_guild(50) and main.gs.bank_silver == 0 and main.gs.silver == 80, "坑口館の窓口では、預金から先に払い、足りない分は所持金から")
	check(not main.gs.pay_at_guild(1000) and main.gs.silver == 80, "両方合わせて足りなければ払えない")

	print("[遺体カート]")
	main._set_screen(null)
	main.start_day()
	for i in 5:
		await physics_frame
	var fl: FloorInstance = main.current
	fl.traps.clear()
	fl.trap_at.clear()
	fl.spawner.pending.clear()
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
	var lead: Hero = main.leader()
	var cl: Hero = main.heroes[1]
	var ro: Hero = main.heroes[2]
	main.place_party(fl.map.center_of(fl.up_cell))
	ro.position = lead.position + Vector2(400, 400)
	check(ItemDB.SHOPS["general"].has("corpse_cart") and Burden.item_kg("corpse_cart") == 2.0, "遺体カートは灯守の店で売っていて、2kg")
	main.gs.add_item("corpse_cart", 1)
	main._load_t = 0.0
	main._update_carry_and_load(0.1)
	check(Hero.has_cart, "カートを持っている")
	var p0: float = lead.buff("power")
	var s0: float = lead._speed_now()
	cl.damage(9999.0, cl.position + Vector2(0, 1), true)
	cl.position = lead.position + Vector2(12, 0)
	main.interact()
	check(cl.on_cart and cl.carried_by == lead and lead.pulling() and lead.carrying == null, "倒れた仲間を、背負わずにカートに載せる")
	check(is_equal_approx(lead.buff("power"), p0) and is_equal_approx(lead._speed_now(), s0), "カートを引いても、足も攻撃も落ちない")
	var cue := false
	for n in fl.get_children():
		if n is Sfx and (n as Sfx).text == "ゴトン":
			cue = true
	check(cue, "載せると「ゴトン」")
	for i in 20:
		lead.position += Vector2(4, 0)
		main._update_carry_and_load(0.0)
	check(lead.cart_pos.distance_to(lead.position) <= Hero.CART_ROPE + 0.5 and lead.cart_pos.x < lead.position.x, "カートは引き手の後ろをついてくる")
	check(cl.position.distance_to(lead.cart_pos) < 14.0, "載せた仲間はカートの上")
	check(not main._left_behind().has(cl), "カートに載せた仲間は、置いていくことにならない")
	ro.damage(9999.0, ro.position + Vector2(0, 1), true)
	ro.position = lead.position + Vector2(-8, 10)
	main.interact()
	check(ro.on_cart and lead.cart_load.size() == 2, "二人目もカートに載せられる")
	var lc: Array = main.load_now()
	check(absf(float(lc[0]) - Burden.party_kg(main.gs, [lead.ch], main.bag_crystal)) < 0.01, "載せた仲間は重さに数えない(カートの 2kg だけ)")
	main.interact()
	check(not lead.pulling() and not cl.on_cart and cl.carried_by == null and ro.carried_by == null, "もう一度 E で、カートから下ろす")
	main.interact()
	check(lead.pulling() and lead.cart_load.size() == 1, "また載せられる")
	cl.revive(0.5)
	ro.revive(0.5)
	check(not cl.on_cart and not ro.on_cart and not lead.pulling(), "立ち上がった仲間は、カートから降りる")

	print("[頭上の HP の棒]")
	check(lead.has_method("_draw_hp_bar") and Hero.HP_BAR_W > 0.0, "仲間の頭上に HP の棒を描く")
	check(not Enemy.new().has_method("_draw_hp_bar"), "魔物には出さない(ken: 魔物は不要)")

	print("[持ち物の画面の重さ]")
	main.open_inventory()
	await process_frame
	var inv = main.inventory
	check(inv != null and inv.weight_lbl.text.contains("荷の重さ"), "持ち物の画面の上に、荷の重さ (%s)" % (inv.weight_lbl.text if inv != null else ""))
	var rows := ""
	for i in inv.item_list.item_count:
		rows += inv.item_list.get_item_text(i) + " / "
	check(rows.contains("kg"), "持ち物の一覧に、品ごとの重さ (%s)" % rows.left(80))
	main.close_inventory()
	await process_frame

	print("[全滅すると所持金を失う]")
	main.gs.silver = 500
	main.gs.bank_silver = 900
	main.dive_insured = false
	for h in main.heroes:
		h.down = true
		h.ch.hp = 0.0
	main._check_wipe()
	var ov := ""
	for l in main.hud.overlay:
		ov += String(l["text"]) + " / "
	check(main.gs.silver == 0 and main.gs.bank_silver == 900 and ov.contains("所持金 500銀貨 も失った"), "全滅すると所持金を失い、預金は無事 (%s)" % ov.left(90))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
