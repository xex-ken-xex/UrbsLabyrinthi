extends Node2D
## 全体の進行。タイトル → キャラ作成 → 街 → 迷宮 → 街、の巡り。
## 迷宮の中身は Urbs Labyrinthi が書き出した JSON(data/floors/)が決めている。ここは遊びの規則だけを持つ。

const SEVERITY_JP := {"setback": "軽度", "dangerous": "危険", "deadly": "致命的"}

var gs := GameState.new()
var heroes: Array = []             # Hero(迷宮の中の体)
var active := 0                    # 操作している仲間の番号
var camera: Camera2D
var hud: Hud
var ui_layer: CanvasLayer
var hud_layer: CanvasLayer
var screen: Control                # 開いている画面(タイトル、作成、街)
var inventory: InventoryScreen
var current: FloorInstance
var floors := {}                   # 層の番号 → FloorInstance(この日の控え)
var bag_silver := 0
var phase := "title"               # title / make / town / dungeon / menu / overlay
var overlay_kind := ""
var trail: Array = []
var light_t := 0.0                 # 燐晶の灯油の残り秒
var pending_return := false
var _last_cell := Vector2i(-99, -99)
var _detect_t := 0.0
var _search_cd := 0.0
var _pick_cd := 0.0
var _prev_phase := ""
var _menu_cd := 0.0
var scripted_input := false        # テスト用: true の間は、キー入力を読まない

func _ready() -> void:
	Dice.rng.randomize()
	_setup_input()
	camera = Camera2D.new()
	camera.zoom = Vector2(1.7, 1.7)
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
	show_title()
	if OS.get_cmdline_user_args().has("--autotest-town"):
		call_deferred("_autotest_town")

## 書き出したビルドで「迷宮 → 街」を再現するための確認用(--autotest-town を付けて起動する)
func _autotest_town() -> void:
	await get_tree().create_timer(0.5).timeout
	show_make()
	await get_tree().create_timer(0.3).timeout
	screen._on_start()
	await get_tree().create_timer(0.3).timeout
	_on_dive()
	await get_tree().create_timer(0.5).timeout
	leader().position = current.map.center_of(current.up_cell)
	await get_tree().create_timer(0.5).timeout
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
	await get_tree().create_timer(0.5).timeout
	print("AUTOTEST done")
	get_tree().quit()

func _setup_input() -> void:
	var defs := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"guard": [KEY_SPACE], "dodge": [KEY_SHIFT],
		"skill1": [KEY_1], "skill2": [KEY_2], "skill3": [KEY_3], "skill4": [KEY_4],
		"switch": [KEY_Q], "interact": [KEY_E], "search": [KEY_F], "quick_heal": [KEY_R],
		"inventory": [KEY_TAB], "confirm": [KEY_ENTER, KEY_KP_ENTER], "credits": [KEY_F1],
	}
	for a in defs:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in defs[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

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
	_set_screen(t)

func show_make() -> void:
	phase = "make"
	var m := CharaMake.new()
	m.cancelled.connect(show_title)
	m.finished.connect(_on_party_made)
	_set_screen(m)

func _on_party_made(chars: Array) -> void:
	gs.new_game(chars)
	go_town(["「ようこそ、ヴェルガ・ノクスへ。許可証は灰等級から。」", "預け金 %d銀貨。装備と薬を整えてから、迷宮へ。" % gs.bank_silver])

func _on_continue() -> void:
	if gs.load_save():
		go_town(["記録を読み込んだ。第%d日。" % (gs.day + 1)])

func go_town(report: Array) -> void:
	phase = "town"
	_clear_dungeon()
	# 全員が倒れていたら、灯手隊が担ぎ出して最低限の手当てをしてくれる
	var any_alive := false
	for c in gs.party:
		if c.hp > 0.0:
			any_alive = true
	if not any_alive:
		for c in gs.party:
			c.hp = 1.0
		report.append("全員が倒れていたため、灯手隊が担ぎ出してくれた。")
	gs.save()
	var t := TownScreen.new()
	t.setup(gs)
	t.dive.connect(_on_dive)
	t.open_inventory.connect(open_inventory)
	t.to_title.connect(show_title)
	_set_screen(t)
	t.arrive(report)

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
	for f in floors.values():
		f.queue_free()
	floors.clear()
	for h in heroes:
		h.queue_free()
	heroes.clear()
	if current != null and current.get_parent() == self:
		remove_child(current)
	current = null
	hud.overlay = []
	hud.hint = ""

# ---------- 日と層 ----------

func floor_path(n: int, night: int) -> String:
	return "res://data/floors/f%02d_n%02d_p%d.json" % [n, night % Balance.NIGHTS, clampi(gs.party.size(), 1, 4)]

## 夜が替わるので、通路も部屋の中身も組み直される(大部屋と階段は同じ場所)
func start_day() -> void:
	_clear_dungeon()
	bag_silver = 0
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
	if gs.blessed:
		gs.blessed = false
		for h in heroes:
			h.buffs["guard"] = {"t": 120.0, "v": 0.8}
	phase = "dungeon"
	hud.overlay = []
	enter_floor(1, "up")
	log_msg("第%d日。%s。" % [gs.day + 1, current.map.data["meta"].get("night_label", "")], Color("e8dcb0"))

func _apply_control() -> void:
	for i in heroes.size():
		heroes[i].controlled = i == active
		heroes[i].cmd = {"move": Vector2.ZERO, "guard": false, "dodge": false}
	if current != null:
		current.leader = leader()

func enter_floor(n: int, arrive: String) -> void:
	var fl: FloorInstance = floors.get(n)
	if fl == null:
		fl = FloorInstance.create(floor_path(n, gs.day))
		if fl == null:
			push_error("層を読めない: %d" % n)
			return
		fl.message.connect(log_msg)
		fl.enemy_killed.connect(_on_enemy_killed)
		floors[n] = fl
	if current != null and current.get_parent() == self:
		remove_child(current)
	current = fl
	add_child(fl)
	move_child(fl, 0)
	fl.heroes = heroes
	fl.leader = leader()
	var cell := fl.up_cell if arrive == "up" else fl.down_cell
	var center := fl.map.center_of(cell)
	for i in heroes.size():
		var h: Hero = heroes[i]
		h.game_floor = fl
		var a := TAU * i / maxf(1.0, heroes.size()) + 0.6
		h.position = center + Vector2.from_angle(a) * (22.0 if i != active else 0.0)
		h.knock = Vector2.ZERO
	trail = [leader().position]
	camera.position = leader().position
	camera.reset_smoothing()
	_last_cell = Vector2i(-99, -99)
	_refresh_view()
	var meta: Dictionary = fl.map.data["meta"]
	log_msg("%s「%s」" % [meta.get("floor_label", "第%d層" % n), fl.style.get("short", "")], Color("e8dcb0"))
	var see: Array = fl.style.get("see", [])
	if arrive == "up" and not see.is_empty() and not fl.visited_rooms.has("floor"):
		fl.visited_rooms["floor"] = true
		log_msg(String(see[Dice.rng.randi_range(0, see.size() - 1)]), Color(0.8, 0.85, 0.9))

func light_radius() -> int:
	var b := 0
	for h in heroes:
		if not h.down:
			b = maxi(b, h.ch.light_bonus())
	return Balance.LIGHT_RADIUS + b + (2 if light_t > 0.0 else 0)

func _refresh_view() -> void:
	var pc := current.map.cell_of(leader().position)
	current.map.compute_visible(pc.x, pc.y, light_radius())
	current.update_flow(pc)
	current.light_pos = leader().position
	current.queue_redraw()

func log_msg(text: String, color: Color = Color.WHITE) -> void:
	var s := text
	while s.length() > 46:
		hud.add_log(s.substr(0, 46), color)
		s = s.substr(46)
	hud.add_log(s, color)

# ---------- 毎フレーム ----------

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("credits"):
		hud.show_credits = not hud.show_credits
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
	camera.position = lead.position
	var pc := current.map.cell_of(lead.position)
	if pc != _last_cell:
		_last_cell = pc
		_refresh_view()
		_enter_room(pc)
	_open_doors_near_heroes()
	_check_traps()
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
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	lead.cmd["move"] = mv
	lead.cmd["guard"] = Input.is_action_pressed("guard")
	if Input.is_action_just_pressed("dodge"):
		lead.cmd["dodge"] = true
	for i in 4:
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
	if Input.is_action_just_pressed("inventory") and _menu_cd <= 0.0:
		open_inventory()

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
		heroes[i].follow_pos = trail[maxi(0, idx)] if idx >= 0 else lead.position

func _check_wipe() -> void:
	for h in heroes:
		if not h.down:
			return
	var lost := bag_silver
	bag_silver = 0
	phase = "overlay"
	overlay_kind = "wipe"
	hud.hint = ""
	hud.overlay = [
		{"text": "全滅した…", "size": 30, "color": Color("ff6a5a")},
		{"text": "", "size": 8},
		{"text": "未査定の燐晶 %d銀貨相当 を失った" % lost, "size": 16},
		{"text": "灯手隊が、倒れた仲間を担ぎ出してくれた。", "size": 16, "color": Color("f1d98a")},
		{"text": "", "size": 8},
		{"text": "Enter: 街へ", "size": 18, "color": Color("9ad8ff")},
	]

func _after_overlay() -> void:
	if overlay_kind == "wipe":
		gs.day += 1
		go_town(["全滅した。未査定の燐晶は失ったが、預け金 %d銀貨 は無事だ。" % gs.bank_silver, "倒れた仲間は、神殿で蘇らせよう。"])

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
	if opened:
		_refresh_view()

func party_passive() -> int:
	var best := 0
	for h in heroes:
		if not h.down:
			best = maxi(best, Balance.passive_perception(h.ch.level) + int(h.ch.class_data()["search"]) / 2)
	return best

func party_best(kind: String) -> int:
	var best := -99
	for h in heroes:
		if h.down:
			continue
		best = maxi(best, h.ch.search_bonus() if kind == "search" else h.ch.lock_bonus())
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
	current.queue_redraw()

func _reveal_door(d: Dictionary) -> void:
	d["found"] = true
	log_msg("隠し扉を見つけた", Color("7bd0e0"))
	_refresh_view()

func _check_traps() -> void:
	for t in current.traps:
		if t["st"] != "hidden" and t["st"] != "revealed":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		for h in heroes:
			if h.down:
				continue
			if current.map.cell_of(h.position) == tc:
				_trigger_trap(t, h)
				break

func _trigger_trap(t: Dictionary, victim: Hero) -> void:
	t["st"] = "triggered"
	current.queue_redraw()
	log_msg("罠！ %s(%s)  %sが踏んだ" % [t["name"], SEVERITY_JP.get(String(t["severity"]), ""), victim.ch.name], Color("ff6a5a"))
	log_msg(String(t["effect"]), Color(0.85, 0.7, 0.7))
	var scale := 1.0
	var kind := String(t["kind"])
	if kind == "save":
		var sv: Dictionary = t["save"]
		var bonus := victim.ch.level / 2 + victim.ch.mod("dex" if String(sv["ability"]) == "敏捷力" else "con")
		var roll := Dice.d20()
		var ok := roll + bonus >= int(sv["dc"])
		log_msg("%sセーヴ %d%+d=%d / 難易度%d → %s" % [sv["ability"], roll, bonus, roll + bonus, int(sv["dc"]), "成功" if ok else "失敗"],
			Color("9be29b") if ok else Color("ff8a7a"))
		if ok:
			scale = 0.5 if t.get("half_on_success", false) else 0.0
	elif kind == "attack":
		var roll2 := Dice.d20()
		var hit := roll2 != 1 and (roll2 == 20 or roll2 + int(t["attack_bonus"]) >= victim.ch.armor_class())
		log_msg("攻撃 %d+%d / AC%d → %s" % [roll2, int(t["attack_bonus"]), victim.ch.armor_class(), "命中" if hit else "外れ"],
			Color("ff8a7a") if hit else Color("9be29b"))
		if not hit:
			scale = 0.0
	elif kind == "alarm":
		current.alert_radius(victim.position, 14.0)
		log_msg("音が響いた。近くの魔物がこちらへ向かう", Color("ffb070"))
	if t.has("damage") and scale > 0.0:
		var n := Dice.roll(String(t["damage"]))
		var dealt := maxf(1.0, n * Balance.TRAP_DMG_SCALE * scale)
		log_msg("%sダメージ %d" % [t.get("damage_type", ""), int(round(dealt))], Color("ff6a5a"))
		victim.damage(dealt, victim.position + Vector2(0, 1), true)

# ---------- 操作 ----------

func _near(cell: Vector2i, cells: float) -> bool:
	return leader().position.distance_to(current.map.center_of(cell)) <= cells * Balance.CELL

func _nearest_chest() -> Variant:
	var best: Variant = null
	var bd := 44.0
	for c in current.chests:
		if c["taken"]:
			continue
		var dd := leader().position.distance_to(current.map.center_of(c["cell"]))
		if dd <= bd:
			bd = dd
			best = c
	return best

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

func _update_hint() -> void:
	var h := ""
	if _nearest_chest() != null:
		h = "E: 宝を回収"
	elif _nearest_locked_door() != null:
		h = "E: 解錠を試みる"
	elif _nearest_trap_to_disarm() != null:
		h = "E: 罠を解除する"
	elif _near(current.down_cell, 1.4):
		h = "E: 下へ降りる" if current.floor_no < Balance.MAX_FLOOR else "この先は未踏(まだ道がない)"
	elif _near(current.up_cell, 1.4):
		h = "E: 街へ戻る" if current.floor_no == 1 else "E: 上へ戻る"
	hud.hint = h

func interact() -> void:
	if phase != "dungeon" or leader().down:
		return
	var chest: Variant = _nearest_chest()
	if chest != null:
		_open_chest(chest)
		return
	var door: Variant = _nearest_locked_door()
	if door != null:
		_pick_lock(door)
		return
	var trap: Variant = _nearest_trap_to_disarm()
	if trap != null:
		_disarm(trap)
		return
	if _near(current.down_cell, 1.4):
		if current.floor_no >= Balance.MAX_FLOOR:
			log_msg("この先は未踏。まだ道がない。", Color(0.7, 0.7, 0.8))
		else:
			enter_floor(current.floor_no + 1, "up")
		return
	if _near(current.up_cell, 1.4):
		if current.floor_no == 1:
			return_to_surface()
		else:
			enter_floor(current.floor_no - 1, "down")

func _open_chest(c: Dictionary) -> void:
	c["taken"] = true
	current.queue_redraw()
	var items: Array = c["items"]
	bag_silver += int(c["silver"])
	if int(c["silver"]) > 0:
		log_msg("燐晶を回収: 約%d銀貨相当(税は持ち帰ったときに引かれる)" % int(c["silver"]), Color("f1d98a"))
	for i in range(1, items.size()):
		var s := String(items[i])
		if s.contains("治療薬"):
			gs.add_item("potion")
			log_msg("拾った: 治療薬", Color("d8e6ff"))
		elif s.contains("灯具"):
			gs.add_item("lamp_oil")
			log_msg("拾った: 燐晶の灯油", Color("d8e6ff"))
		else:
			var v := 40 + current.floor_no * 25 + Dice.rng.randi_range(0, 30)
			bag_silver += v
			log_msg("拾った: %s(約%d銀貨相当)" % [s.get_slice("(", 0).get_slice("（", 0), v], Color("d8e6ff"))
	# 深い層ほど、装備が出やすい
	if Dice.rng.randf() < 0.22:
		var id := _roll_gear(current.floor_no)
		if id != "":
			gs.add_item(id)
			log_msg("装備を見つけた: %s" % ItemDB.item_name(id), Color("ffe9a8"))

func _roll_gear(floor_no: int) -> String:
	var cap := 120 + floor_no * 130
	var pool: Array = []
	for id in ItemDB.ITEMS:
		var it: Dictionary = ItemDB.ITEMS[id]
		var k := String(it["kind"])
		if (k == "weapon" or k == "armor" or k == "acc") and int(it["price"]) <= cap:
			pool.append(id)
	if pool.is_empty():
		return ""
	return String(pool[Dice.rng.randi_range(0, pool.size() - 1)])

func _pick_lock(d: Dictionary) -> void:
	if _pick_cd > 0.0:
		return
	_pick_cd = 0.6
	var roll := Dice.d20()
	var bonus := party_best("lock")
	var ok := roll == 20 or roll + bonus >= int(d["lock_dc"])
	log_msg("解錠 %d%+d / 難易度%d → %s" % [roll, bonus, int(d["lock_dc"]), "成功" if ok else "失敗"], Color("9be29b") if ok else Color("ff8a7a"))
	if ok:
		d["unlocked"] = true

func _disarm(t: Dictionary) -> void:
	var roll := Dice.d20()
	var bonus := party_best("lock")
	var dc := int(t["disarm_dc"])
	if roll == 20 or roll + bonus >= dc:
		t["st"] = "disarmed"
		log_msg("罠を解除した: %s" % t["name"], Color("9be29b"))
		current.queue_redraw()
	elif roll + bonus <= dc - 5:
		log_msg("解除に失敗した!", Color("ff8a7a"))
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
	var bonus := party_best("search")
	var found := false
	for t in current.traps:
		if t["st"] != "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if lp.distance_to(m.center_of(tc)) <= 4.5 * Balance.CELL and m.los(pc.x, pc.y, tc.x, tc.y):
			if Dice.d20() + bonus >= int(t["detect_dc"]):
				_reveal_trap(t)
				found = true
	for d in m.doors:
		if d["type"] != "secret" or d["found"]:
			continue
		var dc := Vector2i(d["x"], d["y"])
		if lp.distance_to(m.center_of(dc)) <= 4.5 * Balance.CELL and m.los(pc.x, pc.y, dc.x, dc.y):
			if Dice.d20() + bonus >= int(d["find_dc"]):
				_reveal_door(d)
				found = true
	if not found:
		log_msg("探ってみたが、何も見つからない", Color(0.7, 0.75, 0.8))

func quick_heal() -> void:
	if phase != "dungeon":
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
				return

# ---------- 持ち物 ----------

func open_inventory() -> void:
	if inventory != null:
		return
	_prev_phase = phase
	if phase == "dungeon":
		phase = "menu"
		hud.hint = ""
		get_tree().paused = false
		for h in heroes:
			h.process_mode = Node.PROCESS_MODE_DISABLED
		if current != null:
			current.process_mode = Node.PROCESS_MODE_DISABLED
			for e in current.enemies:
				e.process_mode = Node.PROCESS_MODE_DISABLED
	inventory = InventoryScreen.new()
	inventory.closed.connect(close_inventory)
	ui_layer.add_child(inventory)
	inventory.open(gs, Callable(self, "use_special"))

func close_inventory() -> void:
	if inventory == null:
		return
	inventory.queue_free()
	inventory = null
	_menu_cd = 0.3
	if _prev_phase == "dungeon":
		phase = "dungeon"
		for h in heroes:
			h.process_mode = Node.PROCESS_MODE_INHERIT
			if h.down and h.ch.hp > 0.0:
				h.revive(h.ch.hp / float(h.ch.max_hp()))
		if current != null:
			current.process_mode = Node.PROCESS_MODE_INHERIT
			for e in current.enemies:
				e.process_mode = Node.PROCESS_MODE_INHERIT
		if pending_return:
			pending_return = false
			return_to_surface()
	elif screen is TownScreen:
		(screen as TownScreen).refresh_top()
		(screen as TownScreen)._refresh_all()

## 迷宮の中でだけ効く道具
func use_special(id: String, _c: Character) -> bool:
	if phase != "menu":
		return false
	match String(ItemDB.ITEMS[id]["use"]):
		"light":
			light_t = 180.0
			_refresh_view()
			return true
		"return":
			pending_return = true
			return true
	return false

# ---------- 出来事 ----------

func _on_enemy_killed(en: Enemy) -> void:
	var alive: Array = []
	for h in heroes:
		if not h.down:
			alive.append(h)
	if alive.is_empty():
		return
	var share := gs.party_xp_share(en.xp, alive.size())
	for h in alive:
		if h.ch.gain_xp(share) > 0:
			log_msg("%sのレベルが上がった! Lv%d" % [h.ch.name, h.ch.level], Color("9ad8ff"))
			h.game_floor.spawn_text(h.position + Vector2(0, -28), "LEVEL UP", Color("9ad8ff"))

func return_to_surface() -> void:
	var gross := bag_silver
	var tax := int(round(gross * Balance.TAX_RATE))
	var net := gross - tax
	gs.bank_silver += net
	bag_silver = 0
	gs.day += 1
	var lines: Array = [
		"持ち帰った燐晶(査定前の見積もり)  %d銀貨" % gross,
		"燐晶税(3割)  −%d銀貨" % tax,
		"預け金に加えた額  +%d銀貨   →   預け金 %d銀貨" % [net, gs.bank_silver],
	]
	var downed: Array = []
	for c in gs.party:
		if c.hp <= 0.0:
			downed.append(c.name)
	if not downed.is_empty():
		lines.append("倒れた仲間: %s(神殿で蘇らせよう)" % "、".join(downed))
	go_town(lines)
