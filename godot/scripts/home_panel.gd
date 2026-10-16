class_name HomePanel
extends VBoxContainer
## 街の「我が家」の中身(TownScreen の右の欄)。部屋ごとの札で切り替える: 台所 / 寝床 / 食料庫 / 物置 / 実験室 / 増築。
## 左に一覧、右に説明と操作(店と同じ形)。仕組みは Home と Cooking。

var town: TownScreen
var gs: GameState
var room := "kitchen"
var sel := ""                  # 一覧で選んでいるもの(部屋ごとの印つき)
var keys: Array = []
var list: ItemList
var detail: RichTextLabel
var actions: VBoxContainer
var pots_box: VBoxContainer

func setup(t: TownScreen, state: GameState, r: String) -> void:
	town = t
	gs = state
	room = r
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()

func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var tabs := UIKit.hbox(6)
	for id in Home.ROOM_ORDER:
		if not Home.has_room(gs, id):
			continue
		var b := UIKit.button(String(Home.ROOMS[id]["name"]), _set_room.bind(id), 92)
		if id == room:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		tabs.add_child(b)
	var bb := UIKit.button("増築", _set_room.bind("build"), 92)
	if room == "build":
		bb.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
	tabs.add_child(bb)
	tabs.set_meta("modes", true)
	add_child(tabs)
	pots_box = UIKit.vbox(4)
	add_child(pots_box)
	var row := UIKit.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(360, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_pick)
	list.item_activated.connect(func(i):
		_on_pick(i)
		var f := town._first_focusable(actions)
		if f != null:
			f.grab_focus())
	list.set_meta("pref", true)
	row.add_child(list)
	var rv := UIKit.vbox(8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", 15)
	rv.add_child(detail)
	actions = UIKit.vbox(6)
	rv.add_child(actions)
	row.add_child(rv)
	_fill()

func _set_room(id: String) -> void:
	room = id
	sel = ""
	_build()
	town.call_deferred("_refocus_content")

## 操作のあと: 上の欄(預け金、HP)と、この欄を作り直す
func _after(line: String, col: Color = UIKit.GOOD) -> void:
	town._say(line, col)
	town.refresh_top()
	_build()
	town.call_deferred("_refocus_content")

func _add(key: String, text: String, icon: Texture2D = null, col: Color = Color(0, 0, 0, 0)) -> void:
	keys.append(key)
	list.add_item(text, icon)
	if col.a > 0.0:
		list.set_item_custom_fg_color(list.item_count - 1, col)

func _fill() -> void:
	keys = []
	list.clear()
	UIKit.clear(pots_box)
	match room:
		"kitchen": _fill_kitchen()
		"bed": _fill_bed()
		"pantry": _fill_pantry()
		"storage": _fill_storage()
		"lab": _fill_lab()
		"build": _fill_build()
	if sel != "" and keys.has(sel):
		list.select(keys.find(sel))
		list.ensure_current_is_visible()
	_show()

func _on_pick(i: int) -> void:
	if i < keys.size():
		sel = String(keys[i])
		_show()

func _show() -> void:
	UIKit.clear(actions)
	match room:
		"kitchen": _show_kitchen()
		"bed": _show_bed()
		"pantry": _show_pantry()
		"storage": _show_storage()
		"lab": _show_lab()
		"build": _show_build()

# ---------- 台所 ----------

func _fill_kitchen() -> void:
	var rs: Array = []
	for pass_i in 2:
		for r in Cooking.recipes():
			if Cooking.can_make(gs, r) == (pass_i == 0):
				rs.append(r)
	for r in rs:
		_add(String(r["id"]), String(r["name"]), ItemIcons.texture("dish_" + String(r["id"])), Color(0, 0, 0, 0) if Cooking.can_make(gs, r) else Color(0.55, 0.55, 0.6))

func _show_kitchen() -> void:
	var r := Cooking.recipe(sel)
	if r.is_empty():
		detail.text = "[color=#8a90a0]台所では、全部の料理を作れる(燃料も時間も要らない)。左の一覧から選ぶ。材料は、市場「灰の辻」か迷宮で。[/color]"
		return
	detail.text = Cooking.recipe_text(gs, r)
	var b := UIKit.button("作る", func():
		var res := Cooking.cook(gs, sel)
		gs.save()
		_after(String(res.get("msg", "")) if bool(res.get("ok", false)) else String(res.get("msg", "")), UIKit.GOOD if bool(res.get("ok", false)) else UIKit.BAD))
	b.disabled = not Cooking.can_make(gs, r)
	actions.add_child(b)

# ---------- 寝床 ----------

func _fill_bed() -> void:
	for c in gs.party:
		_add("", "%s  HP %d/%d  MP %d/%d  満腹 %d" % [c.name, int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp(), int(c.belly)], null, UIKit.BAD if c.hp <= 0.0 else Color(0, 0, 0, 0))

func _show_bed() -> void:
	detail.text = "壁下区の長屋の一間。薄い壁の向こうで、隣の家の子どもが寝言を言っている。\n\n[color=#8a90a0]眠ると、生きている仲間の HP と MP が全快する(無料)。倒れた仲間は、神殿で。[/color]"
	actions.add_child(UIKit.button("眠る(無料)", func():
		for c in gs.party:
			if c.hp > 0.0:
				c.hp = c.max_hp()
				c.mp = c.max_mp()
		gs.save()
		_after("自分の寝床で眠った。宿の寝床より、少しだけよく眠れた気がする。")))
	actions.add_child(UIKit.button("記録をつける(セーブ)", func(): town._say("記録をつけた。" if gs.save() else "記録に失敗した。", UIKit.GOOD)))

# ---------- 食料庫 ----------

func _fill_pantry() -> void:
	var now := gs.clock
	for i in gs.food.size():
		var s: Dictionary = gs.food[i]
		_add("f:%d" % i, "[持ち物] %s ×%d  %s" % [Cooking.stack_name(s, now), int(s["n"]), Cooking.left_text(s, now)], ItemIcons.texture("dish_" + String(s["id"])))
	var p: Array = gs.home["pantry"]
	for i in p.size():
		var s2 := Home.pantry_stack(p[i], now)
		_add("p:%d" % i, "[食料庫] %s ×%d  %s" % [Cooking.stack_name(s2, now), int(s2["n"]), Cooking.left_text(s2, now)], ItemIcons.texture("dish_" + String(s2["id"])),
			Color(0.62, 0.72, 0.42) if Cooking.rotten(s2, now) else Color("c8d8e8"))
	if keys.is_empty():
		_add("", "(料理がない)")

func _show_pantry() -> void:
	detail.text = "床下の、ひんやりした石の棚。[color=#8a90a0]しまった料理は、傷む速さが4分の1になる。持ち物の料理は、まるごとしまう・出す。[/color]"
	if sel.begins_with("f:"):
		var i := int(sel.substr(2))
		if i < gs.food.size():
			actions.add_child(UIKit.button("食料庫にしまう", func():
				Home.store_food(gs, i)
				sel = ""
				_after("食料庫の棚にしまった。", UIKit.TEXT)))
	elif sel.begins_with("p:"):
		var j := int(sel.substr(2))
		if j < (gs.home["pantry"] as Array).size():
			actions.add_child(UIKit.button("持ち物へ出す", func():
				Home.take_food(gs, j)
				sel = ""
				_after("食料庫から出した。", UIKit.TEXT)))

# ---------- 物置 ----------

func _fill_storage() -> void:
	for id in gs.item_ids():
		_add("i:" + String(id), "[持ち物] %s ×%d" % [ItemDB.item_name(id), gs.count(id)], ItemIcons.texture(id) if ItemIcons.has_icon(id) else null)
	var st: Dictionary = gs.home["storage"]
	var sk := st.keys()
	sk.sort()
	for id in sk:
		_add("s:" + String(id), "[物置] %s ×%d" % [ItemDB.item_name(id), int(st[id])], ItemIcons.texture(id) if ItemIcons.has_icon(id) else null, Color("c8d8e8"))
	if keys.is_empty():
		_add("", "(何もない)")

func _show_storage() -> void:
	detail.text = "戸口の脇の、鍵のかかる物置。[color=#8a90a0]預けたものは、全滅しても失わない。迷宮へは持っていけない。[/color]"
	if sel.begins_with("i:"):
		var id := sel.substr(2)
		detail.text += "\n\n[b]%s[/b]\n%s" % [ItemDB.item_name(id), ItemDB.detail(id)]
		actions.add_child(UIKit.button("1つ預ける", func(): Home.deposit(gs, id, 1); _after("%sを物置に入れた。" % ItemDB.item_name(id), UIKit.TEXT)))
		actions.add_child(UIKit.button("全部預ける", func(): Home.deposit(gs, id, gs.count(id)); _after("%sを全部、物置に入れた。" % ItemDB.item_name(id), UIKit.TEXT)))
	elif sel.begins_with("s:"):
		var id2 := sel.substr(2)
		detail.text += "\n\n[b]%s[/b]\n%s" % [ItemDB.item_name(id2), ItemDB.detail(id2)]
		actions.add_child(UIKit.button("1つ出す", func(): Home.withdraw(gs, id2, 1); _after("%sを物置から出した。" % ItemDB.item_name(id2), UIKit.TEXT)))
		actions.add_child(UIKit.button("全部出す", func(): Home.withdraw(gs, id2, 1 << 20); _after("%sを全部、物置から出した。" % ItemDB.item_name(id2), UIKit.TEXT)))

# ---------- 実験室 ----------

func _fill_lab() -> void:
	pots_box.add_child(UIKit.label("釜(%d / %d)%s" % [(gs.home["pots"] as Array).size(), Home.POTS, "   今夜は使えない(煤だらけ)" if Home.lab_closed(gs) else ""], 16, UIKit.ACCENT))
	var pots: Array = gs.home["pots"]
	for i in pots.size():
		var p: Dictionary = pots[i]
		var r := Home.alchemy_recipe(String(p["id"]))
		var row := UIKit.hbox(8)
		var left := int(p["ready"]) - gs.day
		row.add_child(UIKit.label("%s  %s" % [ItemDB.item_name(String(r["out"])), "仕上がっている" if left <= 0 else "あと%d夜" % left], 15, UIKit.GOOD if left <= 0 else UIKit.TEXT))
		if left <= 0:
			row.add_child(UIKit.button("取り出す", func(): _after(Home.collect(gs, i)), 100))
		pots_box.add_child(row)
	for pass_i in 2:
		for r2 in Home.alchemy():
			var ok := _can_brew(r2)
			if ok == (pass_i == 0):
				_add(String(r2["id"]), "%s%s" % [ItemDB.item_name(String(r2["out"])), "" if int(r2["nights"]) == 0 else "  (%d夜)" % int(r2["nights"])],
					ItemIcons.texture(String(r2["out"])), Color(0, 0, 0, 0) if ok else Color(0.55, 0.55, 0.6))

func _can_brew(r: Dictionary) -> bool:
	var need: Dictionary = r["in"]
	for k in need:
		if gs.count(String(k)) < int(need[k]):
			return false
	return true

func _show_lab() -> void:
	var r := Home.alchemy_recipe(sel)
	var al := Home.alchemist(gs)
	var who := "実験役: %s(〈魔法学〉%+d)" % [al.name, al.skill_bonus("arcana")] if al != null else ""
	if r.is_empty():
		detail.text = "棚に瓶と乾いた草が並ぶ、狭い実験室。\n\n[color=#8a90a0]すぐできる調合と、釜に仕込んで何夜か寝かせる熟成がある(迷宮から戻るたびに1夜)。1回に燃料(焚き木束・焼け石・白蝋)を1つ使う。難しさ +5 で上出来(1つ多くできる)、足りないと濁った薬、出目1は「ボフン!」(材料を失い、その夜は使えない)。[/color]\n\n" + who
		return
	var out := String(r["out"])
	var t := "[b][color=#e8dcb0]%s[/color][/b]  %s\n%s\n\n%s\n\n" % [ItemDB.item_name(out), "すぐできる" if int(r["nights"]) == 0 else "%d夜寝かせる" % int(r["nights"]), r["desc"], ItemDB.detail(out)]
	var need: Dictionary = r["in"]
	for k in need:
		var have := gs.count(String(k))
		t += "[color=%s]%s %d[/color](持っている %d)   " % ["#9be29b" if have >= int(need[k]) else "#ff8a7a", ItemDB.item_name(String(k)), int(need[k]), have]
	t += "\nできる数 %d   難しさ %d   燃料 1\n%s" % [int(r["n"]), int(r["dc"]), who]
	detail.text = t
	var b := UIKit.button("調合する" if int(r["nights"]) == 0 else "釜に仕込む", func():
		var res := Home.brew(gs, sel)
		var good := bool(res.get("ok", false)) and String(res.get("kind", "")) != "boom" and String(res.get("kind", "")) != "fail"
		_after(String(res.get("msg", "")), UIKit.GOOD if good else UIKit.BAD))
	b.disabled = not _can_brew(r) or Home.lab_closed(gs) or (int(r["nights"]) > 0 and Home.free_pots(gs) <= 0)
	actions.add_child(b)

# ---------- 増築 ----------

func _fill_build() -> void:
	for id in Home.ROOM_ORDER:
		var rm: Dictionary = Home.ROOMS[id]
		var have := Home.has_room(gs, id)
		_add(id, "%s  %s" % [rm["name"], "(ある)" if have else ("(準備中)" if rm.get("soon", false) else "%d銀貨" % int(rm["price"]))], null,
			UIKit.GOOD if have else (Color(0.55, 0.55, 0.6) if rm.get("soon", false) else Color(0, 0, 0, 0)))

func _show_build() -> void:
	if not Home.ROOMS.has(sel):
		detail.text = "[color=#8a90a0]長屋の大家に頼んで、部屋を足してもらう。左の一覧から選ぶ。[/color]"
		return
	var rm: Dictionary = Home.ROOMS[sel]
	detail.text = "[b][color=#e8dcb0]%s[/color][/b]\n%s" % [rm["name"], rm["desc"]]
	if Home.has_room(gs, sel) or rm.get("soon", false):
		return
	var id := sel
	var b := UIKit.button("増築する(%d銀貨)" % int(rm["price"]), func():
		var e := Home.build(gs, id)
		if e != "":
			town._say(e, UIKit.BAD)
			return
		room = id
		sel = ""
		_after("大家が職人を呼んだ。%sができた。(-%d銀貨)" % [rm["name"], int(rm["price"])]))
	b.disabled = gs.bank_silver < int(rm["price"])
	actions.add_child(b)
