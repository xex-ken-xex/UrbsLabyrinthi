class_name CharaMake
extends Control
## キャラクター作成。最大4人のパーティを、名前、種族、クラス、能力値(ポイントバイ27点)で作る。
## 「おまかせ」でクラスに合った配分になる。

signal finished(chars: Array)
signal cancelled

const NAMES := ["アルド", "セラ", "ロカ", "ミナ", "ガロ", "イルマ", "ティオ", "ネリ", "ダルク", "フィーネ", "ボルグ", "ユナ",
	"カイ", "リーゼ", "ハンス", "ルカ", "ベルナ", "オルト", "シェリ", "グレン", "マルタ", "ノエ", "ヴィクト", "ラナ"]
const DEFAULT_PARTY := [["fighter", "human"], ["cleric", "dwarf"], ["wizard", "elf"], ["rogue", "halfling"]]
const RACE_IDS := ["human", "elf", "dwarf", "halfling"]
const CLASS_IDS := ["fighter", "barbarian", "rogue", "wizard", "cleric", "ranger"]

var slots: Array = []        # {use, name, race, cls, stats}
var sel := 0
var _updating := false
var slot_box: VBoxContainer
var name_edit: LineEdit
var race_opt: OptionButton
var class_opt: OptionButton
var use_check: CheckBox
var stat_rows := {}          # abil → {val, bonus, minus, plus}
var points_label: Label
var preview: RichTextLabel
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
		slots.append({"use": true, "name": NAMES[(i * 5 + 1) % NAMES.size()], "race": d[1], "cls": d[0], "stats": Jobs.auto_stats(d[0])})
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
	# 右: プレビュー
	var right := UIKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	preview = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = false
	preview.scroll_active = true
	preview.add_theme_font_size_override("normal_font_size", 15)
	preview.add_theme_font_size_override("bold_font_size", 15)
	right.add_child(preview)
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
	_updating = false
	_refresh_slots()
	_refresh_form()

func _refresh_form() -> void:
	var s := _cur()
	var on: bool = s["use"]
	name_edit.editable = on
	race_opt.disabled = not on
	class_opt.disabled = not on
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
	_refresh_preview()

func _refresh_preview() -> void:
	var s := _cur()
	if not s["use"]:
		preview.text = "[color=#8a90a0]この枠は使わない。[/color]"
		return
	var c := Character.create(s["name"], s["race"], s["cls"], s["stats"])
	var cd := c.class_data()
	var race: Dictionary = Jobs.RACES[s["race"]]
	var t := "[b][color=#e8dcb0]%s[/color][/b]  %s・%s\n" % [c.name, race["name"], cd["name"]]
	t += "[color=#8a90a0]%s\n%s[/color]\n\n" % [cd["desc"], race["desc"]]
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
	t += "\n使える武器: %s\n着られる鎧: %s" % ["、".join(weapons), "、".join(armors)]
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
	_refresh_all()

func _on_class(i: int) -> void:
	if _updating:
		return
	_cur()["cls"] = CLASS_IDS[i]
	_cur()["stats"] = Jobs.auto_stats(CLASS_IDS[i])
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
		chars.append(Character.create(String(s["name"]).strip_edges(), s["race"], s["cls"], s["stats"]))
	if chars.is_empty():
		msg.text = "一人は必要だ"
		return
	finished.emit(chars)
