class_name FloorInstance
extends Node2D
## 潜っている最中の1層。地図、魔物、落ちているもの、罠、探索の跡を持ち、床を描く。
## 層を離れても捨てずに控えておく。戻ると、扉の開き具合も倒した魔物もそのまま。

signal message(text: String, kind: String)
signal enemy_killed(enemy: Enemy)
signal ground_picked(entry: Dictionary, hero: Hero)   # 落ちているものを拾った
signal shake(strength: float)                         # 画面を揺らす(爆発の罠など)
signal enemy_seen(enemy: Enemy)                       # 魔物が初めて見えた(冒険日記帳)
signal stat(key: String)                              # 実績に数える出来事(Journal.bump)
signal boss_fallen(layer: int, pos: Vector2)                # 層の主(ユニーク)が、みな倒れた(LayerBoss)
signal darkened()                                     # 魔物の「闇」の呪文で、仲間の見える範囲が狭まった

var map: FloorMap
var style: Dictionary
var col := {}
var floor_no := 1             # 階の通し番号(1〜Balance.MAX_FLOOR)。階段と HUD に使う
var layer_no := 1             # 層(第N層)。層は、1〜5階のグループ。拾えるもの、舞台、魔物の強さは、層で決まる
var night_no := 0
var heroes: Array = []        # Hero(パーティ全員。Main が持つ体への参照)
var leader: Hero = null
var enemies: Array = []
var ground := GroundItems.new()   # 光る燐晶、自生物、遺体、落とし物
var traps: Array = []         # 書き出しの罠 + st(hidden / revealed / triggered / disarmed)
var trap_at := {}             # マス(Vector2i) → 罠
var up_cell := Vector2i.ZERO
var down_cell := Vector2i.ZERO
var flow := PackedInt32Array()
var flow_cell := Vector2i(-1, -1)
var visited_rooms := {}
var enc_total := {}
var enc_dead := {}
var light_pos := Vector2.ZERO
var exhale := false
var hot := false              # 竜の気配で、縦穴の縁が熱い(吐く夜の夜の間、第7層から下。DungeonTime → PhosFlow)
var arena := false            # 闘技場(階段は上りだけ。魔物は後から出す)
var enc_serial := 5000
var lamp_on := false           # 燐晶の灯油を灯している(光に弱い魔物が弱る)
var webs := {}                 # 蜘蛛の巣のマス(番号 → true)。巣を張る魔物のまわりに張る。踏むと絡まる
var wanderers: Array = []      # ワンダリング・モンスターで出た遭遇の id(DungeonTime)
var world_props: Array = []    # 地図屋の印、壁の落書き、闇潜りの野営(FloorProps)
var hook_marks: Array = []     # 物がある手がかりの印(RoomHooks)。{room, cell, pos, id, qty, text, taken}
var decor: Array = []          # 絵だけの物: 錆鉄の軌条と止まったトロッコ、部屋の地物(湧き水、茸の畝、揚水機、骨の祭壇、聖歌席)
var master_enc := -1           # 主の間の主(遭遇の id)。倒すと、まわりの控えの巣が散る
const MASTER_REACH := 36.0         # 主の間からこのマス数までの巣は、みな散る
const MASTER_SCATTER_ELSE := 0.25  # それより遠い巣が散る割合
var boss_layer := 0             # 層の主の階なら、その層(LayerBoss.setup_floor)。倒すと 0
var boss_enc := -1              # 層の主の遭遇の id
var fx_overlay: Node2D = null   # 層の主との戦いの間、ダメージの数字を描く所(モノクロの上。BossFx)
var spawner := Spawner.new(self)   # 魔物を近づいたときに出し、遠くでは眠らせる
var ropes: Array = []         # 縦穴の縁の縄梯子(Vector2i。縁の角のマス)。下の階の同じ所へ下りられる
var abyss: Abyss = null       # 縦穴を覗いたときの、下の階の重なり
var tex := {}                 # 差し替え画像(床、壁、通路、アイコン)
var _tex_ver := -1

func _init() -> void:
	process_physics_priority = 100     # 魔物と仲間が動いたあとに、押し合いを決める

func _physics_process(delta: float) -> void:
	Spawner.watch_fps(delta)
	spawner.tick(delta)
	var bodies: Array = []
	for h in heroes:
		if h.is_alive():
			bodies.append(h)
	# 広い層では、仲間から遠い魔物(動かない)を、押し合いの計算に入れない
	for e in enemies:
		if not e.dead and not e.dormant and _near_hero(e.position, NEAR_SIM):
			bodies.append(e)
	Contact.step(delta, bodies)
	ground.update(delta)
	if not webs.is_empty():
		_check_webs()

static func create_from_dict(d: Dictionary) -> FloorInstance:
	var fi := FloorInstance.new()
	fi.setup(FloorMap.new(d))
	return fi

## 舞台の色などを替える(闘技場で、舞台を切り替えたとき)
func set_style(st: Dictionary) -> void:
	style = st
	col = {}
	for k in st.get("col", {}):
		col[k] = Color.html(String(st["col"][k]))
	queue_redraw()

## 遭遇を、center のまわりに出す。出した魔物を返す。state は、出たときの動き(追う chase / 歩き回る wander)
func spawn_encounter(monsters: Array, kind: String, center: Vector2, activity: String = "", state: String = "chase") -> Array:
	enc_serial += 1
	var eid := enc_serial
	enc_total[eid] = 0
	enc_dead[eid] = 0
	var out: Array = []
	var k := 0
	for m in monsters:
		for i in int(m["count"]):
			var en := Enemy.new()
			var pos := center
			for tries in 12:
				var ang := k * 2.399963 + tries * 0.7
				var rad := 14.0 + 15.0 * sqrt(float(k)) * (1.0 - tries * 0.07)
				pos = center + Vector2.from_angle(ang) * rad
				if not map.circle_blocked(pos, 12.0):
					break
			en.setup(self, m, {"id": eid, "kind": kind, "attitude": "敵対", "activity": activity}, pos)
			en.state = state
			en.disguised = false
			en.lurk = ""
			en.died.connect(_on_enemy_died)
			add_child(en)
			enemies.append(en)
			enc_total[eid] += 1
			out.append(en)
			k += 1
	return out

static func create(path: String) -> FloorInstance:
	var m := FloorMap.load_file(path)
	if m == null:
		return null
	var fi := FloorInstance.new()
	fi.setup(m)
	return fi

func setup(m: FloorMap) -> void:
	map = m
	var d := m.data
	style = d.get("style", {})
	for k in style.get("col", {}):
		col[k] = Color.html(String(style["col"][k]))
	layer_no = int(d["meta"]["floor"])
	floor_no = int(d["meta"].get("depth", layer_no))
	night_no = int(d["meta"]["night"])
	exhale = bool(d["meta"].get("exhale", false))
	up_cell = Vector2i(int(d["stairs"]["up"]["x"]), int(d["stairs"]["up"]["y"]))
	var dn: Variant = (d["stairs"] as Dictionary).get("down")
	down_cell = Vector2i(int(dn["x"]), int(dn["y"])) if typeof(dn) == TYPE_DICTIONARY else Vector2i(-1, -1)   # 竜の巣の階(いちばん下)に下りは無い
	for t in d["traps"]:
		var tt: Dictionary = t.duplicate()
		# 仕掛けの動き(fx)は、生成器の罠表が決める。振り子と噴き口は隠れていない(state: found)
		tt["st"] = "revealed" if String(t.get("state", "")) == "found" else "hidden"
		tt["fx"] = String(t.get("fx", ""))
		traps.append(tt)
		trap_at[Vector2i(int(t["x"]), int(t["y"]))] = tt
		if TrapFx.PERIODIC.has(tt["fx"]):
			add_child(TrapFx.make(self, tt, null))
	for p in d.get("props", []):
		if String(p.get("kind", "")) == "rope":
			ropes.append(Vector2i(int(p["x"]), int(p["y"])))
	world_props = FloorProps.pick(d.get("props", []))
	decor = FloorProps.decor(d)
	hook_marks = RoomHooks.marks(self)
	ground.setup(self)
	ground.spawn_all()
	_spawn_enemies()
	_spawn_rope_haunts()
	_spawn_webs()
	abyss = Abyss.new()
	abyss.setup(self)
	add_child(abyss)
	move_child(abyss, 0)      # 魔物や仕掛けより下に描く

## 層の遭遇は、まだ出さずに控えておく(Spawner が、仲間が近づいたら出す)。数だけは先に数える
func _spawn_enemies() -> void:
	for e in map.data["encounters"]:
		var eid := int(e["id"])
		enc_total[eid] = (e["tokens"] as Array).size()
		enc_dead[eid] = 0
		spawner.pending[eid] = e
		if e.get("master", false):
			master_enc = eid

## 縄梯子の下には、落ちてくる者を待つ魔物がいる(ken 10/18)。縄梯子ごとに、その階の遭遇から一種を1〜2体。
## 層の遭遇と同じく控えておき、近づいたら出す(遭遇の id は ROPE_ENC_ID から)
const ROPE_ENC_ID := 9000
func _spawn_rope_haunts() -> void:
	var src: Array = (map.data["encounters"] as Array).filter(func(e): return not e.get("boss", false) and not e.get("master", false) and not (e.get("monsters", []) as Array).is_empty())
	if src.is_empty() or String(map.data["meta"].get("floor_label", "")) == "闘技場":
		return
	for i in ropes.size():
		var e: Dictionary = src[Dice.rng.randi_range(0, src.size() - 1)]
		var line: Dictionary = (e["monsters"][0] as Dictionary).duplicate()
		var rc: Vector2i = ropes[i]
		var tokens: Array = []
		for k in Dice.rng.randi_range(1, 2):
			var c := map.nearest_walkable(rc + Vector2i(Dice.rng.randi_range(-3, 3), Dice.rng.randi_range(-3, 3)), 4)
			if c.x >= 0:
				tokens.append({"x": c.x, "y": c.y, "g": 0})
		if tokens.is_empty():
			continue
		var eid := ROPE_ENC_ID + i
		var enc := {"id": eid, "roomId": -1, "boss": false, "kind": String(e.get("kind", "")), "attitude": "敵対",
			"activity": "縄梯子の下で、落ちてくる者を待っている", "tokens": tokens, "monsters": [line]}
		enc_total[eid] = tokens.size()
		enc_dead[eid] = 0
		spawner.pending[eid] = enc

## 控えていた遭遇の魔物を、書き出しの位置に出す
func spawn_tokens(e: Dictionary) -> void:
	for t in e["tokens"]:
		var mons: Array = e["monsters"]
		var m: Dictionary = mons[int(t["g"])]
		var en := Enemy.new()
		en.setup(self, m, e, map.center_of(Vector2i(int(t["x"]), int(t["y"]))))
		if t.get("sentry", false) and map.room_by_id.has(int(e.get("roomId", -1))):
			var c: Array = map.room_by_id[int(e["roomId"])]["center"]
			en.make_sentry(Vector2i(int(c[0]), int(c[1])))
		en.died.connect(_on_enemy_died)
		add_child(en)
		enemies.append(en)

## 巣を張る魔物(大蜘蛛など)の遭遇のまわりに、蜘蛛の巣を張る
func _spawn_webs() -> void:
	if arena:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(map.data["meta"].get("seed", "")) + str(floor_no) + str(night_no))
	for e in map.data["encounters"]:
		var spin := false
		for m in e["monsters"]:
			if MonTraits.flags_for(m).has("webwalk"):
				spin = true
				break
		if not spin or (e["tokens"] as Array).is_empty():
			continue
		var c0 := Vector2i(int(e["tokens"][0]["x"]), int(e["tokens"][0]["y"]))
		var placed := 0
		for tries in 40:
			if placed >= 7:
				break
			var c := c0 + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			if not map.in_bounds(c.x, c.y) or map.tiles[map.idx(c.x, c.y)] != FloorMap.ROOM or c == up_cell or c == down_cell or trap_at.has(c):
				continue
			if webs.has(map.idx(c.x, c.y)):
				continue
			webs[map.idx(c.x, c.y)] = true
			placed += 1

## 仲間が蜘蛛の巣を踏んだ: 絡まって動けない。巣は破れる。巣の揺れで、巣の主が気づく(Web Sense)
func _check_webs() -> void:
	for h in heroes:
		if not h.is_alive() or h.is_rolling() or h.stuck_t > 0.0:
			continue
		var c := map.cell_of(h.position)
		var i := map.idx(c.x, c.y)
		if not webs.has(i):
			continue
		webs.erase(i)
		h.hold("web", 1.4)
		Sfx.cue(self, h.position, "web")
		queue_redraw()
		var woke := false
		for en in enemies:
			if not en.dead and en.has_trait("websense") and en.position.distance_to(h.position) <= 30.0 * Balance.CELL:
				if en.state == "idle" or en.hidden_form():
					woke = true
				en.wake()
				en.target = h
		if woke:
			message.emit("巣の糸が震えた。巣の主が気づいたようだ", "danger")

func _on_enemy_died(en: Enemy) -> void:
	enc_dead[en.enc_id] = int(enc_dead.get(en.enc_id, 0)) + 1
	enemies.erase(en)
	enemy_killed.emit(en)
	if en.unique and en.enc_id == boss_enc and boss_layer > 0 and not _unique_left():
		var L := boss_layer
		boss_layer = 0
		boss_enc = -1
		boss_fallen.emit(L, en.position)
		if master_enc >= 0:
			_master_fallen()
		return
	if en.enc_id == master_enc and group_dead_fraction(master_enc) >= 1.0:
		_master_fallen()

## 層の主のユニークが、まだ残っているか(出ていないものも数える)
func _unique_left() -> bool:
	if spawner.pending.has(boss_enc):
		return true
	for e in enemies:
		if is_instance_valid(e) and e.unique and not e.dead and e.enc_id == boss_enc:
			return true
	return false

func room_center(rid: int) -> Vector2i:
	var c: Array = map.room_by_id[rid]["center"]
	return Vector2i(int(c[0]), int(c[1]))

## 主の間の主が倒れた: まわりの、まだ出ていない巣は逃げ散る(遠くの巣も少し)。画面の外の出来事なのでログで知らせる
func _master_fallen() -> void:
	var mc := Vector2i(-9999, -9999)
	for e in map.data["encounters"]:
		if int(e["id"]) == master_enc and map.room_by_id.has(int(e["roomId"])):
			mc = room_center(int(e["roomId"]))
	master_enc = -1
	var n := 0
	for eid in spawner.pending.keys():
		var e: Dictionary = spawner.pending[eid]
		var rid := int(e.get("roomId", -1))
		if rid < 0 or e.get("lair", false) or not map.room_by_id.has(rid):
			continue
		if Vector2(room_center(rid) - mc).length() <= MASTER_REACH or randf() < MASTER_SCATTER_ELSE:
			spawner.pending.erase(eid)
			enc_dead[eid] = int(enc_total.get(eid, 0))
			n += 1
	if n > 0:
		message.emit("主が倒れた。このあたりの巣の魔物が、気配を消して散っていく(%d組)。" % n, "info")
	else:
		message.emit("主が倒れた。", "info")
	stat.emit("master")

## 倒されずに、層からいなくなった(落とし穴)
func enemy_gone(en: Enemy) -> void:
	enc_dead[en.enc_id] = int(enc_dead.get(en.enc_id, 0)) + 1
	enemies.erase(en)

# ---------- 魔物を束ねる ----------

func alert_encounter(eid: int) -> void:
	for en in enemies:
		if en.enc_id == eid:
			en.wake()

func alert_radius(pos: Vector2, cells: float) -> void:
	for en in enemies:
		if en.position.distance_to(pos) <= cells * Balance.CELL:
			en.wake()

func group_dead_fraction(eid: int) -> float:
	var total: int = enc_total.get(eid, 1)
	return float(enc_dead.get(eid, 0)) / float(maxi(1, total))

## ダメージの数字。層の主との戦いの間は、モノクロの上に赤で描く(ken 10/18)
func spawn_damage(pos: Vector2, s: String, c: Color) -> void:
	if fx_overlay == null or not is_instance_valid(fx_overlay):
		spawn_text(pos, s, c)
		return
	var ft := FloatText.new()
	ft.text = s
	ft.color = Color("ff2a2a")
	ft.position = pos + position
	fx_overlay.add_child(ft)

func spawn_text(pos: Vector2, s: String, c: Color) -> void:
	var ft := FloatText.new()
	ft.text = s
	ft.color = c
	ft.position = pos
	add_child(ft)

func map_changed() -> void:
	queue_redraw()

func update_flow(pc: Vector2i) -> void:
	if pc != flow_cell:
		flow_cell = pc
		flow = map.compute_flow(pc.x, pc.y)

func cell_of(p: Vector2) -> Vector2i:
	return map.cell_of(p)

# ---------- 描画 ----------

const NEAR_SIM := 520.0     # これより遠い魔物は、押し合いの計算に入れない

func _near_hero(p: Vector2, r: float) -> bool:
	var r2 := r * r
	for h in heroes:
		if (h.position - p).length_squared() < r2:
			return true
	return false

func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(h & 255) / 255.0

func _refresh_tex() -> void:
	if _tex_ver == Assets.version:
		return
	_tex_ver = Assets.version
	var th := String(map.data["meta"].get("theme", ""))
	tex = {
		"floor": Assets.first(["floor_" + th, "floor"]),
		"wall": Assets.first(["wall_" + th, "wall"]),
		"corr": Assets.first(["corr_" + th, "corr", "floor_" + th, "floor"]),
		# ばらつき用(_2、_3)。置いた「floor」(1枚)があるときは使わず、その1枚だけで敷く
		"floor_v": _variants("floor", th),
		"wall_v": _variants("wall", th),
		"walltop": _walltop(th),
		"door": Assets.first(["door_" + th, "door"]),
		"door_open": Assets.first(["door_open_" + th, "door_open"]),
		"stairs_up": Assets.texture("icon_stairs_up"),
		"stairs_down": Assets.texture("icon_stairs_down"),
		"trap": Assets.texture("icon_trap"),
	}

## 「floor_舞台」「floor_舞台_2」「floor_舞台_3」…を集める。同梱の絵が小さい(ドット絵)ときは、ぼかさず拡大する
func _variants(kind: String, th: String) -> Array:
	var out: Array = []
	if Assets.texture(kind, false) != null and Assets.texture("%s_%s" % [kind, th], false) == null:
		return out
	for suffix in ["", "_2", "_3", "_4"]:
		var t := Assets.texture("%s_%s%s" % [kind, th, suffix], true)
		if t != null:
			out.append(t)
	return out

## 壁の天面。壁の絵だけを置き換えたときは、同梱の天面と食い違うので使わず、置いた壁の絵で通す
func _walltop(th: String) -> Texture2D:
	var user_top := Assets.first(["walltop_" + th, "walltop"], false)
	if user_top != null:
		return user_top
	if Assets.first(["wall_" + th, "wall"], false) != null:
		return null
	return Assets.texture("walltop_" + th, true)

func _is_rock(x: int, y: int) -> bool:
	return map.in_bounds(x, y) and map.tiles[map.idx(x, y)] == FloorMap.ROCK

func _pick(variants: Array, fallback: Texture2D, x: int, y: int) -> Texture2D:
	if variants.size() <= 1:
		return fallback
	# 1枚目を多めにして、ばらつきを控えめにする
	var h := _hash(x, y)
	return variants[0] if h < 0.7 else variants[1 + int((h - 0.7) / 0.3 * (variants.size() - 1)) % (variants.size() - 1)]

func _draw() -> void:
	_refresh_tex()
	# 小さな絵(ドット絵)は、ぼかさずに拡大する。大きな絵は、縮めたときにざらつかないようにぼかす
	var small: bool = tex["floor"] != null and tex["floor"].get_width() <= 64
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if small else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var C := float(Balance.CELL)
	var rock: Color = col.get("rock", Color("111111"))
	var floor_a: Color = col.get("floor", Color("444444"))
	var wall: Color = floor_a.darkened(0.5).lerp(rock.lightened(0.2), 0.3)   # 壁は床より暗く、未踏の黒とは区別がつく明るさ
	var floor_b: Color = col.get("floor2", Color("4a4a4a"))
	var corr: Color = col.get("corr", Color("3a3a3a"))
	var glow: Color = col.get("glow", Color("ffffaa"))
	var lc := Vector2(light_pos.x / C, light_pos.y / C)
	var R := float(Balance.LIGHT_RADIUS)
	# 広い層では、画面に入るマスだけを描く
	var vr := (get_global_transform().affine_inverse() * get_canvas_transform().affine_inverse()) * Rect2(Vector2.ZERO, get_viewport_rect().size)
	vr = vr.grow(C * 3.0)
	var cx0 := clampi(int(floor(vr.position.x / C)), 0, map.w - 1)
	var cx1 := clampi(int(ceil(vr.end.x / C)), 0, map.w - 1)
	var cy0 := clampi(int(floor(vr.position.y / C)), 0, map.h - 1)
	var cy1 := clampi(int(ceil(vr.end.y / C)), 0, map.h - 1)
	for y in range(cy0, cy1 + 1):
		for x in range(cx0, cx1 + 1):
			var i := y * map.w + x
			if map.explored[i] == 0:
				continue
			var vis := map.visible[i] == 1
			var f := 0.33
			if vis:
				var dd := Vector2(x + 0.5, y + 0.5).distance_to(lc)
				var rid := map.room_at[i]
				var lit: bool = rid >= 0 and map.room_by_id[rid].get("lit", false) and map.room_at[map.idx(int(lc.x), int(lc.y))] == rid
				f = 1.0 if lit else lerpf(1.0, 0.5, clampf((dd - 2.0) / R, 0.0, 1.0))
			var t := map.tiles[i]
			var rect := Rect2(x * C, y * C, C, C)
			if t == FloorMap.VOID:
				draw_rect(rect, Color.BLACK)      # 虚空(縦穴・竪坑の穴)。底は真っ黒で、何も見えない
				continue
			if t == FloorMap.WATER or t == FloorMap.SHALLOW:
				# 水路。深い水は暗い青、浅瀬は明るい青に平たい石
				var wc: Color = col.get("water", Color("163646")) if t == FloorMap.WATER else col.get("shallow", Color("2e6577"))
				draw_rect(rect, _shade(wc.lightened(_hash(x, y) * 0.08), f))
				if t == FloorMap.SHALLOW:
					draw_circle(rect.get_center() + Vector2(_hash(x, y) - 0.5, _hash(y, x) - 0.5) * C * 0.3, C * 0.2, _shade(Color(0.82, 0.8, 0.74), f))
				elif _hash(x, y) > 0.8:
					draw_circle(rect.get_center() + Vector2(_hash(y, x) - 0.5, _hash(x, y) - 0.5) * C * 0.4, C * 0.08, _shade(Color(0.55, 0.8, 0.9, 0.5), f))
				continue
			if t == FloorMap.PILLAR:
				# 柱(肋骨の柱、沈んだ列柱)。床の上に骨色の丸
				draw_rect(rect, _shade(corr, f))
				draw_circle(rect.get_center(), C * 0.36, _shade(Color(0.1, 0.09, 0.1), f))
				draw_circle(rect.get_center() - Vector2(1.0, 2.0), C * 0.3, _shade(Color(0.86, 0.82, 0.72), f))
				continue
			if t == FloorMap.ROCK:
				if map.wall_adj[i] == 1 and tex["wall"] != null:
					var face_side := tex["walltop"] == null or not _is_rock(x, y + 1)    # 南が床なら、壁の正面
					if face_side:
						draw_texture_rect(_pick(tex["wall_v"], tex["wall"], x, y), rect, false, _shade(Color.WHITE, f))
					else:
						draw_texture_rect(tex["walltop"], rect, false, _shade(Color.WHITE, f))
						# 床に面した縁に、細い明るい線(天面の角)
						var rim := _shade(Color(0.7, 0.7, 0.78), f)
						rim.a = 0.22
						for dv in FloorMap.DIRS4:
							if not _is_rock(x + dv.x, y + dv.y) and map.in_bounds(x + dv.x, y + dv.y):
								var a2 := rect.position + Vector2(C if dv.x > 0 else 0.0, C if dv.y > 0 else 0.0)
								draw_line(a2, a2 + (Vector2(0, C) if dv.x != 0 else Vector2(C, 0)), rim, 1.0)
				elif map.wall_adj[i] == 1:
					draw_rect(rect, _shade(wall, f))
					# 床に面した縁に明るい線を引いて、壁の輪郭を出す(差し替え画像のときは引かない)
					var edge := _shade(wall.lightened(0.45), f)
					for dv in FloorMap.DIRS4:
						var nx: int = x + dv.x
						var ny: int = y + dv.y
						if map.in_bounds(nx, ny) and map.tiles[map.idx(nx, ny)] != FloorMap.ROCK:
							var a := rect.position + Vector2(C if dv.x > 0 else 0.0, C if dv.y > 0 else 0.0)
							var b := a + (Vector2(0, C) if dv.x != 0 else Vector2(C, 0))
							draw_line(a, b, edge, 2.0)
				continue
			var base := corr if t == FloorMap.CORR else (floor_a if (x + y) % 2 == 0 else floor_b)
			base = base.lightened(_hash(x, y) * 0.06)
			if t == FloorMap.DOOR:
				var d: Dictionary = map.door_at[i]
				if d["type"] == "secret" and not d["found"]:
					if tex["wall"] != null:
						draw_texture_rect(tex["wall"], rect, false, _shade(Color.WHITE, f))
					else:
						draw_rect(rect, _shade(wall, f))
					continue
				if tex["corr"] != null:
					draw_texture_rect(tex["corr"], rect, false, _shade(Color.WHITE, f))
				else:
					draw_rect(rect, _shade(corr, f))
				_draw_door(d, rect, f)
				continue
			var ftex: Texture2D = tex["corr"] if t == FloorMap.CORR else _pick(tex["floor_v"], tex["floor"], x, y)
			if ftex != null:
				draw_texture_rect(ftex, rect, false, _shade(Color.WHITE, f))
			else:
				draw_rect(rect, _shade(base, f))
			# 壁の正面の真下の床に、影を落とす(壁が立って見える)
			if tex["walltop"] != null and map.wall_adj[map.idx(x, y - 1)] == 1 and _is_rock(x, y - 1):
				for k in 4:
					draw_rect(Rect2(rect.position.x, rect.position.y + k * 3.0, C, 3.0), Color(0, 0, 0, _shade(Color.WHITE, f).r * (0.42 - k * 0.1)))
	FloorProps.draw_decor(self, vr)
	RoomHooks.draw_marks(self, vr)
	# 階段
	_draw_stairs(up_cell, true, glow)
	if not arena and down_cell.x >= 0:
		_draw_stairs(down_cell, false, glow)
	for rc in ropes:
		var ri := map.idx(rc.x, rc.y)
		if map.explored[ri] == 1 and vr.has_point(map.center_of(rc)):
			_draw_rope(rc, 1.0 if map.visible[ri] == 1 else 0.4)
	FloorProps.draw(self, vr)
	if hot:
		_draw_heat(vr)
	# 蜘蛛の巣
	for i in webs:
		var wc := Vector2i(int(i) % map.w, int(i) / map.w)
		if map.explored[int(i)] == 0 or not vr.has_point(map.center_of(wc)):
			continue
		_draw_web(map.center_of(wc), 1.0 if map.visible[int(i)] == 1 else 0.45)
	# 落ちているもの(光る燐晶、自生物、遺体)
	ground.draw(self, vr)
	# 罠
	for t in traps:
		if t["st"] == "hidden":
			continue
		var tc := Vector2i(int(t["x"]), int(t["y"]))
		if map.explored[map.idx(tc.x, tc.y)] == 0:
			continue
		var cen := map.center_of(tc)
		if TrapFx.PERIODIC.has(t.get("fx", "")):
			continue          # 振り子と噴き口は、TrapFx が描く
		if t.get("fx", "") == "sink" and t["st"] == "triggered":
			# 沈んだ渡し石: 石が無くなって、水が丸く澄んでいる
			draw_circle(cen, C * 0.3, Color(0.12, 0.3, 0.4, 0.8))
			draw_arc(cen, C * 0.3, 0.0, TAU, 16, Color(0.6, 0.82, 0.95, 0.5), 1.0)
			continue
		if t.get("fx", "") == "pit" and t["st"] == "triggered":
			# 開いた穴
			draw_circle(cen, C * 0.42, Color(0, 0, 0, 0.85))
			draw_arc(cen, C * 0.42, 0.0, TAU, 20, Color(0.35, 0.28, 0.2, 0.9), 2.0)
			continue
		var a := 0.9 if t["st"] == "revealed" else 0.35
		if tex["trap"] != null:
			draw_texture_rect(tex["trap"], Rect2(cen - Vector2(C, C) / 2.0, Vector2(C, C)), false, Color(1, 1, 1, a))
			continue
		var cc2 := Color(0.9, 0.25, 0.2, a)
		draw_line(cen + Vector2(-8, -8), cen + Vector2(8, 8), cc2, 2.5)
		draw_line(cen + Vector2(-8, 8), cen + Vector2(8, -8), cc2, 2.5)

## 竜の気配: 縦穴の縁から立ちのぼる陽炎(吐く夜の夜の間、第7層から下)。底の赤い光は見せない(ken 10/17)ので、縁の床だけを揺らす
func _draw_heat(vr: Rect2) -> void:
	var sh: Dictionary = map.data.get("shaft", {})
	if not sh.has("x"):
		return
	var C := float(Balance.CELL)
	var hole := Rect2(float(sh["x"]) * C, float(sh["y"]) * C, float(sh["w"]) * C, float(sh["h"]) * C)
	if not vr.intersects(hole.grow(C * 3.0)):
		return
	var tms := float(Time.get_ticks_msec()) / 1000.0
	for k in 3:
		var r := hole.grow(C * (0.5 + k * 0.7))
		var a := (0.22 - k * 0.06) * (0.75 + 0.25 * sin(tms * 3.0 + k * 1.7))
		var pts := PackedVector2Array()
		var per := r.size.x * 2.0 + r.size.y * 2.0
		var n := 96
		for i in n + 1:
			var d := per * i / float(n)
			var p: Vector2
			if d < r.size.x:
				p = r.position + Vector2(d, 0)
			elif d < r.size.x + r.size.y:
				p = r.position + Vector2(r.size.x, d - r.size.x)
			elif d < r.size.x * 2.0 + r.size.y:
				p = r.end - Vector2(d - r.size.x - r.size.y, 0)
			else:
				p = Vector2(r.position.x, r.end.y - (d - r.size.x * 2.0 - r.size.y))
			p.y += sin(tms * 4.0 + i * 0.9 + k) * 2.5
			pts.append(p)
		draw_polyline(pts, Color(1.0, 0.62, 0.3, a), 3.0 - k * 0.6)

func _draw_web(c: Vector2, k: float) -> void:
	var col := Color(0.92, 0.92, 0.88, 0.55 * k)
	var r := Balance.CELL * 0.62
	var pts: Array = []
	for n in 7:
		var a := TAU * n / 7.0 + float(int(c.x * 7.0 + c.y) % 10) * 0.1
		var p := c + Vector2.from_angle(a) * r * (0.85 + 0.15 * float(n % 2))
		pts.append(p)
		draw_line(c, p, col, 1.0)
	for ring in [0.35, 0.65, 0.95]:
		for n in 7:
			var a2: Vector2 = c.lerp(pts[n], ring)
			var b2: Vector2 = c.lerp(pts[(n + 1) % 7], ring)
			draw_line(a2, b2, col, 1.0)

## 縄梯子: 縁の角の杭と、縦穴の角から闇へ垂れる縄
func _draw_rope(cell: Vector2i, f: float) -> void:
	var C := float(Balance.CELL)
	var cen := map.center_of(cell)
	var sc := map.center_of(map.shaft_center)
	var dir := Vector2(signf(sc.x - cen.x), signf(sc.y - cen.y))
	var corner := cen + dir * C * 0.5
	var post := cen - dir * C * 0.15
	var wood := _shade(Color(0.42, 0.3, 0.18), f)
	var rope := _shade(Color(0.72, 0.58, 0.38), f)
	draw_circle(post, 5.0, wood)
	draw_circle(post + Vector2(-1, -1), 3.0, _shade(Color(0.55, 0.4, 0.25), f))
	draw_arc(post, 7.5, 0.0, TAU, 14, rope, 1.6)
	draw_line(post, corner, rope, 2.2)
	draw_line(corner, corner + dir * C * 0.4, rope.darkened(0.6), 2.0)

func _shade(c: Color, f: float) -> Color:
	var k := f * 1.3
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0)

func _draw_door(d: Dictionary, rect: Rect2, f: float) -> void:
	var tall: bool = d["axis"] == "ew"       # 東西に抜ける扉は、縦長の板
	var dt: Texture2D = tex["door_open"] if d["open"] else tex["door"]
	if dt != null:
		var tint := _shade(Color.WHITE, f)
		if d["type"] == "locked" and not d["unlocked"]:
			tint = _shade(Color(1.0, 0.55, 0.5), f)
		elif d["type"] == "secret":
			tint = _shade(Color(0.6, 0.9, 1.0), f)
		if tall:
			draw_texture_rect(dt, rect, false, tint)
		else:                                  # 南北に抜ける扉は、90度回す
			draw_set_transform(rect.get_center(), PI / 2.0, Vector2.ONE)
			draw_texture_rect(dt, Rect2(-rect.size / 2.0, rect.size), false, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if d["type"] == "locked" and not d["unlocked"] and not d["open"]:
			draw_circle(rect.get_center(), 3.0, _shade(Color("e0c070"), f))
		return
	var c := Color("8a5a2b")
	if d["type"] == "locked" and not d["unlocked"]:
		c = Color("a8362b")
	elif d["type"] == "secret":
		c = Color("4aa0b0")
	c = _shade(c, f)
	var ctr := rect.get_center()
	if d["open"]:
		if tall:
			draw_rect(Rect2(rect.position.x + 1, rect.position.y, 4, rect.size.y), c)
		else:
			draw_rect(Rect2(rect.position.x, rect.position.y + 1, rect.size.x, 4), c)
	else:
		if tall:
			draw_rect(Rect2(ctr.x - 4, rect.position.y, 8, rect.size.y), c)
		else:
			draw_rect(Rect2(rect.position.x, ctr.y - 4, rect.size.x, 8), c)
		if d["type"] == "locked":
			draw_circle(ctr, 3.0, _shade(Color("e0c070"), f))

func _draw_stairs(cell: Vector2i, up: bool, glow: Color) -> void:
	if map.explored[map.idx(cell.x, cell.y)] == 0:
		return
	var C := float(Balance.CELL)
	var k := 1.0 if map.visible[map.idx(cell.x, cell.y)] == 1 else 0.5
	var c := Vector2((cell.x + 0.5) * C, (cell.y + 0.5) * C)
	var icon: Texture2D = tex["stairs_up"] if up else tex["stairs_down"]
	if icon != null:
		draw_texture_rect(icon, Rect2(c - Vector2(C, C) / 2.0, Vector2(C, C)), false, Color(k, k, k))
		return
	var col2 := _shade(glow, k)
	var pts := PackedVector2Array()
	if up:
		pts = PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 9), c + Vector2(-11, 9)])
	else:
		pts = PackedVector2Array([c + Vector2(0, 11), c + Vector2(11, -9), c + Vector2(-11, -9)])
	draw_colored_polygon(pts, Color(col2.r, col2.g, col2.b, 0.35))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col2, 2.0)
	UI.text_center(self, c.x, c.y + 4.0, "上" if up else "下", 11, col2)
