class_name TownLines
extends RefCounted
## 街のセリフを、座暦の月と祭りの夜で替える(ken 10/16)。中身は data/town_lines.json。
## months["1"〜"13"]: その月の行(13 は座渡し)。special["月-夜"]: 祭りなどの夜だけの行(その夜は、こちらだけを使う)。
## 空座の月の31夜目からは(大閏の年)、special["12-31"] の行も、月の行に混ぜる。
## 区分: hub(広場に着いた) / leave(広場へ戻った) / signs(看板) / inn(宿の主人) / rumors(酒場の噂) / walk / look / fortune(寝息通り)

const PATH := "res://data/town_lines.json"
const MONTH_SHARE := 0.7          # 月の行と、いつもの行が両方あるとき、月の行を選ぶ割合

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var p: Variant = JSON.parse_string(f.get_as_text())
			if typeof(p) == TYPE_DICTIONARY:
				_data = p
	return _data

static func _key(day: int) -> String:
	var d := ZaCalendar.date(day)
	return "%d-%d" % [int(d["month"]), int(d["night"])]

## その夜が祭りなどの夜なら、その名前(無ければ "")
static func special_name(day: int) -> String:
	var sp: Dictionary = data().get("special", {}).get(_key(day), {})
	return String(sp.get("name", ""))

## その夜の、区分 cat の候補(祭りの夜はその行だけ。ふだんは月の行)
static func pool(cat: String, day: int) -> Array:
	var all := data()
	var sp: Dictionary = all.get("special", {}).get(_key(day), {})
	if sp.has(cat) and not (sp[cat] as Array).is_empty():
		return sp[cat]
	var d := ZaCalendar.date(day)
	var out: Array = (all.get("months", {}).get(str(int(d["month"])), {}).get(cat, []) as Array).duplicate()
	if int(d["month"]) == 12 and int(d["night"]) > 30:
		out.append_array(all.get("special", {}).get("12-31", {}).get(cat, []))
	return out

## 一つ選ぶ。base はいつもの行(月の行と混ぜる)。祭りの夜は、祭りの行だけ
static func pick(cat: String, day: int, base: Array) -> String:
	var sp_name := special_name(day)
	var p := pool(cat, day)
	if p.is_empty():
		return String(base.pick_random()) if not base.is_empty() else ""
	if sp_name != "" or base.is_empty() or randf() < MONTH_SHARE:
		return String(p.pick_random())
	return String(base.pick_random())

## その夜のあいだは変わらない一つ(宿の主人の挨拶など、画面を作り直しても揺れないように)
static func pick_stable(cat: String, day: int, base: Array) -> String:
	var p := pool(cat, day)
	if p.is_empty():
		p = base
	if p.is_empty():
		return ""
	return String(p[posmod(hash("%s%d" % [cat, day]), p.size())])

## 看板に目をやったときの一行。月の行があれば、半々でいつもの行と混ぜる
static func sign_line(id: String, day: int, base: String) -> String:
	var d := ZaCalendar.date(day)
	var m: Dictionary = data().get("months", {}).get(str(int(d["month"])), {}).get("signs", {})
	if m.has(id) and randf() < 0.5:
		return String(m[id])
	return base
