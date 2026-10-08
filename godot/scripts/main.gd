extends Node2D
## 全体の進行。層の切り替え、日(夜)の巡り、拾い物、罠、階段、地上での査定。
## 迷宮の中身は Urbs Labyrinthi が書き出した JSON(data/floors/)が決めている。ここは遊びの規則だけを持つ。

const SEVERITY_JP := {"setback": "軽度", "dangerous": "危険", "deadly": "致命的"}

var player: Player
var camera: Camera2D
var hud: Hud
var current: FloorInstance
var floors := {}               # 層の番号 → FloorInstance(この日の控え)
var day := 0
var bank_silver := 0
var bag_silver := 0
var phase := "play"            # play / overlay
var overlay_kind := ""
var _last_cell := Vector2i(-99, -99)
var _detect_t := 0.0
var _search_cd := 0.0
var _pick_cd := 0.0
var _hint_t := 0.0

func _ready() -> void:
	Dice.rng.randomize()
	_setup_input()
	player = Player.new()
	player.downed.connect(_on_player_downed)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.7, 1.7)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	var layer := CanvasLayer.new()
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	add_child(player)
	add_child(camera)
	add_child(layer)
	player.reset_stats()
	start_day()

func _setup_input() -> void:
	var defs := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE, KEY_J], "dodge": [KEY_SHIFT, KEY_K],
		"interact": [KEY_E], "search": [KEY_F], "potion": [KEY_Q],
		"confirm": [KEY_ENTER, KEY_KP_ENTER], "credits": [KEY_F1],
	}
	for a in defs:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in defs[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)

# ---------- 日と層 ----------

func floor_path(n: int, night: int) -> String:
	return "res://data/floors/f%02d_n%02d.json" % [n, night % Balance.NIGHTS]

## 夜が替わるので、通路も部屋の中身も組み直される(大部屋と階段は同じ場所)
func start_day() -> void:
	for f in floors.values():
		f.queue_free()
	floors.clear()
	if current != null and current.get_parent() == self:
		remove_child(current)
	current = null
	bag_silver = 0
	player.down = false
	player.reset_stats()
	phase = "play"
	overlay_kind = ""
	hud.overlay = []
	enter_floor(1, "up")
	log_msg("第%d日。%s。" % [day + 1, current.map.data["meta"].get("night_label", "")], Color("e8dcb0"))

func enter_floor(n: int, arrive: String) -> void:
	var fl: FloorInstance = floors.get(n)
	if fl == null:
		fl = FloorInstance.create(floor_path(n, day))
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
	fl.player = player
	player.game_floor = fl
	var cell := fl.up_cell if arrive == "up" else fl.down_cell
	player.position = fl.map.center_of(cell)
	camera.position = player.position
	camera.reset_smoothing()
	_last_cell = Vector2i(-99, -99)
	_refresh_view()
	var meta: Dictionary = fl.map.data["meta"]
	log_msg("%s「%s」" % [meta.get("floor_label", "第%d層" % n), fl.style.get("short", "")], Color("e8dcb0"))
	var see: Array = fl.style.get("see", [])
	if arrive == "up" and not see.is_empty() and not fl.visited_rooms.has("floor"):
		fl.visited_rooms["floor"] = true
		log_msg(String(see[Dice.rng.randi_range(0, see.size() - 1)]), Color(0.8, 0.85, 0.9))

func _refresh_view() -> void:
	var pc := current.map.cell_of(player.position)
	current.map.compute_visible(pc.x, pc.y, Balance.LIGHT_RADIUS)
	current.update_flow(pc)
	current.light_pos = player.position
	current.queue_redraw()

func log_msg(text: String, color: Color = Color.WHITE) -> void:
	# 長い文は、画面に収まるように折る
	var s := text
	while s.length() > 46:
		hud.add_log(s.substr(0, 46), color)
		s = s.substr(46)
	hud.add_log(s, color)

# ---------- 毎フレーム ----------

func _physics_process(delta: float) -> void:
	if current == null:
		return
	_search_cd = maxf(0.0, _search_cd - delta)
	_pick_cd = maxf(0.0, _pick_cd - delta)
	if Input.is_action_just_pressed("credits"):
		hud.show_credits = not hud.show_credits
	if phase == "overlay":
		if Input.is_action_just_pressed("confirm"):
			continue_after_overlay()
		return
	camera.position = player.position
	var pc := current.map.cell_of(player.position)
	if pc != _last_cell:
		_last_cell = pc
		_refresh_view()
		_enter_room(pc)
	_open_doors_near_player()
	_check_traps(pc)
	_detect_t -= delta
	if _detect_t <= 0.0:
		_detect_t = 0.2
		_passive_detect(pc)
		_update_hint()
	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("search"):
		search()
	if Input.is_action_just_pressed("potion"):
		use_potion()

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

func _open_doors_near_player() -> void:
	var m := current.map
	for d in m.doors_near(player.position, 28.0):
		if d["open"]:
			continue
		if d["type"] == "secret" and not d["found"]:
			continue
		if d["type"] == "locked" and not d["unlocked"]:
			continue
		d["open"] = true
		_refresh_view()

func _passive_detect(pc: Vector2i) -> void:
	var m := current.map
	var pp := Balance.passive_perception(player.level)
	for t in current.traps:
		if t["st"] != "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if player.position.distance_to(m.center_of(tc)) > 2.5 * Balance.CELL:
			continue
		if int(t["detect_dc"]) <= pp and m.los(pc.x, pc.y, tc.x, tc.y):
			_reveal_trap(t)
	for d in m.doors:
		if d["type"] != "secret" or d["found"]:
			continue
		var dc := Vector2i(d["x"], d["y"])
		if player.position.distance_to(m.center_of(dc)) > 2.5 * Balance.CELL:
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

# ---------- 罠 ----------

func _check_traps(pc: Vector2i) -> void:
	for t in current.traps:
		if t["st"] != "hidden" and t["st"] != "revealed":
			continue
		if int(t["x"]) == pc.x and int(t["y"]) == pc.y:
			_trigger_trap(t)

func _trigger_trap(t: Dictionary) -> void:
	t["st"] = "triggered"
	current.queue_redraw()
	log_msg("罠！ %s(%s)" % [t["name"], SEVERITY_JP.get(String(t["severity"]), "")], Color("ff6a5a"))
	log_msg(String(t["effect"]), Color(0.85, 0.7, 0.7))
	var scale := 1.0
	var kind := String(t["kind"])
	if kind == "save":
		var sv: Dictionary = t["save"]
		var bonus := player.level / 2
		var roll := Dice.d20()
		var ok := roll + bonus >= int(sv["dc"])
		log_msg("%sセーヴ %d+%d=%d / 難易度%d → %s" % [sv["ability"], roll, bonus, roll + bonus, int(sv["dc"]), "成功" if ok else "失敗"],
			Color("9be29b") if ok else Color("ff8a7a"))
		if ok:
			scale = 0.5 if t.get("half_on_success", false) else 0.0
	elif kind == "attack":
		var roll2 := Dice.d20()
		var hit := roll2 != 1 and (roll2 == 20 or roll2 + int(t["attack_bonus"]) >= 13)
		log_msg("攻撃 %d+%d / AC13 → %s" % [roll2, int(t["attack_bonus"]), "命中" if hit else "外れ"],
			Color("ff8a7a") if hit else Color("9be29b"))
		if not hit:
			scale = 0.0
	elif kind == "alarm":
		current.alert_radius(player.position, 14.0)
		log_msg("音が響いた。近くの魔物がこちらへ向かう", Color("ffb070"))
	if t.has("damage") and scale > 0.0:
		var n := Dice.roll(String(t["damage"]))
		var dealt := maxf(1.0, n * Balance.TRAP_DMG_SCALE * scale)
		log_msg("%sダメージ %d" % [t.get("damage_type", ""), int(round(dealt))], Color("ff6a5a"))
		player.take_damage(dealt, player.position + Vector2(0, 1))

# ---------- 操作 ----------

func _near(cell: Vector2i, cells: float) -> bool:
	return player.position.distance_to(current.map.center_of(cell)) <= cells * Balance.CELL

func _nearest_chest() -> Variant:
	var best: Variant = null
	var bd := 44.0
	for c in current.chests:
		if c["taken"]:
			continue
		var dd := player.position.distance_to(current.map.center_of(c["cell"]))
		if dd <= bd:
			bd = dd
			best = c
	return best

func _nearest_locked_door() -> Variant:
	for d in current.map.doors_near(player.position, 46.0):
		if d["type"] == "locked" and not d["unlocked"]:
			return d
	return null

func _nearest_trap_to_disarm() -> Variant:
	for t in current.traps:
		if t["st"] != "revealed":
			continue
		if player.position.distance_to(current.map.center_of(Vector2i(int(t["x"]), int(t["y"])))) <= 44.0:
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
		h = "E: 地上へ戻る" if current.floor_no == 1 else "E: 上へ戻る"
	hud.hint = h

func interact() -> void:
	if phase != "play" or player.down:
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
		log_msg("拾った: " + s, Color("d8e6ff"))
		if s.contains("治療薬") or s.contains("ポーション"):
			player.potions += 1

func _pick_lock(d: Dictionary) -> void:
	if _pick_cd > 0.0:
		return
	_pick_cd = 0.6
	var roll := Dice.d20()
	var bonus := Balance.skill_bonus(player.level)
	var ok := roll == 20 or roll + bonus >= int(d["lock_dc"])
	log_msg("解錠 %d+%d / 難易度%d → %s" % [roll, bonus, int(d["lock_dc"]), "成功" if ok else "失敗"], Color("9be29b") if ok else Color("ff8a7a"))
	if ok:
		d["unlocked"] = true

func _disarm(t: Dictionary) -> void:
	var roll := Dice.d20()
	var bonus := Balance.skill_bonus(player.level)
	var dc := int(t["disarm_dc"])
	if roll == 20 or roll + bonus >= dc:
		t["st"] = "disarmed"
		log_msg("罠を解除した: %s" % t["name"], Color("9be29b"))
		current.queue_redraw()
	elif roll + bonus <= dc - 5:
		log_msg("解除に失敗した!", Color("ff8a7a"))
		_trigger_trap(t)
	else:
		log_msg("解除に失敗した(もう一度試せる)", Color("ffb070"))

func search() -> void:
	if phase != "play" or player.down or _search_cd > 0.0:
		return
	_search_cd = 0.6
	var m := current.map
	var pc := m.cell_of(player.position)
	var bonus := Balance.skill_bonus(player.level)
	var found := false
	for t in current.traps:
		if t["st"] != "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if player.position.distance_to(m.center_of(tc)) <= 4.5 * Balance.CELL and m.los(pc.x, pc.y, tc.x, tc.y):
			if Dice.d20() + bonus >= int(t["detect_dc"]):
				_reveal_trap(t)
				found = true
	for d in m.doors:
		if d["type"] != "secret" or d["found"]:
			continue
		var dc := Vector2i(d["x"], d["y"])
		if player.position.distance_to(m.center_of(dc)) <= 4.5 * Balance.CELL and m.los(pc.x, pc.y, dc.x, dc.y):
			if Dice.d20() + bonus >= int(d["find_dc"]):
				_reveal_door(d)
				found = true
	if not found:
		log_msg("探ってみたが、何も見つからない", Color(0.7, 0.75, 0.8))

func use_potion() -> void:
	if phase != "play" or player.down:
		return
	if player.potions <= 0:
		log_msg("治療薬がない", Color(0.7, 0.7, 0.8))
		return
	if player.hp >= player.max_hp:
		return
	player.potions -= 1
	player.heal(maxi(8, player.max_hp / 2))

# ---------- 出来事 ----------

func _on_enemy_killed(en: Enemy) -> void:
	if player.gain_xp(en.xp):
		log_msg("レベルが上がった! Lv%d(HP全快)" % player.level, Color("9ad8ff"))
		player.game_floor.spawn_text(player.position + Vector2(0, -28), "LEVEL UP", Color("9ad8ff"))

func return_to_surface() -> void:
	var gross := bag_silver
	var tax := int(round(gross * Balance.TAX_RATE))
	var net := gross - tax
	bank_silver += net
	bag_silver = 0
	phase = "overlay"
	overlay_kind = "surface"
	hud.hint = ""
	hud.overlay = [
		{"text": "地上へ戻った", "size": 28, "color": Color("e8dcb0")},
		{"text": "", "size": 8},
		{"text": "持ち帰った燐晶(査定前の見積もり)  %d銀貨" % gross, "size": 16},
		{"text": "燐晶税(3割)  −%d銀貨" % tax, "size": 16, "color": Color("ff9a7a")},
		{"text": "預け金に加えた額  +%d銀貨   →   預け金 %d銀貨" % [net, bank_silver], "size": 18, "color": Color("f1d98a")},
		{"text": "", "size": 8},
		{"text": "夜が明けると、通路は組み替わっている。", "size": 14, "color": Color(0.8, 0.85, 0.9)},
		{"text": "Enter: 次の夜に潜る", "size": 18, "color": Color("9ad8ff")},
	]

func _on_player_downed() -> void:
	var lost := bag_silver
	bag_silver = 0
	phase = "overlay"
	overlay_kind = "dead"
	hud.hint = ""
	hud.overlay = [
		{"text": "力尽きた…", "size": 30, "color": Color("ff6a5a")},
		{"text": "", "size": 8},
		{"text": "未査定の燐晶 %d銀貨相当 を失った" % lost, "size": 16},
		{"text": "灯手隊に担ぎ出された。預け金 %d銀貨 は無事" % bank_silver, "size": 16, "color": Color("f1d98a")},
		{"text": "", "size": 8},
		{"text": "Enter: 次の夜に潜る", "size": 18, "color": Color("9ad8ff")},
	]

func continue_after_overlay() -> void:
	day += 1
	start_day()
