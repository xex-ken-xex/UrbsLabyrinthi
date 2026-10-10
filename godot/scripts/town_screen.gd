class_name TownScreen
extends Control
## 街。背景の絵の前で、鍛冶屋、雑貨屋、魔法屋、神殿、宿屋を回る。花街(寝息通り)は雰囲気だけ。
## 地上へ戻ると、まずギルドの査定報告が出る。

signal dive
signal open_inventory
signal to_title
signal arena_requested

const LOCATIONS := {
	"hub": {"name": "縁環区・坑口広場", "art": "town"},
	"smith": {"name": "鍛冶組の店「炉火の槌」", "art": "smith"},
	"general": {"name": "雑貨屋「灯守の店」", "art": "general"},
	"magic": {"name": "星録の書院・写本室", "art": "magic"},
	"temple": {"name": "静寂派の神殿・癒院", "art": "temple"},
	"inn": {"name": "宿「止まり木亭」", "art": "inn"},
	"pleasure": {"name": "寝息通り", "art": "pleasure"},
}
const QUOTES := {
	"smith": "「炉火の神ヘルグの槌は、嘘をつかねえ。いい鋼を持っていきな。」",
	"general": "「灯りと薬は、ケチるな。戻ってこられた奴は、みんなそう言う。」",
	"magic": "「写本は、読まれるために在る。迷宮もまた、読まれるべき書物だ。」",
	"temple": "「眠りは誰にも訪れる。静寂の母が、あなたの夜を守りますように。」",
	"inn": "「あいよ、湯と寝床だ。今夜も、何人戻ってきたかね。」",
}
const RUMORS := [
	"第1層の奥で、子どもの足跡を見たって話だ。許可証を持てる歳じゃねえ。",
	"錆鉄の坑道には、夜ごとに位置が変わる坑道の亡霊がいるらしい。灯りを嫌うそうだ。",
	"鏡の水廊では、水面に映る人数が一人多いことがある。数えるときは、声を出さないほうがいい。",
	"骨の大聖堂の聖歌席は、誰も座っていないのに温かいんだと。",
	"吐く夜は魔物が増える。第三節と第五節の夜は、無理をするな。",
	"燐晶は、持ち帰った3割が税だ。徴税官は迷宮の出口で待ってるぜ。",
	"階段の番は強い。だが、あいつの部屋には必ず良い宝がある。",
	"隠し扉の向こうに、手つかずの宝があるって噂は、半分は本当だ。",
	"通路は毎夜変わるが、大きな部屋と階段の位置は変わらない。地図師はそれで食ってる。",
	"相棒契約を結んでおけ。遺品が戻る道ができる。",
	"第10層より先から戻った者はいない。胃袋の主、とだけ聞いた。",
	"盗賊と野伏は、罠によく気づく。仲間にいると心強い。",
]
const WALK_LINES := [
	"紅の提灯が、通りの端まで連なっている。どの店も、戸口に灯りを一つ置いている。",
	"三味線に似た音が、どこかの二階から流れてくる。足を止める者は多くない。",
	"帰還を祝う声が、角の店から漏れてくる。今夜は、何人戻ってきたのだろう。",
	"白粉の香りと、燐晶の灯の金気が混じる。壁下区の風が、通りを抜けていく。",
	"呼び込みの声が、すれ違いざまに小さくなる。冒険者の顔は、どこへ行っても覚えられている。",
	"灯火の女神ルシュカの小さな祠に、客が硬貨を置いていく。願いは皆、似たようなものらしい。",
]
const LOOK_LINES := [
	"見上げると、大穴から昇る青白い光が、提灯の赤に溶けていた。",
	"灯祭の飾りが、まだ一部残っている。色とりどりの灯が風に揺れる。",
	"提灯の紙に、客の名前と日付が小さく書き込まれている。戻らなかった者の名も、まだ消されていない。",
]
const FORTUNES := [
	"占い師「あなたの今夜の星は、東の坑口にある。深く潜るなら、二つ目の階段で引き返しなさい。」",
	"占い師「水に映る自分を、数えてはならぬ。数が合うと、水が喜ぶ。」",
	"占い師「骨は祈りを覚えている。聖歌席に座るなら、立つ時に礼を。」",
	"占い師「仲間のうち一人が、今夜は誰より前に出たがる。止めなくてよい。支えなさい。」",
]

var gs: GameState
var content_panel: PanelContainer
var art: TownArt
var location := "hub"
var shop_mode := "buy"
var sel_id := ""
var shop_ids: Array = []
var report: Array = []
var party_bar: HBoxContainer
var silver_label: Label
var menu_box: VBoxContainer
var content: VBoxContainer
var msg: Label
var shop_list: ItemList
var shop_detail: RichTextLabel
var shop_actions: VBoxContainer
var log_label: Label
var _walk_log: Array = []

func setup(state: GameState) -> void:
	gs = state

func arrive(lines: Array) -> void:
	report = lines
	location = "hub"
	sel_id = ""
	_say("")
	_refresh_all()

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = TownArt.new()
	add_child(art)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 22)
	add_child(margin)
	var root := UIKit.vbox(8)
	margin.add_child(root)
	var top := _glass(UIKit.panel())
	var th := UIKit.hbox(10)
	top.add_child(th)
	party_bar = UIKit.hbox(10)
	party_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(party_bar)
	silver_label = UIKit.label("", 20, Color("f1d98a"))
	th.add_child(silver_label)
	root.add_child(top)
	var row := UIKit.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var left := _glass(UIKit.panel())
	left.custom_minimum_size = Vector2(236, 0)
	menu_box = UIKit.vbox(6)
	left.add_child(menu_box)
	row.add_child(left)
	var cp := _glass(UIKit.panel(), 0.7)
	content_panel = cp
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content = UIKit.vbox(8)
	cp.add_child(content)
	row.add_child(cp)
	msg = UIKit.label("", 16, UIKit.GOLD)
	var mp := _glass(UIKit.panel())
	mp.add_child(msg)
	root.add_child(mp)

## 背景の絵が透けて見えるパネル
func _glass(p: PanelContainer, a: float = 0.62) -> PanelContainer:
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.04, 0.05, 0.08, a), Color(0.66, 0.47, 0.29, 0.7)))
	return p

func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		open_inventory.emit()

func _say(text: String, color: Color = UIKit.GOLD) -> void:
	if msg == null:
		return
	msg.text = text
	msg.add_theme_color_override("font_color", color)

func _refresh_all() -> void:
	if gs == null or menu_box == null:
		return
	_refresh_top()
	_refresh_menu()
	art.set_style(String(LOCATIONS[location]["art"]))
	_build_content()

func refresh_top() -> void:
	_refresh_top()

func _refresh_top() -> void:
	UIKit.clear(party_bar)
	for c in gs.party:
		var l := UIKit.label("%s  Lv%d %s\nHP %d/%d  MP %d/%d" % [c.name, c.level, Jobs.CLASSES[c.cls]["name"], int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp()], 14,
			UIKit.BAD if c.hp <= 0.0 else UIKit.TEXT)
		party_bar.add_child(l)
	silver_label.text = "預け金 %d銀貨" % gs.bank_silver

func _refresh_menu() -> void:
	UIKit.clear(menu_box)
	menu_box.add_child(UIKit.label(String(LOCATIONS[location]["name"]), 15, UIKit.DIM))
	var items := [["hub", "坑口広場"], ["smith", "武器・防具"], ["general", "雑貨屋"], ["magic", "魔法屋"], ["temple", "神殿"], ["inn", "宿屋"], ["pleasure", "花街(寝息通り)"]]
	for it in items:
		var id: String = it[0]
		var b := UIKit.button(it[1], _go.bind(id), 0)
		if id == location:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		menu_box.add_child(b)
	menu_box.add_child(Control.new())
	menu_box.add_child(UIKit.button("持ち物・装備 (Tab)", func(): open_inventory.emit()))
	var dive_btn := UIKit.button("迷宮へ潜る", func(): dive.emit())
	dive_btn.add_theme_stylebox_override("normal", UIKit.box(Color(0.1, 0.22, 0.3, 1.0), UIKit.ACCENT, 2))
	menu_box.add_child(dive_btn)
	menu_box.add_child(UIKit.button("闘技場(調整用)", func(): arena_requested.emit()))
	menu_box.add_child(UIKit.button("タイトルへ", func(): to_title.emit()))

func _go(loc: String) -> void:
	location = loc
	shop_mode = "buy"
	sel_id = ""
	_walk_log.clear()
	_say("")
	_refresh_all()

func _build_content() -> void:
	UIKit.clear(content)
	# 広場では内容の高さだけにして、背景の絵を見せる
	content_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if location == "hub" else Control.SIZE_FILL
	match location:
		"hub": _content_hub()
		"smith", "general", "magic": _content_shop(location)
		"temple": _content_temple()
		"inn": _content_inn()
		"pleasure": _content_pleasure()

func _head(title: String, quote: String = "") -> void:
	content.add_child(UIKit.label(title, 24, UIKit.GOLD))
	if quote != "":
		content.add_child(UIKit.label(quote, 15, Color("b8c4d8")))

# ---------- 広場 ----------

func _content_hub() -> void:
	_head("縁環区・坑口広場", "大穴の縁に立つ坑口館の前。夜でも、燐晶の灯が絶えない。")
	if not report.is_empty():
		content.add_child(UIKit.label("ギルドの査定報告", 18, UIKit.ACCENT))
		for l in report:
			content.add_child(UIKit.label(String(l), 16))
	else:
		content.add_child(UIKit.label("ここから、各店と迷宮の口へ向かえる。", 16))
	content.add_child(Control.new())
	var tip := UIKit.label("装備と呪文書を整え、傷を癒やしてから潜ろう。通路は毎夜、組み替わる。\n倒れた仲間は、神殿でなければ蘇らない。", 14, UIKit.DIM)
	content.add_child(tip)

# ---------- 店 ----------

func _content_shop(sid: String) -> void:
	_head(String(LOCATIONS[sid]["name"]), String(QUOTES.get(sid, "")))
	var mb := UIKit.hbox(8)
	for m in [["buy", "買う"], ["sell", "売る"]]:
		var b := UIKit.button(m[1], _set_mode.bind(m[0]), 110)
		if shop_mode == m[0]:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		mb.add_child(b)
	content.add_child(mb)
	var row := UIKit.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	shop_list = ItemList.new()
	shop_list.custom_minimum_size = Vector2(380, 0)
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_list.item_selected.connect(_on_shop_pick)
	row.add_child(shop_list)
	var rv := UIKit.vbox(8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_detail = RichTextLabel.new()
	shop_detail.bbcode_enabled = true
	shop_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_detail.add_theme_font_size_override("normal_font_size", 15)
	rv.add_child(shop_detail)
	shop_actions = UIKit.vbox(6)
	rv.add_child(shop_actions)
	row.add_child(rv)
	_fill_shop()

func _set_mode(m: String) -> void:
	shop_mode = m
	sel_id = ""
	_build_content()

func _fill_shop() -> void:
	shop_list.clear()
	shop_ids = []
	if shop_mode == "buy":
		for id in ItemDB.SHOPS[location]:
			shop_ids.append(id)
			var price := int(ItemDB.ITEMS[id]["price"])
			shop_list.add_item("%s   %d銀" % [ItemDB.item_name(id), price], ItemIcons.texture(id))
			if price > gs.bank_silver:
				shop_list.set_item_custom_fg_color(shop_list.item_count - 1, Color(0.55, 0.45, 0.45))
	else:
		for id in gs.item_ids():
			shop_ids.append(id)
			shop_list.add_item("%s ×%d   %d銀" % [ItemDB.item_name(id), gs.count(id), ItemDB.sell_price(id)], ItemIcons.texture(id))
		if shop_ids.is_empty():
			shop_list.add_item("(売れるものがない)")
			shop_list.set_item_disabled(0, true)
	if sel_id != "" and shop_ids.has(sel_id):
		shop_list.select(shop_ids.find(sel_id))
	_show_shop_detail()

func _on_shop_pick(i: int) -> void:
	if i < shop_ids.size():
		sel_id = String(shop_ids[i])
		_show_shop_detail()

func _show_shop_detail() -> void:
	UIKit.clear(shop_actions)
	if sel_id == "" or not ItemDB.ITEMS.has(sel_id):
		shop_detail.text = "[color=#8a90a0]品物を選ぶ。[/color]"
		return
	var it: Dictionary = ItemDB.ITEMS[sel_id]
	var t := "[b][color=#e8dcb0]%s[/color][/b]\n%s\n" % [it["name"], ItemDB.detail(sel_id)]
	var kind := String(it["kind"])
	if shop_mode == "buy":
		t += "\n値段 [b]%d銀貨[/b]    所持 %d" % [int(it["price"]), gs.count(sel_id)]
		if kind == "weapon" or kind == "armor" or kind == "acc":
			t += "\n"
			for c in gs.party:
				if ItemDB.can_equip(sel_id, c.cls):
					t += "\n[color=#5bc0de]%s[/color]  %s" % [c.name, c.compare_equip(sel_id)]
				else:
					t += "\n[color=#8a90a0]%s  (装備できない)[/color]" % c.name
		var b := UIKit.button("購入する", _buy.bind(-1))
		b.disabled = int(it["price"]) > gs.bank_silver
		shop_actions.add_child(b)
		if kind == "weapon" or kind == "armor" or kind == "acc":
			for i in gs.party.size():
				var c: Character = gs.party[i]
				if ItemDB.can_equip(sel_id, c.cls):
					var b2 := UIKit.button("買って %s に装備" % c.name, _buy.bind(i))
					b2.disabled = int(it["price"]) > gs.bank_silver
					shop_actions.add_child(b2)
		elif kind == "tome":
			for i in gs.party.size():
				var c2: Character = gs.party[i]
				if (it["classes"] as Array).has(c2.cls) and not c2.skills.has(String(it["teaches"])):
					var b3 := UIKit.button("買って %s が覚える" % c2.name, _buy.bind(i))
					b3.disabled = int(it["price"]) > gs.bank_silver
					shop_actions.add_child(b3)
	else:
		t += "\n買い取り [b]%d銀貨[/b]    所持 %d" % [ItemDB.sell_price(sel_id), gs.count(sel_id)]
		shop_actions.add_child(UIKit.button("売る", _sell))
	shop_detail.text = t

func _buy(member: int) -> void:
	var r := gs.buy(sel_id)
	if r != "":
		_say(r, UIKit.BAD)
		return
	var extra := ""
	if member >= 0:
		var c: Character = gs.party[member]
		if String(ItemDB.ITEMS[sel_id]["kind"]) == "tome":
			extra = gs.learn_tome(sel_id, c)
		else:
			var e := gs.equip(c, sel_id)
			extra = "%sに装備した" % c.name if e == "" else e
	_say("%sを買った。%s" % [ItemDB.item_name(sel_id), extra], UIKit.GOOD)
	_refresh_top()
	_fill_shop()

func _sell() -> void:
	var name := ItemDB.item_name(sel_id)
	var r := gs.sell(sel_id)
	if r != "":
		_say(r, UIKit.BAD)
		return
	_say("%sを売った(+%d銀貨)" % [name, ItemDB.sell_price(sel_id)], UIKit.GOOD)
	if gs.count(sel_id) <= 0:
		sel_id = ""
	_refresh_top()
	_fill_shop()

# ---------- 神殿 ----------

func _revive_cost(c: Character) -> int:
	return 100 * c.level

func _content_temple() -> void:
	_head(String(LOCATIONS["temple"]["name"]), String(QUOTES["temple"]))
	content.add_child(UIKit.label("静寂の母シレンティアの座に、癒しの神イリンの灯が添えられている。", 14, UIKit.DIM))
	content.add_child(UIKit.label("蘇生", 18, UIKit.ACCENT))
	var any := false
	for c in gs.party:
		if c.hp <= 0.0:
			any = true
			var cost := _revive_cost(c)
			var b := UIKit.button("%s を蘇らせる(寄進 %d銀貨)" % [c.name, cost], _revive.bind(c))
			b.disabled = cost > gs.bank_silver
			content.add_child(b)
	if not any:
		content.add_child(UIKit.label("倒れている仲間はいない。", 15, UIKit.DIM))
	content.add_child(UIKit.label("祈り", 18, UIKit.ACCENT))
	var bless := UIKit.button("加護を願う(寄進 100銀貨)  次に潜るとき、しばらく受けるダメージが減る", _bless)
	bless.disabled = gs.bank_silver < 100 or gs.blessed
	content.add_child(bless)
	if gs.blessed:
		content.add_child(UIKit.label("すでに加護を授かっている。", 14, UIKit.GOOD))
	content.add_child(UIKit.button("静かに祈る(無料)", _pray))

func _revive(c: Character) -> void:
	var cost := _revive_cost(c)
	if gs.bank_silver < cost:
		return
	gs.bank_silver -= cost
	c.hp = maxf(1.0, c.max_hp() * 0.5)
	_say("%sは目を開けた。「……夜が、明けたのですね。」" % c.name, UIKit.GOOD)
	_refresh_top()
	_build_content()

func _bless() -> void:
	if gs.bank_silver < 100 or gs.blessed:
		return
	gs.bank_silver -= 100
	gs.blessed = true
	_say("神官が、燐晶の粉を額に置いた。「灯が、あなたと共に在りますように。」", UIKit.GOOD)
	_refresh_top()
	_build_content()

func _pray() -> void:
	_say("膝をつき、目を閉じた。聖堂の奥で、誰も座っていない十二番目の座が、静かに光っている。", UIKit.TEXT)

# ---------- 宿屋 ----------

func _content_inn() -> void:
	_head(String(LOCATIONS["inn"]["name"]), String(QUOTES["inn"]))
	var alive := 0
	for c in gs.party:
		if c.hp > 0.0:
			alive += 1
	var cost := 30 * alive
	var rest := UIKit.button("泊まる(%d銀貨)  生きている仲間のHPとMPが全快する" % cost, _rest.bind(cost))
	rest.disabled = gs.bank_silver < cost or alive == 0
	content.add_child(rest)
	content.add_child(UIKit.button("酒場で噂を聞く(無料)", _rumor))
	content.add_child(UIKit.button("記録をつける(セーブ)", _save))
	content.add_child(Control.new())
	content.add_child(UIKit.label("倒れた仲間は、宿では目を覚まさない。神殿で蘇らせること。", 14, UIKit.DIM))

func _rest(cost: int) -> void:
	if gs.bank_silver < cost:
		return
	gs.bank_silver -= cost
	for c in gs.party:
		if c.hp > 0.0:
			c.hp = c.max_hp()
			c.mp = c.max_mp()
	_say("湯を使い、寝床で眠った。体が軽い。", UIKit.GOOD)
	_refresh_top()
	_build_content()

func _rumor() -> void:
	_say("酒場の隅で聞こえた話だ。\n" + String(RUMORS.pick_random()), UIKit.TEXT)

func _save() -> void:
	_say("記録をつけた。" if gs.save() else "記録に失敗した。", UIKit.GOOD)

# ---------- 花街(雰囲気のみ) ----------

func _content_pleasure() -> void:
	_head("花街「寝息通り」", "縁環区と壁下区の境に伸びる通り。迷宮の「息」に対して、人の寝息の通りと呼ばれる。")
	content.add_child(UIKit.label("灯火の女神ルシュカの守る通り。ここでは、誰もが肩書きを脱いで歩く。", 14, UIKit.DIM))
	var r := UIKit.hbox(8)
	r.add_child(UIKit.button("通りを歩く", func(): _push_walk(String(WALK_LINES.pick_random()))))
	r.add_child(UIKit.button("灯籠を見上げる", func(): _push_walk(String(LOOK_LINES.pick_random()))))
	r.add_child(UIKit.button("占い師の屋台", func(): _push_walk(String(FORTUNES.pick_random()))))
	content.add_child(r)
	log_label = UIKit.label("", 16, Color("e8d8e8"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(0, 220)
	content.add_child(log_label)
	_update_walk()

func _push_walk(line: String) -> void:
	_walk_log.append(line)
	while _walk_log.size() > 4:
		_walk_log.pop_front()
	_update_walk()

func _update_walk() -> void:
	if log_label != null:
		log_label.text = "\n\n".join(_walk_log)
