class_name RoomHooks
extends RefCounted
## 部屋の手がかり(生成器のテーマごとの hooks。部屋のおよそ3分の1)。ken 10/24:
## 初めて入ると、画面の中央に大きめに長めに出て、自然に消える(ログにも残す。Hud.show_banner)。
## 物がある手がかり(認識票・許可証・袋・燐晶)だけ、床に小さく光る印を付け、E で拾える。
## 拾った物は遺品として、坑口館の遺品課に渡せて謝礼が出る(いまの遺品の仕組みのまま)。

## 手がかりの文 → 拾える物 [品物, 数]。"crystal" は燐晶(基本の純度を 0.15kg ずつ)。
## 物でも、値打ちのない物(賭け札、分銅、地図、鍵)や持ち去ると罰当たりな物(供えた花、僧衣)は拾えない
const ITEMS := {
	# 腐葉の回廊
	"灰色の潜行許可証が落ちている。名義の欄が、刃物で削り取られている。": ["relic_permit", 1],
	"相棒契約の認識票が、片方だけ壁の釘に掛けてある。": ["relic_tag", 1],
	"徴税官の封蝋がない燐晶の小袋が、腐葉の下に隠してある。": ["crystal", 2],
	# 錆鉄の坑道
	"鉱車の底に、封蝋のない燐晶が張りつくように残っている。": ["crystal", 1],
	"青銅の潜行許可証が二枚、紐で結ばれて梁に掛けてある。": ["relic_permit", 2],
	"鎧の中に骨が残っている。許可証は黒鉄。この層にいるはずのない等級。": ["relic_permit", 1],
	# 水鏡の回廊
	"銀の潜行許可証が水底に沈んでいる。帰還の記録では、持ち主は生還したことになっている。": ["relic_permit", 1],
	"地図師の測り縄が、結び目を七つ作ったまま捨ててある。": ["relic_tools", 1],
	"水ぎわに、二人分の荷がきちんと並べてある。持ち主の姿はない。": ["relic_gear", 2],
	# 骨の大聖堂
	"骨の柱に、黒鉄の潜行許可証が釘で打ちつけてある。封鎖令の日付が、その下に刻んである。": ["relic_permit", 1],
	"相棒契約の認識票が二枚、祭壇の上に重ねて置いてある。": ["relic_tag", 2],
	# どこにでも
	"誰かの背負い袋が置き去りにされている。中身は荒らされていない。": ["relic_gear", 1],
}
const CRYSTAL_KG := 0.15
const REACH := 30.0             # 拾える距離(画素)
const MARK_COL := Color("c9b6ff")

static func item_for(text: String) -> Array:
	return ITEMS.get(text, [])

## 階の印。物がある手がかりの部屋に一つずつ、部屋の中の決まった床に(部屋と夜で決まる)
static func marks(fl: FloorInstance) -> Array:
	var out: Array = []
	var m := fl.map
	for r in m.rooms:
		var h: Variant = r.get("hook")
		if typeof(h) != TYPE_STRING or not ITEMS.has(h):
			continue
		var rid := int(r["id"])
		var cells: Array = m.room_cells.get(rid, [])
		var ok: Array = []
		for ci in cells:
			var c := Vector2i(int(ci) % m.w, int(ci) / m.w)
			if c == fl.up_cell or c == fl.down_cell or fl.trap_at.has(c):
				continue
			ok.append(c)
		if ok.is_empty():
			continue
		var pick: Vector2i = ok[absi(hash("hook|%d|%d|%d" % [fl.floor_no, fl.night_no, rid])) % ok.size()]
		var it: Array = ITEMS[h]
		out.append({"room": rid, "cell": pick, "pos": m.center_of(pick), "id": String(it[0]), "qty": int(it[1]), "text": String(h), "taken": false})
	return out

## 手の届く印(無ければ空)
static func mark_near(fl: FloorInstance, pos: Vector2) -> Dictionary:
	for mk in fl.hook_marks:
		if not bool(mk["taken"]) and pos.distance_to(mk["pos"]) <= REACH:
			return mk
	return {}

static func item_name(mk: Dictionary) -> String:
	return "燐晶" if String(mk["id"]) == "crystal" else ItemDB.item_name(String(mk["id"]))

## 床の小さく光る印(見たことのある所だけ。見えていないときは暗く)
static func draw_marks(fl: FloorInstance, view: Rect2) -> void:
	var m := fl.map
	var tms := float(Time.get_ticks_msec()) / 1000.0
	for mk in fl.hook_marks:
		if bool(mk["taken"]):
			continue
		var p: Vector2 = mk["pos"]
		var c: Vector2i = mk["cell"]
		if not view.has_point(p) or m.explored[m.idx(c.x, c.y)] == 0:
			continue
		var k := 1.0 if m.visible[m.idx(c.x, c.y)] == 1 else 0.4
		var pulse := 0.5 + 0.5 * sin(tms * 3.0 + float(mk["room"]))
		fl.draw_circle(p, 9.0 + pulse * 3.0, Color(MARK_COL, 0.12 * k))
		fl.draw_circle(p, 4.5, Color(MARK_COL, (0.35 + 0.3 * pulse) * k))
		fl.draw_circle(p, 2.0, Color(1, 1, 1, (0.6 + 0.4 * pulse) * k))
		# きらめき(短い十字)
		var tw := 3.0 + pulse * 3.0
		fl.draw_line(p + Vector2(-tw, 0), p + Vector2(tw, 0), Color(1, 1, 1, 0.5 * pulse * k), 1.0)
		fl.draw_line(p + Vector2(0, -tw), p + Vector2(0, tw), Color(1, 1, 1, 0.5 * pulse * k), 1.0)
