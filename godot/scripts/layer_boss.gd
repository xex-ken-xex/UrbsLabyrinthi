class_name LayerBoss
extends RefCounted
## 層のボス(層の主。ken 10/18)。第1〜9層の、それぞれいちばん下の階の大広間に、名前が黄色のユニークとお供を置く。
## - ユニークは層ごとに決めた魔物1体(ken 10/18: 複数だと HP の棒と名前が見づらいので、いまは1体)に、二つ名をつけて呼ぶ(「疾風のミノタウロス」のように。ken 10/18)。
##   二つ名は EPITHETS の100から、層と倒した回数で選ぶ(戻ってくるたびに、別の二つ名)。HP は同じ魔物の20倍(ken 確定)、体は巨大(H)、伝説的な抵抗つき、逃げない。
##   多くは吹き飛ばしの一撃(構えて、まわりを薙ぎ払う)を持つ(ken 10/18)。
## - 戦いが始まると咆哮(画面を埋める擬音)、戦いの間は画面がモノクロで、ダメージの数字だけ赤(BossFx)。倒すか、別の階へ移ると戻る。
## - 倒すと: 層ごとの実績、大きい燐晶の塊、鍛冶の良品か逸品を一つ。まわりの巣も散る(主の間と同じ)。
## - 倒した層の主は7夜(迷宮の一巡)戻らない(ken 10/18 のカード)。そのあいだ、その階はふつうの主の間。
## 第10層は竜の巣があるので、層の主は置かない。

const HP_MULT := 20.0          # 同じ魔物のふつうの HP の何倍か(ken 10/18 確定)
const DMG_MULT := 1.5
const SIZE := "H"              # 巨大(ken 10/18)
const RETURN_NIGHTS := 7       # 倒してから戻るまでの夜(ken 10/18)
const NAME_COLOR := Color("ffd84a")
const BLAST_CD := [5.0, 7.5]   # 吹き飛ばしの一撃の間(秒)
const BLAST_WINDUP := 0.8
const BLAST_REACH := 70.0      # 体の縁から、この画素までが吹き飛ぶ
const BLAST_KNOCK := 620.0

## 二つ名(ken 10/18: 100くらい)。「疾風の」+「ミノタウロス」のように、魔物の名の前につける
const EPITHETS := [
	"疾風の", "烈火の", "氷結の", "雷鳴の", "鉄壁の", "不死身の", "百戦の", "血塗れの", "狂乱の", "静寂の",
	"深淵の", "灰燼の", "錆鉄の", "腐葉の", "骨喰いの", "千切りの", "鋼牙の", "暴食の", "黒蝕の", "白骨の",
	"嘆きの", "怨嗟の", "呪われし", "忘れられし", "名無しの", "片目の", "隻腕の", "双頭の", "三つ首の", "這い寄る",
	"轟く", "唸る", "吠え猛る", "眠らずの", "夜明け知らずの", "闇纏う", "燐光の", "蒼燐の", "紅蓮の", "翠緑の",
	"黄昏の", "宵闇の", "月喰らいの", "星落としの", "地鳴りの", "岩砕きの", "壁裂きの", "扉破りの", "骨砕きの", "首狩りの",
	"人喰いの", "墓荒らしの", "屍拾いの", "迷い子の", "道塞ぎの", "底なしの", "渇きの", "飢えたる", "貪る", "毒牙の",
	"棘背の", "甲殻の", "鱗の", "獣臭の", "腐臭の", "硫黄の", "灰被りの", "煤けた", "苔むした", "錆びつく",
	"凍える", "焦がす", "揺らぐ", "囁く", "嗤う", "泣き叫ぶ", "歌う", "数える", "見張る", "待ち伏せる",
	"古の", "太古の", "百年の", "千夜の", "七夜の", "吐息の", "呑み込む", "墜ちた", "堕ちた", "狂える",
	"不動の", "瞬身の", "剛力の", "執念の", "復讐の", "誇り高き", "卑しき", "老いたる", "若き", "孤高の",
]

## 層 → {room 広間の名前, roar 咆哮, bosses [SRD の id](名前は二つ名 + 魔物の名。EPITHETS), minions [[id, 4人のときの数]], blast 吹き飛ばしの一撃, intro 入ったときの一行, fall 倒したときの一行}
const BOSSES := {
	1: {"room": "鼠の王の巣", "roar": "ギィィィィィィィッ!!", "blast": true,
		"bosses": ["giant-rat-diseased"], "minions": [["swarm-of-rats", 2], ["giant-rat", 4]],
		"intro": "齧られた骨が山になっている。その上で、牛ほどもある鼠がこちらを見下ろした。",
		"fall": "鼠の王が倒れた。群れの鼠が、四方の穴へ逃げ散っていく。"},
	2: {"room": "墓守の礼拝堂", "roar": "ガアアアアァァァッ!!", "blast": true,
		"bosses": ["ghoul"], "minions": [["ghoul", 1], ["zombie", 4]],
		"intro": "崩れた礼拝堂で、巨きな屍食いが祈るように遺体の山を抱えている。",
		"fall": "巨きな屍食いが倒れた。抱えていた遺体が、ようやく床に横たわる。"},
	3: {"room": "鎧鬼の鍛冶場", "roar": "グオオオオオォォッ!!", "blast": true,
		"bosses": ["ogre"], "minions": [["hobgoblin", 4], ["animated-armor", 1]],
		"intro": "錆びた鉄板を幾重にも打ちつけた大鬼が、冷えた炉の前で金槌を握っている。",
		"fall": "鎧鬼が膝をついた。打ちつけた鉄板が、錆の粉になって崩れる。"},
	4: {"room": "灰の工夫長の詰所", "roar": "オオオオォォォォン…!!", "blast": true,
		"bosses": ["wight"], "minions": [["specter", 2], ["shadow", 3]],
		"intro": "落盤で死んだ工夫たちの影が、まだ点呼を待っている。その前に、灰色の屍が立つ。",
		"fall": "灰色の屍が崩れ落ちた。点呼を待っていた影が、ひとつずつ消えていく。"},
	5: {"room": "合わせ鏡の間", "roar": "キャハハハハハハッ!!", "blast": false,
		"bosses": ["doppelganger"], "minions": [["doppelganger", 2]],
		"intro": "水面に映った影が、こちらと同じ顔で笑った。まわりの水面にも、同じ顔が浮かぶ。",
		"fall": "影が水に溶けた。水面には、自分の顔だけが映っている。"},
	6: {"room": "沈め首の淵", "roar": "シャアアアアァァァッ!!", "blast": true,
		"bosses": ["hydra"], "minions": [["giant-constrictor-snake", 2]],
		"intro": "淵の水が盛り上がり、首がいくつも持ち上がった。",
		"fall": "最後の首が沈んだ。淵の水が、静かに引いていく。"},
	7: {"room": "嘆きの聖歌壇", "roar": "アアアアアアァァァ……!!", "blast": true,
		"bosses": ["wraith"], "minions": [["specter", 4], ["will-o-wisp", 2]],
		"intro": "崩れた聖歌壇から、歌うような嘆きが降ってくる。指揮をとる影が、こちらへ振り向いた。",
		"fall": "指揮をとる影が消えた。嘆きの歌が、途中で止む。"},
	8: {"room": "黒蝕の騎士の回廊", "roar": "ウオオオオオォォッ!!", "blast": true,
		"bosses": ["vampire-spawn"], "minions": [["wight", 1], ["mummy", 3]],
		"intro": "黒く蝕まれた甲冑の騎士が、回廊の奥で剣を抜いた。",
		"fall": "黒く蝕まれた騎士が倒れた。甲冑の中は、からっぽだった。"},
	9: {"room": "空座の門", "roar": "ゴゴゴゴゴゴゴゴゴッ!!", "blast": true,
		"bosses": ["stone-golem"], "minions": [["shield-guardian", 2]],
		"intro": "空の座へ続く門の前で、石の巨人が身を起こした。",
		"fall": "門番が崩れた。門の向こうから、冷たい風が吹いてくる。"},
}

## 層が何階あるか(data/manifest.json)から、層のいちばん下の階(通し番号)を返す。無ければ 0
static func bottom_depth(layer: int) -> int:
	var d := 0
	for L in PhosFlow.manifest().get("layers", []):
		d += int(L.get("floors", 1))
		if int(L.get("layer", 0)) == layer:
			return d
	return 0

## この階(通し番号)が層の主の階なら、その層。違えば 0
static func layer_at(depth: int) -> int:
	for L in BOSSES:
		if bottom_depth(int(L)) == depth:
			return int(L)
	return 0

static func def(layer: int) -> Dictionary:
	return BOSSES.get(layer, {})

static func layers() -> Array:
	var out: Array = BOSSES.keys()
	out.sort()
	return out

## 倒した回数 / 倒した夜(Journal の stats)
static func kills(gs: GameState, layer: int) -> int:
	return Journal.stat(gs, "boss%d" % layer)

## 倒されてから、まだ7夜たっていない(層の主はいない)
static func away(gs: GameState, layer: int) -> bool:
	return kills(gs, layer) > 0 and gs.day - Journal.stat(gs, "boss_day%d" % layer) < RETURN_NIGHTS

static func defeated(gs: GameState, layer: int) -> void:
	Journal.bump(gs, "boss%d" % layer)
	Journal._j(gs)["stats"]["boss_day%d" % layer] = gs.day

## 迷宮の断面に出す一行(ken 10/18)。倒したことが無ければ ""
static func slain_label(gs: GameState, layer: int) -> String:
	if kills(gs, layer) <= 0:
		return ""
	var t := "第%d層の主 討伐済" % layer
	if away(gs, layer):
		t += "(あと%d夜で戻る)" % (RETURN_NIGHTS - (gs.day - Journal.stat(gs, "boss_day%d" % layer)))
	return t

## 二つ名(層、倒した回数、何体目かで決まる。同じ層の主の中では重ならない)
static func epithets(layer: int, cycle: int, n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("boss|%d|%d" % [layer, cycle])
	var out: Array = []
	while out.size() < n:
		var e := String(EPITHETS[rng.randi_range(0, EPITHETS.size() - 1)])
		if not out.has(e):
			out.append(e)
	return out

## 魔物の呼び名(冒険日記帳の名。無ければ SRD の和名)
static func base_name(index: String, fallback: String) -> String:
	return String(Journal.mon(index).get("name", fallback))

## 層の主の顔ぶれ(遭遇の monsters と同じ形)。ユニークは1体ずつ、お供は人数で減らす
static func monsters(layer: int, party: int, cycle: int = 0) -> Array:
	var b := def(layer)
	var out: Array = []
	var mons := {}
	for m in EncounterGen.data().get("monsters", []):
		mons[String(m["i"])] = m
	var bs: Array = b.get("bosses", [])
	var eps := epithets(layer, cycle, bs.size())
	for i in bs.size():
		var id := String(bs[i])
		if not mons.has(id):
			continue
		var o := EncounterGen.mon_line({"m": mons[id], "n": 1, "world": ""})
		var bn := base_name(id, String(o["name_ja"]))
		o["unique"] = true
		o["epithet"] = String(eps[i])
		o["base_name"] = bn
		o["unique_name"] = String(eps[i]) + bn
		o["boss_layer"] = layer
		o["blast"] = bool(b.get("blast", false))
		o["size"] = SIZE
		o["xp"] = int(o["xp"]) * 10
		out.append(o)
	for mn in b.get("minions", []):
		if not mons.has(String(mn[0])):
			continue
		var n := maxi(1, int(ceil(float(mn[1]) * clampi(party, 1, 4) / 4.0)))
		out.append(EncounterGen.mon_line({"m": mons[String(mn[0])], "n": n, "world": ""}))
	return out

## 階の大広間のうち、層の主を置く部屋(大きい順。階段の候補地と、今夜の階段の部屋は使わない)
static func pick_room(map: FloorMap) -> Dictionary:
	var sites := {}
	for s in map.data.get("stair_sites", []):
		sites[int(s.get("room", -1))] = true
	var best: Dictionary = {}
	for r in map.data["rooms"]:
		if not r.get("big", false) or String(r.get("role", "room")) != "room" or sites.has(int(r["id"])) or ["lair", "sump"].has(String(r.get("kind", ""))):
			continue
		if best.is_empty() or int(r["area_cells"]) > int(best["area_cells"]) or (int(r["area_cells"]) == int(best["area_cells"]) and int(r["id"]) < int(best["id"])):
			best = r
	return best

## 層を作った直後に呼ぶ: 層の主の階なら、主の間の遭遇を大広間へ移し、層の主とお供に替える。置いたら層の番号を返す
static func setup_floor(fl: FloorInstance, gs: GameState) -> int:
	var layer := layer_at(fl.floor_no)
	if layer == 0 or fl.arena or away(gs, layer):
		return 0
	var map := fl.map
	var room := pick_room(map)
	if room.is_empty():
		return 0
	var enc: Dictionary = {}
	for e in map.data["encounters"]:
		if e.get("master", false):
			enc = e
	if enc.is_empty():
		return 0
	# 主の間だった小部屋は、ふつうの部屋に戻す
	var old_rid := int(enc.get("roomId", -1))
	if map.room_by_id.has(old_rid):
		map.room_by_id[old_rid]["role"] = "room"
		map.room_by_id[old_rid]["encounter"] = null
	# 大広間にいた群れは、層の主に追い払われた(出さない)
	var rid := int(room["id"])
	if room.get("encounter") != null:
		var oid := int(room["encounter"])
		fl.spawner.pending.erase(oid)
		fl.enc_total.erase(oid)
		fl.enc_dead.erase(oid)
	room["role"] = "master"
	room["encounter"] = int(enc["id"])
	room["name"] = String(def(layer)["room"])
	room["boss"] = layer
	enc["roomId"] = rid
	enc["boss_layer"] = layer
	enc["activity"] = "層の主の間に陣取っている"
	enc["attitude"] = "敵対"
	enc["kind"] = "mindless"        # 逃げない
	enc["monsters"] = monsters(layer, gs.party.size(), kills(gs, layer))
	enc["tokens"] = _tokens(map, room, enc["monsters"])
	fl.enc_total[int(enc["id"])] = (enc["tokens"] as Array).size()
	fl.enc_dead[int(enc["id"])] = 0
	fl.master_enc = int(enc["id"])
	fl.boss_layer = layer
	fl.boss_enc = int(enc["id"])
	return layer

## 置き場所(マス)。ユニークは部屋の真ん中寄りに間を空けて、お供はそのまわり
static func _tokens(map: FloorMap, room: Dictionary, mons: Array) -> Array:
	var rid := int(room["id"])
	var c := Vector2(float(room["center"][0]), float(room["center"][1]))
	var cells: Array = []
	for y in range(int(room["y"]), int(room["y"]) + int(room["h"])):
		for x in range(int(room["x"]), int(room["x"]) + int(room["w"])):
			if map.in_bounds(x, y) and map.room_at[map.idx(x, y)] == rid and not map.solid(x, y):
				cells.append(Vector2i(x, y))
	cells.sort_custom(func(a, b): return Vector2(a).distance_squared_to(c) < Vector2(b).distance_squared_to(c))
	var out: Array = []
	var used: Array = []
	for g in mons.size():
		var m: Dictionary = mons[g]
		var gap := 3.5 if m.get("unique", false) else 1.5
		for i in int(m["count"]):
			var pick := Vector2i(-1, -1)
			for cc in cells:
				var ok := true
				for u in used:
					if Vector2(cc).distance_to(Vector2(u)) < gap:
						ok = false
						break
				if ok:
					pick = cc
					break
			if pick.x < 0 and not cells.is_empty():
				pick = cells[(out.size() * 7) % cells.size()]
			if pick.x < 0:
				continue
			used.append(pick)
			out.append({"x": pick.x, "y": pick.y, "g": g})
	return out

## 倒したときの落とし物: 大きい燐晶の塊と、鍛冶の良品か逸品を一つ、魔法の品(武器・防具・装飾品)を一つ
## last_magic に、落とした魔法の品の id が入る
static var last_magic := ""
static func drop_loot(fl: FloorInstance, layer: int, pos: Vector2) -> String:
	var mid := ItemDB.roll_magic(layer, Dice.rng, ["weapon", "armor", "acc"])
	last_magic = mid
	if mid != "":
		fl.ground.add_item(pos, mid, 1, Vector2.from_angle(Dice.rng.randf() * TAU) * 80.0)
	var kg := (0.5 + 0.35 * layer) * Balance.CRYSTAL_SCALE / 0.3
	fl.ground.add_crystal(pos, Crystal.roll(fl.ground.base, Dice.rng, 0.35), kg, Vector2.from_angle(Dice.rng.randf() * TAU) * 60.0)
	var cap := 150 + 130 * layer
	var pool: Array = []
	for id in Smithing.forgeable_ids(ItemDB.ITEMS):
		var it: Dictionary = ItemDB.ITEMS.get(id, {})
		if not it.is_empty() and int(it.get("price", 0)) <= cap:
			pool.append(id)
	if pool.is_empty():
		return ""
	var base_id := String(pool[Dice.rng.randi_range(0, pool.size() - 1)])
	var tier := 2 if Dice.rng.randf() < minf(0.8, 0.2 + 0.07 * layer) else 1
	var gid := "%s+%d" % [base_id, tier]
	if not ItemDB.ITEMS.has(gid):
		gid = base_id
	fl.ground.add_item(pos, gid, 1, Vector2.from_angle(Dice.rng.randf() * TAU) * 70.0)
	return gid
