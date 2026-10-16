class_name InventoryScreen
extends Control
## 持ち物(Tab)。アイテムを使う、装備を替える、スキルをショートカットに割り当てる、能力値を見る。
## 技能・特技: 技能の習熟を見る。レベルが上がったときの、能力値上昇・特技・熟達を選ぶ。
## 料理: 作った料理を食べる。迷宮の中では、野営で料理を作る(Cooking)。

signal closed

var gs: GameState
var special_handler: Callable = Callable()   # (id, Character) -> bool。灯油や帰還の札のように、迷宮の中で効くもの
var rest_handler: Callable = Callable()      # 迷宮の中だけ。「休む(野営)」
var rest_btn: Button
var save_btn: Button
var save_handler: Callable = Callable()      # 迷宮の中だけ。「記録をつける」(-> bool)
var cook_handler: Callable = Callable()      # 迷宮の中だけ。野営で料理する (rid) -> {ok, msg}(Main.cook_dish)
var eat_handler: Callable = Callable()       # 料理を食べる (i, Character) -> {ok, msg}(Main.eat_dish)
var food_mode := "eat"                       # 料理の欄: eat(食べる) / make(作る)
var reorder_handler: Callable = Callable()   # 隊列を入れ替えたあと、迷宮の中の並びを合わせる(Main)
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
var pick_key := ""            # 選んでいる最中の、能力値上昇・特技・熟達(asi4 など)
var half_mode := false        # 能力値 +1 を二つに分けている途中
var half_abil := ""           # +1 の一つ目

func open(state: GameState, special: Callable = Callable(), rest: Callable = Callable(), reorder: Callable = Callable()) -> void:
	gs = state
	reorder_handler = reorder
	special_handler = special
	rest_handler = rest
	rest_btn.visible = rest.is_valid()
	member = clampi(member, 0, gs.party.size() - 1)
	_refresh()

## 迷宮の中で、記録をつけられるようにする
func set_save(h: Callable) -> void:
	save_handler = h
	save_btn.visible = h.is_valid()

## 料理を食べる・作るの手続きを渡す(作るのは迷宮の中だけ)
func set_food(cook: Callable, eat: Callable) -> void:
	cook_handler = cook
	eat_handler = eat

func _on_save() -> void:
	if not save_handler.is_valid():
		return
	var ok: bool = save_handler.call()
	save_btn.text = "記録した" if ok else "記録できない"

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
	head.add_child(UIKit.label("%s か Esc で閉じる" % Controls.hint("inventory"), 14, UIKit.DIM))
	root.add_child(head)
	member_box = UIKit.hbox(8)
	root.add_child(member_box)
	var row := UIKit.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var tabs := UIKit.vbox(6)
	for t in [["item", "アイテム"], ["food", "料理"], ["equip", "装備"], ["skill", "スキル"], ["talent", "技能・特技"], ["status", "ステータス"]]:
		var b := UIKit.button(t[1], _set_tab.bind(t[0]), 150)
		tab_btns[t[0]] = b
		tabs.add_child(b)
		if t[0] == "item":
			b.call_deferred("grab_focus")
	rest_btn = UIKit.button("休む(野営)", func(): if rest_handler.is_valid(): rest_handler.call(), 150)
	rest_btn.tooltip_text = "6〜8時間休んで、HPとMPを戻す。寝込みを襲われることがある"
	rest_btn.visible = false
	tabs.add_child(rest_btn)
	save_btn = UIKit.button("記録をつける", _on_save, 150)
	save_btn.tooltip_text = "迷宮の中の、この場所から再開できるように記録する(タイトルの「つづきから」)"
	save_btn.visible = false
	tabs.add_child(save_btn)
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

func _unhandled_input(e: InputEvent) -> void:
	if not visible or e.is_echo():
		return
	if e.is_action_pressed("inventory") or e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		return
	if tab == "skill":
		for i in Character.SLOTS:
			if e.is_action_pressed("skill%d" % (i + 1)):
				get_viewport().set_input_as_handled()
				_assign(i)
				return

## 選んでいる仲間を、隊列の前(-1)か後ろ(+1)へ一つ動かす
func _move_member(d: int) -> void:
	var j := member + d
	if j < 0 or j >= gs.party.size():
		return
	var c: Character = gs.party[member]
	gs.party[member] = gs.party[j]
	gs.party[j] = c
	member = j
	if reorder_handler.is_valid():
		reorder_handler.call()
	msg.text = "%sを隊列の%d番目にした。" % [c.name, j + 1]
	_refresh()

func _ch() -> Character:
	return gs.party[member]

func _set_tab(t: String) -> void:
	tab = t
	sel_id = ""
	_end_pick()
	_refresh()

func _end_pick() -> void:
	pick_key = ""
	half_mode = false
	half_abil = ""

func _refresh() -> void:
	if gs == null:
		return
	UIKit.clear(member_box)
	for i in gs.party.size():
		var c: Character = gs.party[i]
		var star := "★" if not c.pending().is_empty() else ""
		var hg: String = {"hungry": "  空腹", "starving": "  腹ぺこ"}.get(c.hunger(), "")
		var b := UIKit.button("%s%s  Lv%d %s\nHP %d/%d  MP %d/%d%s" % [star, c.name, c.level, Jobs.CLASSES[c.cls]["name"], int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp(), hg], func(): member = i; sel_id = "" if tab != "food" else sel_id; _end_pick(); _refresh(), 210)
		b.custom_minimum_size = Vector2(210, 54)
		if i == member:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		if c.hp <= 0.0:
			b.add_theme_color_override("font_color", UIKit.BAD)
		member_box.add_child(b)
	if gs.party.size() > 1:
		var fwd := UIKit.button("◀ 前へ", _move_member.bind(-1), 90)
		fwd.tooltip_text = "選んでいる仲間を、隊列の一つ前へ(先頭が隊列の先頭)"
		fwd.disabled = member == 0
		member_box.add_child(fwd)
		var back := UIKit.button("後ろへ ▶", _move_member.bind(1), 90)
		back.tooltip_text = "選んでいる仲間を、隊列の一つ後ろへ"
		back.disabled = member == gs.party.size() - 1
		member_box.add_child(back)
	for k in tab_btns:
		(tab_btns[k] as Button).add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2) if k == tab else UIKit.box(Color(0.12, 0.13, 0.18, 0.95)))
	UIKit.clear(slot_box)
	UIKit.clear(action_box)
	item_list.clear()
	ids = []
	match tab:
		"item": _fill_items()
		"food": _fill_food()
		"equip": _fill_equip()
		"skill": _fill_skills()
		"talent": _fill_talent()
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
	for i in Character.SLOTS:
		var id := String(c.slots[i])
		var r := UIKit.hbox(6)
		var l := UIKit.label("[%d]" % (i + 1), 16, UIKit.ACCENT)
		l.custom_minimum_size = Vector2(36, 0)
		r.add_child(l)
		r.add_child(UIKit.label(c.skill_label(id) if id != "" else "(空き)", 16, UIKit.GOLD if id != "" else UIKit.DIM))
		slot_box.add_child(r)
	for id in c.skills:
		ids.append(id)
		var at := c.slots.find(id)
		var sk := c.skill_def(id)
		var nm := c.skill_label(id)
		if id == Character.WEAPON_SKILL:
			nm = "武器の技: " + nm
		item_list.add_item("%s%s  MP%d" % [("[%d] " % (at + 1)) if at >= 0 else "", nm, int(sk.get("mp", 0))])
	if sel_id != "" and ids.has(sel_id):
		item_list.select(ids.find(sel_id))

func _talent_add(id: String, txt: String, col: Color = Color(0, 0, 0, 0)) -> void:
	ids.append(id)
	item_list.add_item(txt)
	if col.a > 0.0:
		item_list.set_item_custom_fg_color(item_list.item_count - 1, col)

func _fill_talent() -> void:
	var c := _ch()
	if pick_key != "":
		_fill_pick(c)
	else:
		for e in c.pending():
			var what := "能力値上昇か特技を選ぶ" if e["kind"] == "asi" else "熟達する技能を選ぶ"
			_talent_add("pend:" + String(e["key"]), "★ Lv%d  %s" % [int(e["lv"]), what], UIKit.GOLD)
		var all: Array = Talents.SKILL_ORDER.duplicate()
		all.append("thieves_tools")
		for id in all:
			if id == "thieves_tools" and not c.proficient(id):
				continue
			var mark := "◎" if c.expert(id) else ("●" if c.proficient(id) else "・")
			_talent_add("skill:" + String(id), "%s %s  %+d" % [mark, Talents.skill_name(id), c.skill_bonus(id)],
				UIKit.TEXT if c.proficient(id) else UIKit.DIM)
		for f in c.feats():
			_talent_add("feat:" + String(f), "特技: %s" % Talents.FEATS[f]["name"], UIKit.ACCENT)
	if sel_id != "" and ids.has(sel_id):
		item_list.select(ids.find(sel_id))

## 能力値上昇・特技・熟達の候補
func _fill_pick(c: Character) -> void:
	var kind := ""
	for e in c.pending():
		if e["key"] == pick_key:
			kind = String(e["kind"])
	if kind == "":
		_end_pick()
		_fill_talent()
		return
	if kind == "expertise":
		var cand: Array = ["thieves_tools"]
		cand.append_array(Talents.SKILL_ORDER)
		for id in cand:
			if c.choice_error(pick_key, "exp:" + String(id)) == "":
				_talent_add("take:exp:" + String(id), "熟達: %s  %+d → %+d" % [Talents.skill_name(id), c.skill_bonus(id), c.skill_bonus(id) + c.prof_bonus()])
		return
	if half_mode and half_abil == "":
		for a in Jobs.ABILS:
			if int(c.stats[a]) < 20:
				_talent_add("half1:" + String(a), "+1(一つ目): %s %d → %d" % [Jobs.ABIL_JP[a], int(c.stats[a]), int(c.stats[a]) + 1])
		return
	if half_mode:
		for a in Jobs.ABILS:
			if a != half_abil and int(c.stats[a]) < 20:
				_talent_add("take:abil:%s+%s" % [half_abil, a], "+1(二つ目): %s %d → %d" % [Jobs.ABIL_JP[a], int(c.stats[a]), int(c.stats[a]) + 1])
		return
	for a in Jobs.ABILS:
		if int(c.stats[a]) <= 18:
			_talent_add("take:abil:" + String(a), "能力値 +2: %s %d → %d" % [Jobs.ABIL_JP[a], int(c.stats[a]), int(c.stats[a]) + 2])
	_talent_add("half", "能力値 +1 を二つに分ける…")
	for f in Talents.FEAT_ORDER:
		if not c.has_feat(f):
			_talent_add("take:feat:" + String(f), "特技: %s" % Talents.FEATS[f]["name"], UIKit.ACCENT)

func _fill_status() -> void:
	item_list.add_item("(下の欄に表示)")
	item_list.set_item_disabled(0, true)

func _on_pick(i: int) -> void:
	if i >= ids.size():
		return
	sel_id = String(ids[i])
	if tab == "talent":
		if sel_id.begins_with("pend:"):
			pick_key = sel_id.substr(5)
			sel_id = ""
			_refresh()
			return
		if sel_id == "half":
			half_mode = true
			sel_id = ""
			_refresh()
			return
		if sel_id.begins_with("half1:"):
			half_abil = sel_id.substr(6)
			sel_id = ""
			_refresh()
			return
	_show_detail()

func _show_detail() -> void:
	UIKit.clear(action_box)
	var c := _ch()
	var t := ""
	match tab:
		"status":
			t = _status_text(c)
		"talent":
			t = _talent_detail(c)
		"food":
			t = _food_detail(c)
		"skill":
			if sel_id == Character.WEAPON_SKILL and c.skill_def(sel_id).is_empty():
				t = "[b][color=#e8dcb0]武器の技[/color][/b]\n\n武器を持っていない。装備している武器の種類で、技が決まる。"
				for i in Character.SLOTS:
					action_box.add_child(UIKit.button("[%d]" % (i + 1), _assign.bind(i)))
				action_box.add_child(UIKit.button("外す", _unassign))
			elif sel_id != "" and not c.skill_def(sel_id).is_empty():
				var sk := c.skill_def(sel_id)
				t = "[b][color=#e8dcb0]%s[/color][/b]\nMP %d   再使用 %.1f秒\n\n%s\n\n[color=#8a90a0]数字キー 1〜6 か、下のボタンでスキル1〜6に割り当てる。戦闘中は数字キーか、Ctrl で選んで右クリックで使う。[/color]" % [c.skill_label(sel_id), sk["mp"], sk["cd"], sk["desc"]]
				if sel_id == Character.WEAPON_SKILL:
					t += "\n[color=#5bc0de]武器の技: 装備している武器の種類で変わる(珍しい武器は固有の技)。クラスの得意武器(%s)なら、威力が%.1f倍。[/color]" % [ItemDB.WEAPON_CAT_JP[c.class_data()["weapons"][0]], Balance.FAVORED_TECH]
				for i in Character.SLOTS:
					action_box.add_child(UIKit.button("[%d]" % (i + 1), _assign.bind(i)))
				action_box.add_child(UIKit.button("外す", _unassign))
			else:
				t = "スキルを選ぶ。戦闘中は、数字キー 1〜6 か、Ctrl で選んで右クリックで使う。"
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

func _talent_detail(c: Character) -> String:
	var t := ""
	if pick_key != "":
		var e_lv := int(pick_key.lstrip("asiexp").rstrip("ab"))
		if pick_key.begins_with("exp"):
			t = "[b][color=#e8dcb0]Lv%d 熟達[/color][/b]\n習熟している技能か盗賊道具を一つ選ぶ。その判定の習熟ボーナスが2倍になる。\n\n" % e_lv
		else:
			t = "[b][color=#e8dcb0]Lv%d 能力値上昇か特技[/color][/b]\n能力値を一つ +2 するか、二つを +1 ずつするか(20まで)、特技を一つ選ぶ。\n\n" % e_lv
			if half_mode:
				t += "[color=#5bc0de]+1 を二つ: %s[/color]\n\n" % ("一つ目を選ぶ" if half_abil == "" else "一つ目は%s。二つ目を選ぶ" % Jobs.ABIL_JP[half_abil])
		if sel_id.begins_with("take:"):
			var take := sel_id.substr(5)
			if take.begins_with("feat:"):
				var f: Dictionary = Talents.FEATS[take.substr(5)]
				t += "[b]%s[/b]\n%s\n" % [f["name"], f["desc"]]
			elif take.begins_with("exp:"):
				var id := take.substr(4)
				t += "[b]%s[/b]\n%s\n" % [Talents.skill_name(id), (Talents.SKILLS[id]["desc"] if Talents.SKILLS.has(id) else Talents.TOOLS[id]["desc"])]
			else:
				t += "[b]%s[/b]\n" % "、".join(Array(take.substr(5).split("+")).map(func(a): return Jobs.ABIL_JP[a]))
			var err := c.choice_error(pick_key, take)
			if err == "":
				action_box.add_child(UIKit.button("これにする", _take_sel))
			else:
				t += "\n[color=#ff8a7a]%s[/color]" % err
		else:
			t += "[color=#8a90a0]左の一覧から選ぶ。[/color]"
		action_box.add_child(UIKit.button("やめる", func(): _end_pick(); sel_id = ""; _refresh()))
		return t
	if sel_id.begins_with("skill:"):
		var id := sel_id.substr(6)
		var abil := String(Talents.SKILLS[id]["abil"]) if Talents.SKILLS.has(id) else String(Talents.TOOLS[id]["abil"])
		t = "[b][color=#e8dcb0]%s[/color][/b]  【%s】\n" % [Talents.skill_name(id), Jobs.ABIL_JP[abil]]
		t += "判定 %+d = 補正 %+d%s%s\n\n" % [c.skill_bonus(id), c.mod(abil),
			(" + 習熟 %d" % c.prof_bonus()) if c.proficient(id) else "(習熟していない)",
			(" + 熟達 %d" % c.prof_bonus()) if c.expert(id) else ""]
		t += String(Talents.SKILLS[id]["desc"]) if Talents.SKILLS.has(id) else String(Talents.TOOLS[id]["desc"])
		if Talents.SKILLS.has(id) and float(Talents.SKILLS[id]["fx"]) < 1.0:
			t += "\n[color=#5bc0de]いまの効き目: %d%%[/color]" % int(round(c.skill_fx(id) * 100))
		elif id == "performance":
			t += "\n[color=#5bc0de]いまの効き目: %d銀貨[/color]" % int(c.skill_fx(id))
		return t
	if sel_id.begins_with("feat:"):
		var f2: Dictionary = Talents.FEATS[sel_id.substr(5)]
		return "[b][color=#e8dcb0]特技: %s[/color][/b]\n%s" % [f2["name"], f2["desc"]]
	t = "[b]技能・特技[/b]  習熟ボーナス +%d\n● 習熟  ◎ 熟達(習熟ボーナス2倍)\n\n" % c.prof_bonus()
	if not c.pending().is_empty():
		t += "[color=#e8dcb0]★ の行を選ぶと、能力値上昇・特技・熟達を選べる。[/color]\n\n"
	t += "[color=#8a90a0]技能を選ぶと、迷宮での効き目が出る。[/color]"
	return t

func _take_sel() -> void:
	var c := _ch()
	var take := sel_id.substr(5)
	var err := c.choose(pick_key, take)
	msg.text = err if err != "" else "%sが選んだ: %s" % [c.name, _take_label(take)]
	msg.add_theme_color_override("font_color", UIKit.GOOD if err == "" else UIKit.BAD)
	if err == "":
		_end_pick()
		sel_id = ""
	_refresh()

func _take_label(take: String) -> String:
	if take.begins_with("feat:"):
		return "特技「%s」" % Talents.FEATS[take.substr(5)]["name"]
	if take.begins_with("exp:"):
		return "%sに熟達" % Talents.skill_name(take.substr(4))
	var parts := take.substr(5).split("+")
	if parts.size() == 1:
		return "%s +2" % Jobs.ABIL_JP[parts[0]]
	return "%s +1、%s +1" % [Jobs.ABIL_JP[parts[0]], Jobs.ABIL_JP[parts[1]]]

func _status_text(c: Character) -> String:
	var t := "[b][color=#e8dcb0]%s[/color][/b]  %s・%s  Lv%d\n" % [c.name, Jobs.RACES[c.race]["name"], Jobs.CLASSES[c.cls]["name"], c.level]
	t += "経験点 %d / %d\n\n" % [c.xp, c.xp_for_next()]
	t += "HP [b]%d / %d[/b]    MP [b]%d / %d[/b]\n" % [int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp()]
	t += "体当たり [b]%.1f[/b]/秒    防御 [b]%d[/b](軽減 %d%%)\n" % [c.bump_power(), c.armor_class(), int(c.damage_reduction() * 100)]
	t += "足の速さ [b]%d[/b]    重さ [b]%.2f[/b]\n\n" % [int(c.speed()), c.mass()]
	for a in Jobs.ABILS:
		t += "%s [b]%d[/b](%+d)   " % [Jobs.ABIL_JP[a], c.stats[a], c.mod(a)]
	t += "\n\n習熟ボーナス +%d    受動〈知覚〉 %d    探る %+d    解錠 %+d\n" % [c.prof_bonus(), c.passive_perception(), c.search_bonus(), c.lock_bonus()]
	var sv: Array = []
	for a in Jobs.ABILS:
		sv.append("%s%s %+d" % ["●" if c.save_proficient(a) else "", Jobs.ABIL_JP[a], c.save_bonus(a)])
	t += "セーヴ: %s\n" % "  ".join(sv)
	var fs: Array = c.feats().map(func(f): return Talents.FEATS[f]["name"])
	t += "特技: %s" % ("、".join(fs) if not fs.is_empty() else "なし")
	t += "\n\n" + _belly_text(c)
	if not c.pending().is_empty():
		t += "\n[color=#e8dcb0]★ 選んでいない能力値上昇・特技・熟達がある(「技能・特技」で選ぶ)[/color]"
	if not c.birth.is_empty():
		t += "\n\n[color=#8a90a0]生い立ち: %s[/color]" % Birth.text(c.birth)
	return t

# ---------- 料理 ----------

static func _food_key(s: Dictionary) -> String:
	return "f:%s|%d|%d" % [s["id"], int(s["q"]), int(round(float(s["until"])))]

func _food_index(key: String) -> int:
	for i in gs.food.size():
		if _food_key(gs.food[i]) == key:
			return i
	return -1

func _fill_food() -> void:
	var mb := UIKit.hbox(8)
	for m in [["eat", "食べる"], ["make", "作る"]]:
		var b := UIKit.button(m[1], func(): food_mode = m[0]; sel_id = ""; _refresh(), 110)
		if food_mode == m[0]:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		mb.add_child(b)
	slot_box.add_child(mb)
	var now := gs.clock
	if food_mode == "eat":
		for s in gs.food:
			var key := _food_key(s)
			ids.append(key)
			var bad := Cooking.rotten(s, now)
			item_list.add_item("%s ×%d   %s" % [Cooking.stack_name(s, now), int(s["n"]), Cooking.left_text(s, now)], ItemIcons.texture("dish_" + String(s["id"])))
			if bad:
				item_list.set_item_custom_fg_color(item_list.item_count - 1, Color(0.62, 0.72, 0.42))
				item_list.set_item_icon_modulate(item_list.item_count - 1, Color(0.55, 0.75, 0.4))
			elif int(s["q"]) == Cooking.Q_GREAT:
				item_list.set_item_custom_fg_color(item_list.item_count - 1, UIKit.GOLD)
			elif int(s["q"]) == Cooking.Q_BURNT:
				item_list.set_item_icon_modulate(item_list.item_count - 1, Color(0.45, 0.4, 0.38))
		if ids.is_empty():
			item_list.add_item("(料理がない。「作る」で作る)")
			item_list.set_item_disabled(0, true)
	else:
		# 作れるもの → 野営で作れるもの → 台所のもの(それぞれ、データの順)
		var rs: Array = []
		for pass_i in 3:
			for r in Cooking.recipes():
				var ok_r := Cooking.can_make(gs, r) and not bool(r["home"])
				if (pass_i == 0 and ok_r) or (pass_i == 1 and not ok_r and not bool(r["home"])) or (pass_i == 2 and bool(r["home"])):
					rs.append(r)
		for r in rs:
			ids.append("r:" + String(r["id"]))
			var ok := Cooking.can_make(gs, r)
			var where := "[台所] " if bool(r["home"]) else ""
			item_list.add_item("%s%s%s" % ["" if ok else "  ", where, r["name"]], ItemIcons.texture("dish_" + String(r["id"])))
			if not ok or (bool(r["home"]) or not cook_handler.is_valid()):
				item_list.set_item_custom_fg_color(item_list.item_count - 1, Color(0.55, 0.55, 0.6) if not ok else Color(0.72, 0.68, 0.6))
	if sel_id != "" and ids.has(sel_id):
		item_list.select(ids.find(sel_id))
		item_list.ensure_current_is_visible()

func _belly_text(c: Character) -> String:
	var hg: String = {"full": "満腹", "ok": "ふつう", "hungry": "[color=#ffb070]空腹[/color]", "starving": "[color=#ff7a6a]腹ぺこ(力と足が落ちる)[/color]"}[c.hunger()]
	var t := "%s の満腹 [b]%d[/b] / 100  %s" % [c.name, int(c.belly), hg]
	if c.meal_active():
		var left := (float(c.meal["until"]) - gs.clock) / 60.0
		t += "\n料理の効き目: [color=#9be29b]%s[/color](あと%d時間)" % [Cooking.buff_text(String(c.meal["buff"]), float(c.meal["v"])), int(ceil(left))]
	else:
		t += "\n料理の効き目: なし"
	return t

func _food_detail(c: Character) -> String:
	var t := ""
	var now := gs.clock
	if sel_id.begins_with("f:"):
		var i := _food_index(sel_id)
		if i >= 0:
			var s: Dictionary = gs.food[i]
			var r := Cooking.recipe(String(s["id"]))
			t = "[b][color=#e8dcb0]%s[/color][/b]  ×%d   %s\n%s\n\n" % [Cooking.stack_name(s, now), int(s["n"]), Cooking.left_text(s, now), r.get("desc", "")]
			if Cooking.rotten(s, now):
				t += "[color=#a8c070]くさっている。食べると腹を下す(迷宮では毒のように HP が減る)。売れない。[/color]"
			else:
				var q := int(s["q"])
				t += "満腹 +%d\n" % int(round(float(r["belly"]) * (0.6 if q == Cooking.Q_BURNT else 1.0)))
				if q == Cooking.Q_BURNT:
					t += "焦げていて、効き目はない。"
				else:
					var hrs := float(r["hours"]) * (1.5 if q == Cooking.Q_GREAT else 1.0)
					t += Cooking.buff_text(String(r["buff"]), float(r["v"])) + ("(%d時間)" % int(round(hrs)) if String(r["buff"]) != "" else "")
				t += "\n[color=#8a90a0]効き目は一人一つ。新しく食べると、前の効き目は消える。[/color]"
			if eat_handler.is_valid():
				var b := UIKit.button("%sが食べる" % c.name, _eat_sel)
				b.disabled = c.hp <= 0.0
				action_box.add_child(b)
	elif sel_id.begins_with("r:"):
		var r := Cooking.recipe(sel_id.substr(2))
		if not r.is_empty():
			t = Cooking.recipe_text(gs, r)
			if bool(r["home"]):
				t += "\n\n[color=#c8b890]自宅の台所で作る(自宅は、坑口館の空き家の札で買える)。[/color]"
			elif cook_handler.is_valid():
				t += "\n\n[color=#8a90a0]野営で作る: 20分かかる。燃料(焚き木束・焼け石・白蝋)1つで、火が1時間もつ。[/color]"
				var b := UIKit.button("作る", _cook_sel)
				b.disabled = not Cooking.can_make(gs, r)
				action_box.add_child(b)
			else:
				t += "\n\n[color=#8a90a0]迷宮の中で(野営)作れる。[/color]"
	else:
		t = "[color=#8a90a0]左の一覧から選ぶ。[/color]"
	if food_mode == "eat":
		var bad := 0
		for s in gs.food:
			if Cooking.rotten(s, now):
				bad += int(s["n"])
		if bad > 0:
			action_box.add_child(UIKit.button("くさったものを捨てる(%d皿)" % bad, func():
				msg.text = "くさった料理を%d皿捨てた。" % gs.throw_rotten()
				sel_id = ""
				_refresh()))
	return t + "\n\n" + _belly_text(c)

func _eat_sel() -> void:
	var i := _food_index(sel_id)
	if i < 0 or not eat_handler.is_valid():
		return
	var res: Dictionary = eat_handler.call(i, _ch())
	msg.text = String(res.get("msg", ""))
	msg.add_theme_color_override("font_color", UIKit.GOOD if bool(res.get("ok", false)) and not bool(res.get("rotten", false)) else UIKit.BAD)
	if _food_index(sel_id) < 0:
		sel_id = ""
	_refresh()

func _cook_sel() -> void:
	if not cook_handler.is_valid():
		return
	var res: Dictionary = cook_handler.call(sel_id.substr(2))
	msg.text = String(res.get("msg", ""))
	msg.add_theme_color_override("font_color", UIKit.GOOD if bool(res.get("ok", false)) else UIKit.BAD)
	_refresh()

# ---------- 操作 ----------

func _use_sel() -> void:
	var c := _ch()
	var it: Dictionary = ItemDB.ITEMS[sel_id]
	var r := ""
	if String(it["kind"]) == "consumable" and special_handler.is_valid() and ["light", "return", "buff", "cure", "sleep_throw", "shriek"].has(String(it["use"])):
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
	if tab != "skill" or sel_id == "" or not _ch().skills.has(sel_id):
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
