class_name TownScreen
extends Control
## 街。背景の絵の前で、鍛冶屋、雑貨屋、魔法屋、神殿、宿屋を回る。花街(寝息通り)は雰囲気だけ。
## 地上へ戻ると、まずギルドの査定報告が出る。

signal dive
signal open_inventory
signal arena_requested
signal recruit           # 宿屋の酒場で、仲間を一人加える

const LOCATIONS := {
	"hub": {"name": "縁環区・坑口広場", "art": "town"},
	"smith": {"name": "鍛冶組の店「炉火の槌」", "art": "smith"},
	"general": {"name": "雑貨屋「灯守の店」", "art": "general"},
	"magic": {"name": "星録の書院・写本室", "art": "magic"},
	"temple": {"name": "静寂派の神殿・癒院", "art": "temple"},
	"inn": {"name": "宿「止まり木亭」", "art": "inn"},
	"pleasure": {"name": "寝息通り", "art": "pleasure"},
	"guild": {"name": "坑口館・冒険者ギルド", "art": "guild"},
	"market": {"name": "壁下市場「灰の辻」", "art": "market"},
	"home": {"name": "我が家(壁下区の長屋)", "art": "home"},
}
const QUOTES := {
	"smith": "「炉火の神ヘルグの槌は、嘘をつかねえ。いい鋼を持っていきな。」",
	"general": "「灯りと薬は、ケチるな。戻ってこられた奴は、みんなそう言う。」",
	"magic": "「写本は、読まれるために在る。迷宮もまた、読まれるべき書物だ。」",
	"temple": "「眠りは誰にも訪れる。静寂の母が、あなたの夜を守りますように。」",
	"inn": "「あいよ、湯と寝床だ。今夜も、何人戻ってきたかね。」",
	"guild": "「おかえり。戻ってきた者は、まずここで名を書く。遺品があれば、遺品課の窓口へ。」",
	"home": "壁下区の長屋の一間。戸を閉めると、迷宮の息も、街の喧騒も、少しだけ遠くなる。",
	"market": "「灰麦も豆も、今朝の隊商で入ったばかりだ。迷宮で火を焚くなら、焚き木も持っていきな。」",
	"pleasure": "縁環区と壁下区の境に伸びる通り。迷宮の「息」に対して、人の寝息の通りと呼ばれる。",
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

## 広場の看板: [行き先, 名前, 何の店か, 画面の中の位置(割合), 看板に目をやったときの一行]
const SIGNS := [
	["magic", "星録の書院", "魔法屋・写本", Vector2(0.33, 0.33), "丘の上の書院の窓に、遅くまで灯りがともっている。"],
	["smith", "炉火の槌", "武器・防具", Vector2(0.15, 0.50), "鉄を打つ音が、広場の端まで響いている。"],
	["pleasure", "寝息通り", "花街", Vector2(0.86, 0.47), "紅の提灯が、通りの奥まで連なっている。三味線に似た音がする。"],
	["general", "灯守の店", "雑貨・薬", Vector2(0.30, 0.66), "軒先に、灯具と薬瓶がずらりと吊られている。"],
	["guild", "坑口館", "冒険者ギルド", Vector2(0.64, 0.42), "大穴の縁に、ギルドの本部が建っている。窓口の灯は、夜通し消えない。"],
	["inn", "止まり木亭", "宿・酒場・仲間", Vector2(0.70, 0.66), "笑い声と、焼いた肉の匂いが漏れてくる。"],
	["temple", "静寂派の神殿", "癒し・蘇り", Vector2(0.12, 0.76), "鐘は鳴らない。静寂の母の神殿は、いつも静かだ。"],
	["home", "我が家", "台所・寝床ほか", Vector2(0.46, 0.50), "坑口の灯の届かない路地の奥に、自分の家の戸口がある。"],
	["market", "灰の辻", "市場・食材", Vector2(0.88, 0.76), "壁下区へ下る辻に、麦と豆と干物の露店が並んでいる。"],
	["dive", "坑口", "迷宮へ降りる", Vector2(0.50, 0.80), "大穴から、青白い光が昇っている。今夜の通路は、どう組み替わっただろう。"],
]
const HUB_LINE := "縁環区・坑口広場。大穴の縁に立つ坑口館の前は、夜でも燐晶の灯が絶えない。"
const ENTER_LINES := {
	"smith": "広場を横切り、煤けた戸をくぐった。炉の熱が顔に当たる。",
	"general": "戸の鈴が鳴った。灯油と乾いた薬草のにおいがする。",
	"magic": "丘の石段を上り、書院の重い扉を押した。紙とインクのにおいがする。",
	"temple": "神殿の中は、外の喧騒が嘘のように静かだ。",
	"inn": "止まり木亭の扉を開けると、暖かい空気と話し声に包まれた。",
	"pleasure": "広場の東から、提灯の続く通りへ入った。",
	"guild": "坑口館の扉を押した。査定課の秤の音と、帰還を書き込む筆の音がする。",
	"market": "坂を下って、灰の辻へ出た。焼いた芋の匂いと、売り声がする。",
	"home": "路地を抜けて、長屋の戸を開けた。自分の家のにおいがする。",
}
## 坑口館の掲示板(入るたびに2枚)
const NOTICES := [
	"【捜索の依頼】第3層で消息を絶った三人組。認識票だけでも届けてほしい。遺族より謝礼あり。",
	"【告示】帰還の期日を過ぎた者は、灯手隊が出る。帰還積立に入っていない者は、派遣料を払うこと。",
	"【求む】叫び茸の輪の位置。鳴子の材料にする。薬師組。",
	"【注意】鏡の層で、自分と同じ顔の者に声をかけられても、返事をしないこと。",
	"【講習】新人講習は、毎朝、二の鐘から。罠の見つけ方と、扉の聞き耳。",
	"【遺品課より】引き取り手のない遺品は、一年を過ぎると競りに出す。",
	"【告示】坑口守護官より。大穴の光が揺らいだ夜は、深く潜らないこと。",
	"【求む】腕のいい盗賊。鍵のかかった宝物庫の前で、三日も足止めを食っている。",
]
## 遺品課が引き取るもの。[品物, 謝礼の割合(買い値に対して)]。認識票と遺品の装備は、ここでしか引き取らない
const RELIC_RATE := {"relic_tag": 1.0, "relic_gear": 1.0, "relic_tools": 0.6, "relic_coins": 1.0}
const LEAVE_LINES := ["広場へ戻った。夜風が冷たい。", "広場へ戻った。坑口の光が、今夜も昇っている。", "広場へ戻った。どこかで、帰還を祝う声がする。"]

var gs: GameState
var content_panel: PanelContainer
var art: TownArt
var location := "hub"
var last_place := "dive"           # 広場へ戻ったとき、焦点を置く看板
var shop_mode := "buy"
var sel_id := ""
var shop_ids: Array = []
var report: Array = []
var last_report: Array = []        # 坑口館の査定課で、もう一度読める
var notices: Array = []
var party_bar: HBoxContainer
var silver_label: Label
var date_label: Label              # 今夜の座暦の日付(所持金の上)
var signs: Control                 # 広場の看板(画面の上に置く)
var report_box: PanelContainer     # 地上へ戻ったときの、ギルドの査定報告
var place_box: HBoxContainer       # 店の中: 左に戻るボタン、右に中身
var back_btn: Button
var place_label: Label
var content: VBoxContainer
var msg: Label
var shop_list: ItemList
var shop_detail: RichTextLabel
var shop_actions: VBoxContainer
var log_label: Label
var _walk_log: Array = []
var _parting := ""                 # 別れるかを確かめている仲間の名前
var _insure_ask := false          # 帰還積立: 入るか確かめている
var busy := false                  # 宿で眠っている間(暗転)は、操作を受け付けない

func setup(state: GameState) -> void:
	gs = state

func arrive(lines: Array) -> void:
	report = lines
	location = "hub"
	sel_id = ""
	_say(TownLines.pick("hub", gs.day, [HUB_LINE]), UIKit.TEXT)
	_refresh_all()

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = TownArt.new()
	add_child(art)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 22)
	add_child(margin)
	var root := UIKit.vbox(8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)
	var top := _glass(UIKit.panel())
	var th := UIKit.hbox(10)
	top.add_child(th)
	party_bar = UIKit.hbox(10)
	party_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(party_bar)
	var rv := UIKit.vbox(0)
	date_label = UIKit.label("", 13, UIKit.DIM)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(date_label)
	silver_label = UIKit.label("", 20, Color("f1d98a"))
	silver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(silver_label)
	th.add_child(rv)
	root.add_child(top)
	# 真ん中: 広場では背景の絵だけ(看板は別の層)。店の中では、左に戻るボタン、右に中身
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	place_box = UIKit.hbox(14)
	place_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	place_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(place_box)
	var left := UIKit.vbox(8)
	left.custom_minimum_size = Vector2(250, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place_box.add_child(left)
	place_label = UIKit.label("", 15, UIKit.GOLD)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lp := _glass(UIKit.panel(), 0.5)
	lp.add_child(place_label)
	left.add_child(lp)
	var cp := _glass(UIKit.panel(), 0.72)
	content_panel = cp
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content = UIKit.vbox(8)
	cp.add_child(content)
	place_box.add_child(cp)
	# 下: 一行の語り(看板に目をやると、その店のようすが出る)と、身の回りのこと
	var bottom := _glass(UIKit.panel())
	var bh := UIKit.hbox(8)
	bottom.add_child(bh)
	msg = UIKit.label("", 16, UIKit.GOLD)
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bh.add_child(msg)
	# 街のボタンは、右下にまとめる(ken 10/18)。タイトルへ・操作の設定は、持ち物(Tab)の画面から
	for it in [["持ち物 (%s)" % Controls.hint("inventory"), func(): open_inventory.emit()], ["闘技場", func(): arena_requested.emit()]]:
		var sb := UIKit.button(it[0], it[1])
		sb.add_theme_font_size_override("font_size", 13)
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(sb)
	back_btn = UIKit.button("広場へ (Esc)", func(): _go("hub"), 150)
	back_btn.name = "to_hub"
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(back_btn)
	root.add_child(bottom)
	# 広場の看板。絵の建物の上に、画面の割合で置く
	signs = Control.new()
	signs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	signs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(signs)
	for sg in SIGNS:
		signs.add_child(_make_sign(sg))
	# 査定報告は、看板の上に重ねる(読んで閉じるまで)
	report_box = _glass(UIKit.panel(), 0.9)
	report_box.anchor_left = 0.5
	report_box.anchor_right = 0.5
	report_box.offset_left = -300
	report_box.offset_right = 300
	report_box.offset_top = 104
	add_child(report_box)

## 看板一枚(木の板に名前と、何の店か。下に柱)
func _make_sign(sg: Array) -> Control:
	var id: String = sg[0]
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var at: Vector2 = sg[3]
	holder.anchor_left = at.x
	holder.anchor_right = at.x
	holder.anchor_top = at.y
	holder.anchor_bottom = at.y
	var b := Button.new()
	b.text = "%s\n%s" % [sg[1], sg[2]]
	b.name = "sign_" + id
	b.set_meta("place", id)
	b.add_theme_font_size_override("font_size", 17 if id != "dive" else 19)
	var wood := Color(0.17, 0.10, 0.05, 0.9) if id != "dive" else Color(0.05, 0.16, 0.24, 0.92)
	var edge := Color(0.78, 0.56, 0.30) if id != "dive" else UIKit.ACCENT
	b.add_theme_stylebox_override("normal", UIKit.box(wood, edge, 2, 6))
	b.add_theme_stylebox_override("hover", UIKit.box(wood.lightened(0.15), Color("ffe2a0"), 2, 6))
	b.add_theme_stylebox_override("focus", UIKit.box(wood.lightened(0.2), Color("fff0c0"), 3, 6))
	b.add_theme_stylebox_override("pressed", UIKit.box(wood.lightened(0.25), Color("fff0c0"), 3, 6))
	b.add_theme_color_override("font_color", Color("f3e2b8") if id != "dive" else Color("d8f6ff"))
	b.custom_minimum_size = Vector2(150, 0)
	b.pressed.connect(_on_sign.bind(id))
	b.focus_entered.connect(_sign_say.bind(id, String(sg[4])))
	b.mouse_entered.connect(_sign_say.bind(id, String(sg[4])))
	holder.add_child(b)
	var pole := ColorRect.new()
	pole.color = Color(0.1, 0.06, 0.03, 0.9)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pole)
	# 大きさが決まってから、看板の真ん中を置き場に合わせる
	b.resized.connect(func():
		b.position = Vector2(-b.size.x / 2.0, -b.size.y)
		pole.position = Vector2(-2.0, 0.0)
		pole.size = Vector2(4.0, 18.0))
	return holder

## 看板に目をやった。通りの様子は、月によって替わる
func _sign_say(id: String, base: String) -> void:
	_say(TownLines.sign_line(id, gs.day, base), UIKit.TEXT)

func _on_sign(id: String) -> void:
	last_place = id
	if id == "dive":
		dive.emit()
	else:
		_go(id)

## 背景の絵が透けて見えるパネル
func _glass(p: PanelContainer, a: float = 0.62) -> PanelContainer:
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.04, 0.05, 0.08, a), Color(0.66, 0.47, 0.29, 0.7)))
	return p

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if busy:
		get_viewport().set_input_as_handled()
		return
	if not e.is_echo() and e.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		open_inventory.emit()
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		if e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down") or e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right") or e.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			focus_default()
		return
	# 店の中: 戻る(Esc / B)で、操作 → 品物の一覧 → 広場、と一つずつ戻る
	if location != "hub" and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if f is Button and shop_actions != null and is_instance_valid(shop_actions) and shop_actions.is_ancestor_of(f):
			shop_list.grab_focus()
		else:
			_go("hub")
	elif location != "hub" and f == back_btn and e.is_action_pressed("ui_up"):
		if _focus_content():
			get_viewport().set_input_as_handled()

## コントローラーで操れるよう、焦点を置く。広場では最後に入った店の看板、店の中では中身
func focus_default() -> void:
	if signs == null:
		return
	if location == "hub":
		if report_box.visible and _focus_content_of(report_box):
			return
		var b := signs.find_child("sign_" + last_place, true, false)
		if b != null:
			(b as Button).grab_focus()
	elif not _focus_content():
		back_btn.grab_focus()

func _focus_content_of(n: Node) -> bool:
	var c := _first_focusable(n)
	if c == null:
		return false
	c.grab_focus()
	return true

## 店の中身で、最初に操れるものに焦点を置く。無ければ false
func _focus_content() -> bool:
	if content == null or location == "hub":
		return false
	return _focus_content_of(content)

func _first_focusable(n: Node) -> Control:
	var all: Array = []
	_collect_focusable(n, all)
	for c in all:
		if c.has_meta("pref"):
			return c
	return all[0] if not all.is_empty() else null

func _collect_focusable(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch.is_queued_for_deletion() or not (ch is Control) or not (ch as Control).visible:
			continue
		if _can_focus(ch):
			out.append(ch)
		_collect_focusable(ch, out)

func _can_focus(c: Control) -> bool:
	if c.focus_mode == Control.FOCUS_NONE or not c.visible:
		return false
	if c is BaseButton and (c as BaseButton).disabled:
		return false
	if c is ItemList and (c as ItemList).item_count == 0:
		return false
	return true

## 中身を作り直したあと、焦点が消えていれば置き直す
func _refocus_content() -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f == null or not is_instance_valid(f) or f.is_queued_for_deletion():
		focus_default()

func _say(text: String, color: Color = UIKit.GOLD) -> void:
	if msg == null:
		return
	msg.text = text
	msg.add_theme_color_override("font_color", color)

## 街の擬音(ken 10/18)。押したボタンの上に出す(ボタンが無ければ、下の帯の上)
func _cue(id: String, at: Vector2 = Vector2(-1, -1)) -> void:
	if not is_inside_tree():
		return
	var pos := at
	if pos.x < 0.0:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and is_instance_valid(f) and f.is_visible_in_tree() and is_ancestor_of(f):
			pos = f.get_global_rect().get_center() - global_position
		else:
			pos = Vector2(size.x * 0.5, size.y - 120.0)
	Sfx.cue(self, pos, id)
	var last := get_child(get_child_count() - 1)
	if last is Sfx:
		last.z_index = 0      # 持ち物の画面を開いたら、その下に隠れるように

## 店に入ったときの擬音(戸の鈴、炉の音、酒場のざわめき など)
const ENTER_CUE := {"smith": "t_anvil", "general": "t_bell", "magic": "t_door", "temple": "t_hush", "inn": "t_chatter",
	"guild": "t_pen", "market": "t_bustle", "home": "t_slide", "pleasure": "t_lantern"}

func _refresh_all() -> void:
	if gs == null or signs == null:
		return
	_refresh_top()
	art.set_style(String(LOCATIONS[location]["art"]))
	var hub := location == "hub"
	signs.visible = hub
	var hs := signs.find_child("sign_home", true, false)
	if hs != null:
		hs.get_parent().visible = Home.owned(gs)
	place_box.visible = not hub
	back_btn.visible = not hub
	_build_content()
	call_deferred("_refocus")

func refresh_top() -> void:
	_refresh_top()

func _refresh_top() -> void:
	UIKit.clear(party_bar)
	for i in gs.party.size():
		var c: Character = gs.party[i]
		var tag := "  (相棒)" if i == 1 and not c.hired else ""
		var l := UIKit.label("%s  Lv%d %s%s\nHP %d/%d  MP %d/%d" % [c.name, c.level, Jobs.CLASSES[c.cls]["name"], tag, int(ceil(c.hp)), c.max_hp(), int(c.mp), c.max_mp()], 14,
			UIKit.BAD if c.hp <= 0.0 else UIKit.TEXT)
		party_bar.add_child(l)
	silver_label.text = "所持金 %d銀貨   預金 %d銀貨" % [gs.silver, gs.bank_silver]
	var sp := TownLines.special_name(gs.day) if ZaCalendar.date(gs.day)["month"] != 13 else ""      # 座渡しは、日付に名前が入っている
	date_label.text = "%s  %s%s" % [ZaCalendar.label(gs.day), ZaCalendar.setsu(gs.day), ("  " + sp) if sp != "" else ""]

func _refocus() -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f == null or not is_instance_valid(f) or f.is_queued_for_deletion() or not f.is_visible_in_tree():
		focus_default()

func _go(loc: String) -> void:
	var from := location
	location = loc
	shop_mode = "buy"
	sel_id = ""
	_parting = ""
	_insure_ask = false
	_walk_log.clear()
	if loc == "hub":
		_say(TownLines.pick("leave", gs.day, LEAVE_LINES) if from != "hub" else TownLines.pick("hub", gs.day, [HUB_LINE]), UIKit.TEXT)
	else:
		last_place = loc
		_say(TownLines.pick("enter", gs.day, [String(ENTER_LINES.get(loc, ""))]), UIKit.TEXT)
	_refresh_all()
	if ENTER_CUE.has(loc) and from != loc:
		_cue(String(ENTER_CUE[loc]), Vector2(size.x * 0.5, size.y * 0.42))
	# 行き先を選んだら、そのまま中身を操れるようにする
	call_deferred("focus_default")

func _build_content() -> void:
	UIKit.clear(content)
	_build_report()
	if location == "hub":
		return
	place_label.text = String(QUOTES.get(location, ""))      # 店の人の一言(左)。宿の主人は、月と祭りで替わる
	if location == "inn":
		place_label.text = TownLines.pick_stable("inn", gs.day, [QUOTES["inn"]])
	match location:
		"smith", "general", "magic", "market": _content_shop(location)
		"temple": _content_temple()
		"inn": _content_inn()
		"pleasure": _content_pleasure()
		"guild": _content_guild()
		"home": _content_home()

## 中身の見出し(店の人の一言は、左の札に出す)
func _head(title: String, _quote: String = "") -> void:
	content.add_child(UIKit.label(title, 24, UIKit.GOLD))

# ---------- 広場 ----------

## 地上へ戻ったときの、ギルドの査定報告(広場の上に紙を一枚)。読んだら閉じる
func _build_report() -> void:
	for ch in report_box.get_children():
		ch.queue_free()
	report_box.visible = location == "hub" and not report.is_empty()
	if not report_box.visible:
		return
	last_report = report.duplicate()
	var v := UIKit.vbox(6)
	v.add_child(UIKit.label("ギルドの査定報告", 18, UIKit.ACCENT))
	for l in report:
		var lb := UIKit.label(String(l), 16)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lb)
	var close := UIKit.button("報告を閉じる", func():
		report = []
		_build_report()
		focus_default())
	close.set_meta("pref", true)
	v.add_child(close)
	report_box.add_child(v)

# ---------- 店 ----------

func _content_shop(sid: String) -> void:
	_head(String(LOCATIONS[sid]["name"]), String(QUOTES.get(sid, "")))
	var mb := UIKit.hbox(8)
	for m in [["buy", "買う"], ["sell", "売る"]]:
		var b := UIKit.button(m[1], _set_mode.bind(m[0]), 110)
		if shop_mode == m[0]:
			b.add_theme_stylebox_override("normal", UIKit.box(Color(0.3, 0.25, 0.14, 1.0), UIKit.GOLD, 2))
		mb.add_child(b)
	mb.set_meta("modes", true)
	content.add_child(mb)
	var row := UIKit.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	shop_list = ItemList.new()
	shop_list.custom_minimum_size = Vector2(380, 0)
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_list.item_selected.connect(_on_shop_pick)
	shop_list.item_activated.connect(_on_shop_activate)
	shop_list.focus_entered.connect(_on_list_focus)
	shop_list.set_meta("pref", true)
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
	call_deferred("_refocus_content")

## 一覧に焦点が来たら、選んでいなければ先頭を選ぶ(コントローラーでも説明が出るように)
func _on_list_focus() -> void:
	if shop_list.item_count > 0 and not shop_list.is_anything_selected() and not shop_list.is_item_disabled(0):
		shop_list.select(0)
		_on_shop_pick(0)

## 一覧で決定したら、その品物の操作(購入する など)へ移る
func _on_shop_activate(i: int) -> void:
	_on_shop_pick(i)
	var b := _first_focusable(shop_actions)
	if b != null:
		b.grab_focus()

func _fill_shop() -> void:
	shop_list.clear()
	shop_ids = []
	if shop_mode == "buy":
		for id in ItemDB.SHOPS[location]:
			shop_ids.append(id)
			var price := gs.buy_price(id)
			shop_list.add_item("%s   %d銀" % [ItemDB.item_name(id), price], ItemIcons.texture(id))
			if price > gs.silver:
				shop_list.set_item_custom_fg_color(shop_list.item_count - 1, Color(0.55, 0.45, 0.45))
	else:
		for id in gs.item_ids():
			if ItemDB.GUILD_ONLY.has(id):
				continue      # 認識票と遺品の装備は、坑口館の遺品課へ
			shop_ids.append(id)
			shop_list.add_item("%s ×%d   %d銀" % [ItemDB.item_name(id), gs.count(id), gs.sell_price(id)], ItemIcons.texture(id))
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
		t += "\n値段 [b]%d銀貨[/b]    所持 %d" % [gs.buy_price(sel_id), gs.count(sel_id)]
		if kind == "weapon" or kind == "armor" or kind == "acc":
			t += "\n"
			for c in gs.party:
				if ItemDB.can_equip(sel_id, c.cls):
					t += "\n[color=#5bc0de]%s[/color]  %s" % [c.name, c.compare_equip(sel_id)]
				else:
					t += "\n[color=#8a90a0]%s  (装備できない)[/color]" % c.name
		var b := UIKit.button("購入する", _buy.bind(-1))
		b.disabled = gs.buy_price(sel_id) > gs.silver
		shop_actions.add_child(b)
		if location == "market":
			var b5 := UIKit.button("5つ買う", _buy_n.bind(5))
			b5.disabled = gs.buy_price(sel_id) * 5 > gs.silver
			shop_actions.add_child(b5)
		if kind == "weapon" or kind == "armor" or kind == "acc":
			for i in gs.party.size():
				var c: Character = gs.party[i]
				if ItemDB.can_equip(sel_id, c.cls):
					var b2 := UIKit.button("買って %s に装備" % c.name, _buy.bind(i))
					b2.disabled = gs.buy_price(sel_id) > gs.silver
					shop_actions.add_child(b2)
		elif kind == "tome":
			for i in gs.party.size():
				var c2: Character = gs.party[i]
				if (it["classes"] as Array).has(c2.cls) and not c2.skills.has(String(it["teaches"])):
					var b3 := UIKit.button("買って %s が覚える" % c2.name, _buy.bind(i))
					b3.disabled = gs.buy_price(sel_id) > gs.silver
					shop_actions.add_child(b3)
	else:
		t += "\n買い取り [b]%d銀貨[/b]    所持 %d" % [gs.sell_price(sel_id), gs.count(sel_id)]
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
	_cue("t_coin")
	_refresh_top()
	_fill_shop()
	call_deferred("_refocus_shop")

## 市場で、まとめて買う
func _buy_n(n: int) -> void:
	if gs.buy_price(sel_id) * n > gs.silver:
		_say("所持金が足りない(預金は坑口館で引き出せる)", UIKit.BAD)
		return
	for i in n:
		gs.buy(sel_id)
	_say("%sを%dつ買った。" % [ItemDB.item_name(sel_id), n], UIKit.GOOD)
	_cue("t_coin")
	_refresh_top()
	_fill_shop()
	call_deferred("_refocus_shop")

func _sell() -> void:
	var name := ItemDB.item_name(sel_id)
	var r := gs.sell(sel_id)
	if r != "":
		_say(r, UIKit.BAD)
		return
	_say("%sを売った(+%d銀貨)" % [name, gs.sell_price(sel_id)], UIKit.GOOD)
	_cue("t_sell")
	if gs.count(sel_id) <= 0:
		sel_id = ""
	_refresh_top()
	_fill_shop()
	call_deferred("_refocus_shop")

## 買う・売るのボタンは作り直されるので、焦点を同じ操作か一覧へ戻す
func _refocus_shop() -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f != null and is_instance_valid(f) and not f.is_queued_for_deletion():
		return
	var b := _first_focusable(shop_actions)
	if b != null:
		b.grab_focus()
	elif shop_list.item_count > 0:
		shop_list.grab_focus()
	else:
		_refocus_content()

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
			b.disabled = cost > gs.silver
			content.add_child(b)
	if not any:
		content.add_child(UIKit.label("倒れている仲間はいない。", 15, UIKit.DIM))
	content.add_child(UIKit.label("祈り", 18, UIKit.ACCENT))
	var bless := UIKit.button("加護を願う(寄進 100銀貨)  次に潜るとき、しばらく受けるダメージが減る", _bless)
	bless.disabled = gs.silver < 100 or gs.blessed
	content.add_child(bless)
	if gs.blessed:
		content.add_child(UIKit.label("すでに加護を授かっている。", 14, UIKit.GOOD))
	content.add_child(UIKit.button("静かに祈る(無料)", _pray))

func _revive(c: Character) -> void:
	var cost := _revive_cost(c)
	if gs.silver < cost:
		return
	gs.silver -= cost
	c.hp = maxf(1.0, c.max_hp() * 0.5)
	_say("%sは目を開けた。「……夜が、明けたのですね。」" % c.name, UIKit.GOOD)
	_cue("t_revive")
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

func _bless() -> void:
	if gs.silver < 100 or gs.blessed:
		return
	gs.silver -= 100
	gs.blessed = true
	_say("神官が、燐晶の粉を額に置いた。「灯が、あなたと共に在りますように。」", UIKit.GOOD)
	TownFx.play(self, "bless")
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

func _pray() -> void:
	_say("膝をつき、目を閉じた。聖堂の奥で、誰も座っていない十二番目の座が、静かに光っている。", UIKit.TEXT)
	_cue("t_pray")

# ---------- 坑口館(冒険者ギルド) ----------

func _relic_reward(id: String) -> int:
	return int(round(int(ItemDB.ITEMS[id]["price"]) * float(RELIC_RATE[id])))

func _content_guild() -> void:
	_head(String(LOCATIONS["guild"]["name"]), String(QUOTES["guild"]))
	content.add_child(UIKit.label("大穴の縁に建つ、潜行者組合の本部。窓口の向こうで、査定課の秤が鳴っている。", 14, UIKit.DIM))
	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var lc := UIKit.vbox(6)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(lc)
	var rc := UIKit.vbox(6)
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rc)
	_guild_permit(lc)
	_guild_relics(lc)
	_guild_insurance(lc)
	_guild_house(lc)
	_guild_report(lc)
	_guild_bank(rc)
	_guild_board(rc)

func _wrap(t: String, sz: int, col: Color = UIKit.TEXT) -> Label:
	var lb := UIKit.label(t, sz, col)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lb

## 許可証課: 潜行許可証の等級(Permit。ken 10/16)。層の主を倒すと、戻ったときに書き換える
func _guild_permit(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("許可証課  潜行許可証", 18, UIKit.ACCENT))
	var nx := Permit.next_hint(gs)
	box.add_child(_wrap("いまの許可証: %s。%s" % [Permit.label(gs), nx if nx != "" else "最上の等級。竜の巣まで潜れる。"], 15, UIKit.GOLD))

## 預金課: 所持金を預ける・引き出す(100銀貨 単位。ken 10/18)。店で使えるのは所持金だけ。預金は全滅しても無事
func _guild_bank(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("預金課  預け入れと引き出し", 18, UIKit.ACCENT))
	box.add_child(_wrap("所持金 %d銀貨    預金 %d銀貨" % [gs.silver, gs.bank_silver], 16, UIKit.GOLD))
	var r1 := UIKit.hbox(6)
	for n in [100, 1000]:
		var b := UIKit.button("%d 預ける" % n, _bank.bind(n), 104)
		b.disabled = gs.silver < n
		r1.add_child(b)
	var ba := UIKit.button("全部預ける", _bank.bind(gs.silver - gs.silver % GameState.BANK_UNIT), 110)
	ba.disabled = gs.silver < GameState.BANK_UNIT
	r1.add_child(ba)
	box.add_child(r1)
	var r2 := UIKit.hbox(6)
	for n in [100, 1000]:
		var w := UIKit.button("%d 引き出す" % n, _bank.bind(-n), 104)
		w.disabled = gs.bank_silver < n
		r2.add_child(w)
	box.add_child(r2)
	box.add_child(_wrap("店で使えるのは所持金だけ。所持金は迷宮へも持って入るので、全滅すると失う(帰還積立が効けば半分)。預金は全滅しても無事。査定・依頼の報酬・遺品の謝礼は預金に入る。この窓口(帰還積立、家)では、預金から先に払う。", 13, UIKit.DIM))

## n > 0 なら預ける、n < 0 なら引き出す
func _bank(n: int) -> void:
	var got := gs.deposit(n) if n > 0 else gs.withdraw(-n)
	if got <= 0:
		return
	gs.save()
	if n > 0:
		_cue("t_write")
		_after_guild("窓口の係が銀貨を数え、帳面に書き入れた。「%d銀貨、確かに預かった。」(所持金 → 預金)" % got, UIKit.GOOD)
	else:
		_cue("t_coin")
		_after_guild("係が奥の金庫から銀貨を出して、数えて渡した。「%d銀貨。落とすなよ。」(預金 → 所持金)" % got, UIKit.GOOD)

## 遺品課: 遺品を引き取り、謝礼を出す
func _guild_relics(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("遺品課  遺品の引き取り", 18, UIKit.ACCENT))
	var any := false
	var total := 0
	for id in RELIC_RATE:
		var n := gs.count(id)
		if n <= 0:
			continue
		any = true
		total += _relic_reward(id) * n
		var row := UIKit.hbox(6)
		var ic := TextureRect.new()
		ic.texture = ItemIcons.texture(id)
		ic.custom_minimum_size = Vector2(26, 26)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		row.add_child(_wrap("%s ×%d  謝礼 %d銀/1つ" % [ItemDB.item_name(id), n, _relic_reward(id)], 15))
		row.add_child(UIKit.button("1つ渡す", _hand_relic.bind(id, 1), 92))
		if n > 1:
			row.add_child(UIKit.button("全部", _hand_relic.bind(id, n), 64))
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(64, 0)
			row.add_child(gap)
		box.add_child(row)
	if any:
		box.add_child(UIKit.button("遺品をまとめて渡す(謝礼 %d銀貨)" % total, _hand_all_relics))
	else:
		box.add_child(_wrap("届ける遺品はない。迷宮で遺体を調べると、認識票や遺品が見つかることがある。", 14, UIKit.DIM))
	box.add_child(_wrap("認識票と遺品の装備は、ここでしか引き取らない(店では売れない)。", 13, UIKit.DIM))

## 帰還積立: 次の潜行で全滅しても、灯手隊が装備と持ち物の半分を拾ってくる
func _guild_insurance(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("帰還記録課  帰還積立", 18, UIKit.ACCENT))
	if gs.insured:
		box.add_child(_wrap("次の潜行は、帰還積立に入っている。腐葉の回廊(第1〜2層)で全滅しても、灯手隊が装備と持ち物の半分を拾ってくる。", 14, UIKit.GOOD))
		return
	var cost := gs.insurance_cost()
	if _insure_ask:
		# 確かめる(ken 10/18)
		var ask := _glass(UIKit.panel(), 0.95)
		var av := UIKit.vbox(6)
		ask.add_child(av)
		av.add_child(_wrap("帰還積立に入る? 掛け金 %d銀貨。\n効くのは次の潜行一回ぶんで、腐葉の回廊(第1〜2層)で全滅したときだけ。それより深い層では、灯手隊は拾いに行けない。" % cost, 15, UIKit.GOLD))
		var ah := UIKit.hbox(8)
		var yes := UIKit.button("入る", _insure, 110)
		yes.set_meta("pref", true)
		ah.add_child(yes)
		ah.add_child(UIKit.button("やめる", func():
			_insure_ask = false
			_after_guild("「そうかい。気が変わったら、また来な。」", UIKit.TEXT), 110))
		av.add_child(ah)
		box.add_child(ask)
		return
	var b := UIKit.button("帰還積立に入る(%d銀貨)" % cost, func():
		_insure_ask = true
		_build_content()
		call_deferred("_refocus_insure"))
	b.disabled = gs.guild_funds() < cost
	box.add_child(b)
	box.add_child(_wrap("次の潜行一回ぶん。腐葉の回廊(第1〜2層)で全滅しても、灯手隊が装備と持ち物の半分を拾ってくる。掛け金は仲間のレベルで決まる。", 13, UIKit.DIM))

## 空き家の札: 壁下区の長屋の一間を買う(生産系②)
func _guild_house(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("空き家の札  住まいの斡旋", 18, UIKit.ACCENT))
	if Home.owned(gs):
		box.add_child(_wrap("壁下区の長屋に、自分の家がある(広場の看板「我が家」)。", 14, UIKit.GOOD))
		return
	var b := UIKit.button("壁下区の長屋の一間を買う(%d銀貨)" % Home.HOUSE_PRICE, _buy_house)
	b.disabled = gs.guild_funds() < Home.HOUSE_PRICE
	box.add_child(b)
	box.add_child(_wrap("台所と寝床つき。台所では全部の料理を作れ、寝床ではただで休める。食料庫・物置・実験室は、あとから増築できる。", 13, UIKit.DIM))

func _buy_house() -> void:
	var e := Home.buy_house(gs)
	if e != "":
		_say(e, UIKit.BAD)
		return
	_cue("t_key")
	_after_guild(("係が鍵を一本、窓口に置いた。「壁下区の長屋、三の路地の奥だ。前の住人は……まあ、戻らなかった。」(-%d銀貨。預金から先に払う)  " % Home.HOUSE_PRICE
		+ Trophies.line(Trophies.evaluate(gs))).strip_edges(), UIKit.GOOD)

func _content_home() -> void:
	_head(String(LOCATIONS["home"]["name"]))
	var hp := HomePanel.new()
	hp.setup(self, gs, "kitchen")
	content.add_child(hp)

func _guild_report(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("査定課  前回の査定", 18, UIKit.ACCENT))
	if last_report.is_empty():
		box.add_child(_wrap("今夜の査定の記録は、まだない。", 14, UIKit.DIM))
		return
	for l in last_report:
		box.add_child(_wrap(String(l), 14))

## 掲示板: 受けた依頼と、今日の依頼、告示
func _guild_board(box: VBoxContainer) -> void:
	box.add_child(UIKit.label("掲示板  依頼(受けられるのは%d件まで)" % GameState.MAX_QUESTS, 18, UIKit.ACCENT))
	for i in gs.quests.size():
		var q: Dictionary = gs.quests[i]
		var have := gs.count(String(q["id"]))
		var ok := have >= int(q["n"])
		var row := UIKit.hbox(6)
		row.add_child(_wrap("受けている: %s %s %d/%d  報酬 %d銀" % [q["client"], ItemDB.item_name(String(q["id"])), mini(have, int(q["n"])), int(q["n"]), int(q["reward"])], 15,
			UIKit.GOOD if ok else UIKit.TEXT))
		var d := UIKit.button("納品する", _deliver.bind(i), 92)
		d.disabled = not ok
		row.add_child(d)
		row.add_child(UIKit.button("やめる", _drop_quest.bind(i), 64))
		box.add_child(row)
	var offers := gs.offered_quests()
	for q2 in offers:
		var row2 := UIKit.hbox(6)
		row2.add_child(_wrap("【依頼】%s「%s」%s ×%d  報酬 %d銀" % [q2["client"], q2["line"], ItemDB.item_name(String(q2["id"])), int(q2["n"]), int(q2["reward"])], 15, Color("e8dcb0")))
		var a := UIKit.button("受ける", _accept.bind(q2), 72)
		a.disabled = gs.quests.size() >= GameState.MAX_QUESTS
		row2.add_child(a)
		box.add_child(row2)
	box.add_child(_wrap("依頼の品は、迷宮で拾うか、魔物から取る。掲示板の依頼は、日ごとに貼り替わる。", 13, UIKit.DIM))
	box.add_child(Control.new())
	if notices.is_empty():
		notices = [NOTICES.pick_random()]
	for n2 in notices:
		box.add_child(_wrap(String(n2), 14, UIKit.DIM))

func _after_guild(line: String, col: Color) -> void:
	_say(line, col)
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

## 確かめる欄の「入る」に焦点を置く
func _refocus_insure() -> void:
	for b in content.find_children("*", "Button", true, false):
		if (b as Button).text == "入る":
			(b as Button).grab_focus()
			return
	_refocus_content()

func _insure() -> void:
	_insure_ask = false
	var cost := gs.insurance_cost()
	if gs.insured or not gs.pay_at_guild(cost):
		return
	gs.insured = true
	gs.save()
	_cue("t_write")
	_after_guild("帰還記録課の帳面に、仲間の名を書き込んだ。「無事に戻れば、それが一番だがね。」(-%d銀貨。預金から先に払う)" % cost, UIKit.GOOD)

func _accept(q: Dictionary) -> void:
	var r := gs.accept_quest(q)
	if r != "":
		_say(r, UIKit.BAD)
		return
	_cue("t_peel")
	_after_guild("掲示板から%sの依頼書を剥がして、受付に出した。「%s ×%d。頼んだよ。」" % [q["client"], ItemDB.item_name(String(q["id"])), int(q["n"])], UIKit.TEXT)

func _deliver(i: int) -> void:
	var q: Dictionary = gs.quests[i]
	var got := gs.deliver_quest(i)
	if got < 0:
		_say("まだ数が足りない", UIKit.BAD)
		return
	_cue("t_coin")
	_after_guild("%sを納めた。受付が%sからの報酬を、預金に書き入れた。(預金 +%d銀貨)" % [ItemDB.item_name(String(q["id"])), q["client"], got], UIKit.GOOD)

func _drop_quest(i: int) -> void:
	var q: Dictionary = gs.quests[i]
	gs.drop_quest(i)
	_after_guild("%sの依頼をやめた。依頼書は、また掲示板に貼り戻された。" % q["client"], UIKit.TEXT)

func _hand_relic(id: String, n: int) -> void:
	var got := 0
	for i in mini(n, gs.count(id)):
		gs.remove_item(id)
		got += _relic_reward(id)
	gs.bank_silver += got
	var line := "遺品課の係が、%sを受け取った。「……届けておく。ありがとう。」(謝礼は預金へ +%d銀貨)" % [ItemDB.item_name(id), got]
	if id == "relic_tag":
		line = "係は認識票の名を、帳面と見比べた。「……この人の家族に、知らせておく。」(謝礼は預金へ +%d銀貨)" % got
	_say(line, UIKit.GOOD)
	gs.save()
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

func _hand_all_relics() -> void:
	var got := 0
	for id in RELIC_RATE:
		while gs.count(id) > 0:
			gs.remove_item(id)
			got += _relic_reward(id)
	gs.bank_silver += got
	_say("遺品をまとめて窓口に置いた。係は一つずつ帳面に書き込んだ。(謝礼 +%d銀貨)" % got, UIKit.GOOD)
	gs.save()
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

# ---------- 宿屋 ----------

func _content_inn() -> void:
	_head(String(LOCATIONS["inn"]["name"]), String(QUOTES["inn"]))
	var alive := 0
	for c in gs.party:
		if c.hp > 0.0:
			alive += 1
	var cost := 30 * alive
	var rest := UIKit.button("泊まる(%d銀貨)  生きている仲間のHPとMPが全快する" % cost, _rest.bind(cost))
	rest.disabled = gs.silver < cost or alive == 0
	content.add_child(rest)
	content.add_child(UIKit.button("酒場で噂を聞く(無料)", _rumor))
	var full := gs.party.size() >= Balance.MAX_PARTY
	var rb := UIKit.button("酒場で仲間を探す(いま%d人 / 最大%d人)" % [gs.party.size(), Balance.MAX_PARTY], func(): recruit.emit())
	rb.disabled = full
	content.add_child(rb)
	content.add_child(UIKit.button("記録をつける(セーブ)", _save))
	content.add_child(UIKit.label("倒れた仲間は、宿では目を覚まさない。神殿で蘇らせること。", 14, UIKit.DIM))
	content.add_child(Control.new())
	content.add_child(UIKit.label("並び順(上が隊列の先頭。迷宮では先頭の仲間から操作する)", 16, UIKit.ACCENT))
	for i in gs.party.size():
		var c: Character = gs.party[i]
		var row := UIKit.hbox(8)
		var up := UIKit.button("↑", _move_member.bind(i, -1))
		up.custom_minimum_size = Vector2(40, 32)
		up.disabled = i == 0
		row.add_child(up)
		var dn := UIKit.button("↓", _move_member.bind(i, 1))
		dn.custom_minimum_size = Vector2(40, 32)
		dn.disabled = i == gs.party.size() - 1
		row.add_child(dn)
		var who := "相棒" if not c.hired and i > 0 else ("" if not c.hired else "酒場で加えた仲間")
		var nl := UIKit.label("%d. %s  %s・%s  Lv%d%s" % [i + 1, c.name, Jobs.RACES[c.race]["name"], Jobs.CLASSES[c.cls]["name"], c.level, ("  [%s]" % who) if who != "" else ""], 16,
			UIKit.BAD if c.hp <= 0.0 else UIKit.TEXT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		if c.hired:
			var sure := _parting == c.name
			var pb := UIKit.button("本当に別れる" if sure else "別れる", _part.bind(c), 130)
			if sure:
				pb.add_theme_stylebox_override("normal", UIKit.box(Color(0.35, 0.1, 0.08, 1.0), UIKit.BAD, 2))
			row.add_child(pb)
		content.add_child(row)
	if gs.party.size() > 2:
		content.add_child(UIKit.label("酒場で加えた仲間とは、ここで別れられる(装備は外して、持ち物に残る)。主人公と相棒は別れない。", 14, UIKit.DIM))

## 酒場で加えた仲間と別れる。一度目は確かめ、二度目で別れる
func _part(c: Character) -> void:
	if _parting != c.name:
		_parting = c.name
		_say("%sと別れる? もう一度押すと別れる。装備は外して、持ち物に残る。" % c.name, UIKit.GOLD)
		_build_content()
		call_deferred("_refocus_part", c.name)
		return
	_parting = ""
	if gs.dismiss(c):
		_say("%sと別れた。「縁があったら、また坑口で会おう。」" % c.name, UIKit.TEXT)
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

func _refocus_part(nm: String) -> void:
	var all: Array = []
	_collect_focusable(content, all)
	for b in all:
		if b is Button and (b as Button).text == "本当に別れる":
			(b as Button).grab_focus()
			return
	_refocus_content()

## 並び順を一つ動かす(先頭が、迷宮で最初に操作する仲間で、隊列の先頭)
func _move_member(i: int, d: int) -> void:
	var j := i + d
	if j < 0 or j >= gs.party.size():
		return
	var c: Character = gs.party[i]
	gs.party[i] = gs.party[j]
	gs.party[j] = c
	gs.save()
	_say("%sを%d番目にした。" % [c.name, j + 1], UIKit.TEXT)
	_refresh_top()
	_build_content()
	call_deferred("_refocus_content")

func _rest(cost: int) -> void:
	if gs.silver < cost or busy:
		return
	gs.silver -= cost
	sleep_night("湯を使い、寝床で眠った。")

## 眠って一晩を過ごす(宿、我が家の寝床)。暗転して ｚｚｚｚ…… が昇り、明けると翌朝(ken 10/18)。
## 生きている仲間の HP と MP が全快し、日付が一つ進む。done(一行) を渡すと、明けたあとの画面はそちらで作る
func sleep_night(line: String, done: Callable = Callable()) -> void:
	busy = true
	get_viewport().gui_release_focus()
	var fx := TownFx.play(self, "sleep", _pass_night.bind(line, done))
	fx.finished.connect(func():
		busy = false
		call_deferred("_refocus_content"))

func _pass_night(line: String, done: Callable) -> void:
	for c in gs.party:
		if c.hp > 0.0:
			c.hp = c.max_hp()
			c.mp = c.max_mp()
	var rotten0 := _rotten_count()
	gs.day += 1
	gs.set_clock(gs.town_clock())
	var lines: Array = [line, "翌朝、%s。体が軽い。" % ZaCalendar.label(gs.day)]
	var pots := Home.ready_pots(gs)
	if not pots.is_empty():
		lines.append("実験室で、%sが仕上がっている。" % "、".join(pots))
	var anvil := Smithing.anvil_ready(gs)
	if anvil != "":
		lines.append("鍛冶場で、%sが仕上がっている。" % anvil)
	var rotten := _rotten_count() - rotten0
	if rotten > 0:
		lines.append("料理が%d皿、くさってしまった。" % rotten)
	notices = []      # 掲示板は、日ごとに貼り替わる
	gs.save()
	_refresh_top()
	var full := "  ".join(lines)
	if done.is_valid():
		done.call(full)
	else:
		_say(full, UIKit.GOOD)
		_build_content()

func _rotten_count() -> int:
	var n := 0
	for f in gs.food:
		if Cooking.rotten(f, gs.clock):
			n += int(f["n"])
	return n

func _rumor() -> void:
	_say("酒場の隅で聞こえた話だ。\n" + TownLines.pick("rumors", gs.day, RUMORS), UIKit.TEXT)
	_cue("t_whisper")

func _save() -> void:
	var ok := gs.save()
	_say("記録をつけた。" if ok else "記録に失敗した。", UIKit.GOOD)
	if ok:
		_cue("t_write")

# ---------- 花街(雰囲気のみ) ----------

func _content_pleasure() -> void:
	_head("花街「寝息通り」", "縁環区と壁下区の境に伸びる通り。迷宮の「息」に対して、人の寝息の通りと呼ばれる。")
	content.add_child(UIKit.label("灯火の女神ルシュカの守る通り。ここでは、誰もが肩書きを脱いで歩く。", 14, UIKit.DIM))
	var r := UIKit.hbox(8)
	r.add_child(UIKit.button("通りを歩く", func(): _push_walk(TownLines.pick("walk", gs.day, WALK_LINES)); _cue("t_geta")))
	r.add_child(UIKit.button("灯籠を見上げる", func(): _push_walk(TownLines.pick("look", gs.day, LOOK_LINES)); _cue("t_sway")))
	r.add_child(UIKit.button("占い師の屋台", func(): _push_walk(TownLines.pick("fortune", gs.day, FORTUNES)); _cue("t_fortune")))
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
