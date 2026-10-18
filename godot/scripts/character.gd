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
var stats := {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}   # 種族の補正と能力値上昇を含む最終値
var base_stats := {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}  # 作ったときの値(種族の補正を含む)
var profs: Array = []               # 作るときに選んだ技能(クラスと生い立ちの分。種族の分は含まない)
var birth := {}                     # 生まれ表の結果(Birth)。{origin, job, turn, reason}。無ければ空
var choices := {}                   # 能力値上昇・特技・熟達の選択。key(asi4 など) → {"take": "abil:str" / "abil:str+dex" / "feat:tough" / "exp:stealth"}
var hp := 1.0
var mp := 0.0
var equip := {"weapon": "", "armor": "", "acc": ""}
var skills: Array = []              # 覚えているスキルのid
var slots: Array = ["", "", "", "", "", ""] # スキル 1〜6(数字キー。Ctrl で選んで右クリックでも使う)。0 番目(スキル1)は武器の技
var hired := false                  # 酒場で加えた仲間(3人目と4人目)。宿で別れられる。作ったときの二人(主人公と相棒)は別れない
var belly := Cooking.BELLY_START    # 満腹度(0〜100)。迷宮で起きていると減る。30未満で「ぐぅ〜」、10未満で力と足が落ちる
var meal := {}                      # 料理の効き目(一人一つ) {"id", "buff", "v", "until"(世界の時刻)}。無ければ空
var skill_sel := 0                  # Ctrl で選んでいるスキル(0 = 通常攻撃、1〜6 = slots の 0〜5)。記録しない
const SLOTS := 6
const WEAPON_SKILL := "@weapon"     # 武器の技。skills と slots には、この名前で入る(中身は装備している武器で決まる)
var max_hp_cache := 1
var max_mp_cache := 0

static func create(nm: String, race_id: String, cls_id: String, point_stats: Dictionary, look_id: String = "M", picks: Array = [], birth_d: Dictionary = {}) -> Character:
	var c := Character.new()
	c.birth = Birth.sanitize(birth_d)
	c.name = nm
	c.look = look_id
	c.race = race_id
	c.cls = cls_id
	var bonus: Dictionary = Jobs.RACES[race_id]["bonus"]
	for a in Jobs.ABILS:
		c.base_stats[a] = int(point_stats[a]) + int(bonus.get(a, 0))
	c.profs = picks.duplicate() if Talents.picks_valid(cls_id, picks) else Talents.default_picks(cls_id, race_id)
	c.recalc_stats()
	c.give_starting_kit()
	c.learn(WEAPON_SKILL)      # スキル1 は武器の技
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
	for slot in ["weapon", "armor", "acc"]:     # 装飾品のほか、魔法の武器・防具にも fx がある(陽光の剣の灯りなど)
		var it := equip_item(slot)
		if it.has("fx"):
			t += float((it["fx"] as Dictionary).get(key, 0.0))
	match key:
		"hp_pct": t += meal_v("hp")
		"mp_pct": t += meal_v("mp")
		"light": t += meal_v("light")
	return t

## その種類の傷(fire など)を半分にする装備があるか(魔法の品の resist)
func resists(elem: String) -> bool:
	if elem == "":
		return false
	for slot in ["weapon", "armor", "acc"]:
		if (equip_item(slot).get("resist", []) as Array).has(elem):
			return true
	return false

## 魔法の武器の、魔物の種別ごとの倍率(破邪の鎚矛、竜殺しの剣)
func slay_mult(mon_type: String) -> float:
	var sl: Dictionary = equip_item("weapon").get("slay", {})
	return float(sl.get(mon_type.to_lower(), 1.0))

# ---------- 料理と満腹 ----------

## いま効いている料理の効き目(buff が違うか、切れていれば 0)
func meal_v(buff: String) -> float:
	if meal.is_empty() or String(meal.get("buff", "")) != buff or Cooking.clock >= float(meal.get("until", 0.0)):
		return 0.0
	return float(meal.get("v", 0.0))

func meal_active() -> bool:
	return not meal.is_empty() and Cooking.clock < float(meal.get("until", 0.0))

## "full"(満腹) / "ok" / "hungry"(空腹) / "starving"(腹ぺこ)
func hunger() -> String:
	if belly < Cooking.STARVING:
		return "starving"
	if belly < Cooking.HUNGRY:
		return "hungry"
	if belly >= 80.0:
		return "full"
	return "ok"

## 料理と空腹で変わる倍率(Hero.buff が掛ける)。power / guard / speed / spell
func food_mult(key: String) -> float:
	var m := 1.0
	var v := meal_v(key)
	if v != 0.0:
		m *= (1.0 - v) if key == "guard" else (1.0 + v)
	if hunger() == "starving":
		match key:
			"power": m *= 0.9
			"speed": m *= 0.95
	return m

# ---------- 派生値 ----------

func max_hp() -> int:
	var hit: int = class_data()["hit"]
	var con := mod("con")
	var base := hit + con + (level - 1) * (hit / 2 + 1 + con)
	base += int(float(Jobs.RACES[race]["hp_lv"]) * level)
	base = maxi(base, level * 4)
	if has_feat("tough"):
		base += level * 2
	var v := float(base) * Balance.HP_SCALE * (1.0 + equip_fx("hp_pct"))
	max_hp_cache = int(round(v))
	return max_hp_cache

func max_mp() -> int:
	var cd := class_data()
	var cm := maxi(0, mod(String(cd["cast"])))
	var v := (float(cd["mp0"]) + float(cd["mp_lv"]) * level + cm * level * 0.4) * (1.0 + equip_fx("mp_pct"))
	if has_feat("mana_well"):
		v *= 1.3
	max_mp_cache = int(round(v))
	return max_mp_cache

## 体当たりの毎秒ダメージ(バフ前、相手の防御前)
func bump_power() -> float:
	var cd := class_data()
	var p := float(cd["bump"]) + level * 0.9 + maxi(0, mod(String(cd["atk"]))) * 0.6
	var w := equip_item("weapon")
	if not w.is_empty():
		p += float(w["power"])
	if has_feat("heavy_hitter"):
		p *= 1.25
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
	if has_feat("mobile"):
		s *= 1.1
	var a := equip_item("armor")
	if not a.is_empty() and String(a["type"]) == "heavy" and not a.get("no_slow", false):
		s *= 0.92
	return s

func mass() -> float:
	var m := 1.0 + mod("str") * 0.08
	var a := equip_item("armor")
	if not a.is_empty():
		match String(a["type"]):
			"heavy": m += 0.25
			"medium": m += 0.0 if a.get("light_mass", false) else 0.1
	m *= 1.0 + skill_fx("athletics")
	if has_feat("grappler"):
		m *= 1.25
	return maxf(0.6, m) * (1.0 + equip_fx("mass_pct"))

func light_bonus() -> int:
	return int(Jobs.RACES[race]["light"]) + int(equip_fx("light"))

## 探る(F): 〈知覚〉と〈捜査〉の高いほう
func search_bonus() -> int:
	return maxi(skill_bonus("perception"), skill_bonus("investigation")) + (5 if has_feat("alert") else 0) + int(meal_v("eye"))

## 解錠と罠の解除: 【敏捷】+ 盗賊道具の習熟
func lock_bonus() -> int:
	return skill_bonus("thieves_tools") + int(meal_v("hand"))

## 受動〈知覚〉: 10 + 〈知覚〉
func passive_perception() -> int:
	return 10 + skill_bonus("perception") + (5 if has_feat("alert") else 0) + int(meal_v("eye"))

func roll_cooldown() -> float:
	var r := 1.0 - skill_fx("acrobatics")
	if has_feat("mobile"):
		r *= 0.75
	return Balance.ROLL_COOLDOWN * r

func regen_mp() -> float:
	return maxf(0.25, max_mp() * 0.012) * (1.5 if has_feat("mana_well") else 1.0)

## d20 を振る。幸運の特技があれば、5 以下を一度だけ振り直す
func roll_d20() -> int:
	var r := Dice.d20()
	if r <= 5 and has_feat("lucky"):
		r = Dice.d20()
	return r

## 魔物の種別ごとの、与えるダメージの倍率(〈自然〉〈宗教〉)
func dealt_mult(mon_type: String) -> float:
	var t := mon_type.to_lower()
	if t in ["beast", "plant", "ooze"] or t.begins_with("swarm"):
		return 1.0 + skill_fx("nature")
	if t in ["undead", "fiend", "celestial"]:
		return 1.0 + skill_fx("religion")
	return 1.0

## 魔物の種別ごとの、受けるダメージの倍率(〈動物使い〉〈看破〉、渾身)
func taken_mult(mon_type: String) -> float:
	var m := 1.1 if has_feat("heavy_hitter") else 1.0
	var t := mon_type.to_lower()
	if t == "beast" or t.begins_with("swarm"):
		m *= 1.0 - skill_fx("animal")
	elif t == "humanoid":
		m *= 1.0 - skill_fx("insight")
	return m

# ---------- 技能、セーヴ、能力値上昇、特技 ----------

func prof_bonus() -> int:
	return Talents.prof_bonus(level)

func proficient(id: String) -> bool:
	if profs.has(id) or (Talents.RACE_PROF.get(race, []) as Array).has(id):
		return true
	return (Talents.CLASS_PROF[cls]["tools"] as Array).has(id)

func expert(id: String) -> bool:
	for k in choices:
		if String(choices[k].get("take", "")) == "exp:" + id and _choice_level(String(k)) <= level:
			return true
	return false

## 判定の加値(能力値の補正 + 習熟 + 熟達)
func skill_bonus(id: String) -> int:
	var abil := String(Talents.SKILLS[id]["abil"]) if Talents.SKILLS.has(id) else String(Talents.TOOLS[id]["abil"])
	var b := mod(abil)
	if proficient(id):
		b += prof_bonus()
		if expert(id):
			b += prof_bonus()
	return b

## 技能のハクスラでの効き目(点 × 1点あたり、上限つき)
func skill_fx(id: String) -> float:
	var sk: Dictionary = Talents.SKILLS[id]
	return clampf(maxi(0, skill_bonus(id)) * float(sk["fx"]), 0.0, float(sk["cap"]))

func save_proficient(abil: String) -> bool:
	return (Talents.CLASS_PROF[cls]["saves"] as Array).has(abil)

func save_bonus(abil: String) -> int:
	return mod(abil) + (prof_bonus() if save_proficient(abil) else 0)

func feats() -> Array:
	var out: Array = []
	for k in choices:
		var t := String(choices[k].get("take", ""))
		if t.begins_with("feat:") and _choice_level(String(k)) <= level:
			out.append(t.substr(5))
	return out

func has_feat(id: String) -> bool:
	return feats().has(id)

func _choice_level(key: String) -> int:
	return int(key.lstrip("asiexp").rstrip("ab"))

## まだ選んでいない、能力値上昇・特技・熟達。[{key, lv, kind}]
func pending() -> Array:
	var out: Array = []
	for e in Talents.schedule(cls, level):
		if not choices.has(e["key"]):
			out.append(e)
	return out

## 選べるものか。選べないときは理由を返す(空なら選べる)
func choice_error(key: String, take: String) -> String:
	var entry: Dictionary = {}
	for e in pending():
		if e["key"] == key:
			entry = e
	if entry.is_empty():
		return "いまは選べない"
	var kind := String(entry["kind"])
	if kind == "asi":
		if take.begins_with("feat:"):
			var f := take.substr(5)
			if not Talents.FEATS.has(f):
				return "その特技は無い"
			if has_feat(f):
				return "もう持っている"
			return ""
		if take.begins_with("abil:"):
			var parts := take.substr(5).split("+")
			if parts.size() == 2 and parts[0] == parts[1]:
				return "+1 は別の能力値へ"
			for a in parts:
				if not Jobs.ABILS.has(a):
					return "その能力値は無い"
				if int(stats[a]) + (2 if parts.size() == 1 else 1) > 20:
					return "能力値は20までしか上がらない"
			return "" if parts.size() <= 2 else "選び方が違う"
		return "能力値上昇か特技を選ぶ"
	if kind == "expertise":
		if not take.begins_with("exp:"):
			return "熟達する技能を選ぶ"
		var id := take.substr(4)
		if not proficient(id):
			return "習熟している技能だけ"
		if expert(id):
			return "もう熟達している"
		return ""
	return "選べない"

func choose(key: String, take: String) -> String:
	var err := choice_error(key, take)
	if err != "":
		return err
	choices[key] = {"take": take}
	recalc_stats()
	clamp_resources()
	return ""

## 選んでいない分を、クラスに合わせて自動で埋める(闘技場や自動プレイ用)
func auto_fill_choices() -> void:
	for e in pending():
		if e["kind"] == "asi":
			var done := false
			for a in class_data()["prime"]:
				if int(stats[a]) <= 18:
					choose(String(e["key"]), "abil:" + String(a))
					done = true
					break
			if not done:
				for f in Talents.FEAT_ORDER:
					if choose(String(e["key"]), "feat:" + String(f)) == "":
						break
		else:
			var cand: Array = ["thieves_tools"]
			cand.append_array(Talents.SKILL_ORDER)
			for id in cand:
				if choose(String(e["key"]), "exp:" + String(id)) == "":
					break

## 作ったときの値に、いまのレベルまでの能力値上昇を足して、最終値を出す
func recalc_stats() -> void:
	for a in Jobs.ABILS:
		stats[a] = int(base_stats[a])
	for k in choices:
		if _choice_level(String(k)) > level:
			continue
		var t := String(choices[k].get("take", ""))
		if not t.begins_with("abil:"):
			continue
		var parts := t.substr(5).split("+")
		for a in parts:
			if Jobs.ABILS.has(a):
				stats[a] = mini(20, int(stats[a]) + (2 if parts.size() == 1 else 1))

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
	if sk.get("spell", false):
		d *= 1.0 + skill_fx("arcana")
	if sk.get("weapon", false) and favored_weapon():
		d *= Balance.FAVORED_TECH
		if has_feat("war_caster"):
			d *= 1.2
	if sk.get("kind", "") == "projectile" and has_feat("sharpshooter"):
		d *= 1.2
	return d

func skill_amount(sk: Dictionary) -> float:
	var stat_mod := maxi(0, mod(String(class_data()["cast"])))
	var n := float(sk.get("amount", 0.0)) + stat_mod * float(sk.get("stat", 0.0)) + level * float(sk.get("lv", 0.0))
	return n * heal_mult()

## 回復の倍率(〈医術〉、癒し手)
func heal_mult() -> float:
	return (1.0 + skill_fx("medicine")) * (1.3 if has_feat("healer") else 1.0)

## 装備している武器の種類("none" は素手)
func weapon_cat() -> String:
	var w := equip_item("weapon")
	return String(w.get("cat", "none")) if not w.is_empty() else "none"

## いまの武器の技の id。珍しい武器は固有の技。無ければ ""
func weapon_tech_id() -> String:
	var w := equip_item("weapon")
	if w.is_empty():
		return ""
	return String(w.get("tech", Jobs.WEAPON_TECH.get(String(w["cat"]), "")))

## クラスの得意武器を持っているか(classes.gd の weapons の先頭)
func favored_weapon() -> bool:
	var ws: Array = class_data()["weapons"]
	return not ws.is_empty() and weapon_cat() == String(ws[0])

## スキルの中身。武器の技(@weapon)は、いまの武器の技。無ければ {}
func skill_def(id: String) -> Dictionary:
	if id == WEAPON_SKILL:
		var t := weapon_tech_id()
		return Jobs.SKILLS.get(t, {})
	return Jobs.SKILLS.get(id, {})

## 画面に出すスキルの名前
func skill_label(id: String) -> String:
	if id == WEAPON_SKILL:
		var sk := skill_def(id)
		if sk.is_empty():
			return "武器の技(なし)"
		return "%s%s" % [sk["name"], "(得意)" if favored_weapon() else ""]
	return String(Jobs.SKILLS[id]["name"]) if Jobs.SKILLS.has(id) else id

func learn(id: String) -> bool:
	if skills.has(id) or (not Jobs.SKILLS.has(id) and id != WEAPON_SKILL):
		return false
	skills.append(id)
	for i in slots.size():
		if slots[i] == "":
			slots[i] = id
			break
	return true

## 武器の技をスキル1へ置き、ほかの割り当てはその後ろへ順に詰める(覚えていて枠の空きがあるものも入れる)
func _weapon_first() -> void:
	var rest: Array = []
	for id in slots:
		if String(id) != "" and String(id) != WEAPON_SKILL:
			rest.append(String(id))
	for id in skills:
		if String(id) != WEAPON_SKILL and not rest.has(String(id)):
			rest.append(String(id))
	slots = [WEAPON_SKILL]
	for i in SLOTS - 1:
		slots.append(String(rest[i]) if i < rest.size() else "")

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
		recalc_stats()
		learn_class_skills()
		hp = max_hp()
		mp = max_mp()
	return gained

func clamp_resources() -> void:
	hp = clampf(hp, 0.0, max_hp())
	mp = clampf(mp, 0.0, max_mp())

# ---------- 保存 ----------

func to_dict() -> Dictionary:
	return {"hired": hired, "name": name, "race": race, "cls": cls, "look": look, "level": level, "xp": xp, "stats": stats, "hp": hp, "mp": mp,
		"equip": equip, "skills": skills, "slots": slots, "base_stats": base_stats, "profs": profs, "choices": choices, "birth": birth,
		"belly": belly, "meal": meal}

static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.name = String(d.get("name", "名無し"))
	c.race = String(d.get("race", "human"))
	c.cls = String(d.get("cls", "fighter"))
	c.look = String(d.get("look", "M"))
	c.hired = bool(d.get("hired", false))
	c.birth = Birth.sanitize(d.get("birth", {}))
	c.level = int(d.get("level", 1))
	c.xp = int(d.get("xp", 0))
	# 古いセーブには base_stats が無い。そのときは、いまの能力値を作ったときの値とみなす
	var st: Dictionary = d.get("base_stats", d.get("stats", {}))
	for a in Jobs.ABILS:
		c.base_stats[a] = int(st.get(a, 10))
	var pk: Array = []
	for p in d.get("profs", []):
		pk.append(String(p))
	c.profs = pk if Talents.picks_valid(c.cls, pk) else Talents.default_picks(c.cls, c.race)
	var ch_d: Dictionary = d.get("choices", {})
	for k in ch_d:
		c.choices[String(k)] = {"take": String((ch_d[k] as Dictionary).get("take", ""))}
	c.recalc_stats()
	var eq: Dictionary = d.get("equip", {})
	for k in ["weapon", "armor", "acc"]:
		c.equip[k] = String(eq.get(k, ""))
	c.skills = []
	for s in d.get("skills", []):
		c.skills.append(String(s))
	c.slots = []
	c.slots.resize(SLOTS)
	c.slots.fill("")
	var sl: Array = d.get("slots", [])
	for i in mini(SLOTS, sl.size()):
		c.slots[i] = String(sl[i])
	if not c.skills.has(WEAPON_SKILL):
		c.skills.append(WEAPON_SKILL)      # 武器の技より前の記録
	if sl.size() < SLOTS:
		c._weapon_first()          # 枠が4つだった頃の記録: 武器の技をスキル1へ寄せ、ほかを後ろへ詰める
	c.belly = clampf(float(d.get("belly", Cooking.BELLY_START)), 0.0, Cooking.BELLY_MAX)
	var ml: Variant = d.get("meal", {})
	if typeof(ml) == TYPE_DICTIONARY and not (ml as Dictionary).is_empty():
		c.meal = {"id": String(ml.get("id", "")), "buff": String(ml.get("buff", "")), "v": float(ml.get("v", 0.0)), "until": float(ml.get("until", 0.0))}
	c.hp = float(d.get("hp", c.max_hp()))
	c.mp = float(d.get("mp", c.max_mp()))
	c.clamp_resources()
	return c
