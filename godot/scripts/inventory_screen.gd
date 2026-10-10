class_name InventoryScreen
extends Control
## 持ち物(Tab)。アイテムを使う、装備を替える、スキルをショートカットに割り当てる、能力値を見る。

signal closed

var gs: GameState
var special_handler: Callable = Callable()   # (id, Character) -> bool。灯油や帰還の札のように、迷宮の中で効くもの
var tab := "item"
var member := 0
var ids: Array = []
var sel_id := ""
var tab_btns := {}
var member_box: HBoxContainer
var slot_box: VBoxContainer
var item_list: ItemList
var detail: RichTextLabel
var action_box: HBoxContainer
var msg: Label

func open(state: GameState, special: Callable = Callable()) -> void:
	gs = state
	special_handler = special
	member = clampi(member, 0, gs.party.size() - 1)
	_refresh()

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 40)
	add_child(margin)
	var root := UIKit.vbox(10)
	margin.add_child(root)
	var head := UIKit.hbox(16)
	head.add_child(UIKit.label("持ち物", 28, UIKit.GOLD))
	head.add_child(UIKit.label("Tab / Esc で閉じる", 14, UIKit.DIM))
	root.add_child(head)
	member_box = UIKit.hbox(8)
	root.add_child(member_box)
	var row := UIKit.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var tabs := UIKit.vbox(6)
	for t in [["item", "アイテム"], ["equip", "装備"], ["skill", "スキル"], ["status", "ステータス"]]:
		var b := UIKit.button(t[1], _set_tab.bind(t[0]), 150)
		tab_btns[t[0]] = b
		tabs.add_child(b)
	row.add_child(tabs)
	var mid := UIKit.vbox(6)
	mid.custom_minimum_size = Vector2(380, 0)
	slot_box = UIKit.vbox(4)
	mid.add_child(slot_box)
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_pick)
	mid.add_child(item_list)
	row.add_child(mid)
	var right := UIKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := UIKit.vbox(8)
	right.add_child(rv)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", 15)
	rv.add_child(detail)
	action_box = UIKit.hbox(8)
	rv.add_child(action_box)
	row.add_child(right)
	msg = UIKit.label("", 15, UIKit.GOOD)
	root.add_child(msg)

func _unhandled_key_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_TAB or e.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif e is InputEventKey and e.pressed and not e.echo and tab == "skill" and e.keycode >= KEY_1 and e.keycode <= KEY_4:
		_assign(e.keycode - KEY_1)

func _ch() -> Character:
	return gs.party[member]

func _set_tab(t: String) -> void:
	tab = t
	sel_id = ""
	_refresh()

func _refresh() -> void:
	if gs == null:
		return
	UIKit.clear(member_box)
	for i in gs.party.size():
		var c: Character = gs.party[i]
		var b := UIKit.button("%s  Lv%d %s\nHP %d/%d  MP %d/%d" % [c.name, c.level, Jobs.CLASSES[c.cls]["name"], int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp()], func(): member = i; sel_id = ""; _refresh(), 210)
		b.custom_minimum_size = Vector2(210, 54)
		if i == member:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		if c.hp <= 0.0:
			b.add_theme_color_override("font_color", UIKit.BAD)
		member_box.add_child(b)
	for k in tab_btns:
		(tab_btns[k] as Button).add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2) if k == tab else UIKit.box(Color(0.12, 0.13, 0.18, 0.95)))
	UIKit.clear(slot_box)
	UIKit.clear(action_box)
	item_list.clear()
	ids = []
	match tab:
		"item": _fill_items()
		"equip": _fill_equip()
		"skill": _fill_skills()
		"status": _fill_status()
	_show_detail()

func _fill_items() -> void:
	for id in gs.item_ids():
		var k := String(ItemDB.ITEMS[id]["kind"])
		if k == "consumable" or k == "tome" or k == "material":
			ids.append(id)
			item_list.add_item("%s  ×%d" % [ItemDB.item_name(id), gs.count(id)], ItemIcons.texture(id))
	if ids.is_empty():
		item_list.add_item("(使えるものがない)")
		item_list.set_item_disabled(0, true)
	elif sel_id != "" and ids.has(sel_id):
		item_list.select(ids.find(sel_id))

func _fill_equip() -> void:
	var c := _ch()
	for slot in [["weapon", "武器"], ["armor", "防具"], ["acc", "装飾"]]:
		var r := UIKit.hbox(6)
		var l := UIKit.label(slot[1], 15, UIKit.DIM)
		l.custom_minimum_size = Vector2(44, 0)
		r.add_child(l)
		var cur := String(c.equip[slot[0]])
		var l2 := UIKit.label(ItemDB.item_name(cur) if cur != "" else "(なし)", 16, UIKit.GOLD if cur != "" else UIKit.DIM)
		l2.custom_minimum_size = Vector2(200, 0)
		r.add_child(l2)
		var s: String = slot[0]
		var b := UIKit.button("外す", func(): gs.unequip(c, s); msg.text = ""; _refresh())
		b.disabled = cur == ""
		r.add_child(b)
		slot_box.add_child(r)
	for id in gs.item_ids():
		var k := String(ItemDB.ITEMS[id]["kind"])
		if k == "weapon" or k == "armor" or k == "acc":
			ids.append(id)
			var ok := ItemDB.can_equip(id, c.cls)
			item_list.add_item("%s%s  ×%d" % ["" if ok else "× ", ItemDB.item_name(id), gs.count(id)])
			if not ok:
				item_list.set_item_custom_fg_color(item_list.item_count - 1, Color(0.5, 0.5, 0.55))
	if sel_id != "" and ids.has(sel_id):
		item_list.select(ids.find(sel_id))

func _fill_skills() -> void:
	var c := _ch()
	for i in 4:
		var id := String(c.slots[i])
		var r := UIKit.hbox(6)
		var l := UIKit.label("[%d]" % (i + 1), 16, UIKit.ACCENT)
		l.custom_minimum_size = Vector2(36, 0)
		r.add_child(l)
		r.add_child(UIKit.label(String(Jobs.SKILLS[id]["name"]) if id != "" else "(空き)", 16, UIKit.GOLD if id != "" else UIKit.DIM))
		slot_box.add_child(r)
	for id in c.skills:
		ids.append(id)
		var at := c.slots.find(id)
		item_list.add_item("%s%s  MP%d" % [("[%d] " % (at + 1)) if at >= 0 else "", Jobs.SKILLS[id]["name"], Jobs.SKILLS[id]["mp"]])
	if sel_id != "" and ids.has(sel_id):
		item_list.select(ids.find(sel_id))

func _fill_status() -> void:
	item_list.add_item("(下の欄に表示)")
	item_list.set_item_disabled(0, true)

func _on_pick(i: int) -> void:
	if i < ids.size():
		sel_id = String(ids[i])
		_show_detail()

func _show_detail() -> void:
	UIKit.clear(action_box)
	var c := _ch()
	var t := ""
	match tab:
		"status":
			t = _status_text(c)
		"skill":
			if sel_id != "" and Jobs.SKILLS.has(sel_id):
				var sk: Dictionary = Jobs.SKILLS[sel_id]
				t = "[b][color=#e8dcb0]%s[/color][/b]\nMP %d   再使用 %.1f秒\n\n%s\n\n[color=#8a90a0]数字キー 1〜4 か、下のボタンでショートカットに割り当てる。[/color]" % [sk["name"], sk["mp"], sk["cd"], sk["desc"]]
				for i in 4:
					action_box.add_child(UIKit.button("[%d]" % (i + 1), _assign.bind(i)))
				action_box.add_child(UIKit.button("外す", _unassign))
			else:
				t = "スキルを選ぶ。戦闘中は、数字キー 1〜4 で使う。"
		_:
			if sel_id != "" and ItemDB.ITEMS.has(sel_id):
				t = "[b][color=#e8dcb0]%s[/color][/b]  所持 %d\n%s" % [ItemDB.item_name(sel_id), gs.count(sel_id), ItemDB.detail(sel_id)]
				if tab == "equip":
					if ItemDB.can_equip(sel_id, c.cls):
						t += "\n\n[color=#5bc0de]%s が装備すると[/color]\n%s" % [c.name, c.compare_equip(sel_id)]
						action_box.add_child(UIKit.button("%sに装備する" % c.name, _equip_sel))
					else:
						t += "\n\n[color=#ff8a7a]%s は装備できない[/color]" % Jobs.CLASSES[c.cls]["name"]
				else:
					action_box.add_child(UIKit.button("%sに使う" % c.name, _use_sel))
			else:
				t = "[color=#8a90a0]左の一覧から選ぶ。[/color]"
	detail.text = t

func _status_text(c: Character) -> String:
	var t := "[b][color=#e8dcb0]%s[/color][/b]  %s・%s  Lv%d\n" % [c.name, Jobs.RACES[c.race]["name"], Jobs.CLASSES[c.cls]["name"], c.level]
	t += "経験点 %d / %d\n\n" % [c.xp, c.xp_for_next()]
	t += "HP [b]%d / %d[/b]    MP [b]%d / %d[/b]\n" % [int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp()]
	t += "体当たり [b]%.1f[/b]/秒    防御 [b]%d[/b](軽減 %d%%)\n" % [c.bump_power(), c.armor_class(), int(c.damage_reduction() * 100)]
	t += "足の速さ [b]%d[/b]    重さ [b]%.2f[/b]\n\n" % [int(c.speed()), c.mass()]
	for a in Jobs.ABILS:
		t += "%s [b]%d[/b](%+d)   " % [Jobs.ABIL_JP[a], c.stats[a], c.mod(a)]
	t += "\n\n罠・隠し扉の探知 +%d    解錠 +%d" % [c.search_bonus(), c.lock_bonus()]
	return t

# ---------- 操作 ----------

func _use_sel() -> void:
	var c := _ch()
	var it: Dictionary = ItemDB.ITEMS[sel_id]
	var r := ""
	if String(it["kind"]) == "consumable" and special_handler.is_valid() and ["light", "return", "buff"].has(String(it["use"])):
		if special_handler.call(sel_id, c):
			gs.remove_item(sel_id)
			r = "%sを使った" % it["name"]
	else:
		r = gs.use_item(sel_id, c)
	msg.text = r if r != "" else "いまは使えない"
	msg.add_theme_color_override("font_color", UIKit.GOOD if r != "" else UIKit.BAD)
	if gs.count(sel_id) <= 0:
		sel_id = ""
	_refresh()

func _equip_sel() -> void:
	var r := gs.equip(_ch(), sel_id)
	msg.text = r if r != "" else "装備した"
	msg.add_theme_color_override("font_color", UIKit.GOOD if r == "" else UIKit.BAD)
	if gs.count(sel_id) <= 0:
		sel_id = ""
	_refresh()

func _assign(i: int) -> void:
	if tab != "skill" or sel_id == "" or not Jobs.SKILLS.has(sel_id):
		return
	var c := _ch()
	var old := c.slots.find(sel_id)
	if old >= 0:
		c.slots[old] = c.slots[i]
	c.slots[i] = sel_id
	_refresh()

func _unassign() -> void:
	var c := _ch()
	var at := c.slots.find(sel_id)
	if at >= 0:
		c.slots[at] = ""
	_refresh()
