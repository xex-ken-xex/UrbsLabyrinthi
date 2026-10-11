class_name Talents
extends RefCounted
## 5e の技能(〈運動〉〈隠密〉など)、セーヴの習熟、能力値上昇と特技の定義。
## 習熟ボーナスは 5e と同じ(Lv1〜4 で +2、以後4レベルごとに +1)。
## 技能の「点」は、判定の加値(能力値の補正+習熟)。0 未満は 0 として効果を決める。
## 数値は初版の設計値で、遊んで直す前提。

## abil: 使う能力値 / fx: ハクスラでの効き目(1点あたり) / cap: 効き目の上限
const SKILLS := {
	"athletics": {"name": "運動", "abil": "str", "fx": 0.03, "cap": 0.45,
		"desc": "押し合いの重さ(押す力)が、1点につき3%増える。"},
	"acrobatics": {"name": "軽業", "abil": "dex", "fx": 0.04, "cap": 0.4,
		"desc": "転がり(Shift)の待ち時間が、1点につき4%縮む(最大40%)。"},
	"sleight": {"name": "手先の早業", "abil": "dex", "fx": 0.04, "cap": 0.4,
		"desc": "宝箱から得る燐晶が、1点につき4%増える(パーティでいちばん高い人)。"},
	"stealth": {"name": "隠密", "abil": "dex", "fx": 0.04, "cap": 0.4,
		"desc": "魔物に気づかれる距離が、1点につき4%縮む(最大40%)。"},
	"arcana": {"name": "魔法学", "abil": "int", "fx": 0.03, "cap": 0.45,
		"desc": "呪文の威力が、1点につき3%上がる。"},
	"history": {"name": "歴史", "abil": "int", "fx": 0.03, "cap": 0.45,
		"desc": "魔物を倒して得る経験点が、1点につき3%増える。"},
	"investigation": {"name": "捜査", "abil": "int", "fx": 1.0, "cap": 99.0,
		"desc": "探る(F)判定に使う(〈知覚〉と高いほう)。罠と隠し扉を見つける。"},
	"nature": {"name": "自然", "abil": "int", "fx": 0.04, "cap": 0.5,
		"desc": "野獣、植物、粘体、群れに与えるダメージが、1点につき4%上がる。"},
	"religion": {"name": "宗教", "abil": "int", "fx": 0.04, "cap": 0.5,
		"desc": "アンデッド、悪魔、天上の者に与えるダメージが、1点につき4%上がる。"},
	"animal": {"name": "動物使い", "abil": "wis", "fx": 0.03, "cap": 0.3,
		"desc": "野獣と群れから受けるダメージが、1点につき3%減る(最大30%)。"},
	"insight": {"name": "看破", "abil": "wis", "fx": 0.03, "cap": 0.3,
		"desc": "人型生物から受けるダメージが、1点につき3%減る(最大30%)。動きを読む。"},
	"medicine": {"name": "医術", "abil": "wis", "fx": 0.04, "cap": 0.5,
		"desc": "回復の呪文の回復量が、1点につき4%増える。治療薬はパーティでいちばん高い人の値で効く。"},
	"perception": {"name": "知覚", "abil": "wis", "fx": 1.0, "cap": 99.0,
		"desc": "受動〈知覚〉(10+点)で、近くの罠と隠し扉に気づく。探る(F)判定にも使う。"},
	"survival": {"name": "生存", "abil": "wis", "fx": 0.05, "cap": 0.5,
		"desc": "罠から受けるダメージが、1点につき5%減る(最大50%)。"},
	"deception": {"name": "ペテン", "abil": "cha", "fx": 0.04, "cap": 0.4,
		"desc": "店の買い取りが、1点につき4%高くなる(パーティでいちばん高い人)。"},
	"intimidation": {"name": "威圧", "abil": "cha", "fx": 0.02, "cap": 0.2,
		"desc": "傷つけた魔物が逃げ出しやすくなる(逃げ出すHPの境目が、1点につき2%上がる)。"},
	"performance": {"name": "芸能", "abil": "cha", "fx": 10.0, "cap": 9999.0,
		"desc": "街へ戻ると、宿で芸を見せて、1点につき10銀貨を稼ぐ(パーティでいちばん高い人)。"},
	"persuasion": {"name": "説得", "abil": "cha", "fx": 0.03, "cap": 0.3,
		"desc": "店の値段が、1点につき3%安くなる(最大30%。パーティでいちばん高い人)。"},
}
const SKILL_ORDER := ["athletics", "acrobatics", "sleight", "stealth", "arcana", "history", "investigation", "nature", "religion",
	"animal", "insight", "medicine", "perception", "survival", "deception", "intimidation", "performance", "persuasion"]

## 盗賊道具(解錠と罠の解除。【敏捷】+習熟)。技能ではなく道具の習熟だが、熟達の対象になる
const TOOLS := {"thieves_tools": {"name": "盗賊道具", "abil": "dex",
	"desc": "解錠と罠の解除に使う。習熟していると、習熟ボーナスを足せる。"}}

## クラスの習熟(SRD 5.1 のクラスと同じ)。count: クラスの一覧から選ぶ数
const CLASS_PROF := {
	"fighter": {"count": 2, "saves": ["str", "con"], "tools": [],
		"from": ["acrobatics", "animal", "athletics", "history", "insight", "intimidation", "perception", "survival"]},
	"barbarian": {"count": 2, "saves": ["str", "con"], "tools": [],
		"from": ["animal", "athletics", "intimidation", "nature", "perception", "survival"]},
	"rogue": {"count": 4, "saves": ["dex", "int"], "tools": ["thieves_tools"],
		"from": ["acrobatics", "athletics", "deception", "insight", "intimidation", "investigation", "perception", "performance",
			"persuasion", "sleight", "stealth"]},
	"wizard": {"count": 2, "saves": ["int", "wis"], "tools": [],
		"from": ["arcana", "history", "insight", "investigation", "medicine", "religion"]},
	"cleric": {"count": 2, "saves": ["wis", "cha"], "tools": [],
		"from": ["history", "insight", "medicine", "persuasion", "religion"]},
	"ranger": {"count": 3, "saves": ["str", "dex"], "tools": [],
		"from": ["animal", "athletics", "insight", "investigation", "nature", "perception", "stealth", "survival"]},
}
## 生い立ちで、好きな技能をいくつ選べるか(5e の背景の2つに当たる)
const BACKGROUND_COUNT := 2
## 種族が持つ技能(エルフの鋭い感覚)
const RACE_PROF := {"elf": ["perception"]}

## おまかせの技能(クラスの分 + 生い立ちの分)
const DEFAULT_PICKS := {
	"fighter": ["athletics", "perception", "intimidation", "survival"],
	"barbarian": ["athletics", "survival", "intimidation", "perception"],
	"rogue": ["stealth", "sleight", "acrobatics", "investigation", "perception", "deception"],
	"wizard": ["arcana", "investigation", "history", "medicine"],
	"cleric": ["medicine", "religion", "insight", "persuasion"],
	"ranger": ["perception", "stealth", "survival", "nature", "animal"],
}

## 能力値上昇(か特技)を選べるレベル。key は記録の名前
const ASI_LEVELS := [4, 8, 12, 16, 19]
const ASI_EXTRA := {"fighter": [6, 14], "rogue": [10]}
## 熟達(習熟ボーナスを2倍にする)。盗賊の Lv1 と Lv6 に2つずつ
const EXPERTISE := {"rogue": [1, 6]}

## 特技。fx はコードの側で見る(Character.has_feat)
const FEATS := {
	"tough": {"name": "頑健", "desc": "最大HPが、レベルごとに +2 される。"},
	"alert": {"name": "鋭い目", "desc": "受動〈知覚〉と、探る(F)判定に +5。"},
	"grappler": {"name": "組みつき上手", "desc": "押し合いの重さ(押す力)が 25% 増える。"},
	"mobile": {"name": "身軽", "desc": "足が 10% 速くなり、転がりの待ち時間が 25% 縮む。"},
	"heavy_hitter": {"name": "渾身", "desc": "体当たりが 25% 強くなる。そのかわり、受けるダメージが 10% 増える。"},
	"shield_master": {"name": "盾構え", "desc": "構えの間、受けるダメージがさらに半分になり、触れている敵へ体当たりの 40% で反撃する。"},
	"mana_well": {"name": "魔力の泉", "desc": "最大MPが 30% 増え、MPの回復が 50% 速くなる。"},
	"war_caster": {"name": "呪文の冴え", "desc": "呪文の威力が 20% 上がる。"},
	"sharpshooter": {"name": "射手", "desc": "飛び道具のスキル(矢、投げナイフ、魔弾など)の威力が 20%、射程が 25% 上がる。"},
	"healer": {"name": "癒し手", "desc": "回復の呪文と治療薬の回復量が 30% 増える。"},
	"lucky": {"name": "幸運", "desc": "判定とセーヴで、出目が 5 以下なら一度だけ振り直す。"},
	"resilient": {"name": "不屈", "desc": "一度の潜入で一度だけ、倒れるはずのダメージを受けても HP1 で踏みとどまる。"},
}
const FEAT_ORDER := ["tough", "alert", "grappler", "mobile", "heavy_hitter", "shield_master", "mana_well", "war_caster",
	"sharpshooter", "healer", "lucky", "resilient"]

## 罠のセーヴの能力値(書き出しの日本語名 → 能力値)
const SAVE_ABIL_JP := {"筋力": "str", "敏捷力": "dex", "耐久力": "con", "知力": "int", "判断力": "wis", "魅力": "cha"}

static func prof_bonus(lv: int) -> int:
	return 2 + (maxi(1, lv) - 1) / 4

static func skill_name(id: String) -> String:
	if SKILLS.has(id):
		return "〈%s〉" % SKILLS[id]["name"]
	if TOOLS.has(id):
		return String(TOOLS[id]["name"])
	return id

## そのクラスが、そのレベルまでに選ぶもの。[{key, lv, kind}](kind: asi / expertise)
static func schedule(cls: String, lv: int) -> Array:
	var out: Array = []
	var asi: Array = ASI_LEVELS.duplicate()
	asi.append_array(ASI_EXTRA.get(cls, []))
	asi.sort()
	for l in asi:
		if int(l) <= lv:
			out.append({"key": "asi%d" % int(l), "lv": int(l), "kind": "asi"})
	for l in EXPERTISE.get(cls, []):
		if int(l) <= lv:
			for s in ["a", "b"]:
				out.append({"key": "exp%d%s" % [int(l), s], "lv": int(l), "kind": "expertise"})
	out.sort_custom(func(x, y): return int(x["lv"]) < int(y["lv"]) or (int(x["lv"]) == int(y["lv"]) and String(x["key"]) < String(y["key"])))
	return out

## 作成時の技能の選び方が正しいか。picks は種族の分を含まない
static func picks_valid(cls: String, picks: Array) -> bool:
	var cp: Dictionary = CLASS_PROF[cls]
	var need := int(cp["count"]) + BACKGROUND_COUNT
	if picks.size() != need:
		return false
	var in_class := 0
	var seen := {}
	for p in picks:
		if not SKILLS.has(p) or seen.has(p):
			return false
		seen[p] = true
		if (cp["from"] as Array).has(p):
			in_class += 1
	return in_class >= int(cp["count"])

static func default_picks(cls: String, race: String) -> Array:
	var out: Array = []
	var fixed: Array = RACE_PROF.get(race, [])
	for p in DEFAULT_PICKS[cls]:
		if not fixed.has(p):
			out.append(p)
	# 種族と重なった分は、クラスの一覧か全体から補う
	var need := int(CLASS_PROF[cls]["count"]) + BACKGROUND_COUNT
	for p in SKILL_ORDER:
		if out.size() >= need:
			break
		if not out.has(p) and not fixed.has(p):
			out.append(p)
	out.resize(need)
	if not picks_valid(cls, out):
		out = []
		for p in CLASS_PROF[cls]["from"]:
			if out.size() < int(CLASS_PROF[cls]["count"]) and not fixed.has(p):
				out.append(p)
		for p in SKILL_ORDER:
			if out.size() >= need:
				break
			if not out.has(p) and not fixed.has(p):
				out.append(p)
	return out
