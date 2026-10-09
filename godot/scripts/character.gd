class_name Character
extends RefCounted
## キャラクター一人分のデータ(迷宮の中の体は Hero ノードが持つ)。
## HP と MP は小数で持ち、体当たりの細かいダメージを積み上げる。

var name := "名無し"
var race := "human"
var cls := "fighter"
var look := "M"                     # 見た目(スプライトシート): M 男性 / F 女性
var level := 1
var xp := 0
var stats := {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}   # 種族の補正を含む最終値
var hp := 1.0
var mp := 0.0
var equip := {"weapon": "", "armor": "", "acc": ""}
var skills: Array = []              # 覚えているスキルのid
var slots: Array = ["", "", "", ""] # ショートカット 1〜4
var max_hp_cache := 1
var max_mp_cache := 0

static func create(nm: String, race_id: String, cls_id: String, base_stats: Dictionary, look_id: String = "M") -> Character:
	var c := Character.new()
	c.name = nm
	c.look = look_id
	c.race = race_id
	c.cls = cls_id
	var bonus: Dictionary = Jobs.RACES[race_id]["bonus"]
	for a in Jobs.ABILS:
		c.stats[a] = int(base_stats[a]) + int(bonus.get(a, 0))
	c.give_starting_kit()
	c.learn_class_skills()
	c.hp = c.max_hp()
	c.mp = c.max_mp()
	return c

func give_starting_kit() -> void:
	match cls:
		"fighter": equip = {"weapon": "shortsword", "armor": "leather", "acc": ""}
		"barbarian": equip = {"weapon": "handaxe", "armor": "leather", "acc": ""}
		"rogue": equip = {"weapon": "dagger", "armor": "leather", "acc": ""}
		"wizard": equip = {"weapon": "quarterstaff", "armor": "robe", "acc": ""}
		"cleric": equip = {"weapon": "mace", "armor": "leather", "acc": ""}
		"ranger": equip = {"weapon": "shortbow", "armor": "leather", "acc": ""}

func mod(a: String) -> int:
	return int(floor((int(stats[a]) - 10) / 2.0))

func class_data() -> Dictionary:
	return Jobs.CLASSES[cls]

func equip_item(slot: String) -> Dictionary:
	var id := String(equip.get(slot, ""))
	return ItemDB.ITEMS[id] if id != "" and ItemDB.ITEMS.has(id) else {}

func equip_fx(key: String) -> float:
	var t := 0.0
	var acc := equip_item("acc")
	if not acc.is_empty():
		t += float((acc["fx"] as Dictionary).get(key, 0.0))
	return t

# ---------- 派生値 ----------

func max_hp() -> int:
	var hit: int = class_data()["hit"]
	var con := mod("con")
	var base := hit + con + (level - 1) * (hit / 2 + 1 + con)
	base += int(float(Jobs.RACES[race]["hp_lv"]) * level)
	base = maxi(base, level * 4)
	var v := float(base) * Balance.HP_SCALE * (1.0 + equip_fx("hp_pct"))
	max_hp_cache = int(round(v))
	return max_hp_cache

func max_mp() -> int:
	var cd := class_data()
	var cm := maxi(0, mod(String(cd["cast"])))
	var v := (float(cd["mp0"]) + float(cd["mp_lv"]) * level + cm * level * 0.4) * (1.0 + equip_fx("mp_pct"))
	max_mp_cache = int(round(v))
	return max_mp_cache

## 体当たりの毎秒ダメージ(バフ前、相手の防御前)
func bump_power() -> float:
	var cd := class_data()
	var p := float(cd["bump"]) + level * 0.9 + maxi(0, mod(String(cd["atk"]))) * 0.6
	var w := equip_item("weapon")
	if not w.is_empty():
		p += float(w["power"])
	return p * Balance.BUMP_SCALE * (1.0 + equip_fx("power_pct"))

func armor_class() -> int:
	var ac := 10 + int(equip_fx("ac"))
	var a := equip_item("armor")
	var dex := mod("dex")
	if a.is_empty():
		ac += dex
	else:
		ac += int(a["ac"])
		match String(a["type"]):
			"none", "light": ac += dex
			"medium": ac += mini(dex, 2)
	return ac

## 受けるダメージの軽減率
func damage_reduction() -> float:
	return clampf((armor_class() - 10) * Balance.AC_REDUCTION, 0.0, 0.6)

func speed() -> float:
	var s := Balance.HERO_SPEED * (1.0 + equip_fx("speed_pct"))
	var a := equip_item("armor")
	if not a.is_empty() and String(a["type"]) == "heavy":
		s *= 0.92
	return s

func mass() -> float:
	var m := 1.0 + mod("str") * 0.08
	var a := equip_item("armor")
	if not a.is_empty():
		match String(a["type"]):
			"heavy": m += 0.25
			"medium": m += 0.1
	return maxf(0.6, m) * (1.0 + equip_fx("mass_pct"))

func light_bonus() -> int:
	return int(Jobs.RACES[race]["light"]) + int(equip_fx("light"))

func search_bonus() -> int:
	return Balance.skill_bonus(level) + int(class_data()["search"])

func lock_bonus() -> int:
	return Balance.skill_bonus(level) + int(class_data()["lock"])

func regen_mp() -> float:
	return maxf(0.25, max_mp() * 0.012)

## その装備に替えたときの変化(体当たり、防御、HP、MP)を文にする
func compare_equip(id: String) -> String:
	var slot := ItemDB.slot_of(id)
	if slot == "":
		return ""
	var old := String(equip[slot])
	var b0 := bump_power()
	var a0 := armor_class()
	var h0 := max_hp()
	var m0 := max_mp()
	equip[slot] = id
	var b1 := bump_power()
	var a1 := armor_class()
	var h1 := max_hp()
	var m1 := max_mp()
	equip[slot] = old
	var parts: Array = ["体当たり %.1f→%.1f" % [b0, b1], "防御 %d→%d" % [a0, a1]]
	if h0 != h1:
		parts.append("HP %d→%d" % [h0, h1])
	if m0 != m1:
		parts.append("MP %d→%d" % [m0, m1])
	return "  ".join(parts)

# ---------- スキル ----------

func skill_damage(sk: Dictionary) -> float:
	var stat_mod := maxi(0, mod(String(class_data()["cast"])))
	var d := float(sk.get("dmg", 0.0)) + stat_mod * float(sk.get("stat", 0.0)) + level * float(sk.get("lv", 0.0))
	if sk.get("spell", false) or sk.get("kind", "") == "projectile":
		var w := equip_item("weapon")
		if not w.is_empty():
			d += float(w.get("spell", 0.0))
	return d

func skill_amount(sk: Dictionary) -> float:
	var stat_mod := maxi(0, mod(String(class_data()["cast"])))
	return float(sk.get("amount", 0.0)) + stat_mod * float(sk.get("stat", 0.0)) + level * float(sk.get("lv", 0.0))

func learn(id: String) -> bool:
	if skills.has(id) or not Jobs.SKILLS.has(id):
		return false
	skills.append(id)
	for i in slots.size():
		if slots[i] == "":
			slots[i] = id
			break
	return true

func learn_class_skills() -> Array:
	var gained: Array = []
	for entry in class_data()["skills"]:
		if level >= int(entry[0]) and learn(String(entry[1])):
			gained.append(String(entry[1]))
	return gained

func xp_for_next() -> int:
	return int(Balance.XP_LEVELS[mini(level, Balance.XP_LEVELS.size() - 1)])

## 経験点を加え、上がったレベル数を返す。上がったときは全快
func gain_xp(n: int) -> int:
	if level >= 20:
		return 0
	xp += n
	var gained := 0
	while level < 20 and xp >= int(Balance.XP_LEVELS[level]):
		level += 1
		gained += 1
	if gained > 0:
		learn_class_skills()
		hp = max_hp()
		mp = max_mp()
	return gained

func clamp_resources() -> void:
	hp = clampf(hp, 0.0, max_hp())
	mp = clampf(mp, 0.0, max_mp())

# ---------- 保存 ----------

func to_dict() -> Dictionary:
	return {"name": name, "race": race, "cls": cls, "look": look, "level": level, "xp": xp, "stats": stats, "hp": hp, "mp": mp,
		"equip": equip, "skills": skills, "slots": slots}

static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.name = String(d.get("name", "名無し"))
	c.race = String(d.get("race", "human"))
	c.cls = String(d.get("cls", "fighter"))
	c.look = String(d.get("look", "M"))
	c.level = int(d.get("level", 1))
	c.xp = int(d.get("xp", 0))
	var st: Dictionary = d.get("stats", {})
	for a in Jobs.ABILS:
		c.stats[a] = int(st.get(a, 10))
	var eq: Dictionary = d.get("equip", {})
	for k in ["weapon", "armor", "acc"]:
		c.equip[k] = String(eq.get(k, ""))
	c.skills = []
	for s in d.get("skills", []):
		c.skills.append(String(s))
	c.slots = ["", "", "", ""]
	var sl: Array = d.get("slots", [])
	for i in mini(4, sl.size()):
		c.slots[i] = String(sl[i])
	c.hp = float(d.get("hp", c.max_hp()))
	c.mp = float(d.get("mp", c.max_mp()))
	c.clamp_resources()
	return c
