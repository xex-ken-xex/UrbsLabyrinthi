class_name Permit
extends RefCounted
## 冒険者ギルド(坑口館)の潜行許可証の等級(ken 10/16、10/18)。等級で、潜ってよい層が決まる。
## 等級の名前は、遺体の認識票と同じ(GroundItems.RANKS: 灰・青銅・銀・黒鉄)。
## 上がり方: 層の主(LayerBoss)を倒した実績で上がる。第2層の主で青銅、第4層の主で銀、第6層の主で黒鉄。
## 書き換えは坑口館の窓口なので、倒したあと街へ戻ったときに上がる(帰還の報告に一行)。
## 許可証の外の層へは、階段も縄梯子も使えない。落とし穴で落ちるのは止められない(事故なので、とがめはしない)。

const NAMES := ["灰", "青銅", "銀", "黒鉄"]
const MAX_LAYER := [2, 4, 6, 10]                 # 等級ごとに、潜ってよいいちばん深い層
const NEED := {1: "boss_2", 2: "boss_4", 3: "boss_6"}   # その等級に上がるための実績(層の主)
const NEED_LAYER := {1: 2, 2: 4, 3: 6}

static func level(gs: GameState) -> int:
	return clampi(gs.permit, 0, NAMES.size() - 1)

static func rank_name(gs: GameState) -> String:
	return NAMES[level(gs)]

static func max_layer(gs: GameState) -> int:
	return MAX_LAYER[level(gs)]

## 実績から見て、上がれる等級
static func earned(gs: GameState) -> int:
	var r := 0
	for lv in NEED:
		if Trophies.has(gs, String(NEED[lv])):
			r = maxi(r, int(lv))
	return r

## その階(通し番号)に、いまの許可証で入ってよいか
static func allows_floor(gs: GameState, depth: int) -> bool:
	return layer_of(depth) <= max_layer(gs)

## 階(通し番号)の層(data/manifest.json)
static func layer_of(depth: int) -> int:
	var d := 0
	var last := 1
	for L in PhosFlow.manifest().get("layers", []):
		d += int(L.get("floors", 1))
		last = int(L.get("layer", last))
		if depth <= d:
			return last
	return last

## 「灰等級(第1〜2層まで)」
static func label(gs: GameState) -> String:
	return "%s等級(第%d層まで)" % [rank_name(gs), max_layer(gs)]

## 次の等級に上がる条件(黒鉄なら空)
static func next_hint(gs: GameState) -> String:
	var nx := level(gs) + 1
	if not NEED.has(nx):
		return ""
	return "第%d層の主を倒せば、%s等級(第%d層まで)に上がる。" % [int(NEED_LAYER[nx]), NAMES[nx], MAX_LAYER[nx]]

## 街へ戻ったとき、窓口で書き換える。上がったら報告の一行、上がらなければ空
static func renew(gs: GameState) -> String:
	var e := earned(gs)
	if e <= level(gs):
		return ""
	gs.permit = e
	return "坑口館の窓口で、潜行許可証が%s等級に書き換えられた。これで第%d層まで潜れる。" % [NAMES[e], MAX_LAYER[e]]

## 入れない層へ行こうとしたときの一行
static func refuse_line(gs: GameState, depth: int) -> String:
	return "この先は第%d層。%s等級の許可証では入れない。%s" % [layer_of(depth), rank_name(gs), next_hint(gs)]
