class_name Abyss
extends Node2D
## 縦穴を覗く(設計メモ §7「深淵を覗く」、ken 10/17「2.5D」)。
## 仲間が縦穴の縁に立つと、縦穴の中に、下の階の骨組みを遠いほど小さく暗く重ねて描く(4階ぶん)。
## その下と、竜の巣の階は真っ黒(底は見せない。ken 10/17)。縁から縄梯子が下の階へ垂れている。
## データは data/section.json(tools/export-floors.mjs が書き出す。7夜で変わらないマスだけ)。迷宮の断面図(SectionView)も同じデータを読む。

const SHOW := 4             # 何階下まで描くか
const EYE_M := 8.0          # 遠近の強さ: 覗く目から、この階の床までの見かけの距離(m)。小さいほど深い階が急に小さくなる
const FADE := 0.5           # 縁に立ってから見えきるまで(秒)
const DIM := 0.62           # 一階下るごとの明るさ

static var _data: Dictionary = {}

## data/section.json(一度だけ読む)
static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = FloorMap.read_json("res://data/section.json")
		_data = d if typeof(d) == TYPE_DICTIONARY else {"floors": [], "well": 0}
	return _data

## 階(通し番号)の断面の行。無ければ {}
static func floor_info(depth: int) -> Dictionary:
	var fs: Array = data().get("floors", [])
	return fs[depth - 1] if depth >= 1 and depth <= fs.size() else {}

## この階の床から、depth 階の床までの深さ(m)
static func drop_m(from_depth: int, depth: int) -> float:
	var m := 0.0
	for d in range(from_depth, depth):
		m += float(floor_info(d).get("h_m", 5.0))
	return m

var fl: FloorInstance
var peer := 0.0              # 0〜1。どれだけ見えているか
var seen_once := false       # この夜、この階で一度覗いた(擬音とログは一度だけ)
var _hole := Rect2()         # この階の縦穴(画素)
var _ok := false             # この階に覗ける縦穴がある(竜の巣の階には無い)

func setup(f: FloorInstance) -> void:
	fl = f
	name = "Abyss"
	var sh: Dictionary = f.map.data.get("shaft", {})
	var C := float(Balance.CELL)
	if sh.has("x"):
		_hole = Rect2(float(sh["x"]) * C, float(sh["y"]) * C, float(sh["w"]) * C, float(sh["h"]) * C)
		var c := f.map.shaft_center
		_ok = not f.arena and f.map.in_bounds(c.x, c.y) and f.map.tiles[f.map.idx(c.x, c.y)] == FloorMap.VOID and not floor_info(f.floor_no).is_empty()
	modulate.a = 0.0
	visible = false

## 縁に立っているか(縦穴を一マス広げた中で、縦穴の外)
func _on_rim(p: Vector2) -> bool:
	var C := float(Balance.CELL)
	return _hole.grow(C * 1.6).has_point(p) and not _hole.has_point(p)

func _process(delta: float) -> void:
	if not _ok or fl == null:
		return
	var lead := fl.leader
	var want := lead != null and is_instance_valid(lead) and not lead.down and _on_rim(lead.position)
	var before := peer
	peer = move_toward(peer, 1.0 if want else 0.0, delta / FADE)
	if peer != before:
		modulate.a = smoothstep(0.0, 1.0, peer)
		visible = peer > 0.0
		if before == 0.0:
			queue_redraw()
	if want and not seen_once and peer >= 1.0:
		seen_once = true
		_first_look(lead)

## 初めて覗いたとき: 下から吹き上げる風(ヒュウゥ…)とログに一行
func _first_look(lead: Node2D) -> void:
	Sfx.cue(fl, lead.position, "abyss")
	fl.stat.emit("abyss")          # 実績「深淵を覗く者」
	var deepest := fl.floor_no
	var lair := false
	for k in range(1, SHOW + 1):
		var info := floor_info(fl.floor_no + k)
		if info.is_empty():
			break
		if bool(info.get("lair", false)):
			lair = true
			break
		deepest = fl.floor_no + k
	var n := deepest - fl.floor_no
	if lair:
		fl.message.emit("縦穴を覗いた。下の階の縁が%d重に見え、その下の闇の底で、何か大きなものが息をしている。" % n if n > 0 else "縦穴を覗いた。闇の底で、何か大きなものが息をしている。", "info")
	else:
		fl.message.emit("縦穴を覗いた。下の階の縁が%d重に小さくなっていき、その下は真っ黒だ。下から風が吹き上げてくる。" % n, "info")

func _draw() -> void:
	if not _ok:
		return
	var C := float(Balance.CELL)
	var c0 := _hole.get_center()
	draw_rect(_hole, Color.BLACK)
	var well := int(data().get("well", 0))
	var scales: Array = [1.0]
	for k in range(1, SHOW + 1):
		scales.append(EYE_M / (EYE_M + drop_m(fl.floor_no, fl.floor_no + k)))
	# 深い階から描き、浅い階で上から塗る(浅い階の縦穴の外は、深い階を隠す)
	for k in range(SHOW, 0, -1):
		var info := floor_info(fl.floor_no + k)
		if info.is_empty() or bool(info.get("lair", false)):
			continue          # 竜の巣の階は描かない(底は真っ黒)
		var s: float = scales[k]
		var cs := C * s
		var shade := pow(DIM, k)
		var cols: Dictionary = info.get("col", {})
		var rock := Color.html(String(cols.get("rock", "#111111"))).darkened(0.35)
		var floor_c := Color.html(String(cols.get("floor", "#444444")))
		var corr_c := Color.html(String(cols.get("corr", "#3a3a3a")))
		var rows: Array = info.get("well", [])
		var r := mini(well, int(ceil(_hole.size.x * 0.5 / cs)) + 1)
		for dy in range(-r, r + 1):
			var row: String = rows[dy + well]
			for dx in range(-r, r + 1):
				var ch := row[dx + well]
				if ch == "O":
					continue      # その階の縦穴。もっと下が見える
				var cell := Rect2(c0 + Vector2(dx - 0.5, dy - 0.5) * cs, Vector2(cs, cs))
				var clip := cell.intersection(_hole)
				if clip.size.x <= 0.0 or clip.size.y <= 0.0:
					continue
				var col: Color
				match ch:
					".": col = floor_c
					",", "+": col = corr_c
					"~": col = Color(0.1, 0.24, 0.32)
					"=": col = Color(0.22, 0.42, 0.5)
					"I": col = Color(0.78, 0.74, 0.64)
					_: col = rock
				draw_rect(clip, _dark(col, shade))
		# その階の縦穴の縁(明るい細い線)。遠い階ほど暗い
		var glow := Color.html(String(cols.get("glow", "#ffffaa")))
		var hole_k := Rect2(c0 - _hole.size * 0.5 * s, _hole.size * s)
		draw_rect(hole_k, _dark(glow, shade * 0.55), false, 1.0)
	# 縄梯子: 縁の杭から、下の階の同じ所へ。遠いほど細く暗い
	var ropes: Array = floor_info(fl.floor_no).get("ropes", [])
	for rp in ropes:
		var off := Vector2(float(rp[0]), float(rp[1])) * C
		var inward := -Vector2(signf(off.x), signf(off.y)) * C * 0.5     # 杭は縁の角のマス。縄は縦穴の角から垂れる
		for k in range(0, SHOW):
			var info := floor_info(fl.floor_no + k + 1)
			if info.is_empty() or bool(info.get("lair", false)):
				break
			var a: Vector2 = c0 + (off + inward) * float(scales[k])
			var b: Vector2 = c0 + (off + inward) * float(scales[k + 1])
			draw_line(a, b, _dark(Color(0.62, 0.48, 0.3), pow(DIM, k + 1) * 1.2), maxf(1.0, 2.0 * float(scales[k])))

func _dark(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)
