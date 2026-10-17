class_name Journal
extends RefCounted
## 冒険日記帳(ken 10/17)。見かけた魔物と倒した魔物を種類ごとに、ほかに実績(Trophies)が見る歩みの数を、gs.journal に残す。
## 魔物の一覧は data/bestiary.json(tools/export-bestiary.py が層のデータから作る)。闘技場の魔物は数えない。
##   gs.journal = {"seen": {index: 見かけた数}, "killed": {index: 倒した数}, "first": {index: "N日目 第L層"},
##                 "stats": {key: 数}, "trophies": {id: 取った日}}
## stats の key: cook_great / cook_burnt / rotten_eaten / brew_great / forge_great / wipes / deepest(着いた最も深い層) / lair(竜の巣に着いた) /
##               best_return(一度に持ち帰った燐晶の最高額) / mimic_bite / deepest_floor(着いた最も深い階。通し番号) / abyss(縦穴を覗いた) /
##               rope(縄梯子で上り下りした)

static var _cat := {}

static func catalog() -> Dictionary:
	if _cat.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			_cat = parsed
	return _cat

static func layer_ids() -> Array:
	var out: Array = []
	for k in catalog().get("layers", {}):
		out.append(int(k))
	out.sort()
	return out

## 前の層と魔物の顔ぶれが全く同じ層か(第1層と第2層など。狩り尽くしの実績は一つにまとめる)
static func same_as_prev(n: int) -> bool:
	if n <= 1 or layer(n - 1).is_empty():
		return false
	var a: Array = layer(n).get("mons", []).duplicate()
	var b: Array = layer(n - 1).get("mons", []).duplicate()
	a.sort()
	b.sort()
	return a == b

## 層 n から、顔ぶれが同じ層が続く最後の層
static func span_end(n: int) -> int:
	var e := n
	while not layer(e + 1).is_empty() and same_as_prev(e + 1):
		e += 1
	return e

static func layer(n: int) -> Dictionary:
	return catalog().get("layers", {}).get(str(n), {})

static func mon(index: String) -> Dictionary:
	return catalog().get("monsters", {}).get(index, {})

static func empty() -> Dictionary:
	return {"seen": {}, "killed": {}, "first": {}, "stats": {}, "trophies": {}}

## 読み込んだ記録を整える(古い記録や壊れた記録でも動くように)
static func sanitize(v: Variant) -> Dictionary:
	var j := empty()
	if typeof(v) != TYPE_DICTIONARY:
		return j
	for k in ["seen", "killed", "stats"]:
		var src: Variant = v.get(k, {})
		if typeof(src) == TYPE_DICTIONARY:
			for key in src:
				j[k][String(key)] = int(src[key])
	for k in ["first", "trophies"]:
		var src2: Variant = v.get(k, {})
		if typeof(src2) == TYPE_DICTIONARY:
			for key in src2:
				j[k][String(key)] = src2[key] if k == "trophies" else String(src2[key])
	for key in j["trophies"]:
		j["trophies"][key] = int(j["trophies"][key])
	return j

static func _j(gs: GameState) -> Dictionary:
	if gs.journal.is_empty():
		gs.journal = empty()
	return gs.journal

## 魔物を見かけた。初めて見た種類なら true(日記帳に書き足す)
static func see(gs: GameState, index: String, layer_no: int) -> bool:
	var j := _j(gs)
	var first: bool = not j["seen"].has(index)
	j["seen"][index] = int(j["seen"].get(index, 0)) + 1
	if first:
		j["first"][index] = "%d日目 第%d層" % [gs.day + 1, layer_no]
	return first

static func kill(gs: GameState, index: String) -> void:
	var j := _j(gs)
	j["killed"][index] = int(j["killed"].get(index, 0)) + 1
	if not j["seen"].has(index):
		j["seen"][index] = 1

static func bump(gs: GameState, key: String, n: int = 1) -> void:
	var j := _j(gs)
	j["stats"][key] = int(j["stats"].get(key, 0)) + n

## 最高の値だけ残す(着いた最も深い層、一度に持ち帰った額)
static func best(gs: GameState, key: String, v: int) -> void:
	var j := _j(gs)
	j["stats"][key] = maxi(int(j["stats"].get(key, 0)), v)

static func stat(gs: GameState, key: String) -> int:
	return int(_j(gs)["stats"].get(key, 0))

static func seen(gs: GameState, index: String) -> int:
	return int(_j(gs)["seen"].get(index, 0))

static func killed(gs: GameState, index: String) -> int:
	return int(_j(gs)["killed"].get(index, 0))

static func seen_species(gs: GameState) -> int:
	return (_j(gs)["seen"] as Dictionary).size()

static func killed_total(gs: GameState) -> int:
	var n := 0
	for k in _j(gs)["killed"]:
		n += int(_j(gs)["killed"][k])
	return n

## 層の魔物のうち、倒した種類の数と、全部の数
static func layer_progress(gs: GameState, n: int) -> Vector2i:
	var ids: Array = layer(n).get("mons", [])
	var done := 0
	for id in ids:
		if killed(gs, String(id)) > 0:
			done += 1
	return Vector2i(done, ids.size())

# ---------- 冒険日記帳の画面(InventoryScreen の「冒険日記帳」) ----------

const TYPE_JP := {"aberration": "異形", "beast": "獣", "celestial": "天上の者", "construct": "人造", "dragon": "竜", "elemental": "精霊",
	"fey": "妖精", "fiend": "魔性", "giant": "巨人", "humanoid": "人型", "monstrosity": "怪物", "ooze": "粘体", "plant": "植物",
	"undead": "不死", "swarm": "群れ"}
const SIZE_JP := {"T": "とても小さい", "S": "小さい", "M": "中くらい", "L": "大きい", "H": "とても大きい", "G": "巨大"}
## 特徴の印(MonTraits)を、日記帳に書く一言に
const TRAIT_JP := {"pack": "群れで囲む", "smell": "鼻が利く(壁越しに嗅ぎつける)", "hearing": "耳が利く", "sight": "目が利く",
	"swarm": "群れで重なり合う", "mimic": "物のふりをする", "ambush": "不意を突く", "grapple": "張りつく", "ghost": "壁を抜ける",
	"fortitude": "倒れても起き上がる", "relentless": "一度だけ踏みとどまる", "charge": "構えて突進する", "trample": "突進して踏みつける",
	"leap": "跳びかかる", "regen": "傷が塞がる(火や光で止まる)", "burst": "死に際に弾ける", "rust": "鎧を錆びさせる", "shadow": "闇にまぎれる",
	"flyby": "当てて離れる", "frenzy": "血に狂う", "reckless": "捨て身で来る",
	"sun": "灯りの中で弱る", "sun_weak": "灯りの中で弱り、傷も深くなる", "aquatic": "水たまりに沈んで待つ(陸では鈍い)",
	"amphib": "水たまりに沈んで待つ", "climb": "天井から落ちてくる", "webwalk": "巣を張る", "websense": "巣の揺れで気づく",
	"shape": "人や鼠に化ける", "magic_res": "魔法に強い", "amorph": "扉の下をくぐる", "gaze": "見つめると石になる(目をそらせ)",
	"stench": "ひどい臭い", "glow": "体が光る", "absorb_lightning": "雷を吸う", "water_sus": "冷気に弱い",
	"recall": "迷宮の道を覚えている", "siege": "扉を壊す"}

## 日記帳に載る魔物の名前(見かけていなければ ？？？)
static func entry_name(gs: GameState, index: String) -> String:
	if seen(gs, index) <= 0:
		return "？？？"
	var m := mon(index)
	if not m.is_empty():
		return String(m["name"])
	return String(MonTraits._lookup(index).get("j", index))

## 層の一覧に載っていない魔物(遺体から湧いた、ワンダリングなど)で、出会ったもの
static func others(gs: GameState) -> Array:
	var out: Array = []
	for k in _j(gs)["seen"]:
		if mon(String(k)).is_empty():
			out.append(String(k))
	out.sort()
	return out

static func entry_text(gs: GameState, index: String) -> String:
	var m := mon(index)
	var src := MonTraits._lookup(index)
	if seen(gs, index) <= 0:
		var where: Array = []
		for n in m.get("layers", []):
			where.append("第%d層" % int(n))
		return "[b][color=#e8dcb0]？？？[/color][/b]\n\nまだ見かけていない。%sに出るらしい。" % "・".join(where)
	var name := entry_name(gs, index)
	var ja := String(m.get("name_ja", src.get("j", "")))
	var t := "[b][color=#e8dcb0]%s[/color][/b]%s\n" % [name, "" if ja == name or ja == "" else "(%s)" % ja]
	var ty := String(m.get("type", src.get("t", "")))
	t += "%s・%s   脅威度 %s   HP %d   AC %d\n\n" % [TYPE_JP.get(ty, ty), SIZE_JP.get(String(m.get("size", src.get("z", "M"))), ""),
		_cr_text(float(m.get("cr", src.get("cr", 0)))), int(m.get("hp", src.get("hp", 0))), int(m.get("ac", src.get("ac", 0)))]
	t += "見かけた %d回   倒した %d体\n初めて出会ったのは %s\n" % [seen(gs, index), killed(gs, index), String(_j(gs)["first"].get(index, "—"))]
	var where2: Array = []
	for n in m.get("layers", []):
		where2.append("第%d層" % int(n))
	if not where2.is_empty():
		t += "出る層: %s\n" % "・".join(where2)
	var fl := MonTraits.flags_for({"index": index})
	var tr: Array = []
	for f in fl:
		if TRAIT_JP.has(f):
			tr.append(TRAIT_JP[f])
	if not tr.is_empty():
		t += "\n[color=#5bc0de]覚え書き: %s[/color]\n" % "、".join(tr)
	return t

static func _cr_text(cr: float) -> String:
	if cr > 0.0 and cr < 1.0:
		return "1/%d" % int(round(1.0 / cr))
	return str(int(cr))
