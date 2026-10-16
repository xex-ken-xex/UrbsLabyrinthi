class_name CharaMake
extends Control
## キャラクター作成。名前、種族、クラス、能力値で作る。能力値は「ポイントバイ」(27点。押すとクラスに合った配分になる)か、
## 「ふる」(各3d6。振った目のまま使う)で決める。
## 始めは二人(Balance.START_PARTY)。3人目からは、宿屋で仲間に加える(recruit。一人ずつ作る)。

signal finished(chars: Array)
signal cancelled

const NAMES := ["アルド", "セラ", "ロカ", "ミナ", "ガロ", "イルマ", "ティオ", "ネリ", "ダルク", "フィーネ", "ボルグ", "ユナ",
	"カイ", "リーゼ", "ハンス", "ルカ", "ベルナ", "オルト", "シェリ", "グレン", "マルタ", "ノエ", "ヴィクト", "ラナ"]
const DEFAULT_PARTY := [["fighter", "human", "M"], ["cleric", "dwarf", "F"], ["wizard", "elf", "M"], ["rogue", "halfling", "F"]]
const RACE_IDS := ["human", "elf", "dwarf", "halfling"]
const CLASS_IDS := ["fighter", "barbarian", "rogue", "wizard", "cleric", "ranger"]

var slots: Array = []        # {use, name, race, cls, look, method("buy"/"roll"), stats, picks, birth}
var recruit := false         # 宿屋で仲間を一人加える
var party_now: Array = []    # recruit のとき、いまの仲間(Character)。名前と、おすすめの組み合わせを避けるのに使う
var sel := 0
var _updating := false
var slot_box: VBoxContainer
var name_edit: LineEdit
var race_opt: OptionButton
var look_opt: OptionButton
var class_opt: OptionButton
var use_check: CheckBox
var stat_rows := {}          # abil → {val, race, total, mod, minus, plus}
var _last_total := {}        # abil → 前に出した合計。変わった数字を一瞬光らせる
var points_label: Label
var roll_btn: Button
var buy_btn: Button
var _rolling := 0.0          # 振っている最中の残り時間。そのあいだ数字がくるくる変わる
const ROLL_TIME := 1.1
var preview: RichTextLabel
var prof_label: Label
var prof_checks := {}        # 技能id → CheckBox
var birth_opts := {}         # 生まれ表の key → OptionButton
var msg: Label
var start_btn: Button
var form: VBoxContainer
var look_view: HeroPreview

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
	var n := 1 if recruit else Balance.START_PARTY
	var taken: Array = party_now.map(func(c): return c.name)
	for k in n:
		var i := party_now.size() + k if recruit else k
		var d: Array = DEFAULT_PARTY[i % DEFAULT_PARTY.size()]
		var b := Birth.roll()
		var nm: String = NAMES[(i * 5 + 1) % NAMES.size()]
		while taken.has(nm):
			nm = NAMES[(NAMES.find(nm) + 1) % NAMES.size()]
		slots.append({"use": true, "name": nm, "race": d[1], "cls": d[0], "look": d[2], "method": "buy", "stats": Jobs.auto_stats(d[0]),
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
	if recruit:
		root.add_child(UIKit.label("仲間に加える", 30, UIKit.GOLD))
		root.add_child(UIKit.label("酒場で声をかけた相手だ。いまの仲間 %d人に、一人加わる(最大%d人)。" % [party_now.size(), Balance.MAX_PARTY], 14, UIKit.DIM))
	else:
		root.add_child(UIKit.label("パーティを作る", 30, UIKit.GOLD))
		root.add_child(UIKit.label("始めは%d人。操作するのは一人で、もう一人は自分で戦う。仲間は、宿屋の酒場で最大%d人まで増やせる。" % [Balance.START_PARTY, Balance.MAX_PARTY], 14, UIKit.DIM))
	var row := UIKit.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	# 左: 枠
	var left := UIKit.panel()
	left.custom_minimum_size = Vector2(230, 0)
	row.add_child(left)
	var lv := UIKit.vbox(8)
	left.add_child(lv)
	slot_box = UIKit.vbox(8)
	lv.add_child(slot_box)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)
	look_view = HeroPreview.new()
	look_view.custom_minimum_size = Vector2(0, 180)
	lv.add_child(look_view)
	# 中: フォーム
	var mid := UIKit.panel()
	mid.custom_minimum_size = Vector2(430, 0)
	row.add_child(mid)
	form = UIKit.vbox(6)
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
	# 表(グリッド)にして、見出しと数字の縦列を揃える: 能力値 | − 割り振り ＋ | ＋種族 | ＝合計 | 補正
	var stat_grid := GridContainer.new()
	stat_grid.columns = 7
	stat_grid.add_theme_constant_override("h_separation", 6)
	stat_grid.add_theme_constant_override("v_separation", 1)
	for c in [["能力値", 54], ["", 36], ["割り振り", 62], ["", 36], ["＋種族", 64], ["＝合計", 64], ["補正", 64]]:
		var hl := UIKit.label(String(c[0]), 13, UIKit.DIM)
		hl.custom_minimum_size = Vector2(int(c[1]), 0)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if c[0] == "能力値" else HORIZONTAL_ALIGNMENT_CENTER
		stat_grid.add_child(hl)
	for a in Jobs.ABILS:
		var nm := UIKit.label(String(Jobs.ABIL_JP[a]), 16)
		nm.custom_minimum_size = Vector2(54, 0)
		stat_grid.add_child(nm)
		var minus := UIKit.button("−", _on_stat.bind(a, -1))
		minus.custom_minimum_size = Vector2(36, 28)
		stat_grid.add_child(minus)
		var val := UIKit.label("10", 18, UIKit.GOLD)
		val.custom_minimum_size = Vector2(62, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_grid.add_child(val)
		var plus := UIKit.button("＋", _on_stat.bind(a, 1))
		plus.custom_minimum_size = Vector2(36, 28)
		stat_grid.add_child(plus)
		var cols := {}
		for k in ["race", "total", "mod"]:
			var l := UIKit.label("", 17 if k != "race" else 16, UIKit.TEXT)
			l.custom_minimum_size = Vector2(64, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_grid.add_child(l)
			cols[k] = l
		stat_rows[a] = {"val": val, "race": cols["race"], "total": cols["total"], "mod": cols["mod"], "minus": minus, "plus": plus}
	form.add_child(stat_grid)
	points_label = UIKit.label("", 15, UIKit.GOOD)
	points_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(points_label)
	var br := UIKit.hbox(8)
	roll_btn = UIKit.button("ふる", _on_roll_stats, 100)
	roll_btn.tooltip_text = "各能力値を3d6で振る。振った目のまま使う。何度でも振り直せる"
	br.add_child(roll_btn)
	buy_btn = UIKit.button("ポイントバイ", _on_auto, 140)
	buy_btn.tooltip_text = "27点で割り振る。押すと、クラスに合った配分になる"
	br.add_child(buy_btn)
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
	start_btn = UIKit.button("仲間に加える" if recruit else "このパーティで街へ", _on_start, 280)
	bot.add_child(start_btn)

func _refresh_slots() -> void:
	UIKit.clear(slot_box)
	slot_box.add_child(UIKit.label("パーティ", 18, UIKit.GOLD))
	for i in party_now.size():
		var c: Character = party_now[i]
		slot_box.add_child(UIKit.label("%d. %s\n    %s・%s" % [i + 1, c.name, Jobs.RACES[c.race]["name"], Jobs.CLASSES[c.cls]["name"]], 15, UIKit.DIM))
	for i in slots.size():
		var s: Dictionary = slots[i]
		var txt := "%d. (空き)" % (party_now.size() + i + 1)
		if s["use"]:
			txt = "%d. %s\n    %s・%s" % [party_now.size() + i + 1, s["name"], Jobs.RACES[s["race"]]["name"], Jobs.CLASSES[s["cls"]]["name"]]
		var b := UIKit.button(txt, _select.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		if i == sel:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		slot_box.add_child(b)

func _select(i: int) -> void:
	sel = i
	_rolling = 0.0          # 振っている最中に枠を替えたら、振り終えたことにする
	_last_total.clear()     # 枠を替えたときは光らせない
	_refresh_all()

func _cur() -> Dictionary:
	return slots[sel]

func _refresh_all() -> void:
	_updating = true
	var s := _cur()
	use_check.button_pressed = s["use"]
	use_check.disabled = sel == 0
	use_check.visible = not recruit
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
	var roll := String(s.get("method", "buy")) == "roll"
	roll_btn.disabled = not on or _rolling > 0.0
	buy_btn.disabled = not on or _rolling > 0.0
	for a in Jobs.ABILS:
		var v := int(s["stats"][a])
		var row: Dictionary = stat_rows[a]
		(row["val"] as Label).text = str(v)
		var b := int(bonus.get(a, 0))
		var rl: Label = row["race"]
		rl.text = ("▲%d" % b) if b > 0 else (("▼%d" % -b) if b < 0 else "・")
		rl.add_theme_color_override("font_color", UIKit.GOOD if b > 0 else (UIKit.BAD if b < 0 else UIKit.DIM))
		var total := v + b
		var tl: Label = row["total"]
		tl.text = str(total)
		tl.add_theme_color_override("font_color", UIKit.GOLD)
		var m := int(floor((total - 10) / 2.0))
		var ml: Label = row["mod"]
		ml.text = "%+d" % m
		ml.add_theme_color_override("font_color", UIKit.ACCENT if m > 0 else (UIKit.BAD if m < 0 else UIKit.DIM))
		if _last_total.has(a) and int(_last_total[a]) != total and is_inside_tree():
			_flash(tl)
			_flash(ml)
		_last_total[a] = total
		(row["minus"] as Button).disabled = not on or roll or v <= 8
		var cost_up := Jobs.point_cost(v + 1) - Jobs.point_cost(v)
		(row["plus"] as Button).disabled = not on or roll or v >= 15 or used + cost_up > 27
		# ロール式では ± を消す(表の列がずれないよう、見えなくするだけ)
		for k in ["minus", "plus"]:
			(row[k] as Button).modulate.a = 0.0 if roll else 1.0
			(row[k] as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE if roll else Control.MOUSE_FILTER_STOP
			(row[k] as Button).focus_mode = Control.FOCUS_NONE if roll else Control.FOCUS_ALL
	if roll:
		var sum := 0
		for a in Jobs.ABILS:
			sum += int(s["stats"][a])
		points_label.text = "ふった目(各3d6、3〜18)。合計 %d(標準の配分は72)" % sum
		points_label.add_theme_color_override("font_color", UIKit.GOOD)
	else:
		points_label.text = "残りポイント: %d / 27(ポイントバイ。割り振りは各8〜15)" % (27 - used)
		points_label.add_theme_color_override("font_color", UIKit.GOOD if used <= 27 else UIKit.BAD)
	_refresh_picks()
	_refresh_preview()

## 変わった数字を一瞬光らせる
func _flash(l: Label) -> void:
	l.modulate = Color(2.2, 2.0, 1.2)
	create_tween().tween_property(l, "modulate", Color.WHITE, 0.6)

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
	look_view.visible = s["use"]
	look_view.set_look(String(s["name"]), String(s["cls"]), String(s["race"]), String(s["look"]))
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
	var used: Array = party_now.map(func(c): return c.name)
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
	if not _is_roll():
		_cur()["stats"] = Jobs.auto_stats(CLASS_IDS[i])
	_cur()["picks"] = _birth_picks(Talents.default_picks(CLASS_IDS[i], String(_cur()["race"])))
	_refresh_all()

func _on_stat(a: String, d: int) -> void:
	var s := _cur()
	if _is_roll():
		return
	var v := int(s["stats"][a]) + d
	if v < 8 or v > 15:
		return
	var old := int(s["stats"][a])
	s["stats"][a] = v
	if Jobs.points_used(s["stats"]) > 27:
		s["stats"][a] = old
	_refresh_form()

## ポイントバイにする(ふった目は捨てる)。クラスに合った配分になる
func _on_auto() -> void:
	if _rolling > 0.0:
		return
	_cur()["method"] = "buy"
	_cur()["stats"] = Jobs.auto_stats(String(_cur()["cls"]))
	_refresh_form()

func _is_roll() -> bool:
	return String(_cur().get("method", "buy")) == "roll"

## 各能力値を3d6で、上から順に振る。振った目のまま使う(並べ替えない)。サイコロ3つぶんの擬音が画面を飛び交い、数字がしばらくくるくる回ってから止まる
func _on_roll_stats() -> void:
	if not _cur()["use"] or _rolling > 0.0:
		return
	_cur()["method"] = "roll"
	var st := {}
	for a in Jobs.ABILS:
		st[a] = Dice.roll("3d6")
	_cur()["stats"] = st
	msg.text = ""
	_rolling = ROLL_TIME if is_inside_tree() else 0.0
	_refresh_form()
	if _rolling > 0.0:
		DiceFx.throw(self, Rect2(Vector2.ZERO, size))

func _process(delta: float) -> void:
	if _rolling <= 0.0:
		return
	_rolling -= delta
	if _rolling <= 0.0:
		_rolling = 0.0
		_last_total.clear()
		_refresh_form()
		for a in Jobs.ABILS:
			for k in ["val", "total", "mod"]:
				_flash(stat_rows[a][k])
		return
	# 振っている最中は、数字がくるくる変わる(止まる直前はゆっくり)
	if Engine.get_process_frames() % (2 if _rolling > 0.4 else 5) != 0:
		return
	for a in Jobs.ABILS:
		var row: Dictionary = stat_rows[a]
		(row["val"] as Label).text = str(randi_range(3, 18))
		(row["total"] as Label).text = "?"
		(row["mod"] as Label).text = ""

func _on_start() -> void:
	if _rolling > 0.0:
		return
	var chars: Array = []
	for s in slots:
		if not s["use"]:
			continue
		if String(s["name"]).strip_edges() == "":
			msg.text = "名前のない仲間がいる"
			return
		if party_now.any(func(c): return c.name == String(s["name"]).strip_edges()):
			msg.text = "%sという名前の仲間は、もういる" % String(s["name"]).strip_edges()
			return
		if not Talents.picks_valid(s["cls"], s["picks"]):
			msg.text = "%sの技能を選び終えていない(クラスの一覧から%dつ、ほかに%dつ)" % [s["name"], int(Talents.CLASS_PROF[s["cls"]]["count"]), Talents.BACKGROUND_COUNT]
			return
		chars.append(Character.create(String(s["name"]).strip_edges(), s["race"], s["cls"], s["stats"], s["look"], s["picks"], s["birth"]))
	if chars.is_empty():
		msg.text = "一人は必要だ"
		return
	finished.emit(chars)
