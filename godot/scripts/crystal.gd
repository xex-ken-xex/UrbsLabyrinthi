class_name Crystal
extends RefCounted
## 燐晶(光る石)。純度は 低 / 並 / 高 / 極 と、光り方の定まらない 不明。
## 値段は 1kg あたりの銀貨(docs/urbs-labyrinthi-spec.md §3.4)。持ち帰ると、査定のうえ、3割の燐晶税がかかる。

const ORDER := ["low", "mid", "high", "pure"]
const THEME_BASE := {"fuyou": "low", "sabi": "mid", "kagami": "high", "hone": "pure", "soko": "unk", "generic": "mid"}
const COLORS := {
	"low": Color("9ab0c0"), "mid": Color("48b4e8"), "high": Color("8af4ff"), "pure": Color("d0a0ff"), "unk": Color("b9b4ff"),
}
## 大きさ(kg)の境目。欠片 < 0.08 ≤ かたまり < 0.3 ≤ 大きな塊
const SIZE_S := 0.08
const SIZE_M := 0.3

static func price(id: String) -> int:
	for p in ForageData.PURITIES:
		if p[0] == id:
			return int(p[2])
	return 30

static func jp(id: String) -> String:
	for p in ForageData.PURITIES:
		if p[0] == id:
			return String(p[1])
	return id

static func size_of(kg: float) -> String:
	return "s" if kg < SIZE_S else ("m" if kg < SIZE_M else "l")

static func icon_id(purity: String, kg: float) -> String:
	return "crystal_%s_%s" % [purity, size_of(kg)]

static func base_of(theme: String) -> String:
	return String(THEME_BASE.get(theme, "mid"))

## 舞台の基本の純度から、ひとつの石の純度を決める。bonus が大きいほど、良いものが出やすい(死体や強い魔物)
static func roll(base: String, rng: RandomNumberGenerator, bonus: float = 0.0) -> String:
	if base == "unk":
		return "unk" if rng.randf() < 0.85 else "pure"
	var i := ORDER.find(base)
	var r := rng.randf()
	var up2 := 0.03 + bonus * 0.4
	var up1 := 0.15 + bonus
	if r < up2:
		i += 2
	elif r < up2 + up1:
		i += 1
	elif r < up2 + up1 + 0.25:
		i -= 1
	return String(ORDER[clampi(i, 0, ORDER.size() - 1)])

## 見積もり(銀貨)。袋 {純度: kg} の合計
static func value_of(bag: Dictionary) -> int:
	var v := 0.0
	for p in bag:
		v += float(bag[p]) * price(String(p))
	return int(round(v))

static func weight_of(bag: Dictionary) -> float:
	var w := 0.0
	for p in bag:
		w += float(bag[p])
	return w

static func bag_text(bag: Dictionary) -> String:
	var parts: Array = []
	for pid in ORDER + ["unk"]:
		if bag.has(pid) and float(bag[pid]) > 0.0:
			parts.append("%s%.1f" % [jp(pid), float(bag[pid])])
	return " ".join(parts) if not parts.is_empty() else "なし"
