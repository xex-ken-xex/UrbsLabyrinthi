class_name Trophies
extends RefCounted
## 実績(トロフィー。ken 10/17)。これまでの歩みを、冒険日記帳(Journal)と GameState から判定して残す。
## 取った実績は gs.journal["trophies"] に {id: 取った日}。取ったときは、迷宮では「パンパカパーン!」と頭上の文字とログ、
## 街では下の帯や帰還の報告に一行(Main._show_trophies、HomePanel、TownScreen)。

## [id, 名前, 中身]。層ごとの「狩り尽くし」は LAYER_ALL で足す(顔ぶれが前の層と同じ層は、前の層にまとめる)
const LIST := [
	["first_kill", "初めての獲物", "魔物を初めて倒した"],
	["kills_100", "百の骸", "魔物を100体倒した"],
	["kills_1000", "千の骸", "魔物を1000体倒した"],
	["seen_25", "迷宮の見聞録", "25種の魔物を見かけた"],
	["seen_100", "歩く魔物図鑑", "100種の魔物を見かけた"],
	["deep_3", "錆鉄の坑道へ", "第3層に着いた"],
	["deep_5", "鏡の水廊へ", "第5層に着いた"],
	["deep_7", "骨の大聖堂へ", "第7層に着いた"],
	["deep_10", "未踏の底へ", "第10層に着いた"],
	["lair", "胃袋の主", "大穴の底で、眠る竜を見た"],
	["abyss", "深淵を覗く者", "縦穴の縁から、下の階を覗いた"],
	["level_5", "一人前", "仲間のだれかが Lv5 になった"],
	["level_10", "古強者", "仲間のだれかが Lv10 になった"],
	["party_4", "四人の一行", "仲間が4人そろった"],
	["rich", "燐晶長者", "一度に1000銀貨ぶんの燐晶を持ち帰った"],
	["wipe", "灯手隊の世話", "全滅して、担ぎ出された"],
	["good_meal", "美味しいご飯が炊けた", "料理を上出来に作った"],
	["burnt", "黒焦げ", "料理を焦がした"],
	["rotten", "腹を下した", "くさったものを食べた"],
	["home", "我が家", "家を買った"],
	["brew_great", "会心の調合", "魔法実験で上出来の薬を作った"],
	["masterwork", "逸品", "鍛冶で逸品を打った"],
	["mimic", "宝箱に噛まれた", "物のふりをした魔物に張りつかれた"],
]
const LAYER_ALL := "layer_all_"

## 全部の実績の id(並び順)
static func ids() -> Array:
	var out: Array = []
	for t in LIST:
		out.append(t[0])
	for n in Journal.layer_ids():
		if not Journal.same_as_prev(n):
			out.append(LAYER_ALL + str(n))
	return out

static func name_of(id: String) -> String:
	if id.begins_with(LAYER_ALL):
		var n := int(id.substr(LAYER_ALL.length()))
		var e := Journal.span_end(n)
		return ("第%d層 狩り尽くし" % n) if e == n else ("第%d〜%d層 狩り尽くし" % [n, e])
	for t in LIST:
		if t[0] == id:
			return String(t[1])
	return id

static func desc_of(id: String) -> String:
	if id.begins_with(LAYER_ALL):
		var n := int(id.substr(LAYER_ALL.length()))
		var e2 := Journal.span_end(n)
		return "%s(%s)に出る魔物を、全種類倒した" % ["第%d層" % n if e2 == n else "第%d〜%d層" % [n, e2], String(Journal.layer(n).get("name", ""))]
	for t in LIST:
		if t[0] == id:
			return String(t[2])
	return ""

static func has(gs: GameState, id: String) -> bool:
	return gs.journal.get("trophies", {}).has(id)

## 条件を満たしているか
static func met(gs: GameState, id: String) -> bool:
	if id.begins_with(LAYER_ALL):
		var p := Journal.layer_progress(gs, int(id.substr(LAYER_ALL.length())))
		return p.y > 0 and p.x >= p.y
	match id:
		"first_kill": return Journal.killed_total(gs) >= 1
		"kills_100": return Journal.killed_total(gs) >= 100
		"kills_1000": return Journal.killed_total(gs) >= 1000
		"seen_25": return Journal.seen_species(gs) >= 25
		"seen_100": return Journal.seen_species(gs) >= 100
		"deep_3": return Journal.stat(gs, "deepest") >= 3
		"deep_5": return Journal.stat(gs, "deepest") >= 5
		"deep_7": return Journal.stat(gs, "deepest") >= 7
		"deep_10": return Journal.stat(gs, "deepest") >= 10
		"lair": return Journal.stat(gs, "lair") >= 1
		"abyss": return Journal.stat(gs, "abyss") >= 1
		"level_5", "level_10":
			var need := 5 if id == "level_5" else 10
			for c in gs.party:
				if c.level >= need:
					return true
			return false
		"party_4": return gs.party.size() >= 4
		"rich": return Journal.stat(gs, "best_return") >= 1000
		"wipe": return Journal.stat(gs, "wipes") >= 1
		"good_meal": return Journal.stat(gs, "cook_great") >= 1
		"burnt": return Journal.stat(gs, "cook_burnt") >= 1
		"rotten": return Journal.stat(gs, "rotten_eaten") >= 1
		"home": return Home.owned(gs)
		"brew_great": return Journal.stat(gs, "brew_great") >= 1
		"masterwork": return Journal.stat(gs, "forge_great") >= 1
		"mimic": return Journal.stat(gs, "mimic_bite") >= 1
	return false

## まだ取っていない実績のうち、条件を満たしたものを取る。新しく取った id を返す
static func evaluate(gs: GameState) -> Array:
	if gs.journal.is_empty():
		gs.journal = Journal.empty()
	var out: Array = []
	for id in ids():
		if not has(gs, id) and met(gs, id):
			gs.journal["trophies"][id] = gs.day + 1
			out.append(id)
	return out

## 街の帯や報告に出す一行
static func line(new_ids: Array) -> String:
	if new_ids.is_empty():
		return ""
	var names: Array = []
	for id in new_ids:
		names.append("「%s」" % name_of(String(id)))
	return "パンパカパーン! 実績%sを解除した。" % "".join(names)

static func count(gs: GameState) -> int:
	return (gs.journal.get("trophies", {}) as Dictionary).size()
