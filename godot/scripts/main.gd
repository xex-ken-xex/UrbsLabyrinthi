extends Node2D
## 全体の進行。タイトル → キャラ作成 → 街 → 迷宮 → 街、の巡り。
## 迷宮の中身は Urbs Labyrinthi が書き出した JSON(data/floors/)が決めている。ここは遊びの規則だけを持つ。

const SEVERITY_JP := {"setback": "軽度", "dangerous": "危険", "deadly": "致命的"}

var gs := GameState.new()
var dive_insured := false          # この潜行は帰還積立に入っている
var heroes: Array = []             # Hero(迷宮の中の体)
var active := 0                    # 操作している仲間の番号
var camera: Camera2D
var hud: Hud
var ui_layer: CanvasLayer
var hud_layer: CanvasLayer
var screen: Control                # 開いている画面(タイトル、作成、街)
var inventory: InventoryScreen
var key_config: KeyConfig
var current: FloorInstance
var floors := {}                   # 層の番号 → FloorInstance(この日の控え)
var bag_silver := 0                # 燐晶以外で、査定が要るもの(いまは使わない。テストと将来の拡張用)
var bag_crystal := {}              # 純度 → kg。持ち帰るとき、査定と燐晶税がかかる
var phase := "title"               # title / make / town / dungeon / menu / overlay
var overlay_kind := ""
var trail: Array = []
var light_t := 0.0                 # 燐晶の灯油の残り秒
var pending_return := false
var fire_until := -1.0            # 野営の火が消える時刻(迷宮の時刻、分)。燃料1つで1時間
var _kill_cue_ms := -1000            # 魔物が倒れた擬音を、最後に出した時刻(間引く)
var _jot_cue_ms := 0               # 冒険日記帳に書き足す擬音(サラサラ)を、続けて出さない
var _menu_fx: Array = []           # 持ち物の画面で起きた手ごたえ(料理、食べる)。閉じたら出す [擬音, Hero]
var pending_rest := false         # 持ち物の「休む」を押した(閉じたら休み始める)
var dtime: DungeonTime = null      # 迷宮の中の時間(闘技場では使わない)
var _last_cell := Vector2i(-99, -99)
var _detect_t := 0.0
var _search_cd := 0.0
var _pick_cd := 0.0
var _prev_phase := ""
var _menu_cd := 0.0
var arena: Arena = null            # 闘技場にいるとき
var arena_panel: ArenaPanel = null
var trap_menu: TrapMenu = null     # 見つけた罠の前で、どうするかを選んでいる
var _menu_trap: Dictionary = {}
var _crystal_cue_ms := -10000
var scripted_input := false        # テスト用: true の間は、キー入力を読まない
var _shake := 0.0                  # 画面の揺れ(爆発の罠など)
var _blind_was := false

func _ready() -> void:
	Dice.rng.randomize()
	if DisplayServer.window_is_focused():
		StickyKeys.suppress()
	_setup_input()
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * GameSettings.zoom()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.game = self
	hud_layer.add_child(hud)
	_trace("起動: %s" % " ".join(OS.get_cmdline_args()))
	if Updater.should_check() and not OS.get_cmdline_user_args().has("--autotest-town"):
		var up := Updater.new()
		up.finished.connect(func(note: String):
			show_title()
			if note != "":
				_title_note(note))
		_set_screen(up)
	else:
		show_title()
	if OS.get_cmdline_user_args().has("--autotest-town"):
		call_deferred("_autotest_town")

## Windows の固定キーのショートカット(Shift 5回)は、ゲームが前面にある間だけ止める(StickyKeys)
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			StickyKeys.suppress()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE, NOTIFICATION_PREDELETE:
			StickyKeys.restore()

## 書き出したビルドで「迷宮 → 街」を再現するための確認用(--autotest-town を付けて起動する)
func _autotest_town() -> void:
	await get_tree().create_timer(0.5).timeout
	show_make()
	await get_tree().create_timer(0.3).timeout
	screen._on_start()
	await get_tree().create_timer(0.3).timeout
	_on_dive()
	await get_tree().create_timer(0.5).timeout
	# 戦闘のさなかに階段で戻る(魔物と飛び道具が動いている状態)
	var k := 0
	for e in current.enemies:
		if k >= 6:
			break
		e.position = leader().position + Vector2.from_angle(k * 1.1) * 40.0
		e.wake()
		k += 1
	await get_tree().create_timer(1.5).timeout
	leader().position = current.map.center_of(current.up_cell)
	await get_tree().create_timer(0.3).timeout
	Input.action_press("interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("interact")
	await get_tree().create_timer(1.0).timeout
	print("AUTOTEST 街へ戻る phase=", phase)
	await get_tree().create_timer(0.5).timeout
	# 全滅 → 街
	_on_dive()
	await get_tree().create_timer(0.8).timeout
	for h in heroes:
		h.damage(99999.0, h.position, true)
	await get_tree().create_timer(0.5).timeout
	print("AUTOTEST 全滅 phase=", phase)
	Input.action_press("confirm")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("confirm")
	await get_tree().create_timer(0.8).timeout
	print("AUTOTEST 全滅のあと phase=", phase)
	# 持ち物を開いて閉じ、帰還の札で街へ
	_on_dive()
	await get_tree().create_timer(0.8).timeout
	open_inventory()
	await get_tree().create_timer(0.3).timeout
	pending_return = true
	close_inventory()
	await get_tree().create_timer(0.8).timeout
	print("AUTOTEST 帰還の札 phase=", phase)
	show_title()
	await get_tree().create_timer(0.3).timeout
	_on_continue()
	await get_tree().create_timer(0.5).timeout
	print("AUTOTEST つづきから phase=", phase)
	# 闘技場: 入る、出す、連戦、全滅、出る
	start_arena()
	await get_tree().create_timer(0.5).timeout
	arena.enc_level = 4
	arena.pop()
	arena.pop()
	await get_tree().create_timer(1.5).timeout
	for h in heroes:
		h.damage(99999.0, h.position, true)
	await get_tree().create_timer(0.5).timeout
	arena.auto_waves = true
	arena._next_t = 0.1
	await get_tree().create_timer(1.0).timeout
	exit_arena()
	await get_tree().create_timer(0.8).timeout
	print("AUTOTEST 闘技場 phase=", phase)
	await get_tree().create_timer(0.5).timeout
	print("AUTOTEST done")
	get_tree().quit()

func _setup_input() -> void:
	Controls.setup()
	GameSettings.load_settings()

## 操作の設定(タイトルと街から開く)
func open_key_config() -> void:
	if key_config != null:
		return
	key_config = KeyConfig.new()
	key_config.closed.connect(close_key_config)
	ui_layer.add_child(key_config)

func close_key_config() -> void:
	if key_config == null:
		return
	key_config.queue_free()
	key_config = null
	_menu_cd = 0.3
	if screen != null and screen.has_method("focus_default"):
		screen.call("focus_default")

func leader() -> Hero:
	if heroes.is_empty() or active < 0 or active >= heroes.size() or not is_instance_valid(heroes[active]):
		return null
	return heroes[active]

# ---------- 画面の切り替え ----------

func _set_screen(s: Control) -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	screen = s
	if s != null:
		ui_layer.add_child(s)

func show_title() -> void:
	phase = "title"
	_clear_dungeon()
	var t := TitleScreen.new()
	t.new_game.connect(show_make)
	t.continue_game.connect(_on_continue)
	t.show_credits.connect(func(): hud.show_credits = true)
	t.key_config.connect(open_key_config)
	_set_screen(t)

## タイトルの下に、更新の結果を出す
func _title_note(text: String) -> void:
	if screen is TitleScreen:
		(screen as TitleScreen).set_note(text)

func show_make() -> void:
	phase = "make"
	var m := CharaMake.new()
	m.cancelled.connect(show_title)
	m.finished.connect(_on_party_made)
	_set_screen(m)

## 宿屋の酒場で、仲間を一人加える
func show_recruit() -> void:
	if gs.party.size() >= Balance.MAX_PARTY:
		return
	phase = "make"
	var m := CharaMake.new()
	m.recruit = true
	m.party_now = gs.party.duplicate()
	m.cancelled.connect(_back_to_inn.bind(""))
	m.finished.connect(_on_recruited)
	_set_screen(m)

func _on_recruited(chars: Array) -> void:
	for c in chars:
		if gs.party.size() < Balance.MAX_PARTY:
			c.hired = true
			gs.party.append(c)
	_back_to_inn("%sが仲間に加わった。" % chars[0].name if not chars.is_empty() else "")

func _back_to_inn(said: String) -> void:
	go_town([])
	if screen is TownScreen:
		(screen as TownScreen)._go("inn")
		if said != "":
			(screen as TownScreen)._say(said, UIKit.GOOD)

func _on_party_made(chars: Array) -> void:
	gs.new_game(chars)
	DiveSave.clear()
	go_town(["「ようこそ、ヴェルガ・ノクスへ。許可証は灰等級から。」", "預け金 %d銀貨。装備と薬を整えてから、迷宮へ。" % gs.bank_silver])

func _on_continue() -> void:
	if gs.load_save():
		var d := DiveSave.read()
		if not d.is_empty() and int(d.get("day", -1)) == gs.day:
			resume_dive(d)
			return
		DiveSave.clear()
		go_town(["記録を読み込んだ。%s。" % ZaCalendar.label(gs.day)])

# ---------- 迷宮の中の記録 ----------

## 迷宮の中で記録をつける(持ち物の画面から)。パーティと持ち物は save.json、迷宮の様子は dive.sav
func save_dive() -> bool:
	if dtime == null or current == null or arena != null:
		return false
	var fls := {}
	for n in floors:
		fls[n] = DiveSave.floor_snap(floors[n])
	var hs: Array = []
	for h in heroes:
		hs.append({"party": gs.party.find(h.ch), "pos": h.position, "buffs": h.buffs.duplicate(true), "rust": h.rust, "last_stand": h.last_stand})
	var d := {"version": DiveSave.VERSION, "day": gs.day, "floor": current.floor_no, "floors": fls, "heroes": hs,
		"active": gs.party.find(leader().ch), "bag": bag_crystal.duplicate(), "light_t": light_t, "insured": dive_insured,
		"minutes": dtime.minutes, "resting": dtime.resting, "rest_end": dtime.rest_end, "rest_from": dtime.rest_from, "fire_until": fire_until}
	if not gs.save() or not DiveSave.write(d):
		return false
	log_msg("記録をつけた(%s、%s)。" % [ZaCalendar.label(gs.day), current.map.data["meta"].get("floor_label", "")], Color("9be29b"))
	return true

## 迷宮の中の記録から、その場所で再開する
func resume_dive(d: Dictionary) -> void:
	_trace("resume_dive 日%d 層%d" % [gs.day, int(d["floor"])])
	_set_screen(null)
	_clear_dungeon()
	_clear_bag()
	for c in gs.party:
		var h := Hero.new()
		h.setup(null, c)
		add_child(h)
		heroes.append(h)
	for r in d.get("heroes", []):
		var i := int(r["party"])
		if i < 0 or i >= heroes.size():
			continue
		var h: Hero = heroes[i]
		h.buffs = r.get("buffs", {})
		h.rust = int(r.get("rust", 0))
		h.last_stand = bool(r.get("last_stand", true))
	active = clampi(int(d.get("active", 0)), 0, heroes.size() - 1)
	_apply_control()
	bag_crystal = d.get("bag", {}).duplicate()
	light_t = float(d.get("light_t", 0.0))
	dive_insured = bool(d.get("insured", false))
	phase = "dungeon"
	hud.overlay = []
	dtime = DungeonTime.new(self)
	dtime.minutes = float(d.get("minutes", dtime.minutes))
	dtime.resting = bool(d.get("resting", false))
	dtime.rest_end = float(d.get("rest_end", 0.0))
	dtime.rest_from = float(d.get("rest_from", 0.0))
	fire_until = float(d.get("fire_until", -1.0))
	var fls: Dictionary = d.get("floors", {})
	for n in fls:
		var fl := _make_floor(int(n))
		if fl != null:
			DiveSave.floor_apply(fl, fls[n])
	enter_floor(int(d["floor"]), "up")
	for r in d.get("heroes", []):
		var i := int(r["party"])
		if i >= 0 and i < heroes.size():
			heroes[i].position = r["pos"]
	trail = [leader().position]
	camera.position = leader().position
	camera.reset_smoothing()
	_last_cell = Vector2i(-99, -99)
	_refresh_view()
	log_msg("記録から再開した。%s、%s。" % [ZaCalendar.label(gs.day), current.map.data["meta"].get("night_label", "")], Color("9be29b"))

func _trace(msg: String) -> void:
	print("[urbs] ", msg)   # 強制終了の直前の行が、ログに残る

func go_town(report: Array) -> void:
	_trace("go_town 開始")
	phase = "town"
	_clear_dungeon()
	_trace("go_town: 迷宮を片付けた")
	# 全員が倒れていたら、灯手隊が担ぎ出して最低限の手当てをしてくれる
	var any_alive := false
	for c in gs.party:
		if c.hp > 0.0:
			any_alive = true
	if not any_alive:
		for c in gs.party:
			c.hp = 1.0
		report.append("全員が倒れていたため、灯手隊が担ぎ出してくれた。")
	var won := Trophies.line(Trophies.evaluate(gs))
	if won != "":
		report.append(won)
	gs.save()
	var t := TownScreen.new()
	t.setup(gs)
	t.dive.connect(_on_dive)
	t.open_inventory.connect(open_inventory)
	t.arena_requested.connect(start_arena)
	t.to_title.connect(show_title)
	t.key_config.connect(open_key_config)
	t.recruit.connect(show_recruit)
	_trace("go_town: 街の画面を作る")
	_set_screen(t)
	t.arrive(report)
	_trace("go_town 完了")

func _on_dive() -> void:
	var alive := false
	for c in gs.party:
		if c.hp > 0.0:
			alive = true
	if not alive:
		return
	_set_screen(null)
	start_day()

func _clear_dungeon() -> void:
	_trace("_clear_dungeon 層%d 仲間%d" % [floors.size(), heroes.size()])
	for f in floors.values():
		f.queue_free()
	floors.clear()
	for h in heroes:
		h.queue_free()
	heroes.clear()
	if current != null and current.get_parent() == self:
		remove_child(current)
	if arena != null:
		arena.queue_free()
		arena = null
	if arena_panel != null:
		arena_panel.queue_free()
		arena_panel = null
	camera.zoom = Vector2.ONE * GameSettings.zoom()
	camera.offset = Vector2.ZERO
	current = null
	dtime = null
	pending_rest = false
	hud.overlay = []
	hud.hint = ""

# ---------- 日と層 ----------

## 闘技場(戦闘バランスの調整用)。パーティは複製を使う。経験点も宝も出ない
func start_arena() -> void:
	_trace("start_arena")
	_set_screen(null)
	_clear_dungeon()
	_clear_bag()
	light_t = 0.0
	active = 0
	arena = Arena.new()
	add_child(arena)
	arena.setup(self, gs.party)
	for c in arena.chars:
		var h := Hero.new()
		h.setup(null, c)
		add_child(h)
		heroes.append(h)
	_apply_control()
	phase = "dungeon"
	current = arena.fl
	add_child(current)
	move_child(current, 0)
	current.heroes = heroes
	current.leader = leader()
	current.message.connect(_on_floor_message)
	current.shake.connect(func(v: float): _shake = maxf(_shake, v))
	current.enemy_killed.connect(_on_enemy_killed)
	current.ground_picked.connect(_on_ground_picked)
	var center := current.map.center_of(current.up_cell)
	for i in heroes.size():
		var h: Hero = heroes[i]
		h.game_floor = current
		h.position = center + Vector2.from_angle(TAU * i / maxf(1.0, heroes.size()) + 0.6) * (22.0 if i != active else 0.0)
	trail = [leader().position]
	camera.zoom = Vector2(1.05, 1.05)
	camera.offset = Vector2(190.0 / 1.05, 0.0)       # 右の盤にかからないよう、闘技場を左へ寄せる
	camera.position = Vector2(Arena.W, Arena.H) * Balance.CELL / 2.0
	camera.reset_smoothing()
	_last_cell = Vector2i(-99, -99)
	_refresh_view()
	arena_panel = ArenaPanel.new()
	arena_panel.setup(arena, self)
	ui_layer.add_child(arena_panel)
	log_msg("闘技場。右の盤で、敵をポップ、レベル、係数を調整できる(F2 で出し入れ)", Color("ffe9a8"))

func exit_arena() -> void:
	if arena == null:
		return
	phase = "transition"
	call_deferred("go_town", ["闘技場から戻った。本編のパーティには、影響しない。"])

func floor_path(n: int, night: int) -> String:
	return FloorMap.floor_path(n, night % Balance.NIGHTS, gs.party.size())

## 夜が替わるので、通路も部屋の中身も組み直される(大部屋と階段は同じ場所)
func start_day() -> void:
	_trace("start_day 日%d" % gs.day)
	DiveSave.clear()      # 前の夜の迷宮の記録は、もう使わない
	_clear_dungeon()
	_clear_bag()
	light_t = 0.0
	active = 0
	for c in gs.party:
		var h := Hero.new()
		h.setup(null, c)
		add_child(h)
		heroes.append(h)
	for i in heroes.size():
		if not heroes[i].down:
			active = i
			break
	_apply_control()
	gs.set_clock(gs.town_clock())
	fire_until = -1.0
	for c in gs.party:
		c.belly = maxf(c.belly, Cooking.BELLY_START)     # 宿か自宅で、朝飯を食べて出る
	dive_insured = gs.insured     # 帰還積立は、この潜行一回ぶん
	gs.insured = false
	if gs.blessed:
		gs.blessed = false
		for h in heroes:
			h.buffs["guard"] = {"t": 120.0, "v": 0.8}
	phase = "dungeon"
	hud.overlay = []
	dtime = DungeonTime.new(self)
	enter_floor(1, "up")
	log_msg("%s、%s。" % [ZaCalendar.label(gs.day), current.map.data["meta"].get("night_label", "")], Color("e8dcb0"))

func _apply_control() -> void:
	for i in heroes.size():
		heroes[i].controlled = i == active
		heroes[i].cmd = {"move": Vector2.ZERO, "attack": false, "dodge": false}
		heroes[i].cancel_charge()
	if current != null:
		current.leader = leader()

## その夜の層を作る(まだ作っていなければ)。作れなければ null
func _make_floor(n: int) -> FloorInstance:
	var fl: FloorInstance = floors.get(n)
	if fl != null:
		return fl
	fl = FloorInstance.create(floor_path(n, gs.day))
	if fl == null:
		push_error("層を読めない: %d" % n)
		return null
	fl.message.connect(_on_floor_message)
	fl.shake.connect(func(v: float): _shake = maxf(_shake, v))
	fl.enemy_killed.connect(_on_enemy_killed)
	fl.enemy_seen.connect(_on_enemy_seen)
	fl.stat.connect(_on_floor_stat)
	fl.ground_picked.connect(_on_ground_picked)
	floors[n] = fl
	return fl

func enter_floor(n: int, arrive: String) -> void:
	var fl := _make_floor(n)
	if fl == null:
		return
	if current != null and current.get_parent() == self:
		remove_child(current)
	current = fl
	add_child(fl)
	move_child(fl, 0)
	fl.heroes = heroes
	fl.leader = leader()
	var cell := fl.up_cell if arrive == "up" else fl.down_cell
	for h in heroes:
		h.game_floor = fl
	place_party(fl.map.center_of(cell))
	Sfx.cue(fl, leader().position, "stairs")
	var meta: Dictionary = fl.map.data["meta"]
	log_msg("%s「%s」" % [meta.get("floor_label", "第%d層" % n), fl.style.get("short", "")], Color("e8dcb0"))
	if arena == null:
		Journal.best(gs, "deepest", fl.layer_no)
		_check_trophies()
	var see: Array = fl.style.get("see", [])
	if arrive == "up" and not see.is_empty() and not fl.visited_rooms.has("floor"):
		fl.visited_rooms["floor"] = true
		log_msg(String(see[Dice.rng.randi_range(0, see.size() - 1)]), Color(0.8, 0.85, 0.9))

## 一行を center のまわりへ置き直す(層に着いたとき、夜に放り出されたとき)
func place_party(center: Vector2) -> void:
	for i in heroes.size():
		var h: Hero = heroes[i]
		var a := TAU * i / maxf(1.0, heroes.size()) + 0.6
		h.position = center + Vector2.from_angle(a) * (22.0 if i != active else 0.0)
		h.knock = Vector2.ZERO
	trail = [leader().position]
	camera.position = leader().position
	camera.reset_smoothing()
	_last_cell = Vector2i(-99, -99)
	_refresh_view()

## 休む(野営)。休めないときは、理由をログへ
func start_rest() -> void:
	if dtime == null or phase != "dungeon":
		return
	var why := dtime.start_rest()
	if why != "":
		log_msg(why, Color(0.8, 0.8, 0.85))
	else:
		hud.hint = ""
		Sfx.cue(current, leader().position, "rest")
		log_msg("野営して休む。(%s / %s / Esc で中断)" % [Controls.hint("rest"), Controls.hint("interact")], Color("e8dcb0"))

func light_radius() -> int:
	var b := 0
	for h in heroes:
		if not h.down:
			b = maxi(b, h.ch.light_bonus())
	if leader().blind_t > 0.0:
		return 2          # 眩惑の罠: 目がくらんで、近くしか見えない
	return Balance.LIGHT_RADIUS + b + (2 if light_t > 0.0 else 0)

func _refresh_view() -> void:
	var pc := current.map.cell_of(leader().position)
	current.map.compute_visible(pc.x, pc.y, light_radius())
	current.update_flow(pc)
	current.light_pos = leader().position
	current.queue_redraw()

## 層からの知らせ(kind: info / danger)
func _on_floor_message(text: String, kind: String) -> void:
	log_msg(text, Color("ff6a5a") if kind == "danger" else Color(0.85, 0.85, 0.8))

func log_msg(text: String, color: Color = Color.WHITE) -> void:
	var s := text
	while s.length() > 46:
		hud.add_log(s.substr(0, 46), color)
		s = s.substr(46)
	hud.add_log(s, color)

# ---------- 毎フレーム ----------

func _physics_process(delta: float) -> void:
	# ゲームの速さは迷宮の中だけ(街、メニュー、報告は等速)
	Engine.time_scale = GameSettings.speed() if phase == "dungeon" else 1.0
	if Input.is_action_just_pressed("credits"):
		hud.show_credits = not hud.show_credits
	if Input.is_action_just_pressed("reload_assets"):
		Assets.clear()          # 置いた画像を読み込み直す(フォントは再起動後)
		if current != null:
			current.queue_redraw()
		log_msg("画像を読み込み直した", Color(0.7, 0.85, 1.0))
	match phase:
		"dungeon": _dungeon_frame(delta)
		"overlay":
			if Input.is_action_just_pressed("confirm"):
				_after_overlay()

func _dungeon_frame(delta: float) -> void:
	if current == null or heroes.is_empty():
		return
	_search_cd = maxf(0.0, _search_cd - delta)
	_pick_cd = maxf(0.0, _pick_cd - delta)
	light_t = maxf(0.0, light_t - delta)
	_menu_cd = maxf(0.0, _menu_cd - delta)
	_read_input()
	# 入力で街へ戻った(heroes が空になった)あとは、迷宮の処理を続けない。
	# 書き出したビルドでは、null の Hero へ触れると、エラーではなく強制終了になる
	if phase != "dungeon" or current == null or heroes.is_empty():
		return
	var lead := leader()
	_update_trail(lead)
	camera.position = (Vector2(Arena.W, Arena.H) * Balance.CELL / 2.0) if arena != null else lead.position
	if arena == null:
		_shake = maxf(0.0, _shake - delta)
		camera.offset = Vector2(Dice.rng.randf_range(-1, 1), Dice.rng.randf_range(-1, 1)) * 22.0 * _shake if _shake > 0.0 else Vector2.ZERO
	var pc := current.map.cell_of(lead.position)
	if pc != _last_cell:
		_last_cell = pc
		_refresh_view()
		if arena == null:
			_enter_room(pc)
	_open_doors_near_heroes()
	if arena == null:
		_check_traps()
		if dtime != null:
			dtime.update(delta)
			gs.set_clock(gs.day * 1440.0 + dtime.minutes)
	if (lead.blind_t > 0.0) != _blind_was:
		_blind_was = lead.blind_t > 0.0
		_refresh_view()
	_detect_t -= delta
	if _detect_t <= 0.0:
		_detect_t = 0.2
		_passive_detect(pc)
		_update_hint()
	_check_wipe()

func _read_input() -> void:
	var lead := leader()
	if lead.down:
		_auto_switch()
		lead = leader()
	if scripted_input:
		return
	if dtime != null and dtime.resting:
		# 休んでいる間は、中断だけ受け付ける
		if Input.is_action_just_pressed("rest") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel") \
				or Input.is_action_just_pressed("attack") or Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.5:
			dtime.stop_rest("休むのをやめた。%d時間ほど休んだ。" % int(round((dtime.minutes - dtime.rest_from) / 60.0)))
		return
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	lead.cmd["move"] = mv
	if Input.is_action_just_pressed("dodge"):
		lead.cmd["dodge"] = true
	# 攻撃: 押した瞬間に一度振り、押し続けると溜まり、離すと溜めの一撃(Hero._attack_input)。
	# 選んでいるスキルが 0(通常攻撃)なら、「選んだスキルを使う」(右クリック)でも同じ
	if Input.is_action_just_pressed("skill_next"):
		lead.next_skill()
	var sel0 := lead.ch.skill_sel == 0
	var held := false
	for act in (["attack", "skill_use"] if sel0 else ["attack"]):
		if Input.is_action_pressed(act) and not (_by_mouse(act) and _menu_cd > 0.0):     # 画面のボタンを押した、そのクリックでは振らない
			held = true
			_face_mouse(lead, act)
	lead.cmd["attack"] = held
	if not sel0 and Input.is_action_just_pressed("skill_use") and not (_by_mouse("skill_use") and _menu_cd > 0.0):
		_face_mouse(lead, "skill_use")
		lead.cast_slot(lead.ch.skill_sel - 1)
	for i in Character.SLOTS:
		if Input.is_action_just_pressed("skill%d" % (i + 1)):
			lead.cast_slot(i)
	if Input.is_action_just_pressed("switch"):
		_switch_next()
	if Input.is_action_just_pressed("interact"):
		interact()
		if phase != "dungeon" or heroes.is_empty():
			return
	if Input.is_action_just_pressed("search"):
		search()
	if Input.is_action_just_pressed("quick_heal"):
		quick_heal()
	if Input.is_action_just_pressed("rest"):
		start_rest()
	if Input.is_action_just_pressed("zoom_in"):
		minimap_step(1)
	if Input.is_action_just_pressed("zoom_out"):
		minimap_step(-1)
	if Input.is_action_just_pressed("inventory") and _menu_cd <= 0.0:
		open_inventory()

## その操作を、割り当てたマウスのボタンで押しているか
func _by_mouse(act: String) -> bool:
	var mb: Dictionary = Controls.binds.get(act, {}).get("mouse", {})
	return not mb.is_empty() and Input.is_mouse_button_pressed(int(mb["m"]))

## マウスで押しているなら、マウスの方向を向く(振る・撃つ向き)
func _face_mouse(lead: Hero, act: String) -> void:
	if not _by_mouse(act):
		return
	var to := lead.get_global_mouse_position() - lead.position
	if to.length() > 4.0:
		lead.facing = to.normalized()

## ミニマップ(仲間のまわり)を拡大・縮小する。段は保存する
func minimap_step(d: int) -> void:
	var i := clampi(GameSettings.minimap_index + d, 0, GameSettings.MINIMAPS.size() - 1)
	if i == GameSettings.minimap_index:
		return
	GameSettings.set_minimap(i)
	log_msg("ミニマップ: %s" % GameSettings.minimap_name(), Color(0.7, 0.85, 1.0))

## 迷宮の画面を3段階で拡大・縮小する(マウスのホイール。闘技場は固定)。段は保存する
func zoom_step(d: int) -> void:
	if arena != null or phase != "dungeon":
		return
	var i := clampi(GameSettings.zoom_index + d, 0, GameSettings.ZOOMS.size() - 1)
	if i == GameSettings.zoom_index:
		return
	GameSettings.set_zoom(i)
	camera.zoom = Vector2.ONE * GameSettings.zoom()
	log_msg("画面: %s" % GameSettings.zoom_name(), Color(0.7, 0.85, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if scripted_input or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_step(1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_step(-1)

func _switch_next() -> void:
	for k in range(1, heroes.size()):
		var i := (active + k) % heroes.size()
		if not heroes[i].down:
			active = i
			_apply_control()
			trail = [leader().position]
			log_msg("%sを操作する" % leader().ch.name, Color("ffe9a8"))
			return

func _auto_switch() -> void:
	for i in heroes.size():
		if not heroes[i].down:
			active = i
			_apply_control()
			trail = [leader().position]
			return

func _update_trail(lead: Hero) -> void:
	if trail.is_empty() or lead.position.distance_to(trail[trail.size() - 1]) >= 8.0:
		trail.append(lead.position)
		if trail.size() > 90:
			trail.pop_front()
	var j := 0
	for i in heroes.size():
		if i == active:
			continue
		j += 1
		var idx := trail.size() - 1 - j * 4
		# 跡が足りないときは、先頭の向きの後ろへ並ぶ(仲間同士はすり抜けるので、重ならないように)
		heroes[i].follow_pos = trail[idx] if idx >= 0 else lead.position - lead.facing * 26.0 * j

func _check_wipe() -> void:
	for h in heroes:
		if not h.down:
			return
	if arena != null:
		arena.on_wipe()
		log_msg("全滅。記録して、全回復した", Color("ff9a8a"))
		return
	var lost := bag_value()
	_clear_bag()
	DiveSave.clear()      # 全滅を、迷宮の記録で取り消せないように
	Journal.bump(gs, "wipes")
	# 持ち物も装備も、全部失う(ken 10/16)。帰還積立に入っていれば、装備は戻り、持ち物は半分
	var lost_items := gs.lose_half() if dive_insured else gs.lose_everything()
	var lost_line := "持ち物と装備(武器・防具も)%d点を、すべて失った" % lost_items
	var rescue_line := "灯手隊が、倒れた仲間を担ぎ出してくれた。"
	if dive_insured:
		lost_line = "持ち物 %d点を失った。装備は無事だった" % lost_items
		rescue_line = "帰還積立のおかげで、灯手隊が装備と持ち物の半分を拾ってきてくれた。"
	phase = "overlay"
	overlay_kind = "wipe"
	hud.hint = ""
	hud.overlay = [
		{"text": "全滅した…", "size": 30, "color": Color("ff6a5a")},
		{"text": "", "size": 8},
		{"text": "未査定の燐晶 %d銀貨相当 を失った" % lost, "size": 16},
		{"text": lost_line, "size": 16, "color": Color("ff9a8a")},
		{"text": rescue_line, "size": 16, "color": Color("f1d98a")},
		{"text": "", "size": 8},
		{"text": "%s: 街へ" % Controls.hint("confirm"), "size": 18, "color": Color("9ad8ff")},
	]

func _after_overlay() -> void:
	_trace("_after_overlay %s" % overlay_kind)
	if overlay_kind == "wipe":
		gs.day += 1
		phase = "transition"
		if dive_insured:
			call_deferred("go_town", ["全滅した。未査定の燐晶と、持ち物の半分を迷宮に残してきた。帰還積立のおかげで、装備は戻った。預け金 %d銀貨 は無事だ。" % gs.bank_silver, "倒れた仲間は神殿で蘇らせよう。"])
		else:
			call_deferred("go_town", ["全滅した。未査定の燐晶も、持ち物も装備も、すべて迷宮に残してきた。預け金 %d銀貨 は無事だ。" % gs.bank_silver, "倒れた仲間は神殿で蘇らせ、鍛冶屋で装備を整え直そう。"])

# ---------- 部屋、扉、罠 ----------

func _enter_room(pc: Vector2i) -> void:
	var m := current.map
	var rid := m.room_at[m.idx(pc.x, pc.y)]
	if rid < 0 or current.visited_rooms.has(rid):
		return
	current.visited_rooms[rid] = true
	var r: Dictionary = m.room_by_id[rid]
	log_msg("「%s」" % r["name"], Color("d8e6ff"))
	var feat: Variant = r.get("feature")
	if typeof(feat) == TYPE_DICTIONARY:
		log_msg("%s: %s" % [feat["name"], feat["desc"]], Color(0.78, 0.82, 0.86))
	var hook: Variant = r.get("hook")
	if typeof(hook) == TYPE_STRING:
		log_msg(hook, Color("c9b6ff"))

func _open_doors_near_heroes() -> void:
	var m := current.map
	var opened := false
	for h in heroes:
		if h.down:
			continue
		for d in m.doors_near(h.position, 28.0):
			if d["open"]:
				continue
			if d["type"] == "secret" and not d["found"]:
				continue
			if d["type"] == "locked" and not d["unlocked"]:
				continue
			d["open"] = true
			opened = true
			Sfx.cue(current, m.center_of(Vector2i(int(d["x"]), int(d["y"]))), "door")
	if opened:
		_refresh_view()

func party_passive() -> int:
	var best := 0
	for h in heroes:
		if not h.down:
			best = maxi(best, h.ch.passive_perception())
	return best

func party_best(kind: String) -> int:
	var c := party_best_char(kind)
	return -99 if c == null else (c.search_bonus() if kind == "search" else c.lock_bonus())

## その判定をいちばん得意な仲間(倒れていない人)
func party_best_char(kind: String) -> Character:
	var best: Character = null
	var bv := -999
	for h in heroes:
		if h.down:
			continue
		var v: int = h.ch.search_bonus() if kind == "search" else h.ch.lock_bonus()
		if v > bv:
			bv = v
			best = h.ch
	return best

## 倒れていない仲間のうち、その技能の効き目がいちばん大きい値
func party_skill_fx(id: String) -> float:
	var best := 0.0
	for h in heroes:
		if not h.down:
			best = maxf(best, h.ch.skill_fx(id))
	return best

func _passive_detect(pc: Vector2i) -> void:
	var m := current.map
	var pp := party_passive()
	var lp := leader().position
	for t in current.traps:
		if t["st"] != "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if lp.distance_to(m.center_of(tc)) > 2.5 * Balance.CELL:
			continue
		if int(t["detect_dc"]) <= pp and m.los(pc.x, pc.y, tc.x, tc.y):
			_reveal_trap(t)
	for d in m.doors:
		if d["type"] != "secret" or d["found"]:
			continue
		var dc := Vector2i(d["x"], d["y"])
		if lp.distance_to(m.center_of(dc)) > 2.5 * Balance.CELL:
			continue
		if d["find_dc"] <= pp and m.los(pc.x, pc.y, dc.x, dc.y):
			_reveal_door(d)

func _reveal_trap(t: Dictionary) -> void:
	t["st"] = "revealed"
	log_msg("罠に気づいた: %s" % t["name"], Color("ff9a7a"))
	Sfx.cue(current, current.map.center_of(Vector2i(int(t["x"]), int(t["y"]))), "trap_found")
	current.queue_redraw()

func _reveal_door(d: Dictionary) -> void:
	d["found"] = true
	log_msg("隠し扉を見つけた", Color("7bd0e0"))
	Sfx.cue(current, current.map.center_of(Vector2i(int(d["x"]), int(d["y"]))), "door_secret")
	_refresh_view()

func _check_traps() -> void:
	var now := Time.get_ticks_msec()
	for h in heroes:
		if h.down:
			continue
		var t: Variant = current.trap_at.get(current.map.cell_of(h.position))
		if t == null or (t["st"] != "hidden" and t["st"] != "revealed") or TrapFx.PERIODIC.has(t["fx"]):
			continue
		if int(t.get("safe_until", 0)) > now:
			continue          # 飛び越えている最中(後ろの仲間も続いて越える)
		_trigger_trap(t, h)
	# 魔物も罠を踏む(マスを移ったときだけ。置かれたマスの罠は踏まない)
	for e in current.enemies.duplicate():
		if e.dead:
			continue
		var c := current.map.cell_of(e.position)
		if c == e.trap_cell:
			continue
		e.trap_cell = c
		var t2: Variant = current.trap_at.get(c)
		if t2 != null and (t2["st"] == "hidden" or t2["st"] == "revealed") and not TrapFx.PERIODIC.has(t2["fx"]):
			_trigger_trap(t2, e)

## 予兆のない罠の、踏んだ瞬間の擬音(予兆のある罠は TrapFx.START_CUE)
const TRAP_CUE := {"pit": "pit", "teleport": "warp", "teleport_one": "warp", "cage": "trap", "alarm": "trap_alarm", "squeak": "squeak",
	"summon": "summon", "rust": "rust", "rotate": "spin", "trip": "trip", "poison": "poison", "slide": "slide", "prone": "slide",
	"blind": "flash", "fear": "wail", "chill": "chill", "restrain": "teeth", "lift": "lift", "bolt": "trap"}

func _cell_seen(p: Vector2) -> bool:
	var c := current.map.cell_of(p)
	return current.map.in_bounds(c.x, c.y) and current.map.visible[current.map.idx(c.x, c.y)] == 1

## 罠が働く。victim は踏んだ者(仲間か魔物)。
## 予兆のある罠(TrapFx.MOVING)は判定を振らず、そのとき範囲にいたかで決まる。予兆のない罠は、いままでどおりセーヴか攻撃で決める
func _trigger_trap(t: Dictionary, victim: Body) -> void:
	t["st"] = "triggered"
	current.queue_redraw()
	var fx := String(t.get("fx", ""))
	var pos := current.map.center_of(Vector2i(int(t["x"]), int(t["y"])))
	var hero: Hero = victim as Hero
	var en: Enemy = victim as Enemy
	var seen := hero != null or _cell_seen(pos)
	if seen:
		var who := hero.ch.name if hero != null else en.display_name
		log_msg("罠！ %s(%s)  %sが踏んだ" % [t["name"], SEVERITY_JP.get(String(t["severity"]), ""), who], Color("ff6a5a") if hero != null else Color("ffb070"))
		log_msg(String(t["effect"]), Color(0.85, 0.7, 0.7))
	if TrapFx.MOVING.has(fx):
		var cue := String(TrapFx.START_CUE.get(fx, ""))
		if cue != "":
			Sfx.cue(current, pos, cue)
		current.add_child(TrapFx.make(current, t, victim))
		return
	Sfx.cue(current, pos, String(TRAP_CUE.get(fx, "trap")))
	var scale := 1.0
	var failed := true          # 仕掛けの動き(落とし穴など)が働くか
	var kind := String(t["kind"])
	if kind == "save":
		var sv: Dictionary = t["save"]
		var ok := false
		if hero != null:
			var abil := String(Talents.SAVE_ABIL_JP.get(String(sv["ability"]), "dex"))
			var bonus := hero.ch.save_bonus(abil)
			var roll := hero.ch.roll_d20()
			ok = roll + bonus >= int(sv["dc"])
			log_msg("%sセーヴ %d%+d=%d / 難易度%d → %s" % [sv["ability"], roll, bonus, roll + bonus, int(sv["dc"]), "成功" if ok else "失敗"],
				Color("9be29b") if ok else Color("ff8a7a"))
		else:
			ok = Dice.d20() + TrapFx.mon_save(en) >= int(sv["dc"])
		if ok:
			scale = 0.5 if t.get("half_on_success", false) else 0.0
			failed = false
	elif kind == "attack":
		var ac: int = (hero.ch.armor_class() - hero.rust) if hero != null else en.ac
		var roll2 := Dice.d20()
		var hit := roll2 != 1 and (roll2 == 20 or roll2 + int(t["attack_bonus"]) >= ac)
		if hero != null:
			log_msg("攻撃 %d+%d / AC%d → %s" % [roll2, int(t["attack_bonus"]), ac, "命中" if hit else "外れ"],
				Color("ff8a7a") if hit else Color("9be29b"))
		if not hit:
			scale = 0.0
			failed = false
	elif kind == "alarm":
		current.alert_radius(victim.position, 14.0)
		if seen:
			log_msg("音が響いた。近くの魔物がこちらへ向かう", Color("ffb070"))
	if t.has("damage") and scale > 0.0:
		var n := Dice.roll(String(t["damage"]))
		if hero != null:
			var dealt := maxf(1.0, n * Balance.TRAP_DMG_SCALE * scale * (1.0 - hero.ch.skill_fx("survival")))
			log_msg("%sダメージ %d" % [t.get("damage_type", ""), int(round(dealt))], Color("ff6a5a"))
			hero.damage(dealt, hero.position + Vector2(0, 1), true)
		else:
			en.take_damage(maxf(1.0, n * Balance.TRAP_DMG_SCALE * scale * Balance.TRAP_MON_MULT), Vector2.DOWN, null)
	if failed and victim.is_alive():
		_trap_effect(t, fx, victim, pos)

## 予兆のない罠の、セーヴに失敗したときの動き
func _trap_effect(t: Dictionary, fx: String, victim: Body, pos: Vector2) -> void:
	var hero: Hero = victim as Hero
	var en: Enemy = victim as Enemy
	match fx:
		"pit":
			if hero != null:
				call_deferred("_fall_down")
			else:
				en.fall_away()
		"teleport":
			if hero != null:
				call_deferred("_trap_teleport")
			else:
				call_deferred("_teleport_one", victim)
		"teleport_one": call_deferred("_teleport_one", victim)
		"cage": _drop_cage(t)
		"summon": _trap_summon(pos)
		"squeak": pass          # 鳴るだけ(alarm で魔物が来る)
		"rust":
			if hero != null and bool(hero.ch.equip_item("armor").get("rustproof", false)):
				log_msg("%sの鎧は、錆の雨を弾いた。" % hero.ch.name, Color("c8d8e8"))
			elif hero != null:
				hero.rust = mini(3, hero.rust + 1)
				log_msg("%sの鎧が錆びた。この潜行の間、守りが %d 下がる" % [hero.ch.name, hero.rust], Color("ffb070"))
			else:
				en.apply_sunder(10.0)
		"rotate":
			if hero != null:
				hero.confuse_t = 5.0
				log_msg("目が回る。しばらく前後左右が逆になる", Color("ffb070"))
			else:
				en.apply_stun(1.5)
		"trip":
			TrapFx.knock_down(victim, 0.6)
			if hero != null:
				_spill_crystals(hero)
		"poison":
			var dps := maxf(0.5, Dice.average(String(t.get("damage", "1d4"))) * Balance.TRAP_DMG_SCALE * 0.12)
			TrapFx.poison(victim, 8.0, dps)
			if hero != null:
				log_msg("%sは毒に冒された" % hero.ch.name, Color("9be06a"))
		"slide":
			var dirs: Array = []
			var c := current.map.cell_of(victim.position)
			for d in FloorMap.DIRS4:
				if not current.map.opaque(c.x + d.x, c.y + d.y):
					dirs.append(Vector2(d))
			var v: Vector2 = dirs[Dice.rng.randi_range(0, dirs.size() - 1)] if not dirs.is_empty() else Vector2.ZERO
			victim.knock = v * 360.0 / maxf(0.5, victim.body_mass() * 0.7)
			TrapFx.knock_down(victim, 0.9)
		"prone": TrapFx.knock_down(victim, 1.2)
		"lift": TrapFx.hold(victim, "lift", 1.0)
		"restrain":
			TrapFx.hold(victim, "teeth", 3.0)
			if hero != null:
				log_msg("挟まれた! 攻撃を連打してこじ開ける", Color("ffb070"))
		"blind":
			if hero != null:
				hero.blind_t = 6.0
				if hero == leader():
					_refresh_view()
			else:
				en.apply_stun(1.5)
		"fear":
			if hero != null:
				hero.fear_t = 4.0
			elif en.kind != "mindless":
				en.state = "flee"
				en.timer = 3.0
		"chill": TrapFx.slow(victim, "chill", 0.55, 8.0)

## 転移の罠: 踏んだ一人(または魔物)だけが、同じ層の別の部屋へ。仲間とははぐれる
func _teleport_one(b: Body) -> void:
	if phase != "dungeon" or current == null or arena != null or not is_instance_valid(b) or not b.is_alive():
		return
	var m := current.map
	var pc := m.cell_of(b.position)
	var at := random_room_pos(current, m.room_at[m.idx(pc.x, pc.y)] if m.in_bounds(pc.x, pc.y) else -1)
	if at.x >= INF:
		return
	b.position = at
	b.knock = Vector2.ZERO
	Sfx.cue(current, at, "warp_out")
	if b is Hero:
		var h := b as Hero
		if h == leader():
			trail = [h.position]
			camera.position = h.position
			camera.reset_smoothing()
			_last_cell = Vector2i(-99, -99)
			_refresh_view()
		if heroes.size() > 1:
			log_msg("%sだけが、どこかへ飛ばされた。仲間とはぐれた(%s で操作する仲間を替えられる)" % [h.ch.name, Controls.hint("switch")], Color("b8a8e8"))
		else:
			log_msg("どこかへ飛ばされた。", Color("b8a8e8"))
	else:
		(b as Enemy).trap_cell = m.cell_of(at)

## 召喚の罠: 罠のそばに、この層の魔物の群れが湧く
func _trap_summon(pos: Vector2) -> void:
	var meta: Dictionary = current.map.data["meta"]
	var party_n := 0
	for h in heroes:
		if not h.down:
			party_n += 1
	var level := int(meta.get("party", {}).get("level", 1))
	var enc := EncounterGen.generate(String(meta.get("theme", "generic")), level, 0, maxi(1, party_n))
	if enc.is_empty():
		return
	var lines: Array = []
	for g in enc["groups"]:
		lines.append(EncounterGen.mon_line(g))
	var made: Array = current.spawn_encounter(lines, String(enc["kind"]), pos, "呼び出された")
	if not made.is_empty() and _cell_seen(pos):
		var l0: Dictionary = lines[0]
		log_msg("%sが呼び出された!" % String(l0.get("world_name", l0.get("name_ja", "魔物"))), Color("ff6a5a"))

## 転びの罠: 袋の燐晶の一部が、床へ散らばる(拾い直せる)
func _spill_crystals(h: Hero) -> void:
	var spilled := 0.0
	for pid in bag_crystal.keys():
		var kg := float(bag_crystal[pid])
		var lose := kg * 0.25
		if lose < 0.005:
			continue
		bag_crystal[pid] = kg - lose
		var pieces := clampi(int(lose / 0.05) + 1, 1, 4)
		for i in pieces:
			current.ground.add_crystal(h.position, String(pid), lose / pieces, Vector2.from_angle(Dice.rng.randf() * TAU) * Dice.rng.randf_range(280.0, 480.0))
		spilled += lose
	if spilled > 0.0:
		Sfx.cue(current, h.position + Vector2(0, 12), "spill")
		log_msg("袋から燐晶がこぼれた(%.2fkg)。拾い直せる" % spilled, Color("ffb070"))

## 遺体の毒針(遺体を調べたとき、ときどき)。予兆が無いので【耐久力】セーヴ
func _corpse_needle(pos: Vector2) -> void:
	var h := leader()
	var dc := 10 + current.layer_no
	var roll := h.ch.roll_d20()
	var bonus := h.ch.save_bonus("con")
	Sfx.cue(current, pos, "needle")
	var ok := roll + bonus >= dc
	log_msg("遺体に毒針が仕込んであった! 耐久力セーヴ %d%+d / 難易度%d → %s" % [roll, bonus, dc, "成功" if ok else "失敗"], Color("9be29b") if ok else Color("ff8a7a"))
	if not ok:
		h.poison(10.0, 0.8 + current.layer_no * 0.4)

# ---------- 操作 ----------

func _near(cell: Vector2i, cells: float) -> bool:
	return leader().position.distance_to(current.map.center_of(cell)) <= cells * Balance.CELL

func _nearest_locked_door() -> Variant:
	for d in current.map.doors_near(leader().position, 46.0):
		if d["type"] == "locked" and not d["unlocked"]:
			return d
	return null

func _nearest_trap_to_disarm() -> Variant:
	for t in current.traps:
		if t["st"] != "revealed":
			continue
		if leader().position.distance_to(current.map.center_of(Vector2i(int(t["x"]), int(t["y"])))) <= 44.0:
			return t
	return null

const CORPSE_REACH := 30.0     # 遺体を調べられる距離(画素)

func _update_hint() -> void:
	var h := ""
	if _nearest_locked_door() != null:
		h = "E: 解錠を試みる"
	elif _nearest_trap_to_disarm() != null:
		h = "%s: 罠をどうする?" % Controls.hint("interact")
	elif arena == null and not current.ground.corpse_near(leader().position, CORPSE_REACH).is_empty():
		h = "%s: 遺体を調べる" % Controls.hint("interact")
	elif arena != null:
		h = "E: 闘技場を出る" if _near(current.up_cell, 1.4) else ""
	elif (_near(current.down_cell, 1.4) or _near(current.up_cell, 1.4)) and dtime != null and dtime.stairs_sealed():
		h = "階段は吐息に塞がれている(夜明けまで)"
	elif _near(current.down_cell, 1.4):
		h = "E: 下へ降りる" if current.floor_no < Balance.MAX_FLOOR else "この先は未踏(まだ道がない)"
	elif _near(current.up_cell, 1.4):
		h = "E: 街へ戻る" if current.floor_no == 1 else "E: 上へ戻る"
	hud.hint = h

func interact() -> void:
	if phase != "dungeon" or leader().down:
		return
	var door: Variant = _nearest_locked_door()
	if door != null:
		_pick_lock(door)
		return
	var trap: Variant = _nearest_trap_to_disarm()
	if trap != null:
		open_trap_menu(trap)
		return
	var body := current.ground.corpse_near(leader().position, CORPSE_REACH)
	if not body.is_empty():
		if not bool(body["searched"]) and Dice.rng.randf() < Balance.NEEDLE_CHANCE:
			_corpse_needle(body["pos"])
		current.ground.search_corpse(body)
		current.queue_redraw()
		_update_hint()
		return
	if arena != null:
		if _near(current.up_cell, 1.4):
			exit_arena()
		return
	if (_near(current.down_cell, 1.4) or _near(current.up_cell, 1.4)) and dtime != null and dtime.stairs_sealed():
		Sfx.cue(current, leader().position, "sealed")
		log_msg("階段は、重い吐息に塞がれている。夜明けを待つしかない。", Color("c9b6ff"))
		return
	if _near(current.down_cell, 1.4):
		if current.floor_no >= Balance.MAX_FLOOR:
			log_msg("この先は未踏。まだ道がない。", Color(0.7, 0.7, 0.8))
		else:
			enter_floor(current.floor_no + 1, "up")
		return
	if _near(current.up_cell, 1.4):
		if current.floor_no == 1:
			# 物理処理の最中に、仲間や層を片付けない。次の空き時間に街へ移る
			phase = "transition"
			hud.hint = ""
			call_deferred("return_to_surface")
		else:
			enter_floor(current.floor_no - 1, "down")

## 落ちているものを拾った。燐晶は袋へ(税は持ち帰るときに)、自生物や遺品は持ち物へ(税なし)
func _on_ground_picked(e: Dictionary, h: Hero) -> void:
	if String(e["kind"]) == "crystal":
		var pid := String(e["purity"])
		var kg := float(e["kg"]) * (1.0 + party_skill_fx("sleight"))     # 盗賊の「手際」は、拾える燐晶を増やす
		bag_crystal[pid] = float(bag_crystal.get(pid, 0.0)) + kg
		var ccol: Color = Crystal.COLORS.get(pid, Color.WHITE)
		var ctex := ItemIcons.texture(Crystal.icon_id(pid, kg))
		h.game_floor.add_child(PickupPop.make(ctex, "%s %.2fkg" % [Crystal.jp(pid), kg], ccol, e["pos"], h))
		if Time.get_ticks_msec() - _crystal_cue_ms > 400:      # まとめて拾ったときは、擬音を重ねない
			_crystal_cue_ms = Time.get_ticks_msec()
			Sfx.cue(h.game_floor, h.position, "crystal_big" if kg >= 0.3 else "crystal")
		hud.add_pickup("crystal_" + pid, ctex, Crystal.jp(pid), ccol, kg, "kg")
		return
	var id := String(e["id"])
	var qty := int(e.get("qty", 1))
	var had := gs.count(id)
	gs.add_item(id, qty)
	for q in gs.quests:      # 坑口館の依頼の数が揃った
		if String(q["id"]) == id and had < int(q["n"]) and gs.count(id) >= int(q["n"]):
			log_msg("依頼の品が揃った: %s %d/%d(%s)" % [ItemDB.item_name(id), int(q["n"]), int(q["n"]), q["client"]], Color("f1d98a"))
			h.game_floor.spawn_text(h.position + Vector2(0, -34), "依頼の品が揃った", Color("f1d98a"))
	var it := ItemDB.get_item(id)
	var rare := int(it.get("price", 0)) >= 40 or String(it.get("kind", "")) in ["weapon", "armor", "acc"]
	var icol := Color("d8f0d8") if not rare else Color("ffe9a8")
	var itex := ItemIcons.texture(id)
	h.game_floor.add_child(PickupPop.make(itex, "%s%s" % [ItemDB.item_name(id), "" if qty == 1 else " ×%d" % qty], icol, e["pos"], h))
	hud.add_pickup("item_" + id, itex, ItemDB.item_name(id), icol, float(qty), "")
	if rare:
		log_msg("拾った: %s" % ItemDB.item_name(id), Color("ffe9a8"))

func _clear_bag() -> void:
	bag_silver = 0
	bag_crystal = {}

## 袋の中身の見積もり(銀貨)。税を引く前
func bag_value() -> int:
	return bag_silver + Crystal.value_of(bag_crystal)

func _pick_lock(d: Dictionary) -> void:
	if _pick_cd > 0.0:
		return
	_pick_cd = 0.6
	var who := party_best_char("lock")
	var roll := who.roll_d20()
	var bonus := who.lock_bonus()
	var ok := roll == 20 or roll + bonus >= int(d["lock_dc"])
	log_msg("解錠 %d%+d / 難易度%d → %s" % [roll, bonus, int(d["lock_dc"]), "成功" if ok else "失敗"], Color("9be29b") if ok else Color("ff8a7a"))
	current.add_child(UnlockFx.make(current.map.center_of(Vector2i(int(d["x"]), int(d["y"]))), ok))
	if ok:
		d["unlocked"] = true
		current.map_changed()

func _disarm(t: Dictionary) -> void:
	var who := party_best_char("lock")
	var roll := who.roll_d20()
	var bonus := who.lock_bonus()
	var dc := int(t["disarm_dc"])
	if roll == 20 or roll + bonus >= dc:
		t["st"] = "disarmed"
		log_msg("罠を解除した: %s" % t["name"], Color("9be29b"))
		Sfx.cue(current, current.map.center_of(Vector2i(int(t["x"]), int(t["y"]))), "disarm")
		current.queue_redraw()
	elif roll + bonus <= dc - 5:
		log_msg("解除に失敗した!", Color("ff8a7a"))
		Sfx.cue(current, current.map.center_of(Vector2i(int(t["x"]), int(t["y"]))), "disarm_fail")
		if not TrapFx.PERIODIC.has(String(t.get("fx", ""))):
			_trigger_trap(t, leader())
	else:
		log_msg("解除に失敗した(もう一度試せる)", Color("ffb070"))

func search() -> void:
	if phase != "dungeon" or leader().down or _search_cd > 0.0:
		return
	_search_cd = 0.6
	var m := current.map
	var lp := leader().position
	var pc := m.cell_of(lp)
	var who := party_best_char("search")
	var bonus := who.search_bonus()
	var found := false
	for t in current.traps:
		if t["st"] != "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if lp.distance_to(m.center_of(tc)) <= 4.5 * Balance.CELL and m.los(pc.x, pc.y, tc.x, tc.y):
			if who.roll_d20() + bonus >= int(t["detect_dc"]):
				_reveal_trap(t)
				found = true
	for d in m.doors:
		if d["type"] != "secret" or d["found"]:
			continue
		var dc := Vector2i(d["x"], d["y"])
		if lp.distance_to(m.center_of(dc)) <= 4.5 * Balance.CELL and m.los(pc.x, pc.y, dc.x, dc.y):
			if who.roll_d20() + bonus >= int(d["find_dc"]):
				_reveal_door(d)
				found = true
	if not found:
		log_msg("探ってみたが、何も見つからない", Color(0.7, 0.75, 0.8))
		Sfx.cue(current, lp, "search")

func quick_heal() -> void:
	if phase != "dungeon" or arena != null:
		return
	var worst: Character = null
	var wr := 0.9
	for h in heroes:
		if h.down:
			continue
		var r: float = h.hp_frac()
		if r < wr:
			wr = r
			worst = h.ch
	if worst == null:
		return
	for id in ["potion", "hi_potion"]:
		if gs.count(id) > 0:
			var r2 := gs.use_item(id, worst)
			if r2 != "":
				log_msg(r2, Color("9be29b"))
				for h in heroes:
					if h.ch == worst:
						Sfx.cue(current, h.position, "drink")
				return

# ---------- 持ち物 ----------

func open_inventory() -> void:
	if inventory != null:
		return
	if arena != null:
		log_msg("闘技場では、持ち物を開けない", Color(0.7, 0.75, 0.8))
		return
	_prev_phase = phase
	if phase == "dungeon":
		phase = "menu"
		hud.hint = ""
		_freeze_world(true)
	inventory = InventoryScreen.new()
	inventory.closed.connect(close_inventory)
	ui_layer.add_child(inventory)
	inventory.open(gs, Callable(self, "use_special"), Callable(self, "_rest_from_menu") if phase == "menu" and dtime != null else Callable(), Callable(self, "sync_hero_order"))
	if phase == "menu" and dtime != null:
		inventory.set_save(Callable(self, "save_dive"))
	inventory.set_food(Callable(self, "cook_dish") if phase == "menu" and dtime != null else Callable(), Callable(self, "eat_dish"))

## 隊列(gs.party の順)を入れ替えたら、迷宮の仲間の並びも合わせる。操作している仲間は、そのまま
func sync_hero_order() -> void:
	if heroes.is_empty():
		return
	var cur := leader()
	heroes.sort_custom(func(a, b): return gs.party.find(a.ch) < gs.party.find(b.ch))
	active = maxi(0, heroes.find(cur))
	trail = [leader().position] if leader() != null else []

## 迷宮を止める・動かす(持ち物や罠の選択を開いている間)
func _freeze_world(on: bool) -> void:
	var m := Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	for h in heroes:
		h.process_mode = m
	if current != null:
		current.process_mode = m
		for e in current.enemies:
			e.process_mode = m

# ---------- 罠の前で選ぶ(解除する / わざと発動させる / 飛び越える) ----------

const JUMP_DC := {"setback": 10, "dangerous": 13, "deadly": 16}

func jump_dc(t: Dictionary) -> int:
	return int(JUMP_DC.get(String(t.get("severity", "")), 12))

## 飛び越える判定は、操作している仲間の〈軽業〉か〈運動〉の高いほう
func jump_bonus() -> int:
	var c: Character = leader().ch
	return maxi(c.skill_bonus("acrobatics"), c.skill_bonus("athletics"))

func open_trap_menu(t: Dictionary) -> void:
	if trap_menu != null or phase != "dungeon":
		return
	_menu_trap = t
	phase = "menu"
	hud.hint = ""
	_freeze_world(true)
	var who := party_best_char("lock")
	var fx := String(t.get("fx", ""))
	var fx_note := {"pit": "踏むと床が抜けて、下の階へ落ちる。", "teleport": "踏むと、同じ層のどこかへ引き込まれる。", "cage": "踏むと格子が落ち、部屋の出口が閉ざされる。",
		"teleport_one": "踏んだ一人だけが、同じ層のどこかへ飛ばされる。"}
	var note := "%s(%s)。%s%s" % [String(t["trigger"]) if t.has("trigger") else "", SEVERITY_JP.get(String(t["severity"]), ""), String(fx_note.get(fx, "")), String(t.get("effect", ""))]
	var opts: Array = [["disarm", "解除する", "%sの盗賊道具 %+d / 難易度 %d。大きく外すと発動する。" % [who.name, who.lock_bonus(), int(t["disarm_dc"])]]]
	if TrapFx.MOVING.has(fx):
		opts.append(["spring", "わざと発動させる", "石を投げて発動させる。離れていれば無事。巻き込まれる範囲に仲間や魔物がいれば当たる。音で魔物が気づく。"])
	elif not TrapFx.PERIODIC.has(fx):
		opts.append(["spring", "わざと発動させる", "石を投げて空撃ちさせる。確実だが、音で近くの魔物が気づく。"])
	opts.append(["jump", "飛び越える" if not TrapFx.PERIODIC.has(fx) else "間合いを測って抜ける", "%sの〈軽業〉か〈運動〉 %+d / 難易度 %d。罠は残る。失敗すると踏む。" % [leader().ch.name, jump_bonus(), jump_dc(t)]])
	trap_menu = TrapMenu.new()
	trap_menu.setup("罠: %s" % t["name"], note, opts)
	trap_menu.chosen.connect(_on_trap_choice)
	ui_layer.add_child(trap_menu)

func _on_trap_choice(a: String) -> void:
	if trap_menu != null:
		trap_menu.queue_free()
		trap_menu = null
	phase = "dungeon"
	_freeze_world(false)
	_menu_cd = 0.3
	var t := _menu_trap
	_menu_trap = {}
	if t.is_empty() or t["st"] != "revealed":
		return
	match a:
		"disarm": _disarm(t)
		"spring": spring_trap(t)
		"jump": jump_trap(t)

## 石を投げて、わざと発動させる。だれも傷つかないが、音が立つ
func spring_trap(t: Dictionary) -> void:
	t["st"] = "triggered"
	var pos := current.map.center_of(Vector2i(int(t["x"]), int(t["y"])))
	var fx := String(t.get("fx", ""))
	if TrapFx.MOVING.has(fx):
		# 動きのある罠は、本当に動く(離れて投げれば無事。魔物を巻き込める)
		log_msg("石を投げた。%sが動き出した" % t["name"], Color("e8dcb0"))
		var cue := String(TrapFx.START_CUE.get(fx, ""))
		if cue != "":
			Sfx.cue(current, pos, cue)
		current.add_child(TrapFx.make(current, t, null))
		current.alert_radius(pos, 8.0)
		current.queue_redraw()
		return
	if fx == "summon":
		Sfx.cue(current, pos, "summon")
		log_msg("石を投げた。%sが働いた" % t["name"], Color("e8dcb0"))
		_trap_summon(pos)
		current.queue_redraw()
		return
	Sfx.cue(current, pos, "trap_alarm" if String(t["kind"]) == "alarm" else "trap")
	log_msg("石を投げた。%sが空を切った" % t["name"], Color("e8dcb0"))
	var loud := 14.0 if String(t["kind"]) == "alarm" else 8.0
	current.alert_radius(pos, loud)
	log_msg("物音が響いた。近くの魔物が気づいたかもしれない" if loud < 10.0 else "音が響いた。近くの魔物がこちらへ向かう", Color("ffb070"))
	current.queue_redraw()

## 飛び越える。成功すると、しばらくの間、一行はこの罠を踏まずに越えられる(罠は残る)
func jump_trap(t: Dictionary) -> void:
	var roll := leader().ch.roll_d20()
	var b := jump_bonus()
	var ok := roll == 20 or (roll != 1 and roll + b >= jump_dc(t))
	log_msg("飛び越える %d%+d / 難易度%d → %s" % [roll, b, jump_dc(t), "成功" if ok else "失敗"], Color("9be29b") if ok else Color("ff8a7a"))
	if ok:
		t["safe_until"] = Time.get_ticks_msec() + 6000
		current.spawn_text(leader().position + Vector2(0, -26), "ひらり", Color("9be29b"))
	elif not TrapFx.PERIODIC.has(String(t.get("fx", ""))):
		_trigger_trap(t, leader())      # 振り子や噴き口は、外せばそのまま刃や炎が来る

## 落とし穴: 一行ごと下の階へ落ちる(どこかの部屋)。いちばん下の階では、浅い穴で済む
func _fall_down() -> void:
	if phase != "dungeon" or current == null or arena != null:
		return
	if current.floor_no >= Balance.MAX_FLOOR:
		log_msg("穴は浅かった。這い上がった。", Color(0.8, 0.8, 0.85))
		return
	log_msg("床が抜けた! 一行は下の階へ落ちた", Color("ff9a7a"))
	enter_floor(current.floor_no + 1, "up")
	var at := random_room_pos(current, -1)
	if at.x < INF:
		place_party(at)
	for h in heroes:
		if not h.down:
			h.damage(maxf(1.0, Dice.roll("1d6") * Balance.TRAP_DMG_SCALE), h.position + Vector2(0, 1), true)

## 水鏡など: 同じ層の別の部屋へ
func _trap_teleport() -> void:
	if phase != "dungeon" or current == null or arena != null:
		return
	var m := current.map
	var pc := m.cell_of(leader().position)
	var at := random_room_pos(current, m.room_at[m.idx(pc.x, pc.y)])
	if at.x >= INF:
		return
	place_party(at)
	log_msg("引き込まれ、見知らぬ部屋に出た。", Color("b8a8e8"))

## 落とし格子: 罠のある部屋の扉が、すべて鍵のかかった格子になる。物音で魔物が来る
func _drop_cage(t: Dictionary) -> void:
	var rid := int(t.get("roomId", -1))
	var n := 0
	for d in current.map.doors:
		if int(d.get("room", -1)) != rid or rid < 0 or (d["type"] == "secret" and not d["found"]):
			continue
		d["open"] = false
		d["type"] = "locked"
		d["unlocked"] = false
		d["lock_dc"] = maxi(int(d["lock_dc"]), int(t.get("disarm_dc", 12)))
		n += 1
	var pos := current.map.center_of(Vector2i(int(t["x"]), int(t["y"])))
	current.alert_radius(pos, 14.0)
	if n > 0:
		log_msg("格子が落ちた! 部屋の出口が閉ざされた(扉の前で %s: 解錠)" % Controls.hint("interact"), Color("ff9a7a"))
	else:
		log_msg("格子が落ちる轟音が響いた", Color("ffb070"))
	current.map_changed()
	_refresh_view()

## 層の中の、ほかの部屋(避ける部屋 avoid と、魔物のいる部屋を除く)の床を一つ。無ければ (INF, INF)
func random_room_pos(fl: FloorInstance, avoid: int) -> Vector2:
	var m := fl.map
	var rooms: Array = []
	for r in m.rooms:
		var rid := int(r["id"])
		if rid == avoid or not m.room_cells.has(rid) or (m.room_cells[rid] as Array).is_empty():
			continue
		var occupied := false
		for e in fl.enemies:
			var ec := m.cell_of(e.position)
			if not e.dead and m.in_bounds(ec.x, ec.y) and m.room_at[m.idx(ec.x, ec.y)] == rid:
				occupied = true
				break
		if not occupied:
			rooms.append(rid)
	if rooms.is_empty():
		return Vector2(INF, INF)
	var cells: Array = m.room_cells[rooms[Dice.rng.randi_range(0, rooms.size() - 1)]]
	var c: int = cells[cells.size() / 2]
	return m.center_of(Vector2i(c % m.w, c / m.w))

func _rest_from_menu() -> void:
	pending_rest = true
	close_inventory()

func close_inventory() -> void:
	if inventory == null:
		return
	inventory.queue_free()
	inventory = null
	_menu_cd = 0.3
	for fx in _menu_fx:
		var h: Hero = fx[1]
		if current != null and is_instance_valid(h):
			var off: Vector2 = fx[2] if fx.size() > 2 else Vector2.ZERO
			if String(fx[0]).begins_with("@"):
				current.spawn_text(h.position + Vector2(0, -36) + off, String(fx[0]).substr(1), Color("ffe08a"))
			else:
				Sfx.cue(current, h.position + off, String(fx[0]))
	_menu_fx.clear()
	if phase == "town" and screen is TownScreen:
		(screen as TownScreen).refresh_top()
		var won := Trophies.line(Trophies.evaluate(gs))      # 街で持ち物を開いている間に取った実績(くさったものを食べた、など)
		if won != "":
			gs.save()
			(screen as TownScreen)._say(won, UIKit.GOLD)
		screen.call_deferred("focus_default")   # 持ち物を閉じたら、コントローラーの焦点を街へ戻す
	if _prev_phase == "dungeon":
		phase = "dungeon"
		_freeze_world(false)
		for h in heroes:
			if h.down and h.ch.hp > 0.0:
				h.revive(h.ch.hp / float(h.ch.max_hp()))
		if pending_return:
			pending_return = false
			return_to_surface()
		elif pending_rest:
			pending_rest = false
			start_rest()
	elif screen is TownScreen:
		(screen as TownScreen).refresh_top()
		(screen as TownScreen)._refresh_all()

# ---------- 料理(Cooking) ----------

func _hero_of(ch: Character) -> Hero:
	for h in heroes:
		if h.ch == ch:
			return h
	return null

## 野営で料理する(持ち物の画面から)。{ok, msg}。燃料で火を熾し、20分かかる
func cook_dish(rid: String) -> Dictionary:
	if dtime == null or current == null or arena != null:
		return {"ok": false, "msg": "ここでは料理できない"}
	var r := Cooking.recipe(rid)
	if bool(r.get("home", false)):
		return {"ok": false, "msg": "これは自宅の台所でしか作れない"}
	var why := dtime.chased_reason()
	if why != "":
		return {"ok": false, "msg": why.replace("休めない", "料理できない")}
	if not Cooking.can_make(gs, r):
		return {"ok": false, "msg": "材料が足りない"}
	var lit := ""
	if dtime.minutes >= fire_until:
		var fuel := ""
		for id in Cooking.tag_ids("fuel"):
			if gs.count(String(id)) > 0 and not (r["in"] as Dictionary).has(String(id)):
				fuel = String(id)
				break
		if fuel == "":
			return {"ok": false, "msg": "燃料が無い(焚き木束・焼け石・白蝋)"}
		gs.remove_item(fuel)
		fire_until = dtime.minutes + Cooking.FIRE_MINUTES
		lit = "%sで火を熾した。" % ItemDB.item_name(fuel)
	var res := Cooking.cook(gs, rid)
	if not bool(res.get("ok", false)):
		return res
	dtime.minutes += Cooking.CAMP_MINUTES
	gs.set_clock(gs.day * 1440.0 + dtime.minutes)
	var lead := leader()
	var kind := String(res.get("kind", ""))
	_menu_fx.append(["simmer" if kind == "simmer" or kind == "smoke" else "sizzle", lead])
	match int(res["q"]):
		Cooking.Q_GREAT: _menu_fx.append(["@上出来!", lead])
		Cooking.Q_BURNT: _menu_fx.append(["burnt", lead])
	log_msg(lit + String(res["msg"]), Color("ffe08a") if int(res["q"]) == Cooking.Q_GREAT else Color("e8dcb0"))
	res["msg"] = lit + String(res["msg"])
	_check_trophies()
	return res

## 料理を食べる(街でも迷宮でも)。i は gs.food の番号
func eat_dish(i: int, ch: Character) -> Dictionary:
	var res := Cooking.eat(gs, i, ch)
	if not bool(res.get("ok", false)):
		return res
	var h := _hero_of(ch) if phase == "menu" else null
	if h != null:
		_menu_fx.append(["munch", h])
		if bool(res.get("rotten", false)):
			h.poison(30.0, ch.max_hp() * 0.008)
			_menu_fx.append(["bellyache", h])
		elif bool(res.get("poison", false)):
			h.poison(20.0, ch.max_hp() * 0.02)
			_menu_fx.append(["poison", h])
		log_msg(String(res["msg"]), Color("e8dcb0"))
	elif bool(res.get("rotten", false)) or bool(res.get("poison", false)):
		ch.hp = maxf(1.0, ch.hp - ch.max_hp() * 0.1)     # 街では、寝込んで少し弱る
	_check_trophies()
	return res

## 迷宮の中でだけ効く道具
func use_special(id: String, _c: Character) -> bool:
	if phase != "menu":
		return false
	match String(ItemDB.ITEMS[id]["use"]):
		"light":
			light_t = maxf(light_t, float(ItemDB.ITEMS[id].get("t", 180.0)))
			_refresh_view()
			_menu_fx.append(["ignite", leader()])
			return true
		"buff":
			var it: Dictionary = ItemDB.ITEMS[id]
			for h in heroes:
				if h.ch == _c:
					var v := float(it["v"])
					if String(it["buff"]) == "regen":
						v = h.ch.max_hp() * v / float(it["t"])      # 時間をかけて、最大HPの v 割
					h.buffs[String(it["buff"])] = {"t": float(it["t"]), "v": v}
					_menu_fx.append(["drink", h])
					return true
			return false
		"return":
			pending_return = true
			_menu_fx.append(["recall", leader()])
			return true
		"cure":
			var hc := _hero_of(_c)
			if hc == null or hc.poison_t <= 0.0:
				return false
			hc.poison_t = 0.0
			_menu_fx.append(["drink", hc])
			return true
		"sleep_throw", "shriek":
			var it2: Dictionary = ItemDB.ITEMS[id]
			var lead := leader()
			var r := 4.0 if String(it2["use"]) == "sleep_throw" else 5.0
			var n := 0
			for e in current.enemies:
				if not e.dead and e.position.distance_to(lead.position) <= r * Balance.CELL:
					e.apply_stun(float(it2["v"]))
					n += 1
			_menu_fx.append(["glass", lead, Vector2(0, 22)])
			if String(it2["use"]) == "shriek":
				current.alert_radius(lead.position, 14.0)
				_menu_fx.append(["trap_alarm", lead])
			else:
				_menu_fx.append(["gas", lead])
			log_msg("%sを割った。%d体の魔物が動きを止めた。" % [it2["name"], n], Color("e8dcb0"))
			return true
	return false

# ---------- 出来事 ----------

func _on_enemy_killed(en: Enemy) -> void:
	if arena != null:
		return          # 闘技場では、経験点も落とし物もない
	Journal.kill(gs, String(en.mon.get("index", "")))
	en.game_floor.ground.drop_from_enemy(en)
	# 倒れる音。まとめて倒したときは重ねない(0.25秒に一つ)
	var now := Time.get_ticks_msec()
	if now - _kill_cue_ms > 250:
		_kill_cue_ms = now
		Sfx.cue(en.game_floor, en.position + Vector2(0, 14), "kill")
	var alive: Array = []
	for h in heroes:
		if not h.down:
			alive.append(h)
	if alive.is_empty():
		return
	var share := gs.party_xp_share(en.xp, alive.size())
	for h in alive:
		var before: int = h.ch.pending().size()
		if h.ch.gain_xp(int(round(share * (1.0 + h.ch.skill_fx("history"))))) > 0:
			log_msg("%sのレベルが上がった! Lv%d" % [h.ch.name, h.ch.level], Color("9ad8ff"))
			if h.ch.pending().size() > before:
				log_msg("%sは、能力値上昇か特技を選べる(%s →「技能・特技」)" % [h.ch.name, Controls.hint("inventory")], Color("ffe9a8"))
			h.game_floor.spawn_text(h.position + Vector2(0, -28), "LEVEL UP", Color("9ad8ff"))
			Sfx.cue(h.game_floor, h.position + Vector2(0, 16), "levelup")
	_check_trophies()

## 魔物が初めて見えた(冒険日記帳)。初めて見た種類なら、日記帳に書き足す
func _on_enemy_seen(en: Enemy) -> void:
	if arena != null or current == null:
		return
	if Journal.see(gs, String(en.mon.get("index", "")), current.layer_no):
		log_msg("冒険日記帳に、%sを書き足した" % en.display_name, Color(0.8, 0.85, 0.9))
		var now := Time.get_ticks_msec()
		if now - _jot_cue_ms > 1500 and leader() != null:
			_jot_cue_ms = now
			Sfx.cue(current, leader().position + Vector2(0, -10), "jot")
		_check_trophies()

func _on_floor_stat(key: String) -> void:
	if arena != null:
		return
	Journal.bump(gs, key)
	_check_trophies()

## 実績を調べ、新しく取ったものを知らせる(迷宮では擬音と頭上の文字とログ。持ち物の画面の中なら閉じたら出す)
func _check_trophies() -> void:
	if arena != null or phase == "town":
		return     # 街では、持ち物を閉じたときや報告でまとめて知らせる
	var won := Trophies.evaluate(gs)
	if won.is_empty():
		return
	for id in won:
		log_msg("パンパカパーン! 実績「%s」を取った(%s)" % [Trophies.name_of(String(id)), Trophies.desc_of(String(id))], Color("ffe08a"))
	var lead := leader()
	if lead == null or current == null:
		return
	var label := "実績「%s」" % Trophies.name_of(String(won[0]))
	if phase == "menu":
		_menu_fx.append(["trophy", lead, Vector2(0, -12)])
		_menu_fx.append(["@" + label, lead, Vector2(0, -22)])
	else:
		Sfx.cue(current, lead.position + Vector2(0, -12), "trophy")
		current.spawn_text(lead.position + Vector2(0, -58), label, Color("ffe08a"))

func return_to_surface() -> void:
	_trace("return_to_surface 第%d層から" % (current.floor_no if current != null else 0))
	var gross := bag_value()
	var tax := int(round(gross * Balance.TAX_RATE))
	Journal.best(gs, "best_return", gross)
	var net := gross - tax
	gs.bank_silver += net
	var detail: Array = []
	for pid in Crystal.ORDER + ["unk"]:
		if bag_crystal.has(pid) and float(bag_crystal[pid]) > 0.0:
			detail.append("%s %.2fkg × %d銀" % [Crystal.jp(pid), float(bag_crystal[pid]), Crystal.price(pid)])
	_clear_bag()
	DiveSave.clear()
	gs.day += 1
	gs.set_clock(gs.town_clock())
	var lines: Array = []
	if not detail.is_empty():
		lines.append("査定:  " + "   ".join(detail))
	lines += [
		"持ち帰った燐晶(査定前の見積もり)  %d銀貨" % gross,
		"燐晶税(3割)  −%d銀貨" % tax,
		"預け金に加えた額  +%d銀貨   →   預け金 %d銀貨" % [net, gs.bank_silver],
		"茸や素材など、迷宮の自生物は、持ち物のまま(燐晶ではないので、税はかからない)",
	]
	var downed: Array = []
	for c in gs.party:
		if c.hp <= 0.0:
			downed.append(c.name)
	if not downed.is_empty():
		lines.append("倒れた仲間: %s(神殿で蘇らせよう)" % "、".join(downed))
	var rotten := 0
	for f in gs.food:
		if Cooking.rotten(f, gs.clock):
			rotten += int(f["n"])
	var pots := Home.ready_pots(gs)
	if not pots.is_empty():
		lines.append("自宅の実験室で、%sが仕上がっている" % "、".join(pots))
	var anvil := Smithing.anvil_ready(gs)
	if anvil != "":
		lines.append("自宅の鍛冶場で、%sが冷めて仕上がっている" % anvil)
	if rotten > 0:
		lines.append("持ち帰った料理のうち%d皿が、くさっていた(持ち物の「料理」で捨てられる)" % rotten)
	# 〈芸能〉: 宿で芸を見せて稼ぐ(倒れていない仲間のうち、いちばん高い人)
	var perf := 0.0
	var performer := ""
	for c in gs.party:
		if c.hp > 0.0 and c.skill_fx("performance") > perf:
			perf = c.skill_fx("performance")
			performer = c.name
	if perf > 0.0:
		gs.bank_silver += int(perf)
		lines.append("%sが宿で芸を見せた  +%d銀貨(〈芸能〉)" % [performer, int(perf)])
	go_town(lines)
