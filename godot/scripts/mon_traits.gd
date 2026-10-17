class_name MonTraits
extends RefCounted
## 魔物の SRD の特徴(Pack Tactics など)を、動きの印に直す。
## 層のデータ(Core の書き出し)は特徴を持たないので、encounter-data.json の同じ index の魔物から引く。
## 印ごとの動きは enemy.gd(設計は /mnt/project-files/design/2026-10-17-monster-traits.md)。
##   pack 群れで囲む(仲間が同じ相手に触れていると痛い。散って回り込む)
##   smell / hearing / sight 鋭い感覚(遠くから気づく。嗅覚と聴覚は壁越しでも)
##   swarm 群れ(ほかの魔物とすり抜け、HPが半分を切ると弱まる)
##   mimic 擬態(気づかれるまで物のふり。近づくと飛びかかる) / ambush 不意打ち(最初の一瞬が痛い)
##   grapple 張りつく(当たった仲間が動けなくなる)
##   ghost すり抜け(壁を抜けて迫る)
##   fortitude しぶとさ(倒れても起き上がることがある) / relentless 一度だけ踏みとどまる
##   charge 突進 / trample 突進して転ばせる / leap 跳びかかる
##   regen 再生(火・酸・光で止まる)
##   burst 死に際に弾ける
##   rust 金属を錆びさせる
##   shadow 闇にまぎれる(近づかないと見えにくい)
##   flyby 当てて離れる
##   frenzy 血に狂う(傷ついた相手に強い) / reckless 捨て身(与えるのも受けるのも増える)

const FLAGS := {
	"Pack Tactics": "pack", "Martial Advantage": "pack",
	"Keen Smell": "smell", "Keen Hearing and Smell": "smell", "Keen Sight and Smell": "smell",
	"Keen Hearing": "hearing", "Keen Hearing and Sight": "hearing", "Echolocation": "hearing",
	"Keen Sight": "sight",
	"Swarm": "swarm",
	"False Appearance": "mimic", "False Appearance (Object Form Only)": "mimic",
	"Ambusher": "ambush", "Surprise Attack": "ambush",
	"Grappler": "grapple", "Adhesive (Object Form Only)": "grapple",
	"Incorporeal Movement": "ghost",
	"Undead Fortitude": "fortitude", "Relentless": "relentless",
	"Charge": "charge", "Charge (Boar or Hybrid Form Only)": "charge", "Trampling Charge": "trample", "Pounce": "trample",
	"Standing Leap": "leap",
	"Regeneration": "regen",
	"Death Burst": "burst",
	"Corrode Metal": "rust", "Rust Metal": "rust",
	"Shadow Stealth": "shadow",
	"Flyby": "flyby",
	"Blood Frenzy": "frenzy", "Reckless": "reckless",
}
## 再生を止める、仲間の攻撃の種類(スキルの elem)
const REGEN_STOP := ["fire", "acid", "radiant"]

static var _by_index := {}

static func _lookup(index: String) -> Dictionary:
	if _by_index.is_empty():
		for m in EncounterGen.data().get("monsters", []):
			_by_index[String(m["i"])] = m
	return _by_index.get(index, {})

## 魔物の行(層のデータか、EncounterGen.mon_line)から、印の集まりを作る
static func flags_for(m: Dictionary) -> Dictionary:
	var names: Array = m.get("traits", [])
	if names.is_empty():
		names = _lookup(String(m.get("index", ""))).get("tr", [])
	var out := {}
	for n in names:
		var f: String = FLAGS.get(String(n if typeof(n) == TYPE_STRING else n.get("n", "")), "")
		if f != "":
			out[f] = true
	return out

## 耐久力の修正値(しぶとさの判定に使う)
static func con_mod(m: Dictionary) -> int:
	var ab: Array = m.get("abilities", [])
	if ab.size() < 3:
		ab = _lookup(String(m.get("index", ""))).get("ab", [])
	return int(floor((int(ab[2]) - 10) / 2.0)) if ab.size() >= 3 else 0
