class_name DiveSave
extends RefCounted
## 迷宮の中の記録(ken 10/16)。持ち物の画面の「記録をつける」で書き、タイトルの「つづきから」で、その場所から再開する。
## パーティと持ち物は、いつもの記録(GameState、user://save.json)に、同じときに書く。
## こちらには、その夜の迷宮だけを書く: 今いる層、仲間の位置、袋の燐晶、迷宮の時刻、訪れた層ごとの様子
## (見た範囲、扉、罠、落ちているもの、生きている魔物)。街へ戻るか、全滅するか、次の夜に潜ると消える。

const PATH := "user://dive.sav"
const VERSION := 1

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

static func write(d: Dictionary) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	return true

static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	if typeof(v) != TYPE_DICTIONARY or int(v.get("version", 0)) != VERSION:
		return {}
	return v

# ---------- 層 ----------

static func floor_snap(fl: FloorInstance) -> Dictionary:
	var doors: Array = []
	for d in fl.map.doors:
		doors.append(d.duplicate(true))
	var traps: Array = []
	for t in fl.traps:
		traps.append(t.duplicate(true))
	var ens: Array = []
	for e in fl.enemies:
		if is_instance_valid(e) and not e.dead:
			ens.append({"m": e.mon, "id": e.enc_id, "kind": e.kind, "att": e.attitude, "pos": e.position, "hp": e.hp,
				"state": e.state, "asleep": e.asleep, "fled": e.fled, "sentry": e.sentry, "nest": e.nest_cell})
	return {"explored": fl.map.explored, "doors": doors, "traps": traps, "ground": fl.ground.entries.duplicate(true),
		"enemies": ens, "enc_total": fl.enc_total.duplicate(), "enc_dead": fl.enc_dead.duplicate(),
		"visited": fl.visited_rooms.duplicate(), "serial": fl.enc_serial, "wanderers": fl.wanderers.duplicate(),
		"webs": fl.webs.keys(), "pending": fl.spawner.pending.keys(), "queued": fl.spawner.queued, "hunt": fl.spawner.hunt.keys(), "master": fl.master_enc}

## 作り直したばかりの層に、記録した様子を戻す
static func floor_apply(fl: FloorInstance, s: Dictionary) -> void:
	var ex: PackedByteArray = s.get("explored", PackedByteArray())
	if ex.size() == fl.map.explored.size():
		fl.map.explored = ex
	var doors: Array = s.get("doors", [])
	for i in mini(doors.size(), fl.map.doors.size()):
		var d: Dictionary = fl.map.doors[i]       # 扉の参照(door_at)は、そのまま使う
		d.merge(doors[i], true)
	# 罠も、同じ辞書を書き換える(動き続ける罠の仕掛けが、辞書を持っている)
	var traps: Array = s.get("traps", [])
	for i in traps.size():
		if i < fl.traps.size():
			(fl.traps[i] as Dictionary).merge(traps[i], true)
		else:
			fl.traps.append(traps[i])
	fl.trap_at.clear()
	for t in fl.traps:
		fl.trap_at[Vector2i(int(t["x"]), int(t["y"]))] = t
	fl.ground.entries = s.get("ground", []).duplicate(true)
	for e in fl.enemies:
		e.queue_free()
	fl.enemies.clear()
	for r in s.get("enemies", []):
		var en := Enemy.new()
		en.setup(fl, r["m"], {"id": r["id"], "kind": r["kind"], "attitude": r["att"]}, r["pos"])
		if r.get("sentry", false):
			en.make_sentry(r["nest"])
		en.hp = float(r["hp"])
		en.state = "idle" if String(r["state"]) == "warn" else String(r["state"])
		en.asleep = bool(r["asleep"])
		en.fled = bool(r["fled"])
		if en.state != "idle":
			en.disguised = false
			en.lurk = ""
		en.died.connect(fl._on_enemy_died)
		fl.add_child(en)
		fl.enemies.append(en)
	fl.enc_total = s.get("enc_total", {}).duplicate()
	fl.enc_dead = s.get("enc_dead", {}).duplicate()
	fl.visited_rooms = s.get("visited", {}).duplicate()
	fl.enc_serial = int(s.get("serial", fl.enc_serial))
	fl.wanderers = s.get("wanderers", []).duplicate()
	# まだ出していない遭遇(記録に無ければ、どれも出したあと)
	var keep := {}
	for eid in s.get("pending", []):
		keep[int(eid)] = true
	for eid in fl.spawner.pending.keys():
		if not keep.has(int(eid)):
			fl.spawner.pending.erase(eid)
	fl.spawner.queued = int(s.get("queued", 0))
	fl.master_enc = int(s.get("master", fl.master_enc))
	fl.spawner.hunt = {}
	for eid in s.get("hunt", []):
		fl.spawner.hunt[int(eid)] = true
	if s.has("webs"):
		fl.webs.clear()
		for i in s["webs"]:
			fl.webs[int(i)] = true
	fl.map_changed()
	fl.queue_redraw()
