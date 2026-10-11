class_name CharaMake
extends Control
## キャラクター作成。最大4人のパーティを、名前、種族、クラス、能力値(ポイントバイ27点)で作る。
## 「おまかせ」でクラスに合った配分になる。

signal finished(chars: Array)
signal cancelled

const NAMES := ["アルド", "セラ", "ロカ", "ミナ", "ガロ", "イルマ", "ティオ", "ネリ", "ダルク", "フィーネ", "ボルグ", "ユナ",
	"カイ", "リーゼ", "ハンス", "ルカ", "ベルナ", "オルト", "シェリ", "グレン", "マルタ", "ノエ", "ヴィクト", "ラナ"]
const DEFAULT_PARTY := [["fighter", "human", "M"], ["cleric", "dwarf", "F"], ["wizard", "elf", "M"], ["rogue", "halfling", "F"]]
const RACE_IDS := ["human", "elf", "dwarf", "halfling"]
const CLASS_IDS := ["fighter", "barbarian", "rogue", "wizard", "cleric", "ranger"]

var slots: Array = []        # {use, name, race, cls, look, stats, picks, birth}
var sel := 0
var _updating := false
var slot_box: VBoxContainer
var name_edit: LineEdit
var race_opt: OptionButton
var look_opt: OptionButton
var class_opt: OptionButton
var use_check: CheckBox
var stat_rows := {}          # abil → {val, bonus, minus, plus}
var points_label: Label
var preview: RichTextLabel
var prof_label: Label
var prof_checks := {}        # 技能id → CheckBox
var birth_opts := {}         # 生まれ表の key → OptionButton
var msg: Label
var start_btn: Button
var form: VBoxContainer

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TownArt.new()
	art.style = "inn"
	art.asset_key = "bg_charamake"
	add_child(art)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	for i in Balance.MAX_PARTY:
		var d: Array = DEFAULT_PARTY[i]
		var b := Birth.roll()
		slots.append({"use": true, "name": NAMES[(i * 5 + 1) % NAMES.size()], "race": d[1], "cls": d[0], "look": d[2], "stats": Jobs.auto_stats(d[0]),
			"birth": b, "picks": Birth.apply_to_picks(b, d[0], d[1], Talents.default_picks(d[0], d[1]))})
	_build()
	_select(0)

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 36)
	add_child(margin)
	var root := UIKit.vbox(10)
	margin.add_child(root)
	root.add_child(UIKit.label("パーティを作る", 30, UIKit.GOLD))
	root.add_child(UIKit.label("最大4人。操作するのは一人で、残りは自分で戦う。クラスの組み合わせを考えよう。", 14, UIKit.DIM))
	var row := UIKit.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	# 左: 枠
	var left := UIKit.panel()
	left.custom_minimum_size = Vector2(230, 0)
	row.add_child(left)
	slot_box = UIKit.vbox(8)
	left.add_child(slot_box)
	# 中: フォーム
	var mid := UIKit.panel()
	mid.custom_minimum_size = Vector2(430, 0)
	row.add_child(mid)
	form = UIKit.vbox(8)
	mid.add_child(form)
	use_check = CheckBox.new()
	use_check.text = "この枠を使う"
	use_check.toggled.connect(_on_use)
	form.add_child(use_check)
	var nr := UIKit.hbox(8)
	nr.add_child(UIKit.label("名前", 16, UIKit.DIM))
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(190, 34)
	name_edit.max_length = 8
	name_edit.text_changed.connect(_on_name)
	nr.add_child(name_edit)
	nr.add_child(UIKit.button("名前をふる", _on_random_name))
	form.add_child(nr)
	var rr := UIKit.hbox(8)
	rr.add_child(UIKit.label("種族", 16, UIKit.DIM))
	race_opt = OptionButton.new()
	for id in RACE_IDS:
		race_opt.add_item(Jobs.RACES[id]["name"])
	race_opt.item_selected.connect(_on_race)
	rr.add_child(race_opt)
	rr.add_child(UIKit.label("クラス", 16, UIKit.DIM))
	class_opt = OptionButton.new()
	for id in CLASS_IDS:
		class_opt.add_item(Jobs.CLASSES[id]["name"])
	class_opt.item_selected.connect(_on_class)
	rr.add_child(class_opt)
	rr.add_child(UIKit.label("見た目", 16, UIKit.DIM))
	look_opt = OptionButton.new()
	look_opt.add_item("男性")
	look_opt.add_item("女性")
	look_opt.item_selected.connect(_on_look)
	rr.add_child(look_opt)
	form.add_child(rr)
	form.add_child(UIKit.label("能力値(ポイントバイ27点。8〜15)", 16, UIKit.DIM))
	for a in Jobs.ABILS:
		var r := UIKit.hbox(6)
		var nm := UIKit.label(String(Jobs.ABIL_JP[a]), 16)
		nm.custom_minimum_size = Vector2(54, 0)
		r.add_child(nm)
		var minus := UIKit.button("−", _on_stat.bind(a, -1))
		minus.custom_minimum_size = Vector2(36, 32)
		r.add_child(minus)
		var val := UIKit.label("10", 18, UIKit.GOLD)
		val.custom_minimum_size = Vector2(34, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(val)
		var plus := UIKit.button("＋", _on_stat.bind(a, 1))
		plus.custom_minimum_size = Vector2(36, 32)
		r.add_child(plus)
		var bonus := UIKit.label("", 15, UIKit.ACCENT)
		bonus.custom_minimum_size = Vector2(130, 0)
		r.add_child(bonus)
		form.add_child(r)
		stat_rows[a] = {"val": val, "bonus": bonus, "minus": minus, "plus": plus}
	points_label = UIKit.label("", 16, UIKit.GOOD)
	form.add_child(points_label)
	var br := UIKit.hbox(8)
	br.add_child(UIKit.button("おまかせ(クラスに合わせる)", _on_auto))
	br.add_child(UIKit.button("ランダム配分", _on_random_stats))
	form.add_child(br)
	# 右: 技能の習熟と、プレビュー
	var right := UIKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var rv := UIKit.vbox(6)
	right.add_child(rv)
	var bh := UIKit.hbox(6)
	var bl := UIKit.vbox(2)
	bl.add_child(UIKit.label("生い立ち", 15, UIKit.DIM))
	bl.add_child(UIKit.button("ふる", _on_roll_birth))
	bh.add_child(bl)
	var bg := GridContainer.new()
	bg.columns = 2
	bg.add_theme_constant_override("h_separation", 4)
	bg.add_theme_constant_override("v_separation", 2)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in Birth.KEYS:
		var ob := OptionButton.new()
		ob.fit_to_longest_item = false
		ob.clip_text = true
		ob.add_theme_font_size_override("font_size", 13)
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.tooltip_text = String(Birth.KEY_JP[k])
		for e in Birth.table(k):
			ob.add_item("%s: %s" % [Birth.KEY_JP[k], e["name"]])
		ob.item_selected.connect(_on_birth.bind(k))
		bg.add_child(ob)
		birth_opts[k] = ob
	bh.add_child(bg)
	rv.add_child(bh)
	var ph := UIKit.hbox(8)
	prof_label = UIKit.label("", 15, UIKit.DIM)
	prof_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prof_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ph.add_child(prof_label)
	ph.add_child(UIKit.button("おまかせ", _on_auto_picks))
	rv.add_child(ph)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	for id in Talents.SKILL_ORDER:
		var cb := CheckBox.new()
		cb.text = "%s【%s】" % [Talents.SKILLS[id]["name"], String(Jobs.ABIL_JP[Talents.SKILLS[id]["abil"]]).substr(0, 1)]
		cb.add_theme_font_size_override("font_size", 13)
		cb.tooltip_text = String(Talents.SKILLS[id]["desc"])
		cb.toggled.connect(_on_pick.bind(id))
		grid.add_child(cb)
		prof_checks[id] = cb
	rv.add_child(grid)
	preview = RichTextLabel.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.bbcode_enabled = true
	preview.fit_content = false
	preview.scroll_active = true
	preview.add_theme_font_size_override("normal_font_size", 15)
	preview.add_theme_font_size_override("bold_font_size", 15)
	rv.add_child(preview)
	# 下
	msg = UIKit.label("", 15, UIKit.BAD)
	root.add_child(msg)
	var bot := UIKit.hbox(12)
	root.add_child(bot)
	bot.add_child(UIKit.button("戻る", func(): cancelled.emit(), 140))
	start_btn = UIKit.button("このパーティで街へ", _on_start, 280)
	bot.add_child(start_btn)

func _refresh_slots() -> void:
	UIKit.clear(slot_box)
	slot_box.add_child(UIKit.label("パーティ", 18, UIKit.GOLD))
	for i in slots.size():
		var s: Dictionary = slots[i]
		var txt := "%d. (空き)" % (i + 1)
		if s["use"]:
			txt = "%d. %s\n    %s・%s" % [i + 1, s["name"], Jobs.RACES[s["race"]]["name"], Jobs.CLASSES[s["cls"]]["name"]]
		var b := UIKit.button(txt, _select.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		if i == sel:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		slot_box.add_child(b)

func _select(i: int) -> void:
	sel = i
	_refresh_all()

func _cur() -> Dictionary:
	return slots[sel]

func _refresh_all() -> void:
	_updating = true
	var s := _cur()
	use_check.button_pressed = s["use"]
	use_check.disabled = sel == 0
	name_edit.text = s["name"]
	race_opt.select(RACE_IDS.find(s["race"]))
	class_opt.select(CLASS_IDS.find(s["cls"]))
	look_opt.select(0 if s["look"] == "M" else 1)
	var b: Dictionary = s["birth"]
	for k in Birth.KEYS:
		(birth_opts[k] as OptionButton).select(int(b.get(k, -1)))
	_updating = false
	_refresh_slots()
	_refresh_form()

func _refresh_form() -> void:
	var s := _cur()
	var on: bool = s["use"]
	name_edit.editable = on
	race_opt.disabled = not on
	class_opt.disabled = not on
	look_opt.disabled = not on
	for k in birth_opts:
		(birth_opts[k] as OptionButton).disabled = not on
	var bonus: Dictionary = Jobs.RACES[s["race"]]["bonus"]
	var used := Jobs.points_used(s["stats"])
	for a in Jobs.ABILS:
		var v := int(s["stats"][a])
		var row: Dictionary = stat_rows[a]
		(row["val"] as Label).text = str(v)
		var b := int(bonus.get(a, 0))
		(row["bonus"] as Label).text = ("種族 +%d → %d (補正 %+d)" % [b, v + b, int(floor((v + b - 10) / 2.0))]) if b > 0 else ("→ %d (補正 %+d)" % [v, int(floor((v - 10) / 2.0))])
		(row["minus"] as Button).disabled = not on or v <= 8
		var cost_up := Jobs.point_cost(v + 1) - Jobs.point_cost(v)
		(row["plus"] as Button).disabled = not on or v >= 15 or used + cost_up > 27
	points_label.text = "残りポイント: %d / 27" % (27 - used)
	points_label.add_theme_color_override("font_color", UIKit.GOOD if used <= 27 else UIKit.BAD)
	_refresh_picks()
	_refresh_preview()

## 技能の習熟の欄。クラスの一覧にある技能を太字の色で、種族の分は固定で示す
func _refresh_picks() -> void:
	var s := _cur()
	var cp: Dictionary = Talents.CLASS_PROF[s["cls"]]
	var fixed: Array = Talents.RACE_PROF.get(s["race"], [])
	var picks: Array = s["picks"]
	var need := int(cp["count"]) + Talents.BACKGROUND_COUNT
	_updating = true
	for id in prof_checks:
		var cb: CheckBox = prof_checks[id]
		var in_class := (cp["from"] as Array).has(id)
		cb.button_pressed = picks.has(id) or fixed.has(id)
		cb.disabled = not s["use"] or fixed.has(id)
		for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
			cb.add_theme_color_override(k, UIKit.ACCENT if in_class else UIKit.TEXT)
	_updating = false
	var ok := Talents.picks_valid(s["cls"], picks)
	var t := "技能: クラスの一覧(青)から %d つ ＋ 生い立ち(前職)で %d つ。選んだ %d / %d" % [int(cp["count"]), Talents.BACKGROUND_COUNT, picks.size(), need]
	if not fixed.is_empty():
		t += "(%sは種族で習熟)" % "、".join(fixed.map(func(x): return Talents.skill_name(x)))
	prof_label.text = t
	prof_label.add_theme_color_override("font_color", UIKit.GOOD if ok else UIKit.DIM)

func _refresh_preview() -> void:
	var s := _cur()
	if not s["use"]:
		preview.text = "[color=#8a90a0]この枠は使わない。[/color]"
		return
	var c := Character.create(s["name"], s["race"], s["cls"], s["stats"], s["look"], s["picks"])
	var cd := c.class_data()
	var race: Dictionary = Jobs.RACES[s["race"]]
	var t := "[b][color=#e8dcb0]%s[/color][/b]  %s・%s\n" % [c.name, race["name"], cd["name"]]
	t += "[color=#8a90a0]%s\n%s[/color]\n\n" % [cd["desc"], race["desc"]]
	if not (s["birth"] as Dictionary).is_empty():
		var js: Array = Birth.job_skills(s["birth"]).map(func(x): return Talents.skill_name(x))
		t += "[b][color=#e8dcb0]生い立ち[/color][/b](前職の技能: %s)\n%s\n\n" % ["、".join(js), Birth.text(s["birth"])]
	t += "最大HP [b]%d[/b]   最大MP [b]%d[/b]\n体当たり [b]%.1f[/b]/秒   防御 [b]%d[/b]\n" % [c.max_hp(), c.max_mp(), c.bump_power(), c.armor_class()]
	t += "装備: %s / %s\n\n" % [ItemDB.item_name(String(c.equip["weapon"])), ItemDB.item_name(String(c.equip["armor"]))]
	t += "[b][color=#5bc0de]スキル[/color][/b]\n"
	for e in cd["skills"]:
		var sk: Dictionary = Jobs.SKILLS[e[1]]
		t += "Lv%d [b]%s[/b](MP%d)  %s\n" % [e[0], sk["name"], sk["mp"], sk["desc"]]
	var weapons: Array = []
	for w in cd["weapons"]:
		weapons.append(ItemDB.WEAPON_CAT_JP[w])
	var armors: Array = []
	for a in cd["armor"]:
		armors.append(ItemDB.ARMOR_TYPE_JP[a])
	t += "\n使える武器: %s\n着られる鎧: %s\n" % ["、".join(weapons), "、".join(armors)]
	var saves: Array = []
	for a in Talents.CLASS_PROF[c.cls]["saves"]:
		saves.append(Jobs.ABIL_JP[a])
	t += "セーヴの習熟: %s\n" % "、".join(saves)
	var tools: Array = []
	for tl in Talents.CLASS_PROF[c.cls]["tools"]:
		tools.append(Talents.skill_name(tl))
	if not tools.is_empty():
		t += "道具の習熟: %s(解錠 %+d)\n" % ["、".join(tools), c.lock_bonus()]
	t += "受動〈知覚〉 [b]%d[/b]   探る %+d\n" % [c.passive_perception(), c.search_bonus()]
	preview.text = t

# ---------- 入力 ----------

func _on_use(on: bool) -> void:
	if _updating or sel == 0:
		return
	_cur()["use"] = on
	_refresh_all()

func _on_name(txt: String) -> void:
	if _updating:
		return
	_cur()["name"] = txt
	_refresh_slots()
	_refresh_preview()

func _on_random_name() -> void:
	var used: Array = []
	for s in slots:
		used.append(s["name"])
	var pool: Array = NAMES.filter(func(n): return not used.has(n))
	_cur()["name"] = String(pool.pick_random() if not pool.is_empty() else NAMES.pick_random())
	_refresh_all()

func _on_race(i: int) -> void:
	if _updating:
		return
	_cur()["race"] = RACE_IDS[i]
	# 種族で習熟する技能と重なったら、選び直す
	for p in Talents.RACE_PROF.get(RACE_IDS[i], []):
		if (_cur()["picks"] as Array).has(p):
			_cur()["picks"] = _birth_picks(Talents.default_picks(String(_cur()["cls"]), RACE_IDS[i]))
			break
	_refresh_all()

func _on_pick(on: bool, id: String) -> void:
	if _updating:
		return
	msg.text = ""
	var picks: Array = _cur()["picks"]
	var cls := String(_cur()["cls"])
	if on and not picks.has(id):
		if picks.size() >= int(Talents.CLASS_PROF[cls]["count"]) + Talents.BACKGROUND_COUNT:
			msg.text = "技能は選び終えている。替えるなら、先に一つ外す"
			_refresh_form()
			return
		picks.append(id)
	elif not on:
		picks.erase(id)
	_refresh_form()

func _on_auto_picks() -> void:
	_cur()["picks"] = _birth_picks(Talents.default_picks(String(_cur()["cls"]), String(_cur()["race"])))
	_refresh_form()

## いまの生い立ち(前職)の技能を、生い立ちの2つに入れる
func _birth_picks(picks: Array) -> Array:
	return Birth.apply_to_picks(_cur()["birth"], String(_cur()["cls"]), String(_cur()["race"]), picks)

func _on_birth(i: int, key: String) -> void:
	if _updating:
		return
	var b: Dictionary = _cur()["birth"]
	if b.is_empty():
		b = Birth.roll()
	b[key] = i
	_cur()["birth"] = b
	if key == "job":
		_cur()["picks"] = _birth_picks(_cur()["picks"])
	_refresh_all()

func _on_roll_birth() -> void:
	_cur()["birth"] = Birth.roll()
	_cur()["picks"] = _birth_picks(_cur()["picks"])
	msg.text = ""
	_refresh_all()

func _on_look(i: int) -> void:
	if _updating:
		return
	_cur()["look"] = "M" if i == 0 else "F"
	_refresh_all()

func _on_class(i: int) -> void:
	if _updating:
		return
	_cur()["cls"] = CLASS_IDS[i]
	_cur()["stats"] = Jobs.auto_stats(CLASS_IDS[i])
	_cur()["picks"] = _birth_picks(Talents.default_picks(CLASS_IDS[i], String(_cur()["race"])))
	_refresh_all()

func _on_stat(a: String, d: int) -> void:
	var s := _cur()
	var v := int(s["stats"][a]) + d
	if v < 8 or v > 15:
		return
	var old := int(s["stats"][a])
	s["stats"][a] = v
	if Jobs.points_used(s["stats"]) > 27:
		s["stats"][a] = old
	_refresh_form()

func _on_auto() -> void:
	_cur()["stats"] = Jobs.auto_stats(String(_cur()["cls"]))
	_refresh_form()

func _on_random_stats() -> void:
	var st := {}
	for a in Jobs.ABILS:
		st[a] = 8
	var guard := 0
	while guard < 200:
		guard += 1
		var a: String = Jobs.ABILS.pick_random()
		if int(st[a]) >= 15:
			continue
		st[a] += 1
		if Jobs.points_used(st) > 27:
			st[a] -= 1
			if Jobs.points_used(st) >= 26:
				break
	_cur()["stats"] = st
	_refresh_form()

func _on_start() -> void:
	var chars: Array = []
	for s in slots:
		if not s["use"]:
			continue
		if String(s["name"]).strip_edges() == "":
			msg.text = "名前のない仲間がいる"
			return
		if not Talents.picks_valid(s["cls"], s["picks"]):
			msg.text = "%sの技能を選び終えていない(クラスの一覧から%dつ、ほかに%dつ)" % [s["name"], int(Talents.CLASS_PROF[s["cls"]]["count"]), Talents.BACKGROUND_COUNT]
			return
		chars.append(Character.create(String(s["name"]).strip_edges(), s["race"], s["cls"], s["stats"], s["look"], s["picks"], s["birth"]))
	if chars.is_empty():
		msg.text = "一人は必要だ"
		return
	finished.emit(chars)
