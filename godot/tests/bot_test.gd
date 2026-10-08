extends SceneTree
## 自動プレイで難しさを見る:  godot --headless --path godot -s res://tests/bot_test.gd -- [何日ぶん] [層の数]
## 先頭の仲間が最寄りの魔物へ突っ込み、残りはAIで戦う。全部倒したら下り階段へ進む。

var main: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 16
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 4
	var top_floor := int(args[1]) if args.size() > 1 else 4
	var totals := {}
	var start := int(args[2]) if args.size() > 2 else 0
	for day in range(start, start + days):
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await physics_frame
		main.scripted_input = true
		var chars: Array = []
		for k in [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]:
			chars.append(Character.create(k[0], k[1], k[0], Jobs.auto_stats(k[0])))
		main.gs.new_game(chars)
		main.gs.day = day
		main._set_screen(null)
		main.start_day()
		await physics_frame
		var line := "day %d:" % day
		var wiped := false
		for fl_no in range(1, top_floor + 1):
			if fl_no > 1:
				main.enter_floor(fl_no, "up")
			var res: Array = await _clear_floor(fl_no)
			line += "  F%d[%s %ds kills%d Lv%d hp%d%%]" % [fl_no, res[0], res[1], res[2], main.gs.party[0].level, res[3]]
			if res[0] != "clear":
				wiped = res[0] == "wipe"
				break
			# 次の層の前に、薬と魔力水ぶんだけ立て直す(街には戻らない前提)
		print(line)
		main.queue_free()
		await physics_frame
	quit()

func _clear_floor(fl_no: int) -> Array:
	var fl: FloorInstance = main.current
	var m := fl.map
	for d in m.doors:
		d["unlocked"] = true
		d["found"] = true
		d["open"] = true
	main._refresh_view()
	var kills0 := 0
	var total0: int = fl.enemies.size()
	var frames := 0
	var flow := PackedInt32Array()
	var target: Enemy = null
	while frames < 7200:
		frames += 1
		await physics_frame
		var lead: Hero = main.leader()
		if main.phase != "dungeon":
			return ["wipe", frames / 60, total0 - fl.enemies.size(), _hp_pct()]
		if frames % 10 == 1:
			main.quick_heal()
			# 最寄りの(到達できる)魔物
			target = null
			var best := 1 << 30
			var lc := m.cell_of(lead.position)
			for e in fl.enemies:
				if e.dead:
					continue
				var f := m.compute_flow(m.cell_of(e.position).x, m.cell_of(e.position).y, 120)
				var dd := f[m.idx(lc.x, lc.y)]
				if dd >= 0 and dd < best:
					best = dd
					target = e
					flow = f
			if target == null:
				flow = m.compute_flow(fl.down_cell.x, fl.down_cell.y, 400)
		var mv := Vector2.ZERO
		if target != null and is_instance_valid(target) and not target.dead:
			if lead.position.distance_to(target.position) < 60.0:
				mv = (target.position - lead.position).normalized()
				lead.cast_slot(frames % 4)
			else:
				var nx := m.flow_step(flow, m.cell_of(lead.position), true)
				if nx.x >= 0:
					mv = (m.center_of(nx) - lead.position).normalized()
		else:
			if lead.position.distance_to(m.center_of(fl.down_cell)) < 30.0:
				main.interact()
				return ["clear", frames / 60, total0 - fl.enemies.size(), _hp_pct()]
			var nx2 := m.flow_step(flow, m.cell_of(lead.position), true)
			if nx2.x >= 0:
				mv = (m.center_of(nx2) - lead.position).normalized()
		lead.cmd = {"move": mv, "guard": false, "dodge": false}
	return ["timeout", frames / 60, total0 - fl.enemies.size(), _hp_pct()]

func _hp_pct() -> int:
	var cur := 0.0
	var mx := 0.0
	for h in main.heroes:
		cur += h.ch.hp
		mx += h.ch.max_hp()
	return int(100.0 * cur / maxf(1.0, mx))
