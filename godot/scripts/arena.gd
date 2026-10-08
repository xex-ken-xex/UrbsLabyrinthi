class_name Arena
extends Node
## 闘技場(戦闘バランスの調整用)。広い一部屋で、選んだ遭遇レベルの魔物を出して戦う。
## パーティは本編の仲間の複製で、レベルを自由に変えても、本編には影響しない。経験点も宝も出ない。

const W := 26
const H := 16
const THEME_FLOOR := {"fuyou": 1, "sabi": 3, "kagami": 5, "hone": 7, "soko": 10, "generic": 1}

var main: Node
var fl: FloorInstance
var chars: Array = []              # 本編の仲間の複製
var theme_id := "fuyou"
var enc_level := 1
var diff := 1                      # 0:低 1:中 2:高
var party_n := 4                   # 遭遇の予算に使う人数
var auto_waves := false
var level_up_each := true
var heal_between := true
var wave := 0
var wave_active := false
var wave_t := 0.0
var wave_enemies := 0
var wave_xp := 0
var history: Array = []
var _snap_dealt := 0.0
var _snap_taken := 0.0
var _next_t := -1.0
var _style_cache := {}

## 本編の仲間を複製して、闘技場の床を作る
func setup(main_node: Node, base_party: Array) -> void:
	main = main_node
	for c in base_party:
		var cp := Character.from_dict((c as Character).to_dict())
		cp.hp = float(cp.max_hp())
		cp.mp = float(cp.max_mp())
		chars.append(cp)
	party_n = clampi(chars.size(), 1, 8)
	var sum := 0
	for c in chars:
		sum += c.level
	enc_level = clampi(int(round(float(sum) / maxf(1.0, chars.size()))), 1, 20)
	fl = FloorInstance.create_from_dict(_make_dict(theme_id))
	fl.arena = true

func _style_for(id: String) -> Dictionary:
	if not _style_cache.has(id):
		var path := "res://data/floors/f%02d_n00_p1.json" % int(THEME_FLOOR.get(id, 1))
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_style_cache[id] = parsed["style"] if typeof(parsed) == TYPE_DICTIONARY else {}
	return _style_cache[id]

func _make_dict(id: String) -> Dictionary:
	var rows: Array = []
	for y in H:
		var row := ""
		for x in W:
			row += "#" if (x == 0 or y == 0 or x == W - 1 or y == H - 1) else "."
		rows.append(row)
	var room := {"id": 0, "no": 1, "name": "闘技場", "role": "entrance", "big": true, "shape": "rect", "x": 1, "y": 1, "w": W - 2, "h": H - 2,
		"center": [W / 2, H / 2], "area_cells": (W - 2) * (H - 2), "lit": true, "exits": [], "flavor": "", "traps": []}
	var st := _style_for(id).duplicate(true)
	return {"schema": "urbs-labyrinthi/0.1",
		"meta": {"grid": {"width": W, "height": H}, "floor": 1, "night": 0, "theme": id, "floor_label": "闘技場", "night_label": "調整用", "exhale": false},
		"grid": rows, "rooms": [room], "doors": [], "traps": [], "encounters": [],
		"stairs": {"up": {"x": 2, "y": H - 3, "room": 0}, "down": {"x": W - 3, "y": 2, "room": 0}},
		"style": st}

func set_theme(id: String) -> void:
	theme_id = id
	if fl != null:
		fl.set_style(_style_for(id))

# ---------- 魔物を出す ----------

func spawn_center(avoid: Vector2) -> Vector2:
	var best := Vector2(W * 16.0, H * 16.0)
	for tries in 40:
		var p := Vector2(Dice.rng.randf_range(4.0, W - 4.0), Dice.rng.randf_range(4.0, H - 4.0)) * float(Balance.CELL)
		if p.distance_to(avoid) > 260.0 and not fl.map.circle_blocked(p, 20.0):
			return p
	return best

## 選んだ遭遇レベル、難度、舞台で、遭遇を一つ出す。出した遭遇の説明を返す
func pop() -> String:
	var enc := EncounterGen.generate(theme_id, enc_level, diff, party_n)
	if enc.is_empty():
		return "この条件では、魔物を作れなかった"
	var lead: Hero = main.leader()
	var center := spawn_center(lead.position if lead != null else Vector2.ZERO)
	var lines: Array = []
	var names: Array = []
	for g in enc["groups"]:
		var line := EncounterGen.mon_line(g)
		lines.append(line)
		names.append("%s×%d" % [String(line.get("world_name", line["name_ja"])), int(g["n"])])
	var made: Array = fl.spawn_encounter(lines, String(enc["kind"]), center)
	if not wave_active:
		wave += 1
		wave_active = true
		wave_t = 0.0
		wave_enemies = 0
		wave_xp = 0
		_snap_dealt = _sum_dealt()
		_snap_taken = _sum_taken()
	wave_enemies += made.size()
	wave_xp += int(enc["xp"])
	return "Lv%d・%s: %s(%d体、XP %d / 予算 %d)" % [enc_level, EncounterGen.DIFF_JP[diff], "、".join(names), made.size(), int(enc["xp"]), int(enc["budget"])]

func clear_enemies() -> void:
	for e in fl.enemies.duplicate():
		e.dead = true
		e.queue_free()
	fl.enemies.clear()
	wave_active = false
	_next_t = -1.0

# ---------- 仲間 ----------

func set_level(i: int, lv: int) -> void:
	if i < 0 or i >= chars.size():
		return
	var c: Character = chars[i]
	lv = clampi(lv, 1, 20)
	c.level = lv
	c.xp = int(Balance.XP_LEVELS[lv - 1])
	c.learn_class_skills()
	c.hp = float(c.max_hp())
	c.mp = float(c.max_mp())
	_sync_hero(i)

func set_all_levels(lv: int) -> void:
	for i in chars.size():
		set_level(i, lv)

func _sync_hero(i: int) -> void:
	var hs: Array = main.heroes
	if i < hs.size():
		var h: Hero = hs[i]
		if h.down:
			h.revive(1.0)
		h.ch.hp = float(h.ch.max_hp())
		h.ch.mp = float(h.ch.max_mp())

func heal_all() -> void:
	for i in chars.size():
		chars[i].hp = float(chars[i].max_hp())
		chars[i].mp = float(chars[i].max_mp())
		_sync_hero(i)
	for h in main.heroes:
		h.cds.clear()
		h.buffs.clear()

func reset_stats() -> void:
	for h in main.heroes:
		h.stat_dealt = 0.0
		h.stat_taken = 0.0
	history.clear()
	wave = 0

func _sum_dealt() -> float:
	var t := 0.0
	for h in main.heroes:
		t += h.stat_dealt
	return t

func _sum_taken() -> float:
	var t := 0.0
	for h in main.heroes:
		t += h.stat_taken
	return t

# ---------- 波 ----------

func _physics_process(delta: float) -> void:
	if fl == null:
		return
	if wave_active:
		wave_t += delta
		if fl.enemies.is_empty():
			_finish_wave("勝利")
	if _next_t >= 0.0:
		_next_t -= delta
		if _next_t < 0.0:
			_next_t = -1.0
			if heal_between:
				heal_all()
			if level_up_each:
				enc_level = mini(20, enc_level + 1)
			pop()

func _finish_wave(result: String) -> void:
	var downs := 0
	for h in main.heroes:
		if h.down:
			downs += 1
	history.append("波%d %s  Lv%d・%s  %d体 XP%d  %.1f秒  与ダメ %d  被ダメ %d  倒れた %d人" % [wave, result, enc_level, EncounterGen.DIFF_JP[diff],
		wave_enemies, wave_xp, wave_t, int(_sum_dealt() - _snap_dealt), int(_sum_taken() - _snap_taken), downs])
	while history.size() > 12:
		history.pop_front()
	wave_active = false
	if auto_waves and result == "勝利":
		_next_t = 2.0

## 全滅したとき: 記録して、魔物を消し、仲間を全快させる(連戦は止める)
func on_wipe() -> void:
	if wave_active:
		_finish_wave("全滅")
	clear_enemies()
	auto_waves = false
	heal_all()

func summary() -> String:
	var t := ""
	if wave_active:
		t += "波%d 戦闘中  残り %d体  %.1f秒\n" % [wave, fl.enemies.size(), wave_t]
	else:
		t += "待機中(波 %d まで)\n" % wave
	for h in main.heroes:
		t += "%s Lv%d  HP %d/%d  与 %d  受 %d%s\n" % [h.ch.name, h.ch.level, int(ceil(h.ch.hp)), h.ch.max_hp(), int(h.stat_dealt), int(h.stat_taken), "  (倒)" if h.down else ""]
	return t
